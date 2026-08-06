//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import SwiftUI
import Combine
@_spi(PredictionsFaceLiveness) import AWSPredictionsPlugin

struct InstructionContainerView: View {
    @ObservedObject var viewModel: FaceLivenessDetectionViewModel

    var body: some View {
        switch viewModel.livenessState.state {
        case .displayingFreshness:
            InstructionView(
                text: LocalizedStrings.challenge_instruction_hold_still,
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .livenessInstructionPill
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_hold_still
                )
            }

        case .awaitingFaceInOvalMatch(.faceTooClose, _):
            InstructionView(
                text: LocalizedStrings.challenge_instruction_move_face_back,
                backgroundColor: .livenessErrorBackground,
                textColor: .livenessErrorLabel,
                font: .livenessInstructionPill
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_move_face_back
                )
            }

        case .awaitingFaceInOvalMatch(let reason, let percentage):
            InstructionView(
                text: .init(reason.localizedValue),
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .livenessInstructionPill
            )

            ProgressBarView(
                emptyColor: .livenessProgressTrack,
                borderColor: .clear,
                fillColor: .livenessProgressFill,
                indicatorColor: .livenessProgressFill,
                percentage: percentage
            )
            .frame(width: 180, height: 6)
            .padding(.top, 14)
        case .recording(ovalDisplayed: true):
            InstructionView(
                text: LocalizedStrings.challenge_instruction_move_face_closer,
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .livenessInstructionPill
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_instruction_move_face_closer
                )
            }

            ProgressBarView(
                emptyColor: .livenessProgressTrack,
                borderColor: .clear,
                fillColor: .livenessProgressFill,
                indicatorColor: .livenessProgressFill,
                percentage: 0.2
            )
            .frame(width: 180, height: 6)
            .padding(.top, 14)
        case .pendingFacePreparedConfirmation(.pendingCheck):
            EmptyView()
        case .pendingFacePreparedConfirmation(let reason):
            InstructionView(
                text: .init(reason.localizedValue),
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .livenessInstructionPill
            )
        case .completedDisplayingFreshness:
            InstructionView(
                text: LocalizedStrings.challenge_verifying,
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .livenessInstructionPill
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_verifying
                )
            }
        case .completedNoLightCheck:
            InstructionView(
                text: LocalizedStrings.challenge_verifying,
                backgroundColor: .livenessPrimaryBackground,
                textColor: .livenessPrimaryLabel,
                font: .livenessInstructionPill
            )
            .onAppear {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: LocalizedStrings.challenge_verifying
                )
            }
        case .faceMatched:
            if let challenge = viewModel.challengeReceived,
               case .faceMovementAndLightChallenge = challenge {
                InstructionView(
                    text: LocalizedStrings.challenge_instruction_hold_still,
                    backgroundColor: .livenessPrimaryBackground,
                    textColor: .livenessPrimaryLabel,
                    font: .livenessInstructionPill
                )
            } else {
                EmptyView()
            }
        default:
            EmptyView()
        }
    }
}
