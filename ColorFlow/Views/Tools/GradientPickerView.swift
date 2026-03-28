import SwiftUI

struct GradientPickerView: View {
    @Binding var startColor: Color
    @Binding var endColor: Color
    @Binding var angle: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [startColor, endColor],
                                        startPoint: gradientStart,
                                        endPoint: gradientEnd))
                    .frame(height: 80)
                    .padding(.horizontal)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start").font(.caption).foregroundStyle(.secondary)
                        ColorPicker("", selection: $startColor)
                            .labelsHidden()
                            .frame(width: 44, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("End").font(.caption).foregroundStyle(.secondary)
                        ColorPicker("", selection: $endColor)
                            .labelsHidden()
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Angle: \(Int(angle))°").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $angle, in: 0...360, step: 15)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Gradient Fill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var gradientStart: UnitPoint {
        let rad = angle * .pi / 180
        return UnitPoint(x: 0.5 - cos(rad) * 0.5, y: 0.5 - sin(rad) * 0.5)
    }
    private var gradientEnd: UnitPoint {
        let rad = angle * .pi / 180
        return UnitPoint(x: 0.5 + cos(rad) * 0.5, y: 0.5 + sin(rad) * 0.5)
    }
}
