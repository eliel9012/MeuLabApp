import SwiftUI

/// Detalhes ACARS para watchOS
struct WatchACARSView: View {
    @State private var isLoading = true
    @State private var summary: WatchACARSData?
    @State private var messages: [WatchACARSMessage] = []
    @State private var error: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if isLoading {
                    ProgressView("Carregando...")
                        .frame(maxWidth: .infinity)
                } else if let error {
                    ErrorView(message: error) {
                        Task { await loadData() }
                    }
                } else {
                    // Contadores
                    if let summary {
                        HStack {
                            StatItem(value: "\(summary.messagesTotal)", label: "Mensagens")
                            StatItem(value: "\(summary.uniqueFlights ?? 0)", label: "Voos")
                        }
                        
                        Divider()
                    }
                    
                    // Mensagens recentes
                    Text("Recentes")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if messages.isEmpty {
                        Text("Nenhuma mensagem")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(messages) { msg in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(msg.flight ?? msg.registration ?? "???")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    if let label = msg.label {
                                        Text(label)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .background(Color.orange.opacity(0.3))
                                            .cornerRadius(4)
                                    }
                                }
                                if let text = msg.text {
                                    Text(text)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("ACARS")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        error = nil
        
        do {
            async let summaryTask = WatchAPIService.shared.fetchACARSSummary()
            async let messagesTask = WatchAPIService.shared.fetchACARSMessages()
            
            summary = try await summaryTask
            let list = try await messagesTask
            messages = list.messages
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

#Preview {
    WatchACARSView()
}
