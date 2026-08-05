//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
import SwiftUI
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

/// Visual states exposed by ``FaceLivenessPreviewView``.
///
/// Each case maps directly to a state rendered by the production liveness state
/// machine. The preview changes only the camera input and state driver; all
/// visible liveness chrome is shared with ``FaceLivenessDetectorView``.
public enum FaceLivenessPreviewState: String, CaseIterable, Sendable {
    case camera
    case noFace = "no-face"
    case notInOval = "not-in-oval"
    case moveCloser = "move-closer"
    case moveBack = "move-back"
    case moveLeft = "move-left"
    case moveRight = "move-right"
    case moveToDimmerArea = "move-to-dimmer-area"
    case moveToBrighterArea = "move-to-brighter-area"
    case multipleFaces = "multiple-faces"
    case holdStill = "hold-still"
    case freshness
    case verifying

    fileprivate func livenessState(progress: Double) -> LivenessStateMachine.State {
        switch self {
        case .camera:
            return .waitForRecording
        case .noFace:
            return .pendingFacePreparedConfirmation(.noFace)
        case .notInOval:
            return .pendingFacePreparedConfirmation(.notInOval)
        case .moveCloser:
            return .awaitingFaceInOvalMatch(.moveFaceCloser, progress)
        case .moveBack:
            return .awaitingFaceInOvalMatch(.faceTooClose, progress)
        case .moveLeft:
            return .awaitingFaceInOvalMatch(.moveFaceLeft, progress)
        case .moveRight:
            return .awaitingFaceInOvalMatch(.moveFaceRight, progress)
        case .moveToDimmerArea:
            return .pendingFacePreparedConfirmation(.moveToDimmerArea)
        case .moveToBrighterArea:
            return .pendingFacePreparedConfirmation(.moveToBrighterArea)
        case .multipleFaces:
            return .pendingFacePreparedConfirmation(.multipleFaces)
        case .holdStill:
            return .faceMatched
        case .freshness:
            return .displayingFreshness
        case .verifying:
            return .completedDisplayingFreshness
        }
    }
}

/// Simulator-safe rendering of the production face-liveness UI.
///
/// This view composes the same `_FaceLivenessDetectionView`, camera controller,
/// oval renderer, instruction container, progress bar, and close button used by
/// ``FaceLivenessDetectorView``. It substitutes a still-image layer for the
/// capture session and a selected state for the live detector, so it never
/// opens the camera, contacts AWS, or consumes a liveness attempt.
public struct FaceLivenessPreviewView: View {
    @StateObject private var viewModel: FaceLivenessDetectionViewModel

    private let state: FaceLivenessPreviewState
    private let imageURL: URL?
    private let oval: CGRect
    private let freshnessColor: UIColor

    /// Creates a production-UI preview.
    ///
    /// - Parameters:
    ///   - state: Detector state to render.
    ///   - progress: Progress bar value, clamped to `0...1`.
    ///   - imageURL: Optional still image used in place of the camera feed.
    ///   - oval: Oval frame normalized to the production camera window.
    ///   - freshnessColor: Static color shown for the freshness state.
    ///   - onClose: Action invoked by the production close button.
    public init(
        state: FaceLivenessPreviewState = .moveCloser,
        progress: Double = 0.45,
        imageURL: URL? = nil,
        oval: CGRect = CGRect(x: 0.16, y: 0.16, width: 0.68, height: 0.62),
        freshnessColor: UIColor = UIColor(red: 240 / 255, green: 191 / 255, blue: 255 / 255, alpha: 1),
        onClose: @escaping () -> Void = {}
    ) {
        let clampedProgress = min(max(progress, 0), 1)
        let faceDetector = FaceLivenessPreviewFaceDetector()
        let videoChunker = VideoChunker(
            assetWriter: LivenessAVAssetWriter(),
            assetWriterDelegate: VideoChunker.AssetWriterDelegate(),
            assetWriterInput: LivenessAVAssetWriterInput()
        )
        let captureSession = FaceLivenessPreviewCaptureSession(
            imageURL: imageURL,
            faceDetector: faceDetector,
            videoChunker: videoChunker
        )
        let viewModel = FaceLivenessDetectionViewModel(
            faceDetector: faceDetector,
            faceInOvalMatching: FaceInOvalMatching(instructor: Instructor()),
            videoChunker: videoChunker,
            stateMachine: LivenessStateMachine(
                state: state.livenessState(progress: clampedProgress)
            ),
            closeButtonAction: onClose,
            sessionID: "preview",
            isPreviewScreenEnabled: false,
            challengeOptions: .init()
        )

        viewModel.captureSession = captureSession
        viewModel.challengeReceived = .faceMovementAndLightChallenge("2.0.0")
        viewModel.closeButtonAction = onClose

        self._viewModel = StateObject(wrappedValue: viewModel)
        self.state = state
        self.imageURL = imageURL
        self.oval = oval
        self.freshnessColor = freshnessColor
    }

