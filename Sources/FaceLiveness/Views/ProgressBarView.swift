//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct ProgressBarView: View {
    let emptyColor: Color
    let borderColor: Color
    let fillColor: Color
    let indicatorColor: Color
    let percentage: Double

    // SONDER PATCH: AWS's bordered bar replaced with a slim capsule track,
    // vertically centered in the frame the callers give it.
    var body: some View {
        GeometryReader { proxy in
            VStack {
                Spacer(minLength: 0)
                ZStack(alignment: .leading) {
                    Capsule()
                        .frame(width: proxy.size.width, height: 6)
                        .foregroundColor(emptyColor)

                    Capsule()
                        .frame(
                            width: min(percentage, 1) * proxy.size.width,
                            height: 6
                        )
                        .foregroundColor(fillColor)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
