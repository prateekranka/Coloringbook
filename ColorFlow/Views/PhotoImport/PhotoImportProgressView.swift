import SwiftUI

/// Full-screen progress overlay shown while the pipeline is running.
struct PhotoImportProgressView: View {
    let stage: PhotoPipelineStage
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated icon
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.accent)
                    .symbolEffect(.pulse)

                // Stage labels
                VStack(spacing: 16) {
                    ForEach(PhotoPipelineStage.allCases, id: \.rawValue) { s in
                        StageRow(stage: s, currentStage: stage)
                    }
                }
                .padding(.horizontal, AppTheme.screenPadding * 2)

                // Progress bar
                ProgressView(value: stage.progress)
                    .progressViewStyle(.linear)
                    .tint(AppTheme.accent)
                    .padding(.horizontal, AppTheme.screenPadding * 2)

                Spacer()

                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .tint(AppTheme.textSecondary)
                    .padding(.bottom, 32)
                    .accessibilityIdentifier("photoImport.cancel")
            }
        }
    }
}

// MARK: - Stage Row

private struct StageRow: View {
    let stage: PhotoPipelineStage
    let currentStage: PhotoPipelineStage

    private var status: RowStatus {
        if stage.rawValue < currentStage.rawValue { return .done }
        if stage.rawValue == currentStage.rawValue { return .active }
        return .pending
    }

    private enum RowStatus { case done, active, pending }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                switch status {
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .active:
                    ProgressView()
                        .tint(AppTheme.accent)
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                case .pending:
                    Image(systemName: "circle")
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.4))
                }
            }
            .frame(width: 20, height: 20)

            Text(stage.label)
                .font(.subheadline)
                .foregroundStyle(status == .pending ? AppTheme.textSecondary.opacity(0.5) : AppTheme.textPrimary)

            Spacer()
        }
    }
}
