import SwiftUI

#if DEBUG
struct CanvasEngineToggleView: View {
    @Binding var engine: DrawingEngineMode

    var body: some View {
        HStack(spacing: 6) {
            Text("Engine")
                .font(.system(size: 11, weight: .bold))
            Picker("Engine", selection: $engine) {
                ForEach(DrawingEngineMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
#endif