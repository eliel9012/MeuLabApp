import SwiftUI

// MARK: - Navigate View (Books → Chapters → Verses)

struct BibleNavigateView: View {
    @Binding var selectedBook: BibleBook?
    @Binding var selectedChapter: BibleChapter?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach([BibleBook.Testament.old, .new], id: \.self) { testament in
                        let books = BibleCatalogue.books.filter { $0.testament == testament }
                        TestamentSection(testament: testament.rawValue, books: books)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .navigationDestination(for: BibleBook.self) { book in
                BibleChaptersView(book: book)
            }
        }
    }
}

// MARK: - Testament Section

private struct TestamentSection: View {
    let testament: String
    let books: [BibleBook]

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(testament)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.amber)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)

            if isExpanded {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(books) { book in
                        NavigationLink(value: book) {
                            BookCard(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Book Card

private struct BookCard: View {
    let book: BibleBook

    var body: some View {
        VStack(spacing: 4) {
            Text(book.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75)
                .lineLimit(2)

            Text("\(book.chapterCount) cap.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            Color.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.amber.opacity(0.30), lineWidth: 1)
        )
    }
}

// MARK: - Chapters View

struct BibleChaptersView: View {
    let book: BibleBook
    private let columns = [GridItem(.adaptive(minimum: 52, maximum: 64), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(1...book.chapterCount, id: \.self) { chapter in
                    NavigationLink(value: chapter) {
                        ChapterButton(number: chapter)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background {
            LinearGradient(
                colors: [Color.amber.opacity(0.06), Color(.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Int.self) { chapter in
            BibleChapterView(bookSlug: book.slug, bookName: book.name, chapterNumber: chapter)
        }
    }
}

private struct ChapterButton: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(.callout)
            .fontWeight(.semibold)
            .frame(width: 52, height: 52)
            .background(Color.amber.opacity(0.12), in: Circle())
            .overlay(Circle().strokeBorder(Color.amber.opacity(0.35), lineWidth: 1))
            .foregroundStyle(.primary)
    }
}

// MARK: - Chapter View (Verses)

struct BibleChapterView: View {
    let bookSlug: String
    let bookName: String
    let chapterNumber: Int

    @State private var chapter: BibleChapter? = nil
    @State private var fontSize: CGFloat = 17
    @State private var readerViewModel = BibleReaderViewModel()
    @State private var highlightedVerseIndex: Int = -1
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var loader: BibleLoader { BibleLoader.shared }

    var body: some View {
        Group {
            if let chapter {
                versesContent(chapter)
            } else {
                ProgressView("Carregando…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("\(bookName) \(chapterNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { fontToolbar }
        .task {
            chapter = loader.chapter(bookSlug: bookSlug, chapterNumber: chapterNumber)
            if let chapter {
                let verses = chapter.verses.map { $0.text }
                readerViewModel.loadChapterIfNeeded(
                    book: bookName, chapter: chapterNumber, verses: verses)
            }
        }
    }

    @ViewBuilder
    private func versesContent(_ chapter: BibleChapter) -> some View {
        VStack(spacing: 0) {
            // Playback Controls
            PlaybackControlBar(viewModel: readerViewModel, highlightedIndex: $highlightedVerseIndex)
                .padding(Edge.Set.horizontal, 16)
                .padding(Edge.Set.vertical, 12)
                .background(Color.amber.opacity(0.08))
                .borderTop(Color.amber.opacity(0.2), height: 1)
                .borderBottom(Color.amber.opacity(0.2), height: 1)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(chapter.verses.enumerated()), id: \.offset) { index, verse in
                            VerseRowWithReader(
                                verse: verse,
                                fontSize: fontSize,
                                isHighlighted: index == readerViewModel.highlightedVerseIndex,
                                index: index,
                                onTap: {
                                    readerViewModel.skipToVerse(index)
                                    highlightedVerseIndex = index
                                }
                            )
                            .id(index)
                        }
                    }
                    .padding(.horizontal, sizeClass == .regular ? 32 : 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 44)
                }
                .background {
                    LinearGradient(
                        colors: [Color.amber.opacity(0.05), Color(.systemBackground)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
                .onChange(of: readerViewModel.highlightedVerseIndex) { oldValue, newValue in
                    if newValue != highlightedVerseIndex {
                        highlightedVerseIndex = newValue
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var fontToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                fontSize = max(13, fontSize - 2)
            } label: {
                Image(systemName: "textformat.size.smaller")
            }
            Button {
                fontSize = min(28, fontSize + 2)
            } label: {
                Image(systemName: "textformat.size.larger")
            }
        }
    }
}

// MARK: - Verse Row

struct VerseRow: View {
    let verse: BibleVerse
    var fontSize: CGFloat = 17

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(verse.number)")
                .font(.system(size: fontSize * 0.72, weight: .bold))
                .foregroundStyle(Color.amber)
                .frame(minWidth: 24, alignment: .trailing)
                .padding(.top, 3)

            Text(verse.text)
                .font(.system(size: fontSize))
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Verse Row with Reader (Highlighted during playback)

struct VerseRowWithReader: View {
    let verse: BibleVerse
    var fontSize: CGFloat = 17
    var isHighlighted: Bool = false
    var index: Int = 0
    var onTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(verse.number)")
                .font(.system(size: fontSize * 0.72, weight: .bold))
                .foregroundStyle(isHighlighted ? Color.white : Color.amber)
                .frame(minWidth: 24, alignment: .trailing)
                .padding(.top, 3)

            Text(verse.text)
                .font(.system(size: fontSize))
                .foregroundStyle(isHighlighted ? Color.white : .primary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHighlighted ? Color.amber.opacity(0.7) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isHighlighted ? Color.amber : Color.amber.opacity(0.2),
                    lineWidth: isHighlighted ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Playback Control Bar

struct PlaybackControlBar: View {
    var viewModel: BibleReaderViewModel
    @Binding var highlightedIndex: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Stop Button
                Button(action: { viewModel.stop() }) {
                    Image(systemName: "stop.fill")
                        .frame(width: 36, height: 36)
                        .background(Color.red.opacity(0.2))
                        .foregroundStyle(.red)
                        .clipShape(Circle())
                }
                .disabled(!viewModel.isPlaying && !viewModel.isPaused)

                // Play/Pause Button
                Button(action: {
                    if viewModel.isPlaying {
                        viewModel.pause()
                    } else if viewModel.isPaused {
                        viewModel.resume()
                    } else {
                        viewModel.play()
                        highlightedIndex = 0
                    }
                }) {
                    Image(
                        systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill"
                    )
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                }

                Spacer()

                // Status
                VStack(alignment: .trailing, spacing: 2) {
                    Text(
                        viewModel.isPlaying ? "Lendo..." : viewModel.isPaused ? "Pausado" : "Parado"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("\(viewModel.highlightedVerseIndex + 1)/\(viewModel.verses.count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.amber.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Speed Info
            if viewModel.isPlaying || viewModel.isPaused {
                Text("Toque em um versículo para pular")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    func borderTop(_ color: Color, height: CGFloat = 1) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(height: height)
            self
        }
    }

    func borderBottom(_ color: Color, height: CGFloat = 1) -> some View {
        VStack(spacing: 0) {
            self
            Rectangle()
                .fill(color)
                .frame(height: height)
        }
    }
}

#Preview {
    NavigationStack {
        BibleChaptersView(book: BibleCatalogue.books[0])
    }
}
