import SwiftUI

struct BibleChapterReaderView: View {
    @State private var viewModel = BibleReaderViewModel()
    @Namespace private var namespace

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .frame(height: 60)
                .padding(.horizontal)
                .padding(.vertical, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(viewModel.verses.enumerated()), id: \.offset) {
                            index, verse in
                            ReaderVerseRow(
                                verseNumber: index + 1,
                                text: verse,
                                isHighlighted: index == viewModel.highlightedVerseIndex,
                                namespace: namespace
                            )
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.skipToVerse(index)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.highlightedVerseIndex) { oldValue, newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }

            Spacer()

            playbackControlsView
                .padding()
        }
        .background(Color(.systemBackground))
        .onAppear {
            loadSampleChapter()
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentBook)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Capítulo \(viewModel.currentChapterNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Versículos")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("\(viewModel.highlightedVerseIndex + 1)/\(viewModel.verses.count)")
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
        }
    }

    private var playbackControlsView: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.stop() }) {
                Image(systemName: "stop.fill")
                    .frame(width: 40, height: 40)
                    .background(Color.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .clipShape(Circle())
            }
            .disabled(!viewModel.isPlaying && !viewModel.isPaused)

            Button(action: {
                if viewModel.isPlaying {
                    viewModel.pause()
                } else if viewModel.isPaused {
                    viewModel.resume()
                } else {
                    viewModel.play()
                }
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }

            Spacer()

            VStack(alignment: .center, spacing: 4) {
                Text(viewModel.isPlaying ? "Lendo..." : viewModel.isPaused ? "Pausado" : "Parado")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(viewModel.highlightedVerseIndex + 1)/\(viewModel.verses.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadSampleChapter() {
        let sampleVerses = [
            "Havia um homem fariseu chamado Nicodemos, príncipe dos judeus.",
            "Este foi ter com Jesus de noite, e disse-lhe: Rabi, bem sabemos que és mestre vindo de Deus; porque ninguém pode fazer estes sinais que tu fazes, se Deus não for com ele.",
            "Jesus respondeu, e disse-lhe: Na verdade, na verdade te digo que aquele que não nascer de novo, não pode ver o reino de Deus.",
            "Disse-lhe Nicodemos: Como pode um homem nascer, sendo velho? Porventura pode entrar pela segunda vez no ventre de sua mãe, e nascer?",
            "Jesus respondeu: Na verdade, na verdade te digo que aquele que não nascer da água e do Espírito, não pode entrar no reino de Deus.",
            "O que é nascido da carne é carne, e o que é nascido do Espírito é espírito.",
            "Não te maravilhes de te ter dito: Convém-vos nascer de novo.",
            "O vento assopra onde quer, e ouves a sua voz; mas não sabes donde vem, nem para onde vai; assim é todo aquele que é nascido do Espírito.",
        ]

        viewModel.setChapter(book: "João", chapter: 3, verses: sampleVerses)
    }
}

// MARK: - Verse Row Component

struct ReaderVerseRow: View {
    let verseNumber: Int
    let text: String
    let isHighlighted: Bool
    let namespace: Namespace.ID

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(verseNumber)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
                .frame(width: 24, alignment: .center)

            Text(text)
                .font(.body)
                .lineLimit(nil)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHighlighted ? Color.blue.opacity(0.15) : Color.clear)
                .matchedGeometryEffect(id: "highlighted", in: namespace, isSource: isHighlighted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isHighlighted ? Color.blue.opacity(0.5) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    BibleChapterReaderView()
}
