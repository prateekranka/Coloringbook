import SwiftUI

struct StampPickerView: View {
    @Binding var selectedStamp: StampShape
    @Binding var stampSize: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                    ForEach(StampShape.allCases) { shape in
                        Button {
                            selectedStamp = shape
                            HapticService.shared.impact(.light)
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: shape.systemImageName)
                                    .font(.system(size: 28))
                                    .foregroundStyle(selectedStamp == shape ? Color.accentColor : Color.primary)
                                Text(shape.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 70, height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedStamp == shape ? Color.accentColor.opacity(0.12) : Color(UIColor.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Size: \(Int(stampSize)) pt").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $stampSize, in: 10...80)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Stamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
