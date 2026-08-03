# Sonder patch

This fork restyles the liveness UI chrome as Sonder while leaving the
check itself — streaming/session logic, oval geometry, face detection,
and the flash (freshness) sequence — byte-identical to upstream.

Patched (all hunks marked `SONDER PATCH` / `SONDER ADDITION`):

- `Utilities/Color+Liveness.swift` — AWS teal → Sonder palette
- `Utilities/Font+Liveness.swift` — NEW: Nunito typography (faces are
  registered by the consuming app; falls back to the system font)
- `Views/Instruction/InstructionView.swift` — capsule pill
- `Views/Instruction/InstructionContainerView.swift` — fonts + progress colors
- `Views/ProgressBarView.swift` — slim capsule track
- `Views/Liveness/_FaceLivenessDetectionView.swift` — canvas color, full-bleed
  camera layout, REC indicator removed, safe-area-aware overlay
- `Views/Liveness/LivenessViewController.swift` — canvas color; camera is a
  centered, rounded 3:4 window (~84% of screen width) so the oval reads as a
  portrait frame; face normalization uses the shared camera rect
- `Views/GetReadyPage/GetReadyPageView.swift`, `Views/RecordingButton.swift`,
  `Views/CameraPermission/CameraPermissionView.swift` — fonts
- `Resources/Base.lproj/Localizable.strings` — Sonder-voice copy

## Branches & tags

- `sonder` — upstream tag + this patch. Consumed by
  `sienvision/sonder` (packages/face-liveness) via SPM, pinned to a
  `<upstream>-sonder.<n>` tag (e.g. `1.4.5-sonder.1`).

## Upgrading (AWS's 120-day SDK version policy)

1. `git fetch upstream --tags`, then rebase `sonder` onto the new tag:
   `git rebase <new-tag> sonder`
2. Resolve conflicts (the patch surface above is deliberately tiny),
   re-tag as `<new-tag>-sonder.1`, push branch + tag.
3. Bump the pinned tag in sonder's FaceLivenessDetector.podspec,
   rebuild, and run a real device check before shipping.