    public var body: some View {
        _FaceLivenessDetectionView(
            viewModel: viewModel,
            videoView: {
                FaceLivenessPreviewCameraView(
                    viewModel: viewModel,
                    state: state,
                    oval: oval,
                    freshnessColor: freshnessColor
                )
            }
        )
        .id(imageURL)
    }
}

private struct FaceLivenessPreviewCameraView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel
    let state: FaceLivenessPreviewState
    let oval: CGRect
    let freshnessColor: UIColor

    func makeUIViewController(context: Context) -> _LivenessViewController {
        let controller = _LivenessViewController(viewModel: viewModel)
        controller.loadViewIfNeeded()

        DispatchQueue.main.async {
            configure(controller)
        }

        return controller
    }

    func updateUIViewController(
        _ controller: _LivenessViewController,
        context: Context
    ) {
        DispatchQueue.main.async {
            configure(controller)
        }
    }

    private func configure(_ controller: _LivenessViewController) {
        guard let previewLayer = controller.previewLayer else { return }

        if !controller.ovalExists, state != .camera {
            let size = previewLayer.bounds.size
            controller.drawOvalInCanvas(
                CGRect(
                    x: oval.minX * size.width,
                    y: oval.minY * size.height,
                    width: oval.width * size.width,
                    height: oval.height * size.height
                )
            )
        }

        if state == .freshness {
            controller.freshnessView.alpha = controller.freshness.initialAlpha
            controller.freshnessView.backgroundColor = freshnessColor
        } else {
            controller.freshnessView.clearColors()
        }
    }
}

private final class FaceLivenessPreviewCaptureSession: LivenessCaptureSession {
    private let imageURL: URL?

    init(
        imageURL: URL?,
        faceDetector: FaceDetector,
        videoChunker: VideoChunker
    ) {
        self.imageURL = imageURL
        super.init(
            captureDevice: LivenessCaptureDevice(avCaptureDevice: nil),
            outputDelegate: OutputSampleBufferCapturer(
                faceDetector: faceDetector,
                videoChunker: videoChunker
            )
        )
    }

    override func configureCamera(frame: CGRect) throws -> CALayer {
        let layer = CAGradientLayer()
        layer.frame = frame
        layer.colors = [
            UIColor(red: 0.83, green: 0.79, blue: 0.86, alpha: 1).cgColor,
            UIColor(red: 0.48, green: 0.43, blue: 0.53, alpha: 1).cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.contentsGravity = .resizeAspectFill

        guard let imageURL else { return layer }

        URLSession.shared.dataTask(with: imageURL) { data, _, _ in
            guard let data, let image = UIImage(data: data)?.cgImage else { return }
            DispatchQueue.main.async {
                layer.colors = nil
                layer.contents = image
            }
        }.resume()

        return layer
    }

    override func startSession() {}
    override func stopRunning() {}
}

private final class FaceLivenessPreviewFaceDetector: FaceDetector {
    func detectFaces(from buffer: CVPixelBuffer) {}
    func setResultHandler(detectionResultHandler: FaceDetectionResultHandler) {}
}
