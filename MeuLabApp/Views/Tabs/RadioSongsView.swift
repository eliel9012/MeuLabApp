import SwiftUI

struct RadioSongsView: View {
    @EnvironmentObject var appState: AppState
    @State private var items: [NowPlaying] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading && items.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(items, id: \.timestamp) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(item.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let ts = parseTimestamp(item.timestamp) {
                        Text(ts.timeAgoDisplay())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    } else {
                        Text(item.timestamp)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Músicas")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task {
            if items.isEmpty {
                await load()
            }
        }
    }

    private func parseTimestamp(_ ts: String) -> Date? {
        Formatters.isoDate.date(from: ts) ?? Formatters.isoDateNoFrac.date(from: ts)
    }

    @MainActor
    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let resp = try await APIService.shared.fetchRadioHistory(limit: 100)
            items = resp.items
        } catch {
            // Keep existing list if any; only show error for context.
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        RadioSongsView()
            .environmentObject(AppState())
    }
}

