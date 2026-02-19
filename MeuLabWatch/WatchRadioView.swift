import SwiftUI

struct WatchRadioView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.blue)
            Text("Rádio")
                .font(.headline)
            Text("Em breve")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    WatchRadioView()
}
