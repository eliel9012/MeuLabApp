import SwiftUI

struct WatchBibleView: View {
    @State private var isLoading = false
    @State private var currentVerse: BibleVerse?
    @State private var error: String?

    // Versículos populares para exibição rápida
    private let popularVerses: [BibleVerse] = [
        BibleVerse(
            reference: "João 3:16",
            text:
                "Porque Deus amou o mundo de tal maneira que deu o seu Filho unigênito, para que todo aquele que nele crê não pereça, mas tenha a vida eterna."
        ),
        BibleVerse(reference: "Salmos 23:1", text: "O Senhor é o meu pastor; nada me faltará."),
        BibleVerse(
            reference: "Filipenses 4:13", text: "Posso todas as coisas naquele que me fortalece."),
        BibleVerse(
            reference: "Provérbios 3:5-6",
            text:
                "Confia no Senhor de todo o teu coração e não te estribes no teu próprio entendimento. Reconhece-o em todos os teus caminhos, e ele endireitará as tuas veredas."
        ),
        BibleVerse(
            reference: "Isaías 41:10",
            text:
                "Não temas, porque eu sou contigo; não te assombres, porque eu sou o teu Deus; eu te fortaleço, e te ajudo, e te sustento com a destra da minha justiça."
        ),
        BibleVerse(
            reference: "Romanos 8:28",
            text:
                "E sabemos que todas as coisas contribuem juntamente para o bem daqueles que amam a Deus, daqueles que são chamados por seu decreto."
        ),
        BibleVerse(
            reference: "Mateus 11:28",
            text: "Vinde a mim, todos os que estais cansados e oprimidos, e eu vos aliviarei."),
        BibleVerse(
            reference: "Jeremias 29:11",
            text:
                "Porque eu bem sei os pensamentos que tenho a vosso respeito, diz o Senhor; pensamentos de paz e não de mal, para vos dar o fim que esperais."
        ),
        BibleVerse(
            reference: "Salmos 91:1-2",
            text:
                "Aquele que habita no esconderijo do Altíssimo, à sombra do Onipotente descansará. Direi do Senhor: Ele é o meu Deus, o meu refúgio, a minha fortaleza, e nele confiarei."
        ),
        BibleVerse(
            reference: "Gálatas 5:22-23",
            text:
                "Mas o fruto do Espírito é: amor, gozo, paz, longanimidade, benignidade, bondade, fé, mansidão, temperança. Contra essas coisas não há lei."
        ),
        BibleVerse(
            reference: "Salmos 119:105",
            text: "Lâmpada para os meus pés é tua palavra, e luz para o meu caminho."),
        BibleVerse(
            reference: "1 Coríntios 13:4-7",
            text:
                "O amor é sofredor, o amor é benigno; o amor não é invejoso; o amor não trata com leviandade, não se ensoberbece, não se porta com indecência, não busca os seus interesses, não se irrita, não suspeita mal."
        ),
    ]

    var body: some View {
        WatchLabScreen(title: "Bíblia", icon: "book.fill", tint: WatchLabTheme.orange) {
            if let verse = currentVerse {
                // Reference card
                WatchLabPanel(tint: WatchLabTheme.orange) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verse.reference)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(WatchLabTheme.ink)
                        }
                        Spacer()
                    }
                }

                // Verse text
                WatchLabPanel(tint: WatchLabTheme.violet) {
                    Text(verse.text)
                        .font(.caption)
                        .foregroundStyle(WatchLabTheme.ink)
                        .lineSpacing(3)
                }
            }

            // Actions
            WatchLabPanel(tint: WatchLabTheme.blue) {
                Button {
                    randomVerse()
                } label: {
                    HStack {
                        Image(systemName: "shuffle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(WatchLabTheme.cyan)
                        Text("Versículo aleatório")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(WatchLabTheme.ink)
                        Spacer()
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)

                Button {
                    dailyVerse()
                } label: {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(WatchLabTheme.orange)
                        Text("Versículo do dia")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(WatchLabTheme.ink)
                        Spacer()
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.04))
                    )
                }
                .buttonStyle(.plain)
            }

            if let error {
                WatchLabPanel(tint: WatchLabTheme.red) {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(WatchLabTheme.red)
                }
            }
        }
        .onAppear {
            dailyVerse()
        }

    }

    private func randomVerse() {
        currentVerse = popularVerses.randomElement()
    }

    private func dailyVerse() {
        // Use day of year to pick a consistent daily verse
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % popularVerses.count
        currentVerse = popularVerses[index]
    }

}

struct BibleVerse: Identifiable {
    let id = UUID()
    let reference: String
    let text: String
}

#Preview {
    WatchBibleView()
}
