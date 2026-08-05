//
// SONDER PATCH: shared layout adjustments for the production liveness flow
// and its simulator preview.
//

import CoreGraphics

enum LivenessLayout {
    /// Leaves breathing room between the progress bar and camera window.
    static let cameraVerticalOffset: CGFloat = 20

    /// Preserves the service-provided oval aspect ratio while adding inset
    /// space between it and every edge of the camera window.
    static let ovalScale: CGFloat = 0.84

    static func insetOval(_ rect: CGRect) -> CGRect {
        let width = rect.width * ovalScale
        let height = rect.height * ovalScale

        return CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }
}
