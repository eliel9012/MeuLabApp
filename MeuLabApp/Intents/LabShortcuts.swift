import AppIntents

struct LabShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AircraftCountIntent(),
            phrases: [
                "Quantas aeronaves no \(.applicationName)?",
                "Quantos aviões no \(.applicationName)?",
                "Radar \(.applicationName)",
                "Aeronaves \(.applicationName)",
            ],
            shortTitle: "Contagem de Aeronaves",
            systemImageName: "airplane"
        )

        AppShortcut(
            intent: SystemStatusIntent(),
            phrases: [
                "Status do \(.applicationName)",
                "Como está o \(.applicationName)?",
                "Laboratório \(.applicationName)",
            ],
            shortTitle: "Status do Laboratório",
            systemImageName: "server.rack"
        )

        AppShortcut(
            intent: PlayRadioIntent(),
            phrases: [
                "Tocar rádio do \(.applicationName)",
                "Ouvir \(.applicationName)",
                "Play \(.applicationName)",
            ],
            shortTitle: "Tocar Rádio",
            systemImageName: "radio"
        )

        AppShortcut(
            intent: IntelligentBriefingIntent(),
            phrases: [
                "Briefing do \(.applicationName)",
                "Resumo inteligente do \(.applicationName)",
                "Como está tudo no \(.applicationName)",
            ],
            shortTitle: "Briefing Inteligente",
            systemImageName: "brain.head.profile"
        )

        AppShortcut(
            intent: AskLabIntent(),
            phrases: [
                "Perguntar ao \(.applicationName)",
                "Consultar \(.applicationName)",
                "Pergunta no \(.applicationName)",
            ],
            shortTitle: "Perguntar ao Lab",
            systemImageName: "message.badge.waveform"
        )

        AppShortcut(
            intent: ReadChapterIntent(),
            phrases: [
                "Ler \(.applicationName) capítulo",
                "Ler Bíblia no \(.applicationName)",
            ],
            shortTitle: "Ler Capítulo da Bíblia",
            systemImageName: "book.closed"
        )

        AppShortcut(
            intent: PauseBibleReadingIntent(),
            phrases: [
                "Pausar leitura no \(.applicationName)"
            ],
            shortTitle: "Pausar Leitura",
            systemImageName: "pause.fill"
        )

        AppShortcut(
            intent: ResumeBibleReadingIntent(),
            phrases: [
                "Retomar leitura no \(.applicationName)"
            ],
            shortTitle: "Retomar Leitura",
            systemImageName: "play.fill"
        )

        AppShortcut(
            intent: StopBibleReadingIntent(),
            phrases: [
                "Parar leitura no \(.applicationName)"
            ],
            shortTitle: "Parar Leitura",
            systemImageName: "stop.fill"
        )
    }
}
