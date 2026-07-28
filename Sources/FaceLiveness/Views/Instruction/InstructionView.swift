//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI

struct InstructionView: View {
    let text: String
    let backgroundColor: Color
    var textColor: Color = .livenessLabel
    var font: Font = .body
    
    var body: some View {
        // SONDER PATCH: rounded-full pill, matching the app's chips.
        Text(text)
            .foregroundColor(textColor)
            .font(font)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(backgroundColor))
    }
}
