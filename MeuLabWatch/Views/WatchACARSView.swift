import SwiftUI

struct WatchACARSView: View {
    @State private var isLoading = true
    @State private var summary: WatchACARSData?
    @State private var messages: [WatchACARSMessage] = []
    @State private var error: String?
    @State private var searchText = ""
    @State private var isSearching = false

    var body: some View {
        WatchLabScreen(title: "ACARS", icon: "envelope.badge.fill", tint: WatchLabTheme.orange) {
            if isLoading && messages.isEmpty {
                WatchLabPanel(tint: WatchLabTheme.orange) {
                    WatchLabStateView(
                        icon: "envelope.badge",
                        title: "Atualizando",
                        subtitle: "Buscando fila recente de mensagens.",
                        tint: WatchLabTheme.orange,
                        actionTitle: nil,
                        action: nil
                    )
                }
            } else if let error, messages.isEmpty {
                WatchLabPanel(tint: WatchLabTheme.red) {
                    WatchLabStateView(
                        icon: "wifi.exclamationmark",
                        title: "Falha",
                        subtitle: error,
                        tint: WatchLabTheme.red,
                        actionTitle: "Tentar",
                        action: { Task { await loadData() } }
                    )
                }
            } else {
                if let summary {
                    WatchLabPanel(tint: WatchLabTheme.orange) {
                        HStack {
                            WatchLabMiniMetricCard(
                                icon: "envelope.fill",
                                value: "\(summary.messagesTotal)",
                                label: "Msgs",
                                tint: WatchLabTheme.orange
                            )
                            WatchLabMiniMetricCard(
                                icon: "airplane",
                                value: "\(summary.uniqueFlights ?? 0)",
                                label: "Voos",
                                tint: WatchLabTheme.blue
                            )
                        }
                    }
                }

                // Search bar
                WatchLabPanel(tint: WatchLabTheme.cyan) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(WatchLabTheme.secondary)

                        TextField("Buscar voo...", text: $searchText)
                            .font(.caption2)
                            .foregroundStyle(WatchLabTheme.ink)
                            .textInputAutocapitalization(.characters)
                            .onSubmit {
                                Task { await searchMessages() }
                            }

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                Task { await loadData() }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(WatchLabTheme.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                WatchLabPanel(tint: WatchLabTheme.violet) {
                    Text(isSearching ? "Resultados: \(searchText)" : "Mensagens recentes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    if messages.isEmpty {
                        Text(isSearching ? "Nenhum resultado." : "Nenhuma mensagem recente.")
                            .font(.caption2)
                            .foregroundStyle(WatchLabTheme.secondary)
                    } else {
                        ForEach(messages.prefix(6)) { msg in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(msg.flight ?? msg.registration ?? "???")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(WatchLabTheme.ink)
                                    Spacer()
                                    if let label = msg.label {
                                        Text(label)
                                            .font(.system(size: 9, weight: .bold, design: .rounded))
                                            .foregroundStyle(WatchLabTheme.orange)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(WatchLabTheme.orange.opacity(0.14)))
                                    }
                                }
                                if let text = msg.text {
                                    Text(text)
                                        .font(.caption2)
                                        .foregroundStyle(WatchLabTheme.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                WatchLabTheme.violet.opacity(0.14), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        error = nil
        isSearching = false
        do {
            async let summaryTask = WatchAPIService.shared.fetchACARSSummary()
            async let messagesTask = WatchAPIService.shared.fetchACARSMessages()
            summary = try await summaryTask
            messages = try await messagesTask.messages
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func searchMessages() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            await loadData()
            return
        }
        isLoading = true
        isSearching = true
        do {
            let result = try await WatchAPIService.shared.searchACARSMessages(query: searchText)
            messages = result.messages ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    WatchACARSView()
}
