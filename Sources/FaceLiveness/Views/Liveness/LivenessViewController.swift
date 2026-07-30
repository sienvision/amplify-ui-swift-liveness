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

    // SONDER PATCH: keep the (possibly oval-recentered) camera position
    // across layout passes.
    private var cameraLayerPosition: CGPoint?

    override func viewDidLayoutSubviews() {
        previewLayer?.position = cameraLayerPosition ?? view.center
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
        // The extra 12% overscan leaves slack to recenter the oval on
        // screen (see drawOvalInCanvas) without uncovering an edge.
        let fillScale = max(view.frame.width / 3.0, view.frame.height / 4.0) * 1.12
        let width = 3.0 * fillScale
        let height = 4.0 * fillScale
        let cameraFrame = CGRect(x: 0, y: 0, width: width, height: height)

        guard let avLayer = viewModel.configureCamera(withinFrame: cameraFrame) else {
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.livenessState
                    .unrecoverableStateEncountered(.missingVideoPermission)
            }
            return
        }

        avLayer.position = view.center
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
    func displaySingleFrame(uiImage: UIImage) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let previewLayer = self.previewLayer else { return }
            let imageView = UIImageView(image: uiImage)
            imageView.frame = previewLayer.frame
            self.view.addSubview(imageView)
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

            // SONDER PATCH: nudge the camera (and the oval with it) so the
            // oval sits in the middle of the screen, limited to the slack
            // the overscanned camera leaves before uncovering an edge. Pure
            // display translation — matching happens in camera-rect space.
            let layerFrame = previewLayer.frame
            let slackX = max(0, (layerFrame.width - self.view.frame.width) / 2)
            let slackY = max(0, (layerFrame.height - self.view.frame.height) / 2)
            let ovalCenterInView = CGPoint(
                x: layerFrame.minX + ovalRect.midX,
                y: layerFrame.minY + ovalRect.midY
            )
            let shiftX = min(max(self.view.center.x - ovalCenterInView.x, -slackX), slackX)
            let shiftY = min(max(self.view.center.y - ovalCenterInView.y, -slackY), slackY)
            let position = CGPoint(
                x: previewLayer.position.x + shiftX,
                y: previewLayer.position.y + shiftY
            )
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.position = position
            CATransaction.commit()
            self.cameraLayerPosition = position

            let ovalView = OvalView(
                frame: previewLayer.frame,
                ovalFrame: ovalRect
            )
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
