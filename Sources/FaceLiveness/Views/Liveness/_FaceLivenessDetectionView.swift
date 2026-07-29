//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct _FaceLivenessDetectionView<VideoView: View>: View {
    let videoView: VideoView
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel
    @Binding var displayResultsView: Bool

    init(
        viewModel: FaceLivenessDetectionViewModel,
        @ViewBuilder videoView: @escaping () -> VideoView
    ) {
        self.viewModel = viewModel
        self.videoView = videoView()

        self._displayResultsView = .init(
            get: { viewModel.livenessState.state == .completed },
            set: { _ in }
        )
    }

    // SONDER PATCH: the camera fills the whole screen (center-cropped by the
    // view controller) instead of sitting in a letterboxed 3:4 window, the
    // REC indicator is gone, and the overlay chrome respects the safe area.
    var body: some View {
        ZStack {
            Color.livenessBackground
                .edgesIgnoringSafeArea(.all)
            videoView
                .edgesIgnoringSafeArea(.all)
            VStack {
                HStack(alignment: .top) {
                    Spacer()

                    CloseButton(
                        action: viewModel.closeButtonAction
                    )
                }
                .padding()

                InstructionContainerView(
                    viewModel: viewModel
                )

                Spacer()
            }
            .padding([.leading, .trailing])
        }
    }
}
