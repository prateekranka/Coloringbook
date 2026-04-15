import SwiftUI

/// Sheet that lets the user choose an ambient background sound and adjust volume.
struct AmbientSoundView: View {
    @ObservedObject var soundService: AmbientSoundService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // ── Sound options ────────────────────────────────────────
                Section("Sounds") {
                    ForEach(AmbientSoundService.Sound.allCases) { sound in
                        SoundRow(
                            sound: sound,
                            isSelected: soundService.currentSound == sound
                        ) {
                            if sound == .none {
                                soundService.stop()
                            } else {
                                soundService.play(sound)
                            }
                        }
                    }
                }

                // ── Volume control ───────────────────────────────────────
                Section("Volume") {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)

                        Slider(value: $soundService.volume, in: 0...1)
                            .disabled(soundService.currentSound == .none)

                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                    }
                }
            }
            .navigationTitle("Ambient Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Row

private struct SoundRow: View {
    let sound: AmbientSoundService.Sound
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: sound.icon)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 24)

                Text(sound.rawValue)
                    .foregroundStyle(Color.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
