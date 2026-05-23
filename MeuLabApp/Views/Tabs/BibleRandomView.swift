import SwiftUI

struct BibleRandomView: View {
    @State private var verse: BibleVerse? = nil
    @State private var isLoading = false

    private var loader: BibleLoader { BibleLoader.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let verse {
                    RandomVerseCard(verse: verse)
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
                        Text(verse == nil ? "Versículo Aleatório" : "Outro Versículo")
                            .font(MacOS9Typography.bodyBold(14))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(MacOS9Colors.panelBackground)
                    .foregroundStyle(MacOS9Colors.primaryText)
                    .overlay(Mac9BevelBorder(isRaised: true))
                    .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
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
        .background(MacOS9Colors.windowBackground.ignoresSafeArea())
    }

    private var inspireText: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(MacOS9Colors.statusOrange)

            Text("Deixe a Palavra falar ao seu coração")
                .font(MacOS9Typography.body(14))
                .foregroundStyle(MacOS9Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(MacOS9Colors.panelBackground)
        .overlay(Mac9BevelBorder(isRaised: true))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
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
            HStack {
                Image(systemName: "book.pages")
                    .foregroundStyle(MacOS9Colors.statusOrange)
                Text("\(bookName) \(verse.chapter):\(verse.number)")
                    .font(MacOS9Typography.menuLabel(13))
                    .foregroundStyle(MacOS9Colors.statusOrange)
                Spacer()
            }

            Text(verse.text)
                .font(MacOS9Typography.editorialHeading(23))
                .foregroundStyle(MacOS9Colors.primaryText)
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(MacOS9Colors.border)
                .frame(height: 1)

            NavigationLink(destination: BibleChapterView(
                bookSlug: verse.book,
                bookName: bookName,
                chapterNumber: verse.chapter
            )) {
                Label("Ler \(bookName) \(verse.chapter)", systemImage: "arrow.right.circle")
                    .font(MacOS9Typography.bodyBold(13))
                    .foregroundStyle(MacOS9Colors.selection)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(MacOS9Colors.panelBackground)
        .overlay(Mac9BevelBorder(isRaised: true))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.statusOrange, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        BibleRandomView()
    }
}
