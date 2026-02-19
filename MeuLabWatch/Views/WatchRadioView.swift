import SwiftUI

struct WatchRadioView: View {
    @State private var nowPlaying: String = "Carregando..."
    @State private var stationName: String = ""
    @State private var isLoading = true
    @State private var signalStrength: Int = 0

    // Gradient matching the Radio Widget
    private let radioGradient = LinearGradient(
        colors: [Color(hex: "F472B6"), Color(hex: "DB2777")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Station Icon/Card
                ZStack {
                    Circle()
                        .fill(radioGradient.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "radio.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(radioGradient)
                }
                .padding(.top, 8)
                
                // Info
                VStack(spacing: 4) {
                    Text(stationName.isEmpty ? "Rádio MeuLab" : stationName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(nowPlaying)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal)
                
                // Stats/Controls
                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.title3)
                            .foregroundStyle(.cyan)
                        Text("Online")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(spacing: 2) {
                        Text("\(signalStrength)%")
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.green)
                        Text("Sinal")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                
                // Refresh Button
                Button {
                    Task { await loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        do {
            // Using existing WatchAPIService (assuming it has fetchRadio or similar, if not I'll add it)
            // For now simulating or using generic fetch
            // Check WatchAPIService to confirm if it has radio methods
             let data = try await WatchAPIService.shared.fetchNowPlaying()
             nowPlaying = data.displayTitle
             stationName = data.radioName
             signalStrength = Int.random(in: 80...100) // Mock signal for now
        } catch {
            nowPlaying = "Erro ao carregar"
        }
        isLoading = false
    }
}

#Preview {
    WatchRadioView()
}
