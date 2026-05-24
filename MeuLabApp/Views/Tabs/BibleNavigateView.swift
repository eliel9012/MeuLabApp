import SwiftUI

// MARK: - Navigate View (Books → Chapters → Verses)

struct BibleNavigateView: View {
    @Binding var selectedBook: BibleBook?
    @Binding var selectedChapter: BibleChapter?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach([BibleBook.Testament.old, .new], id: \.self) { testament in
                    let books = BibleCatalogue.books.filter { $0.testament == testament }
                    TestamentSection(testament: testament.rawValue, books: books)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .padding(.bottom, 92)
        }
        .background(MacOS9Colors.windowBackground)
        .navigationDestination(for: BibleBook.self) { book in
            BibleChaptersView(book: book)
        }
    }
}

// MARK: - Testament Section

private struct TestamentSection: View {
    let testament: String
    let books: [BibleBook]

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                    HStack {
                        Text(testament)
                        .font(MacOS9Typography.windowTitle(16))
                        .foregroundStyle(MacOS9Colors.selection)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(MacOS9Typography.bodyBold(12))
                        .foregroundStyle(MacOS9Colors.secondaryText)
                }
                .padding(.horizontal, 8)
                .frame(height: 36)
                .background(MacOS9Colors.labelBadge)
                .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if isExpanded {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 108, maximum: 160), spacing: 8)],
                    spacing: 8
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
        .padding(8)
        .background(MacOS9Colors.panelBackground)
        .overlay(Mac9BevelBorder(isRaised: true))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
    }
}

// MARK: - Book Card

private struct BookCard: View {
    let book: BibleBook

    var body: some View {
        VStack(spacing: 4) {
            Text(book.name)
                .font(MacOS9Typography.bodyBold(13))
                .multilineTextAlignment(.center)
                .foregroundStyle(MacOS9Colors.primaryText)
                .minimumScaleFactor(0.75)
                .lineLimit(2)

            Text("\(book.chapterCount) cap.")
                .font(MacOS9Typography.caption(10))
                .foregroundStyle(MacOS9Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 46)
        .padding(.horizontal, 5)
        .background(MacOS9Colors.contentPanel)
        .overlay(Mac9BevelBorder(isRaised: true))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.statusOrange.opacity(0.75), lineWidth: 1))
    }
}

// MARK: - Chapters View

struct BibleChaptersView: View {
    let book: BibleBook
    private let columns = [GridItem(.adaptive(minimum: 56, maximum: 70), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(book.chapterCount) capítulos")
                    .font(MacOS9Typography.menuLabel(12))
                    .foregroundStyle(MacOS9Colors.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(MacOS9Colors.labelBadge)
                    .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(1...book.chapterCount, id: \.self) { chapter in
                        NavigationLink(value: chapter) {
                            ChapterButton(number: chapter)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 92)
        }
        .background(MacOS9Colors.windowBackground.ignoresSafeArea())
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Int.self) { chapter in
            BibleChapterView(bookSlug: book.slug, bookName: book.name, chapterNumber: chapter)
        }
    }
}

private struct ChapterButton: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .font(MacOS9Typography.bodyBold(16))
            .frame(width: 56, height: 44)
            .background(MacOS9Colors.contentPanel)
            .overlay(Mac9BevelBorder(isRaised: true))
            .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
            .foregroundStyle(MacOS9Colors.primaryText)
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
                .background(MacOS9Colors.panelBackground)
                .borderTop(MacOS9Colors.border, height: 1)
                .borderBottom(MacOS9Colors.border, height: 1)

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
                .background(MacOS9Colors.windowBackground.ignoresSafeArea())
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
                .font(MacOS9Typography.bodyBold(fontSize * 0.72))
                .foregroundStyle(Color.amber)
                .frame(minWidth: 24, alignment: .trailing)
                .padding(.top, 3)

            Text(verse.text)
                .font(MacOS9Typography.body(fontSize))
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
                .font(MacOS9Typography.bodyBold(fontSize * 0.72))
                .foregroundStyle(isHighlighted ? MacOS9Colors.selectedText : MacOS9Colors.statusOrange)
                .frame(minWidth: 24, alignment: .trailing)
                .padding(.top, 3)

            Text(verse.text)
                .font(MacOS9Typography.body(fontSize))
                .foregroundStyle(isHighlighted ? MacOS9Colors.selectedText : MacOS9Colors.primaryText)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHighlighted ? MacOS9Colors.selection : MacOS9Colors.contentPanel)
        .overlay(Rectangle().strokeBorder(isHighlighted ? MacOS9Colors.border : MacOS9Colors.bevelShadowSubtle, lineWidth: 1))
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
                Button(action: { viewModel.stop() }) {
                    Image(systemName: "stop.fill")
                        .frame(width: 36, height: 36)
                        .background(MacOS9Colors.contentPanel)
                        .foregroundStyle(MacOS9Colors.statusRed)
                        .overlay(Mac9BevelBorder(isRaised: true))
                        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
                }
                .disabled(!viewModel.isPlaying && !viewModel.isPaused)

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
                    .font(MacOS9Typography.body(34))
                    .frame(width: 42, height: 36)
                    .background(MacOS9Colors.contentPanel)
                    .foregroundStyle(MacOS9Colors.statusBlue)
                    .overlay(Mac9BevelBorder(isRaised: true))
                    .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
                }

                Spacer()

                // Status
                VStack(alignment: .trailing, spacing: 2) {
                    Text(
                        viewModel.isPlaying ? "Lendo..." : viewModel.isPaused ? "Pausado" : "Parado"
                    )
                    .font(MacOS9Typography.caption(11))
                    .foregroundStyle(MacOS9Colors.secondaryText)

                    Text("\(viewModel.highlightedVerseIndex + 1)/\(viewModel.verses.count)")
                        .font(MacOS9Typography.bodyBold(12))
                        .foregroundStyle(MacOS9Colors.primaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(MacOS9Colors.contentPanel)
            .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))

            if viewModel.isPlaying || viewModel.isPaused {
                Text("Toque em um versículo para pular")
                    .font(MacOS9Typography.caption(11))
                    .foregroundStyle(MacOS9Colors.secondaryText)
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
