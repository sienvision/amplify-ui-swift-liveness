//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//
// SONDER PATCH: AWS's teal palette replaced with the Sonder palette
// (apps/app/src/constants/colors.ts). The app ships light-only, so both
// variants carry the light values.
//

import SwiftUI

extension Color {
    /// Instruction pill background — scarabaeus-800.
    static let livenessPrimaryBackground = Color.dynamicColors(
        light: .hex("#323232"),
        dark: .hex("#323232")
    )

    static let livenessPrimaryLabel = Color.dynamicColors(
        light: .hex("#FEFAFF"),
        dark: .hex("#FEFAFF")
    )

    /// Screen canvas — APP_BG (almost-white).
    static let livenessBackground = Color.dynamicColors(
        light: .hex("#FEFAFF"),
        dark: .hex("#FEFAFF")
    )

    static let livenessLabel = Color.dynamicColors(
        light: .hex("#323232"),
        dark: .hex("#323232")
    )

    /// Error pill — Sonder orange-600.
    static let livenessErrorBackground = Color.dynamicColors(
        light: .hex("#FC5A43"),
        dark: .hex("#FC5A43")
    )

    static let livenessErrorLabel = Color.dynamicColors(
        light: .hex("#FEFAFF"),
        dark: .hex("#FEFAFF")
    )

    /// Warning box — love-200 surface, scarabaeus-800 text.
    static let livenessWarningBackground = Color.dynamicColors(
        light: .hex("#FAECFF"),
        dark: .hex("#FAECFF")
    )

    static let livenessWarningLabel = Color.dynamicColors(
        light: .hex("#323232"),
        dark: .hex("#323232")
    )

    static let livenessPreviewBorder = Color.dynamicColors(
        light: .hex("#E6E6E6"),
        dark: .hex("#E6E6E6")
    )

    /// SONDER ADDITION: progress capsule — scarabaeus-100 track,
    /// love-700 fill (the verified-badge color).
    static let livenessProgressTrack = Color.hex("#F3F3F3")
    static let livenessProgressFill = Color.hex("#CE76E4")
}
