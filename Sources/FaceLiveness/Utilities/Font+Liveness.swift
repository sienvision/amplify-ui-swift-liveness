//
// SONDER PATCH: typography for the vendored liveness UI. The Nunito faces
// are registered by the app itself (expo-font embeds the TTFs), so they are
// referenced by PostScript name; Font.custom falls back to the system font
// if a face is ever missing.
//

import SwiftUI

extension Font {
    /// Instruction pill / headline text.
    static let livenessInstruction = Font.custom("Nunito-ExtraBold", size: 20)
    /// Secondary / body copy.
    static let livenessBody = Font.custom("Nunito-Bold", size: 15)
    /// Small chips (REC indicator).
    static let livenessChip = Font.custom("Nunito-ExtraBold", size: 12)
}
