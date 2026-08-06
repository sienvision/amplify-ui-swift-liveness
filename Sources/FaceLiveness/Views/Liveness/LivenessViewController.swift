//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import UIKit
import AVFoundation
import Vision
import Amplify
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

final class _LivenessViewController: UIViewController {
    let viewModel: FaceLivenessDetectionViewModel
    var previewLayer: CALayer?

    let faceShapeLayer = CAShapeLayer()
    var ovalExists = false
    var ovalRect: CGRect?
    var freshness = Freshness()
    let freshnessView = FreshnessView()
    var readyForOval = false

    init(
        viewModel: FaceLivenessDetectionViewModel
    ) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        viewModel.livenessViewControllerDelegate = self
        viewModel.normalizeFace = { [weak self] face in
            guard let self = self else { return face }
            return DispatchQueue.main.sync {
                // SONDER PATCH: normalize into the same rect all other
                // geometry uses (the screen-covering camera rect) instead of
                // a hardcoded width-fit 3:4 box — with the covering camera
                // the old math shrank faces relative to the oval and the
                // face match could never progress.
                face.normalize(
                    width: self.viewModel.cameraViewRect.width,
                    height: self.viewModel.cameraViewRect.height
                )
            }
        }
    }
    
    deinit {
        guard let previewLayer = self.previewLayer else { return }
        previewLayer.removeFromSuperlayer()
        (previewLayer as? AVCaptureVideoPreviewLayer)?.session = nil
        self.previewLayer = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // SONDER PATCH: match the app background instead of black.
        view.backgroundColor = UIColor(red: 254/255, green: 250/255, blue: 255/255, alpha: 1)
        layoutSubviews()
        setupAVLayer()
    }

    // SONDER PATCH: the camera renders in a rounded 3:4 window
    // instead of covering the screen, so the oval reads as a portrait frame
    // rather than swallowing the whole page. Same-aspect scaling of the
    // upstream geometry — detection, oval, and streamed video are unchanged.
    private var cameraWindowSize: CGSize {
        let width = min(
            view.bounds.width * 0.84,
            view.bounds.height * 0.58 * 3 / 4
        )
        return CGSize(width: width, height: width / 3 * 4)
    }

    private var cameraWindowCenter: CGPoint {
        CGPoint(
            x: view.bounds.midX,
            y: view.bounds.midY + LivenessLayout.cameraVerticalOffset
        )
    }

    override func viewDidLayoutSubviews() {
        previewLayer?.position = cameraWindowCenter
        ovalView?.center = cameraWindowCenter
        view.viewWithTag(Self.verificationPlaceholderTag)?.frame = cameraWindowFrame
    }

    private static let verificationPlaceholderTag = 8_141

    private var cameraWindowFrame: CGRect {
        let size = cameraWindowSize
        return CGRect(
            x: cameraWindowCenter.x - size.width / 2,
            y: cameraWindowCenter.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    // SONDER PATCH: once capture is complete, cover the frozen selfie with a
    // neutral loading state while the recorded video finishes uploading.
    func displayVerificationPlaceholder() {
        guard view.viewWithTag(Self.verificationPlaceholderTag) == nil else { return }

        let placeholder = UIView(frame: cameraWindowFrame)
        placeholder.tag = Self.verificationPlaceholderTag
        placeholder.backgroundColor = UIColor(
            red: 243 / 255,
            green: 243 / 255,
            blue: 243 / 255,
            alpha: 1
        )
        placeholder.layer.cornerRadius = 24
        placeholder.layer.masksToBounds = true

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor(
            red: 169 / 255,
            green: 169 / 255,
            blue: 169 / 255,
            alpha: 1
        )
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        placeholder.addSubview(spinner)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: placeholder.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: placeholder.centerYAnchor)
        ])

        view.addSubview(placeholder)
    }

    private func layoutSubviews() {
        freshnessView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(freshnessView)
        NSLayoutConstraint.activate([
            freshnessView.topAnchor.constraint(equalTo: view.topAnchor),
            freshnessView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            freshnessView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            freshnessView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        freshnessView.clearColors()
    }

    private func setupAVLayer() {
        guard previewLayer == nil else { return }
        // SONDER PATCH: scale the 3:4 camera rect up to COVER the screen
        // (center-crop) instead of letterboxing it. Every piece of face/oval
        // geometry derives from this same rect, so coordinates remain
        // self-consistent, and the streamed video is the raw camera feed
        // either way. The aspect ratio must stay 3:4.
        let size = cameraWindowSize
        let cameraFrame = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        guard let avLayer = viewModel.configureCamera(withinFrame: cameraFrame) else {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.livenessState
                    .unrecoverableStateEncountered(.missingVideoPermission)
            }
            return
        }

        avLayer.position = cameraWindowCenter
        avLayer.cornerRadius = 24
        avLayer.masksToBounds = true
        self.previewLayer = avLayer
        if let previewLayer = self.previewLayer {
            viewModel.cameraViewRect = previewLayer.frame
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.layer.insertSublayer(avLayer, at: 0)
            self.view.layoutIfNeeded()

            self.viewModel.startSession()
        }
    }

    var runningFreshness = false
    var hasSentClientInformationEvent = false
    var challengeID = UUID().uuidString
    var initialFace: FaceDetection?
    var videoStartTimeStamp: UInt64?
    var faceMatchStartTime: UInt64?
    var freshnessEventsComplete = false
    var videoSentCount = 0
    var hasSentFinalEvent = false
    var hasSentEmptyFinalVideoEvent = false
    var ovalView: OvalView?


    required init?(coder: NSCoder) { fatalError() }
}

extension _LivenessViewController: FaceLivenessViewControllerPresenter {
    func displaySingleFrame(uiImage _: UIImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let previewLayer = self.previewLayer else { return }
            self.displayVerificationPlaceholder()
            (previewLayer as? AVCaptureVideoPreviewLayer)?.session = nil
            previewLayer.removeFromSuperlayer()
            self.viewModel.stopRecording()
        }
    }

    func displayFreshness(colorSequences: [FaceLivenessSession.DisplayColor]) {
        self.ovalView?.setNeedsDisplay()
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.livenessState.displayingFreshness()
        }
        self.freshness.showColorSequences(
            colorSequences,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height,
            view: self.freshnessView,
            onNewColor: { [weak self] colorEvent in
                self?.viewModel.sendColorDisplayedEvent(colorEvent)
            },
            onComplete: { [weak self] in
                guard let self else { return }
                self.freshnessView.removeFromSuperview()

                self.viewModel.handleFreshnessComplete()
            }
        )
    }

    func drawOvalInCanvas(_ ovalRect: CGRect) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let previewLayer = self.previewLayer else { return }

            let ovalView = OvalView(
                frame: previewLayer.frame,
                ovalFrame: ovalRect
            )
            // SONDER PATCH: clip the dimmed oval overlay to the rounded
            // camera window.
            ovalView.layer.cornerRadius = 24
            ovalView.layer.masksToBounds = true
            self.ovalView = ovalView
            ovalView.center = previewLayer.position
            self.view.insertSubview(
                ovalView,
                belowSubview: self.freshnessView
            )

            self.ovalRect = ovalRect
            self.ovalExists = true
        }
    }
    
    func completeNoLightCheck() {
        self.viewModel.completeNoLightCheck()
    }
}
