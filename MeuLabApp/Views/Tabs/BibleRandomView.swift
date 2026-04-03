import SwiftUI

struct BibleRandomView: View {
    @State private var verse: BibleVerse? = nil
    @State private var isLoading = false

    private var loader: BibleLoader { BibleLoader.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let verse {
                    RandomVerseCard(verse: verse)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 1.1).combined(with: .opacity)
                        ))
                }

                Button {
                    generateRandom()
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(Color.mogno)
                        } else {
                            Image(systemName: "dice")
                        }
                        Text(verse == nil ? "✨ Versículo Aleatório" : "🎲 Outro Versículo")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.amber, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.mogno)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                if verse == nil {
                    inspireText
                }

                Spacer(minLength: 44)
            }
            .padding(.horizontal)
            .padding(.top, 24)
        }
        .background {
            LinearGradient(
                colors: [Color.amber.opacity(0.06), Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var inspireText: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundStyle(Color.amber.opacity(0.5))

            Text("Deixe a Palavra falar ao seu coração")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func generateRandom() {
        isLoading = true
        Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                verse = loader.randomVerse()
            }
            isLoading = false
        }
    }
}

// MARK: - Random Verse Card

private struct RandomVerseCard: View {
    let verse: BibleVerse

    private var bookName: String {
        BibleCatalogue.book(slug: verse.book)?.name ?? verse.book
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Reference badge
            HStack {
                Image(systemName: "book.pages")
                    .foregroundStyle(Color.amber)
                Text("\(bookName) \(verse.chapter):\(verse.number)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.amber)
                Spacer()
            }

            // Verse text
            Text(verse.text)
                .font(.title3)
                .fontWeight(.light)
                .foregroundStyle(.primary)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(Color.amber.opacity(0.3))

            // Navigate to chapter
            NavigationLink(destination: BibleChapterView(
                bookSlug: verse.book,
                bookName: bookName,
                chapterNumber: verse.chapter
            )) {
                Label("Ler \(bookName) \(verse.chapter)", systemImage: "arrow.right.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.amber)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .glassCard(tint: Color.amber, cornerRadius: 18)
    }
}

#Preview {
    NavigationStack {
        BibleRandomView()
    }
}
