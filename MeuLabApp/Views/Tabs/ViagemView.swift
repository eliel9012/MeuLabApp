import CoreLocation
import SwiftUI
import UIKit

// ============================================================
// VIAGEM — CRONOLOGIA FINAL
// Port nativo do roteiro (React/JSX "Cronologia") para SwiftUI.
// Viagem Set/2026 — Eliel & Ana Paula — França, Portugal, Inglaterra.
// Timeline dia a dia com voos, hotéis, casamento e endereços
// que abrem no Apple Maps.
// ============================================================

// MARK: - Cores

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Two-tone colour resolved from the interface style. Used for the accents that
/// carry this screen's voice — the warm sepias and the booking green — which must
/// keep their hue but change luminance to stay readable on either backdrop.
private func vAdaptive(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
        UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
    })
}

private enum VPalette {
    // Structure — page, text and rules follow the system appearance so the glass
    // has something to refract that matches the rest of the app.
    static let bg = Color(uiColor: .systemGroupedBackground)
    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let descColor = Color(uiColor: .secondaryLabel)
    static let cardBorder = Color(uiColor: .separator)

    // Identity — the hero gradient and the cream it is printed on. Fixed on
    // purpose: the gradient is always dark, so its text is always light.
    static let heroStart = Color(hex: 0x1B2A4A)
    static let heroMid = Color(hex: 0x2E4470)
    static let heroEnd = Color(hex: 0x6E5A8E)
    static let heroInk = Color(hex: 0xF7F3EB)
    /// The navy of the hero, lifted in dark mode so the nav-bar title reads.
    static let titleAccent = vAdaptive(light: 0x2E4470, dark: 0x9DB6E4)

    // Accents drawn over the adaptive surface.
    static let mapsLink = vAdaptive(light: 0x6E6452, dark: 0xC2B69C)
    static let mapsDot = vAdaptive(light: 0xA89C87, dark: 0x9A8F79)
    static let loungeText = vAdaptive(light: 0x7A5C1E, dark: 0xEEC479)
    static let loungeBase = Color(hex: 0xE3A857)
    static let refBase = vAdaptive(light: 0x2E7D5A, dark: 0x74D3A6)

    // Shimmer badge — always sits on the dark hero gradient, so it stays fixed.
    static let shimmerBase = Color(hex: 0x2E7D5A)
    static let shimmerMint = Color(hex: 0x8CDCB4)
    static let shimmerText = Color(hex: 0xCFF3DF)
}

// MARK: - Tons por categoria de dia

private enum VTone {
    case travel, leisure, wedding, home

    /// Same four hues in both appearances; only the luminance moves, because a
    /// 0x2E4470 navy that reads as ink on cream disappears against dark glass.
    var accent: Color {
        switch self {
        case .travel: return vAdaptive(light: 0x2E4470, dark: 0x8FAAD9)
        case .leisure: return vAdaptive(light: 0x2E7D5A, dark: 0x6FCFA0)
        case .wedding: return vAdaptive(light: 0xB8862D, dark: 0xE3B860)
        case .home: return vAdaptive(light: 0x6E5A8E, dark: 0xB49CD8)
        }
    }

    var chip: Color {
        switch self {
        case .wedding: return accent.opacity(0.16)
        default: return accent.opacity(0.14)
        }
    }

    var label: String {
        switch self {
        case .travel: return "deslocamento"
        case .leisure: return "dia livre"
        case .wedding: return "o grande dia"
        case .home: return "volta"
        }
    }
}

// MARK: - Modelos

private struct VEvent: Identifiable {
    let id = UUID()
    let time: String
    let icon: String
    let title: String
    let desc: String
    let address: String?
    let mapsQuery: String?
    /// Geocoded once at build time via MKLocalSearch. Text queries are ambiguous —
    /// "Restaurants Moustiers-Sainte-Marie" resolved to Canada, "Stansted Express
    /// Liverpool Street" to Boston — so the pin is placed by coordinate instead.
    let lat: Double?
    let lon: Double?
    /// IANA identifier for the local time zone at this event's location. Events with
    /// no location of their own inherit the previous event's zone.
    let tz: String?
    let ref: String?
    let lounge: String?

    init(
        time: String,
        icon: String,
        title: String,
        desc: String,
        address: String? = nil,
        maps: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil,
        tz: String? = nil,
        ref: String? = nil,
        lounge: String? = nil
    ) {
        self.time = time
        self.icon = icon
        self.title = title
        self.desc = desc
        self.address = address
        self.mapsQuery = maps
        self.lat = lat
        self.lon = lon
        self.tz = tz
        self.ref = ref
        self.lounge = lounge
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var timeZone: TimeZone? {
        guard let tz else { return nil }
        return TimeZone(identifier: tz)
    }
}

private struct VDay: Identifiable {
    let id: String
    let date: String
    let weekday: String
    let title: String
    let tone: VTone
    let events: [VEvent]
}

// MARK: - Dados da viagem (fonte: cronologia_final.jsx)

private enum VData {
    static let days: [VDay] = [
        VDay(
            id: "d06", date: "06 set", weekday: "domingo",
            title: "Ribeirão Preto → Londrina", tone: .travel,
            events: [
                VEvent(
                    time: "06:00", icon: "🛫",
                    title: "Voo 4211 — Ribeirão Preto (RAO) → Londrina (LDB)",
                    desc: "Eliel viaja sozinho neste trecho. Voo com 1 conexão, chegada em Londrina às 10:15. Bagagem despachada incluída. Reencontro com a Ana em Londrina.",
                    address: "Aeroporto Leite Lopes (RAO), Av. Thomaz Alberto Whately, Ribeirão Preto – SP",
                    maps: "Aeroporto+Leite+Lopes+Ribeirao+Preto",
                    lat: -21.1392477, lon: -47.7765262,
                    tz: "America/Sao_Paulo",
                    ref: "LATAM · voo 4211"
                ),
                VEvent(
                    time: "10:15", icon: "🤝",
                    title: "Chegada em Londrina — reencontro com a Ana",
                    desc: "Pernoite em Londrina. Amanhã (07/09) vocês seguem juntos para Guarulhos.",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa",
                    lat: -23.328542, lon: -51.1377836,
                    tz: "America/Sao_Paulo"
                ),
            ]
        ),
        VDay(
            id: "d07dom", date: "07 set", weekday: "segunda (madrugada)",
            title: "Londrina → Guarulhos", tone: .travel,
            events: [
                VEvent(
                    time: "~04:15", icon: "⏰",
                    title: "Sair para o aeroporto de Londrina",
                    desc: "Voo às 05:45 — estar no LDB por volta das 04:45. Londrina é aeroporto pequeno, o check-in é rápido.",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa",
                    lat: -23.328542, lon: -51.1377836,
                    tz: "America/Sao_Paulo"
                ),
                VEvent(
                    time: "05:45", icon: "✈️",
                    title: "Voo LATAM LA3691 — Londrina (LDB) → São Paulo (GRU)",
                    desc: "Voo direto, Eliel + Ana Paula. Chegada em Guarulhos às 07:05.",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa",
                    lat: -23.328542, lon: -51.1377836,
                    tz: "America/Sao_Paulo",
                    ref: "LATAM · LA3691"
                ),
                VEvent(
                    time: "07:05 → 14:10", icon: "⏱️",
                    title: "Conexão em Guarulhos (~7h) — bem folgada",
                    desc: "⚠️ Reservas separadas (LATAM + Iberia): retirem a bagagem na esteira do desembarque doméstico e RE-DESPACHEM no balcão da Iberia, no Terminal 3. A LATAM não transfere direto. Só que o balcão da Iberia abre ~3h antes, por volta das 11:10 — ou seja, sobram ~4h de espera na área pública antes do check-in.",
                    address: "Aeroporto de Guarulhos (GRU), Terminal 3, Guarulhos – SP",
                    maps: "Aeroporto+de+Guarulhos+Terminal+3",
                    lat: -23.4244366, lon: -46.4761362,
                    tz: "America/Sao_Paulo"
                ),
            ]
        ),
        VDay(
            id: "d07", date: "07 set", weekday: "segunda (tarde)",
            title: "São Paulo → Madrid", tone: .travel,
            events: [
                VEvent(
                    time: "~11:10", icon: "🧳",
                    title: "Check-in Iberia — Terminal 3",
                    desc: "Balcão abre ~3h antes do voo. Depois: segurança, imigração e enfim o lounge.",
                    address: "Aeroporto Internacional de Guarulhos, Terminal 3, Guarulhos – SP",
                    maps: "Aeroporto+de+Guarulhos+Terminal+3",
                    lat: -23.4244366, lon: -46.4761362,
                    tz: "America/Sao_Paulo"
                ),
                VEvent(
                    time: "14:10 BRT", icon: "✈️",
                    title: "Voo IB 268 — Guarulhos → Madrid",
                    desc: "Voo noturno. Chegada dia 08/09 às 05:35 (hora de Madri).",
                    address: "Aeroporto Internacional de Guarulhos, Rod. Hélio Smidt s/n, Cumbica, Guarulhos – SP",
                    maps: "Aeroporto+Internacional+de+Guarulhos",
                    lat: -23.4262732, lon: -46.4816737,
                    tz: "America/Sao_Paulo",
                    ref: "Iberia · 9WAXMR",
                    lounge: "Terminal 3, mezanino (após imigração): LATAM VIP Lounge (24h, um dos melhores do país) ou W Premium 'The Pier' — ambos aceitam Priority Pass/DragonPass. O GRU Executive Lounge aceita Priority Pass fora do horário 16h–22h (vocês embarcam antes, ok!)."
                ),
            ]
        ),
        VDay(
            id: "d08", date: "08 set", weekday: "terça-feira",
            title: "Madrid → Marselha → Montpellier", tone: .travel,
            events: [
                VEvent(
                    time: "10:15", icon: "✈️",
                    title: "Voo IB 1169 — Madrid → Marseille",
                    desc: "Chegada às 12:00 (hora da França).",
                    address: "Aeroporto Adolfo Suárez Madrid-Barajas, Av. de la Hispanidad s/n, 28042 Madrid",
                    maps: "Aeropuerto+Adolfo+Suarez+Madrid+Barajas",
                    lat: 40.4936983, lon: -3.5674678,
                    tz: "Europe/Madrid",
                    ref: "Iberia · 9WAXMR",
                    lounge: "Conexão no T4 (voo Schengen): Iberia Dalí Premium Lounge, após a segurança (5h30–23h) — acesso via classe executiva ou status oneworld Sapphire/Emerald. Com Priority Pass, a alternativa no T4 é a Sala Plaza Mayor."
                ),
                VEvent(
                    time: "~12:30", icon: "🚌",
                    title: "Navette 91 — Aeroporto de Marseille → Gare St-Charles",
                    desc: "Após desembarque e retirada de bagagem. A navette (linha 91) sai do ponto entre os terminais T1 e T2, a cada ~10 min, ~25 min de viagem, €10/pessoa. Deixa vocês direto na estação de trem St-Charles (plataformas 13/14).",
                    address: "Navette 91, Aéroport Marseille Provence → Gare Saint-Charles",
                    maps: "Navette+91+Marseille+Aeroport+Saint+Charles",
                    lat: 43.2919482, lon: 5.4367409,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "13:25", icon: "🚆",
                    title: "Trem TER — Marseille St-Charles → Montpellier St-Roch",
                    desc: "Chegada às 15:00. Margem de ~55 min entre a chegada do voo (12:00) e o trem, contando a navette — justo mas viável se a bagagem sair rápido. Se atrasar, há trens ~a cada 30-60 min.",
                    address: "Gare de Marseille St-Charles, Square Narvik, 13001 Marseille",
                    maps: "Gare+de+Marseille+Saint-Charles",
                    lat: 43.3030462, lon: 5.3804125,
                    tz: "Europe/Paris",
                    ref: "Trainline · F3F5WA"
                ),
                VEvent(
                    time: "15:30", icon: "🏨",
                    title: "Check-in — Ibis Budget Montpellier Centre Millenaire",
                    desc: "2 noites (08 → 10/09). Check-in a partir das 14:00, check-out até 11:00.",
                    address: "Rue des Frères Lumière, ZA Blaise Pascal, 34000 Montpellier",
                    maps: "Ibis+Budget+Montpellier+Centre+Millenaire",
                    lat: 43.5891812, lon: 3.8917946,
                    tz: "Europe/Paris",
                    ref: "Booking · 6850519282"
                ),
            ]
        ),
        VDay(
            id: "d09", date: "09 set", weekday: "quarta-feira",
            title: "Montpellier — visitas de manhã, Aigues-Mortes à tarde", tone: .leisure,
            events: [
                VEvent(
                    time: "~09:00", icon: "🫖",
                    title: "Visita à Mme Maleville",
                    desc: "Antecipada para a manhã. Place Jean Bène fica no centro, acessível de tram.",
                    address: "33 Place Jean Bène, 34000 Montpellier",
                    maps: "33+Place+Jean+Bene+Montpellier",
                    lat: 43.6041278, lon: 3.8956694,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~11:00", icon: "🏫",
                    title: "Visita à Accent Français",
                    desc: "A 2 min da Place de la Comédie e pertinho da Gare Saint-Roch — dá para emendar direto no trem.",
                    address: "Accent Français, 2 Rue de Verdun, 34000 Montpellier",
                    maps: "Accent+Francais+Montpellier",
                    lat: 43.6077617, lon: 3.8804644,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~12:30", icon: "🥖",
                    title: "Almoço rápido perto da Gare Saint-Roch",
                    desc: "Comer leve antes de embarcar. O Empanadas Club tem formule a €10.",
                    address: "Gare de Montpellier Saint-Roch, Pl. Auguste Gibert, 34000 Montpellier",
                    maps: "Gare+Montpellier+Saint+Roch",
                    lat: 43.6057616, lon: 3.8801889,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "13:50", icon: "🚆",
                    title: "TGV INOUI 6204 + TER 77557 — Montpellier → Aigues-Mortes",
                    desc: "⚡ O trem mais rápido do dia: 1h14. TGV até Nîmes (14:15), baldeação de 9 min, TER 14:24 → Aigues-Mortes 15:04. ⚠️ Conexão curta: se o TGV atrasar, o das 14:12 chega às 16:09 com 35 min de folga.",
                    address: "Gare de Montpellier Saint-Roch, Pl. Auguste Gibert, 34000 Montpellier",
                    maps: "Gare+Montpellier+Saint+Roch",
                    lat: 43.6057616, lon: 3.8801889,
                    tz: "Europe/Paris",
                    ref: "SNCF · comprar no dia (~€6–17/pax)"
                ),
                VEvent(
                    time: "15:04", icon: "🏰",
                    title: "Aigues-Mortes — cidade murada e as salinas rosas",
                    desc: "Muralhas medievais do séc. XIII, Tour de Constance, e o trenzinho turístico pelas Salins du Midi. O rosa vem da alga Dunaliella salina — setembro é o auge da cor, depois de um verão inteiro de evaporação.",
                    address: "Aigues-Mortes, 30220, Gard",
                    maps: "Aigues-Mortes+Salins+du+Midi",
                    lat: 43.5576922, lon: 4.1833878,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~18:30", icon: "🌅",
                    title: "Golden hour nas salinas",
                    desc: "Fim de tarde é quando o rosa fica mais intenso e a luz favorece as fotos. Bom momento para a Pocket 3.",
                    address: "Salins d'Aigues-Mortes, 30220",
                    maps: "Salins+Aigues-Mortes",
                    lat: 43.5576922, lon: 4.1833878,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "18:49", icon: "🚆",
                    title: "TER 77582 — Aigues-Mortes → Montpellier",
                    desc: "Chegada 20:25 em Saint-Roch. Alternativas: 17:20 (chega 19:00) se quiserem jantar em Montpellier, ou o último às 20:07 (chega 22:03).",
                    address: "Gare d'Aigues-Mortes, 30220",
                    maps: "Gare+Aigues-Mortes",
                    lat: 43.5712252, lon: 4.1913436,
                    tz: "Europe/Paris",
                    ref: "SNCF · comprar no dia"
                ),
                VEvent(
                    time: "noite", icon: "🏨",
                    title: "Ibis Budget Montpellier — 2ª noite",
                    desc: "Jantar no centro ou perto do hotel. Amanhã: check-out às 11h e carro às 11h30.",
                    address: "Rue des Frères Lumière, ZA Blaise Pascal, 34000 Montpellier",
                    maps: "Ibis+Budget+Montpellier+Centre+Millenaire",
                    lat: 43.5891812, lon: 3.8917946,
                    tz: "Europe/Paris",
                    ref: "Booking · 6850519282"
                ),
            ]
        ),
        VDay(
            id: "d10", date: "10 set", weekday: "quinta-feira",
            title: "Montpellier → Montmeyan", tone: .travel,
            events: [
                VEvent(
                    time: "10:00", icon: "🚗",
                    title: "Retirar carro — Alamo (Peugeot 308 aut. ou similar)",
                    desc: "3 dias, one-way até Marseille. Levar voucher (no app), CNH, passaporte e cartão de crédito do titular.",
                    address: "Alamo — Gare de Montpellier Saint-Roch, Pl. Auguste Gibert, 34000 Montpellier",
                    maps: "Alamo+Gare+Montpellier+Saint+Roch",
                    lat: 43.6036714, lon: 3.8796437,
                    tz: "Europe/Paris",
                    ref: "Alamo · voucher no app"
                ),
                VEvent(
                    time: "~10:45", icon: "🛣️",
                    title: "Estrada: Montpellier → Aix-en-Provence",
                    desc: "~170 km pela A9 + A7/A8, ~1h50. Chegada em Aix por volta das 12:40.",
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~12:45", icon: "🥐",
                    title: "Almoço em Aix-en-Provence",
                    desc: "Estacionar no Parking Mignet ou Rotonde e almoçar no Cours Mirabeau, a avenida mais charmosa da Provence — fontes, platanas e cafés históricos como Les Deux Garçons, frequentado por Cézanne.",
                    address: "Cours Mirabeau, 13100 Aix-en-Provence",
                    maps: "Cours+Mirabeau+Aix-en-Provence",
                    lat: 43.52665876340277, lon: 5.448134243819376,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~14:15", icon: "🛣️",
                    title: "Estrada: Aix → Montmeyan",
                    desc: "~75 km, ~1h por estradas provençais (D560/D13). Paisagem linda de vinhedos e oliveiras.",
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~15:30", icon: "🏡",
                    title: "Check-in — Airbnb Montmeyan (hôte: Yael)",
                    desc: "3 noites (10 → 13/09). Check-in a partir das 15:00. Gîte tranquilo com vista para o Parque do Verdon.",
                    address: "56 Route de Riez, 83670 Montmeyan, França",
                    maps: "56+Route+de+Riez+83670+Montmeyan",
                    lat: 43.648746, lon: 6.063175,
                    tz: "Europe/Paris",
                    ref: "Airbnb · hôte Yael"
                ),
            ]
        ),
        VDay(
            id: "d11", date: "11 set", weekday: "sexta-feira",
            title: "Provence — Moustiers, porcelanas & Verdon", tone: .leisure,
            events: [
                VEvent(
                    time: "~09:00", icon: "🏺",
                    title: "Moustiers-Sainte-Marie — feira de sexta + capital da faiança",
                    desc: "A 'cidadezinha das porcelanas'! Mercado semanal toda sexta de manhã na Place Montelupo, em frente ao Museu da Faiança. O vilarejo é mundialmente famoso desde o séc. XVII pela faiança pintada à mão — ateliês como Bondil e L'atelier des Cigales abertos para visita. ~40 min de carro de Montmeyan.",
                    address: "Place Montelupo, 04360 Moustiers-Sainte-Marie",
                    maps: "Place+Montelupo+Moustiers-Sainte-Marie",
                    lat: 43.8458, lon: 6.2215,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~11:00", icon: "⭐",
                    title: "Capela Notre-Dame de Beauvoir & a estrela suspensa",
                    desc: "Trilha curta (~20 min de subida) até a capela com vista panorâmica do vilarejo e da estrela dourada suspensa entre as falésias — a lenda do cavaleiro de Blacas.",
                    address: "Chapelle Notre-Dame de Beauvoir, Moustiers-Sainte-Marie",
                    maps: "Chapelle+Notre-Dame+de+Beauvoir+Moustiers",
                    lat: 43.8482313, lon: 6.2240714,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~12:30", icon: "🍽️",
                    title: "Almoço em Moustiers",
                    desc: "Terraços com vista nas ruelas de pedra. Provar a truta local e os vinhos de Provence.",
                    address: "Centro de Moustiers-Sainte-Marie, 04360",
                    maps: "Restaurants+Moustiers-Sainte-Marie",
                    lat: 43.8458, lon: 6.2215,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~14:30", icon: "🛶",
                    title: "Lac de Sainte-Croix — pedalinho na entrada do cânion",
                    desc: "Alugar pedalinho ou caiaque na Pont du Galetas (~€20-30/h) e remar para DENTRO das Gorges du Verdon — águas turquesa entre falésias de 700m. Imperdível!",
                    address: "Pont du Galetas, Lac de Sainte-Croix, 83630 Aiguines",
                    maps: "Pont+du+Galetas+Lac+Sainte-Croix",
                    lat: 43.8017, lon: 6.2494,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~17:00", icon: "🌄",
                    title: "Mirantes de Aiguines ou Route des Crêtes",
                    desc: "Fim de tarde com vista: o vilarejo de Aiguines (famoso pelos torneiros de madeira) ou, se sobrar fôlego, a Route des Crêtes em La Palud — 14 belvederes sobre o cânion. Golden hour espetacular.",
                    address: "Aiguines, 83630, Var",
                    maps: "Aiguines+village+Verdon",
                    lat: 43.7355679, lon: 6.3768878,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "23:00", icon: "💻",
                    title: "Icatalk — 18:00 de Brasília",
                    desc: "⚠️ Única sexta da viagem que cai fora do Brasil. 23h no horário francês, já de volta ao Airbnb em Montmeyan. Confirmar a qualidade do Wi-Fi com a Yael antes — é zona rural. Lembrar que o casamento é no dia seguinte.",
                    address: "56 Route de Riez, 83670 Montmeyan",
                    maps: "56+Route+de+Riez+83670+Montmeyan",
                    lat: 43.648746, lon: 6.063175,
                    tz: "Europe/Paris"
                ),
            ]
        ),
        VDay(
            id: "d12", date: "12 set", weekday: "sábado",
            title: "O Casamento 💒", tone: .wedding,
            events: [
                VEvent(
                    time: "~13:45", icon: "👔",
                    title: "Sair de Montmeyan rumo a Aups",
                    desc: "Dress code: terno e gravata — e nada de vermelho (cor do casamento). Aups fica a ~12 min de carro de Montmeyan.",
                    address: "Montmeyan → Aups, Var",
                    maps: "Montmeyan+to+Aups",
                    lat: 43.6274, lon: 6.2234,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "14:30", icon: "⛪",
                    title: "Missa — Collégiale Saint-Pancrace d'Aups",
                    desc: "Cerimônia religiosa de Bastien & Anne-Clotilde, celebrada pelo Abbé Joseph-Marie Sallé.",
                    address: "Collégiale Saint-Pancrace, Place de la Collégiale, 83630 Aups",
                    maps: "Collegiale+Saint-Pancrace+Aups",
                    lat: 43.627374, lon: 6.2243932,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "17:30", icon: "🥂",
                    title: "Cocktail — Domaine de la Roquette",
                    desc: "Coquetel das 17h30 às 19h30 nos jardins do domaine, em Montmeyan (~12 min de Aups).",
                    address: "Domaine de la Roquette, 3173 Route de Riez, 83670 Montmeyan",
                    maps: "Domaine+de+la+Roquette+3173+Route+de+Riez+Montmeyan",
                    lat: 43.6727, lon: 6.0537,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "19:30", icon: "🍽️",
                    title: "Jantar à mesa (dîner placé)",
                    desc: "Jantar com lugares marcados, seguido de festa. À noite, arrumar as malas: amanhã a saída é cedo!",
                    address: "Domaine de la Roquette, 3173 Route de Riez, 83670 Montmeyan",
                    maps: "Domaine+de+la+Roquette+Montmeyan",
                    lat: 43.6727, lon: 6.0537,
                    tz: "Europe/Paris"
                ),
            ]
        ),
        VDay(
            id: "d13", date: "13 set", weekday: "domingo",
            title: "Montmeyan → Marselha → Paris", tone: .travel,
            events: [
                VEvent(
                    time: "~07:00", icon: "🌅",
                    title: "Saída do Airbnb",
                    desc: "Dirigir ~1h30 até Marseille. Abastecer o tanque antes de devolver (posto perto da estação).",
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "09:00", icon: "🚗",
                    title: "Devolver carro — Alamo, Gare de Marseille St-Charles",
                    desc: "Margem de 1h até o trem. Conferir instruções de devolução no voucher.",
                    address: "Alamo — Gare de Marseille St-Charles, Square Narvik, 13001 Marseille",
                    maps: "Alamo+Gare+Marseille+Saint+Charles",
                    lat: 43.3028347, lon: 5.3783715,
                    tz: "Europe/Paris",
                    ref: "Alamo · devolução"
                ),
                VEvent(
                    time: "10:11", icon: "🚄",
                    title: "Frecciarossa 6104 — Marseille → Paris Gare de Lyon",
                    desc: "Vagão 7, assentos 8A e 8B (Standard Silêncio). Chegada às 13:34.",
                    address: "Paris Gare de Lyon, Place Louis-Armand, 75012 Paris",
                    maps: "Paris+Gare+de+Lyon",
                    lat: 48.8446001, lon: 2.3737772,
                    tz: "Europe/Paris",
                    ref: "Trenitalia/Omio · DMDKRN"
                ),
                VEvent(
                    time: "~14:15", icon: "👋",
                    title: "Visita à prima da Ana — Mitry-Mory",
                    desc: "De Gare de Lyon: Metrô L14 até Châtelet (~5 min) + RER B direção Mitry-Claye até a estação Villeparisis–Mitry-le-Neuf (~30 min) + ~6 min a pé. Total ~50 min. Tarde em família.",
                    address: "Mitry-Mory, 77290, Île-de-France",
                    maps: "Villeparisis+Mitry+le+Neuf+RER",
                    lat: 48.9531589, lon: 2.6031794,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "~20:00", icon: "🚇",
                    title: "Volta para o Mercure Levallois",
                    desc: "RER B (Villeparisis → Gare du Nord ~28 min) + Metrô L3 (Gare du Nord → Louise Michel ~18 min) + 3 min a pé. Total ~55 min. Último RER B de Mitry passa à meia-noite, sem stress.",
                    address: "48 Rue Chaptal, 92300 Levallois-Perret",
                    maps: "Mercure+Paris+Levallois+48+Rue+Chaptal",
                    lat: 48.889729, lon: 2.2827056,
                    tz: "Europe/Paris",
                    ref: "Booking · 5508609912 · PIN 8588"
                ),
            ]
        ),
        VDay(
            id: "d14", date: "14 set", weekday: "segunda-feira",
            title: "Paris → Porto", tone: .travel,
            events: [
                VEvent(
                    time: "~07:40", icon: "🚇",
                    title: "Check-out Mercure + Metrô até Porte Maillot",
                    desc: "Check-out do Mercure (a partir das 06:30). Metrô L3 Louise Michel → Porte Maillot são 2 paradas (~5 min) + 4 min a pé até o Parking Pershing. Estejam lá até ~08:30.",
                    address: "Porte Maillot — Parking Pershing, 22-24 Bd Pershing, 75017 Paris",
                    maps: "Parking+Pershing+Porte+Maillot+Beauvais+shuttle",
                    lat: 48.8799, lon: 2.2821,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "09:00", icon: "🚌",
                    title: "Shuttle Aérobus — Porte Maillot → Beauvais",
                    desc: "Bilhetes já comprados (2 idas). Viagem ~1h15, chegada ~10:15. Guichês abertos das 3h às 19h30 e só aceitam cartão.",
                    address: "Parking Pershing, 22-24 Boulevard Pershing, 75017 Paris",
                    maps: "Navette+Beauvais+Porte+Maillot",
                    lat: 48.8799, lon: 2.2821,
                    tz: "Europe/Paris",
                    ref: "Aéroport Beauvais · 8WCM8N"
                ),
                VEvent(
                    time: "~10:15", icon: "🛬",
                    title: "Chegada ao Aéroport de Beauvais-Tillé",
                    desc: "2h40 de folga até o voo. Check-in Ryanair + segurança. Beauvais é pequeno, mas as filas podem surpreender.",
                    address: "Aéroport de Beauvais-Tillé, 60004 Beauvais",
                    maps: "Aeroport+Beauvais+Tille",
                    lat: 49.4598402, lon: 2.1144819,
                    tz: "Europe/Paris"
                ),
                VEvent(
                    time: "12:55", icon: "✈️",
                    title: "Voo Ryanair FR 595 — Beauvais → Porto",
                    desc: "Chegada ~14:10 (hora de Portugal, -1h vs França).",
                    address: "Aéroport de Beauvais-Tillé, 60004 Beauvais",
                    maps: "Aeroport+Beauvais+Tille",
                    lat: 49.4598402, lon: 2.1144819,
                    tz: "Europe/Paris",
                    ref: "Ryanair · X5I2TQ",
                    lounge: "Beauvais é um aeroporto low-cost básico — sem sala VIP. Levem lanches e água (depois da segurança as opções são limitadas e caras)."
                ),
                VEvent(
                    time: "~14:30", icon: "🤝",
                    title: "Porto — chegada e encontro com Pastor Roberto",
                    desc: "⚠️ Agora é a única tarde/noite no Porto — vocês saem na manhã do dia 15. Aproveitem bem: Ribeira, caves de Vinho do Porto em Gaia, pôr do sol sobre o Douro. Hospedagem em Palmeira de Faro com o pastor (~50 min do centro).",
                    address: "Aeroporto Francisco Sá Carneiro, Pedras Rubras, 4470-558 Maia",
                    maps: "Aeroporto+Francisco+Sa+Carneiro",
                    lat: 41.2368178, lon: -8.6708281,
                    tz: "Europe/Lisbon"
                ),
            ]
        ),
        VDay(
            id: "d15", date: "15 set", weekday: "terça-feira",
            title: "Porto → Londres", tone: .travel,
            events: [
                VEvent(
                    time: "~06:45", icon: "🚗",
                    title: "Traslado Palmeira de Faro → aeroporto do Porto",
                    desc: "A esposa do Pastor Roberto leva vocês. Voo às 09:30, cheguem por volta das 07:30. Trajeto ~50 min.",
                    address: "Aeroporto Francisco Sá Carneiro, Pedras Rubras, 4470-558 Maia",
                    maps: "Aeroporto+Francisco+Sa+Carneiro",
                    lat: 41.2368178, lon: -8.6708281,
                    tz: "Europe/Lisbon"
                ),
                VEvent(
                    time: "09:30", icon: "✈️",
                    title: "Voo Ryanair FR 520 — Porto → London Stansted",
                    desc: "Vocês 3: Eliel, Ana Paula e José Roberto Dos Santos. Chegada 11:55 (hora UK, mesmo fuso que Portugal). Duração 2h25.",
                    address: "London Stansted Airport, Bassingbourn Rd, Stansted CM24 1QW",
                    maps: "London+Stansted+Airport",
                    lat: 51.8899745, lon: 0.2615261,
                    tz: "Europe/London",
                    ref: "Ryanair · Q67BHK",
                    lounge: "Porto: ANA Lounge, nível 3 junto aos portões 31–32. Priority Pass ou reserva avulsa ~€22–38 em ana.pt — vista pra pista e café da manhã."
                ),
                VEvent(
                    time: "~12:15", icon: "🛂",
                    title: "Imigração UK + Stansted Express → Liverpool Street",
                    desc: "Fila de imigração para brasileiros: ~30-60 min. Depois, Stansted Express (~47 min, ~£20/pessoa, trens a cada 15 min). Chegada em Liverpool Street por volta das 14h.",
                    address: "Liverpool Street Station, London EC2M 7QH",
                    maps: "Liverpool+Street+Station+London",
                    lat: 51.5172859, lon: -0.0827853,
                    tz: "Europe/London"
                ),
                VEvent(
                    time: "~14:30", icon: "🏠",
                    title: "Check-in — Airbnb da Maura, Liverpool Street",
                    desc: "2 noites (15 e 16/09). ⚠️ A anfitriã exige que a carta de check-in seja lida por completo antes da chegada — códigos, porta certa e regras de silêncio com os vizinhos. Leia com antecedência e salve offline.",
                    address: "Central London, perto da Liverpool Street Station",
                    maps: "Liverpool+Street+Station+London",
                    lat: 51.5172859, lon: -0.0827853,
                    tz: "Europe/London",
                    ref: "Airbnb · hôte Maura"
                ),
                VEvent(
                    time: "tarde", icon: "🤝",
                    title: "Encontro com o Ivan em Londres",
                    desc: "Foi ele quem pediu a antecipação para terça. Tarde e noite livres na cidade.",
                    tz: "Europe/London"
                ),
                VEvent(
                    time: "21:15", icon: "🛫",
                    title: "Pastor Roberto volta — TAP TP 1331, Gatwick → Porto",
                    desc: "Só ele, no mesmo dia. Tarifa Classic (inclui bagagem de porão). Terminal S, check-in fecha 20:30, abre dia 14 às 09:15. Chegada no Porto 23:40. ⚠️ Dados de passaporte pendentes na reserva — ele precisa preencher antes.",
                    address: "London Gatwick Airport, South Terminal, Horley RH6 0NP",
                    maps: "London+Gatwick+South+Terminal",
                    lat: 51.156167, lon: -0.1626062,
                    tz: "Europe/London",
                    ref: "TAP · YZIMAB · bilhete 0472526389155",
                    lounge: "Para o Pastor: Gatwick South Terminal tem o No1 Lounge (Priority Pass/pré-reserva ~£35)."
                ),
                VEvent(
                    time: "~19:00", icon: "🚆",
                    title: "Trem do Pastor até Gatwick",
                    desc: "Thameslink ou Southern (~£12–16, de Farringdon ou London Bridge) em vez do Gatwick Express (£24,10). Sair de Londres por volta das 19h para chegar com folga.",
                    address: "Farringdon ou London Bridge Station, London",
                    maps: "Thameslink+Farringdon+to+Gatwick",
                    lat: 51.5156, lon: -0.1047,
                    tz: "Europe/London"
                ),
            ]
        ),
        VDay(
            id: "d16", date: "16 set", weekday: "quarta-feira",
            title: "Londres — dia inteiro", tone: .leisure,
            events: [
                VEvent(
                    time: "dia todo", icon: "🇬🇧",
                    title: "Londres com o Ivan",
                    desc: "Dia livre na cidade. Brick Lane, City, os clássicos — tudo a partir de Liverpool Street. Airbnb da Maura (2ª noite).",
                    address: "Liverpool Street / Shoreditch, London",
                    maps: "Liverpool+Street+Station+London",
                    lat: 51.5172859, lon: -0.0827853,
                    tz: "Europe/London"
                ),
                VEvent(
                    time: "refeições", icon: "🍺",
                    title: "Wetherspoon — Hamilton Hall",
                    desc: "Dentro da própria estação de Liverpool Street, no antigo salão de baile do Great Eastern Hotel. Pratos de £1,99 a £13,58, a maioria já com bebida inclusa.",
                    address: "Hamilton Hall, Bishopsgate, London EC2M 7PY",
                    maps: "Hamilton+Hall+Wetherspoon+London",
                    lat: 51.5175171, lon: -0.0809911,
                    tz: "Europe/London"
                ),
            ]
        ),
        VDay(
            id: "d17", date: "17 set", weekday: "quinta-feira",
            title: "Londres → Marselha → Madrid → 🇧🇷", tone: .travel,
            events: [
                VEvent(
                    time: "08:00", icon: "🚶",
                    title: "Check-out do Airbnb + caminhada até Liverpool Street",
                    desc: "Deixar tudo conforme as instruções da Maura (chaves, códigos, limpeza básica). A estação fica a poucos minutos a pé.",
                    address: "Central London, perto da Liverpool Street Station",
                    maps: "Liverpool+Street+Station+London",
                    lat: 51.5172859, lon: -0.0827853,
                    tz: "Europe/London"
                ),
                VEvent(
                    time: "08:25", icon: "🚆",
                    title: "Stansted Express → Stansted Airport",
                    desc: "~47 min, ~£20/pessoa (trens a cada 15 min). Chegada ~09:12 — ~2h antes do voo, ideal para Ryanair internacional.",
                    address: "Liverpool Street Station, London EC2M 7QH",
                    maps: "Stansted+Express+Liverpool+Street",
                    lat: 51.5173, lon: -0.0828,
                    tz: "Europe/London"
                ),
                VEvent(
                    time: "11:15", icon: "✈️",
                    title: "Voo Ryanair FR 1468 — Stansted → Marseille",
                    desc: "Assentos 14A e 14B, tarifa Plus com mala de 20kg. Chegada 14:15 (hora França).",
                    address: "London Stansted Airport, CM24 1QW",
                    maps: "London+Stansted+Airport",
                    lat: 51.8899745, lon: 0.2615261,
                    tz: "Europe/London",
                    ref: "Ryanair · K512SN",
                    lounge: "Stansted: Escape Lounge, após a segurança (Priority Pass ou pré-reserva ~£30-40). Chegando às ~09:12, dá quase 2h de lounge antes do embarque."
                ),
                VEvent(
                    time: "17:55", icon: "✈️",
                    title: "Voo IB 1172 — Marseille → Madrid",
                    desc: "⚠️ Troca de terminal em MRS: vocês chegam no Terminal 2 (Ryanair) e a Iberia parte do Terminal 1 — são vizinhos, ~5-10 min a pé. Margem de 3h40, tranquilo. Chegada em Madri 19:45.",
                    address: "Aéroport Marseille Provence, 13700 Marignane",
                    maps: "Aeroport+Marseille+Provence",
                    lat: 43.440548, lon: 5.2228209,
                    tz: "Europe/Paris",
                    ref: "Iberia · N1L14",
                    lounge: "Marseille Terminal 1 (após a troca de terminal): Salon Lubéron (Priority Pass/pré-reserva) — ótimo pra passar parte das 3h40 de espera com conforto."
                ),
                VEvent(
                    time: "23:55", icon: "🌙",
                    title: "Voo IB 267 — Madrid → Guarulhos",
                    desc: "Passageiros: FELIPEJUNIOR/ELIEL + PEREIRADEALMEIDA/ANAPAULA. Chegada 18/09 às 05:55 (BRT).",
                    address: "Aeropuerto Adolfo Suárez Madrid-Barajas, 28042 Madrid",
                    maps: "Aeropuerto+Madrid+Barajas",
                    lat: 40.4936983, lon: -3.5674678,
                    tz: "Europe/Madrid",
                    ref: "Iberia · J1NDY",
                    lounge: "Madri T4S (voo intercontinental): Iberia Velázquez Premium Lounge, dentro do duty free (6h–1h) — executiva/oneworld Sapphire+. Com Priority Pass: Sala Neptuno, também no T4S. Ótima pra esperar o voo da meia-noite."
                ),
            ]
        ),
        VDay(
            id: "d18", date: "18 set", weekday: "sexta-feira",
            title: "Guarulhos → Congonhas → Londrina", tone: .home,
            events: [
                VEvent(
                    time: "05:55 BRT", icon: "🛬",
                    title: "Desembarque em Guarulhos (voo IB 267)",
                    desc: "Chegada do voo de Madri. A partir daqui: imigração (Polícia Federal) + esteira de bagagem. Contem ~1h a 1h30 — voo intercontinental costuma formar fila. Prontos por volta das 07:00–07:30.",
                    address: "Aeroporto Internacional de Guarulhos (GRU), Guarulhos – SP",
                    maps: "Aeroporto+de+Guarulhos",
                    lat: -23.4262732, lon: -46.4816737,
                    tz: "America/Sao_Paulo"
                ),
                VEvent(
                    time: "~07:30", icon: "🚕",
                    title: "Uber/táxi — Guarulhos → Congonhas",
                    desc: "⚠️ Aeroportos diferentes! ~40 min a 1h de trajeto, mais carregado numa sexta de manhã. Custo ~R$ 80–120. Chegada em CGH por volta das 08:30.",
                    address: "GRU → Aeroporto de Congonhas, Av. Washington Luís s/n, São Paulo – SP",
                    maps: "Aeroporto+de+Congonhas+Sao+Paulo",
                    lat: -23.6262622, lon: -46.6594291,
                    tz: "America/Sao_Paulo"
                ),
                VEvent(
                    time: "~08:30", icon: "🧳",
                    title: "Check-in LATAM em Congonhas",
                    desc: "Reserva separada da internacional: é preciso re-despachar as malas no balcão da LATAM. Voo às 11:10 — margem confortável de ~2h30. Se puderem levar só bagagem de mão neste trecho, ganham tempo.",
                    address: "Aeroporto de Congonhas (CGH), Av. Washington Luís s/n, São Paulo – SP",
                    maps: "Aeroporto+de+Congonhas+Sao+Paulo",
                    lat: -23.6262622, lon: -46.6594291,
                    tz: "America/Sao_Paulo"
                ),
                VEvent(
                    time: "11:10", icon: "✈️",
                    title: "Voo LATAM LA3120 — Congonhas (CGH) → Londrina (LDB)",
                    desc: "Voo direto, 1h15. Chegada em Londrina às 12:25.",
                    address: "Aeroporto de Congonhas (CGH), São Paulo – SP",
                    maps: "Aeroporto+de+Congonhas+Sao+Paulo",
                    lat: -23.6262622, lon: -46.6594291,
                    tz: "America/Sao_Paulo",
                    ref: "LATAM · QJBWJF"
                ),
                VEvent(
                    time: "12:25", icon: "🏠",
                    title: "Chegada em Londrina",
                    desc: "11 dias, 4 países, 1 casamento inesquecível. Bem-vindos de volta!",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa",
                    lat: -23.328542, lon: -51.1377836,
                    tz: "America/Sao_Paulo"
                ),
            ]
        ),
        VDay(
            id: "d18b", date: "18 set", weekday: "sexta (tarde)",
            title: "Retirada do carro em Londrina", tone: .home,
            events: [
                VEvent(
                    time: "12:30", icon: "🚗",
                    title: "Retirar carro — Localiza, Aeroporto de Londrina",
                    desc: "Fiat Mobi ou similar (Grupo B, compacto com ar). Retirada logo após o pouso das 12:25 — o balcão fica no próprio aeroporto. Devolução no mesmo local dia 21 de manhã.",
                    address: "Localiza — Aeroporto de Londrina, Av. Santos Dumont 1772, Novo Aeroporto, Londrina – PR",
                    maps: "Localiza+Aeroporto+de+Londrina",
                    lat: -23.328542, lon: -51.1377836,
                    tz: "America/Sao_Paulo",
                    ref: "Localiza · IT43063 54CJJ"
                ),
                VEvent(
                    time: "18:00", icon: "💻",
                    title: "Icatalk — 18h de Brasília",
                    desc: "✅ Já em casa e no fuso normal. Boa deixa para contar da viagem!",
                    tz: "America/Sao_Paulo"
                ),
            ]
        ),
        VDay(
            id: "d19", date: "19–20 set", weekday: "sábado e domingo",
            title: "Fim de semana em Londrina", tone: .leisure,
            events: [
                VEvent(
                    time: "livre", icon: "🏡",
                    title: "Dias livres com a Ana em Londrina",
                    desc: "Com o carro à disposição. Descansar do fuso e organizar as fotos e vídeos da viagem.",
                    tz: "America/Sao_Paulo"
                ),
            ]
        ),
        VDay(
            id: "d21", date: "21 set", weekday: "segunda-feira",
            title: "Londrina → Ribeirão Preto (só Eliel)", tone: .home,
            events: [
                VEvent(
                    time: "~05:45", icon: "🚗",
                    title: "Devolver carro — Localiza, Aeroporto de Londrina",
                    desc: "⚠️ Confirmar com a loja se abre antes das 6h — nem toda unidade de aeroporto opera tão cedo. Abastecer na véspera, ainda em Londrina. Devolução no mesmo local da retirada.",
                    address: "Localiza — Aeroporto de Londrina, Av. Santos Dumont 1772, Novo Aeroporto, Londrina – PR",
                    maps: "Localiza+Aeroporto+de+Londrina",
                    lat: -23.328542, lon: -51.1377836,
                    tz: "America/Sao_Paulo",
                    ref: "Localiza · IT43063 54CJJ"
                ),
                VEvent(
                    time: "07:20", icon: "✈️",
                    title: "GOL G3 1209 — Londrina (LDB) → Congonhas (CGH)",
                    desc: "Tarifa Classic, assento 7C. Chegada 08:30. Bagagem: 10kg de mão + 12kg pequena + 23kg despachada.",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa",
                    lat: -23.328542, lon: -51.1377836,
                    tz: "America/Sao_Paulo",
                    ref: "GOL · QZDFUX"
                ),
                VEvent(
                    time: "08:30 → 10:10", icon: "⏱️",
                    title: "Conexão em Congonhas (1h40)",
                    desc: "Troca de avião, mas mesma reserva — a bagagem segue direto até Ribeirão Preto, sem re-despacho.",
                    address: "Aeroporto de Congonhas (CGH), Av. Washington Luís s/n, São Paulo – SP",
                    maps: "Aeroporto+de+Congonhas+Sao+Paulo",
                    lat: -23.6262622, lon: -46.6594291,
                    tz: "America/Sao_Paulo"
                ),
                VEvent(
                    time: "10:10", icon: "🏡",
                    title: "GOL G3 1338 — Congonhas (CGH) → Ribeirão Preto (RAO)",
                    desc: "Assento 8C. Chegada às 11:15. Fim da viagem!",
                    address: "Aeroporto Leite Lopes (RAO), Av. Thomaz Alberto Whately, Ribeirão Preto – SP",
                    maps: "Aeroporto+Leite+Lopes+Ribeirao+Preto",
                    lat: -21.1392477, lon: -47.7765262,
                    tz: "America/Sao_Paulo",
                    ref: "GOL · QZDFUX"
                ),
            ]
        ),
    ]
}

// MARK: - Badge "tudo reservado" com shimmer

private struct VShimmerBadge: View {
    @State private var animate = false

    var body: some View {
        Text("✅ Tudo reservado — 27 reservas confirmadas!")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(VPalette.shimmerText)
            .padding(.horizontal, 24)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    Capsule().fill(VPalette.shimmerBase.opacity(0.18))
                    LinearGradient(
                        colors: [
                            VPalette.shimmerBase.opacity(0.15),
                            VPalette.shimmerMint.opacity(0.45),
                            VPalette.shimmerBase.opacity(0.15),
                        ],
                        startPoint: animate ? .trailing : .leading,
                        endPoint: animate ? UnitPoint(x: 2.2, y: 0.5) : UnitPoint(x: -1.2, y: 0.5)
                    )
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(VPalette.shimmerMint.opacity(0.5), lineWidth: 1)
            )
            .onAppear {
                withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}

// MARK: - Linha de evento

private struct VEventRow: View {
    let event: VEvent
    let accent: Color
    let showTopBorder: Bool

    /// DST-aware, for the same reason as `zoneLabel`: in September these events are
    /// on summer time, so the standard-time abbreviation would be off by an hour.
    static func zoneAbbreviation(_ zone: TimeZone, at date: Date) -> String {
        let style: NSTimeZone.NameStyle =
            zone.isDaylightSavingTime(for: date) ? .shortDaylightSaving : .shortStandard
        return zone.localizedName(for: style, locale: Locale(identifier: "pt_BR"))
            ?? zone.abbreviation(for: date)
            ?? zone.identifier
    }

    /// Real instant of this event, used only to decide summer vs winter time.
    private var eventDate: Date? {
        TripEngine.shared.stops.first { $0.title == event.title && $0.time == event.time }?.date
    }

    private var mapsURL: URL? {
        let label = event.address ?? event.mapsQuery?.replacingOccurrences(of: "+", with: " ")
        let encoded = label?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        // Prefer the verified coordinate: `ll` drops the pin exactly and `q` only
        // labels it, so Apple Maps never has to guess from the text.
        if let lat = event.lat, let lon = event.lon {
            var url = "https://maps.apple.com/?ll=\(lat),\(lon)"
            if let encoded { url += "&q=\(encoded)" }
            return URL(string: url)
        }

        guard let encoded else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(event.time)
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundColor(accent)
                    .multilineTextAlignment(.trailing)
                // The itinerary crosses four zones; an unlabelled "17:30" invites
                // reading it as local time.
                if let zone = event.timeZone, zone.identifier != TimeZone.current.identifier {
                    Text(VEventRow.zoneAbbreviation(zone, at: eventDate ?? Date()))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(VPalette.muted)
                }
            }
            .frame(width: 74, alignment: .trailing)

            Text(event.icon)
                .font(.system(size: 19))

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(VPalette.ink)

                Text(event.desc)
                    .font(.system(size: 12.8))
                    .foregroundColor(VPalette.descColor)
                    .lineSpacing(3)

                if let address = event.address, let url = mapsURL {
                    Link(destination: url) {
                        HStack(alignment: .top, spacing: 6) {
                            Text("📍").font(.system(size: 12))
                            Text(address)
                                .font(.system(size: 11.8, weight: .medium))
                                .underline(color: VPalette.mapsDot)
                        }
                        .foregroundColor(VPalette.mapsLink)
                    }
                    .padding(.top, 4)
                }

                if let lounge = event.lounge {
                    HStack(alignment: .top, spacing: 0) {
                        Text("🛋️ Sala VIP: ")
                            .fontWeight(.bold)
                            .fixedSize(horizontal: true, vertical: false)
                        Text(lounge)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 11.5))
                    .foregroundColor(VPalette.loungeText)
                    .lineSpacing(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(VPalette.loungeBase.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(VPalette.loungeBase.opacity(0.35), lineWidth: 1)
                    )
                    .padding(.top, 7)
                }

                if let ref = event.ref {
                    Text(ref)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(VPalette.refBase)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(VPalette.refBase.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .padding(.top, 7)
                }
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 12)
        .overlay(alignment: .top) {
            if showTopBorder {
                Rectangle()
                    .fill(VPalette.cardBorder)
                    .frame(height: 1)
            }
        }
    }
}

// MARK: - Seção de um dia (colapsável)

/// Picks between plain and tinted glass without duplicating the call site.
private struct VDayCardSurface: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        if let tint {
            content.glassCard(tint: tint, cornerRadius: 18)
        } else {
            content.glassCard(cornerRadius: 18)
        }
    }
}

private struct VDaySection: View {
    let day: VDay
    let isExpanded: Bool
    /// The day the trip is on right now, ringed so it is findable in a list of 17.
    var isFocused: Bool = false
    let onToggle: () -> Void

    private var dayNumber: String {
        String(day.date.split(separator: " ").first ?? Substring(day.date))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerButton
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(day.events.enumerated()), id: \.offset) { idx, ev in
                        VEventRow(event: ev, accent: day.tone.accent, showTopBorder: idx != 0)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .padding(.top, 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        // The focused day carries the tint so it still stands out from sixteen
        // siblings; the rest are plain glass.
        .modifier(VDayCardSurface(tint: isFocused ? day.tone.accent : nil))
        .shadow(color: Color.black.opacity(isFocused ? 0.18 : 0.10), radius: 16, y: 9)
    }

    private var headerButton: some View {
        Button(action: onToggle) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(day.tone.accent)
                    .frame(width: 5)

                HStack(alignment: .center, spacing: 16) {
                    VStack(spacing: 0) {
                        Text(dayNumber)
                            .font(.system(size: 26, weight: .semibold, design: .serif))
                            .foregroundColor(day.tone.accent)
                        Text("set")
                            .font(.system(size: 12.5))
                            .italic()
                            .foregroundColor(VPalette.muted)
                    }
                    .frame(minWidth: 54)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(day.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(VPalette.ink)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            Text(day.weekday)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(VPalette.muted)
                            Text(day.tone.label.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.4)
                                .foregroundColor(day.tone.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 2)
                                .background(day.tone.chip)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VPalette.mapsDot)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.25), value: isExpanded)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View principal

struct ViagemView: View {
    /// Only the day in focus starts open. Opening all 17 buries the one that matters.
    @State private var expandedDays: Set<String> = []
    @State private var focusDayID: String?
    @Namespace private var glassNamespace
    @StateObject private var locator = TripLocator.shared
    @StateObject private var alerts = TripNotifications.shared
    @State private var now = Date()

    /// Drives the "agora" card; a minute is plenty for a two-week itinerary.
    private let tick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    heroHeader

                    VStack(spacing: 16) {
                        // Above "AGORA" on purpose: while a flight is in the air,
                        // it is the only thing on this screen worth looking at.
                        FlightProgressCard(legs: flightLegs, now: now)

                        statusCard

                        // One container for the seventeen day cards: glass cannot
                        // sample other glass, and these are siblings on screen.
                        // `glassEffectID` lets a card's shape morph as it expands
                        // instead of the effect being torn down and rebuilt.
                        GlassEffectContainer(spacing: 0) {
                            ForEach(VData.days) { day in
                                VDaySection(
                                    day: day,
                                    isExpanded: expandedDays.contains(day.id),
                                    isFocused: day.id == focusDayID,
                                    onToggle: { toggle(day.id) }
                                )
                                .glassEffectID(day.id, in: glassNamespace)
                                .id(day.id)
                            }
                        }
                        footerNote
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .onAppear { focusToday(proxy: proxy) }
            }
        }
        .background(VPalette.bg.ignoresSafeArea())
        .navigationTitle("Viagem")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                styledNavTitle
            }
        }
        .onReceive(tick) { now = $0 }
        .task {
            TripEngine.shared.load(ViagemBridge.makeStops())
            locator.start()
            await alerts.requestAuthorizationIfNeeded()
            await alerts.rescheduleAll(stops: TripEngine.shared.stops)
            publishNextStopToWidget()
        }
    }

    // MARK: - Agora

    private var currentStop: TripStop? { TripEngine.shared.currentStop(now: now) }

    /// Flight legs paired out of the itinerary. Rebuilt with the minute tick,
    /// which is also what keeps the card honest after `TripEngine` loads.
    private var flightLegs: [FlightLeg] { FlightLegBuilder.legs(from: TripEngine.shared.stops) }
    private var nextStop: TripStop? { TripEngine.shared.nextStop(now: now) }

    /// Time zone to treat as "there": the place the traveller is actually standing
    /// when GPS knows, otherwise the zone of the itinerary entry in force.
    private var thereZone: TimeZone? {
        locator.stopHere?.timeZone ?? TripEngine.shared.activeTimeZone(now: now)
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("AGORA")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(VPalette.muted)
                Spacer()
                if alerts.scheduledCount > 0 {
                    Label("\(alerts.scheduledCount) alertas", systemImage: "bell.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(VPalette.muted)
                }
            }

            clockRow

            if let here = locator.stopHere {
                // Standing at a venue is not the same as being at that scheduled
                // activity: the cocktail is on the 12th even if you drive past the
                // estate today. Only claim the stage when the clock agrees too.
                let onSchedule = here.id == currentStop?.id || here.id == nextStop?.id
                statusLine(
                    icon: "location.fill",
                    tint: onSchedule ? VTone.leisure.accent : VPalette.muted,
                    text: onSchedule
                        ? "Você está em: \(placeName(here)) — \(here.title)"
                        : "Você está em: \(placeName(here))"
                )
            } else if let near = locator.nearestStop, let d = locator.nearestDistance {
                statusLine(icon: "location", tint: VPalette.muted,
                           text: "\(formatDistance(d)) de \(placeName(near))")
            } else if !locator.isAuthorized {
                statusLine(icon: "location.slash", tint: VPalette.muted,
                           text: "Localização desligada — etapa detectada só pelo horário")
            }

            if let next = nextStop {
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("A SEGUIR")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(VPalette.muted)
                    Text("\(next.icon) \(next.title)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VPalette.ink)
                    Text("\(next.dayDate) · \(next.time)\(zoneSuffix(next))")
                        .font(.system(size: 12))
                        .foregroundColor(VPalette.muted)
                }
            }
        }
        .padding(16)
        .glassCard(tint: VTone.leisure.accent, cornerRadius: 18)
    }

    /// Home and destination clocks side by side. Getting this wrong is how people
    /// miss flights, so it is shown even when both zones agree.
    private var clockRow: some View {
        let home = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        let there = thereZone ?? home
        return HStack(spacing: 0) {
            clockCell(place: "Brasil", zone: home)
            if there.identifier != home.identifier {
                Rectangle().fill(VPalette.cardBorder).frame(width: 1, height: 40)
                clockCell(place: countryName(for: there), zone: there, highlighted: true)
            }
        }
    }

    private func clockCell(place: String, zone: TimeZone, highlighted: Bool = false) -> some View {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        df.timeZone = zone
        return VStack(alignment: .leading, spacing: 1) {
            Text(place.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.0)
                .foregroundColor(VPalette.muted)
            Text(df.string(from: now))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(highlighted ? VTone.leisure.accent : VPalette.ink)
            Text(gmtOffset(zone, at: now))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(VPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, highlighted ? 14 : 0)
    }

    private func statusLine(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundColor(VPalette.ink)
            Spacer(minLength: 0)
        }
    }

    /// Country the trip is in, named from its time zone. "GMT+1" alone tells the
    /// traveller nothing about where that clock belongs.
    private func countryName(for zone: TimeZone) -> String {
        switch zone.identifier {
        case "America/Sao_Paulo": return "Brasil"
        case "Europe/Madrid": return "Espanha"
        case "Europe/Paris": return "França"
        case "Europe/Lisbon": return "Portugal"
        case "Europe/London": return "Inglaterra"
        default: return zone.identifier.split(separator: "/").last
            .map { $0.replacingOccurrences(of: "_", with: " ") } ?? zone.identifier
        }
    }

    /// Real offset at that instant, so September's summer time reads GMT+2 for
    /// Paris rather than the standard-time GMT+1.
    private func gmtOffset(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        let hours = seconds / 3600
        let minutes = abs(seconds % 3600) / 60
        let sign = hours < 0 ? "−" : "+"
        return minutes == 0
            ? "GMT\(sign)\(abs(hours))"
            : String(format: "GMT%@%d:%02d", sign, abs(hours), minutes)
    }

    /// Place name for the GPS line — the venue, not the scheduled activity.
    private func placeName(_ stop: TripStop) -> String {
        if let address = stop.address,
            let first = address.split(separator: ",").first,
            !first.isEmpty
        {
            return String(first).trimmingCharacters(in: .whitespaces)
        }
        return stop.title
    }

    /// Marks a time that is not in the phone's current zone, so "17:30" is never
    /// silently read as local.
    private func zoneSuffix(_ stop: TripStop) -> String {
        guard let zone = stop.timeZone, zone.identifier != TimeZone.current.identifier else { return "" }
        let at = stop.date ?? now
        return " · \(countryName(for: zone)) \(gmtOffset(zone, at: at))"
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        meters < 1000
            ? "\(Int(meters)) m"
            : String(format: "%.0f km", meters / 1000)
    }

    private func focusToday(proxy: ScrollViewProxy) {
        TripEngine.shared.load(ViagemBridge.makeStops())
        guard let id = TripEngine.shared.focusDayID(now: Date()) else {
            expandedDays = Set(VData.days.map(\.id))
            return
        }
        focusDayID = id
        expandedDays = [id]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(id, anchor: .top)
            }
        }
    }

    private func publishNextStopToWidget() {
        guard let next = TripEngine.shared.nextStop() else { return }
        WidgetDataManager.shared.updateTrip(
            title: next.title,
            time: "\(next.dayDate) · \(next.time)",
            icon: next.icon,
            date: next.date
        )
    }

    private func toggle(_ id: String) {
        withAnimation(.smooth(duration: 0.35)) {
            if expandedDays.contains(id) {
                expandedDays.remove(id)
            } else {
                expandedDays.insert(id)
            }
        }
    }

    private var styledNavTitle: some View {
        HStack(spacing: 6) {
            Text("✈️")
                .font(.system(size: 14))
            Text("Viagem")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(VPalette.titleAccent)
        }
    }

    private var heroHeader: some View {
        VStack(spacing: 12) {
            Text("CRONOLOGIA FINAL · 06–21 SET 2026")
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(3)
                .foregroundColor(VPalette.heroInk.opacity(0.78))
                .multilineTextAlignment(.center)

            Text("O roteiro, hora a hora")
                .font(.system(size: 38, weight: .semibold, design: .serif))
                .foregroundColor(VPalette.heroInk)
                .multilineTextAlignment(.center)

            Text("com todos os endereços no mapa")
                .font(.system(size: 18, design: .serif))
                .italic()
                .foregroundColor(VPalette.heroInk.opacity(0.9))
                .multilineTextAlignment(.center)

            VShimmerBadge()
                .padding(.top, 6)
        }
        .padding(.top, 56)
        .padding(.bottom, 46)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [VPalette.heroStart, VPalette.heroMid, VPalette.heroEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var footerNote: some View {
        VStack(spacing: 4) {
            Text("Toque em qualquer endereço para abrir no Apple Maps 📍")
                .font(.system(size: 18, design: .serif))
                .italic()
            Text("Boa viagem, Eliel & Ana 🤍")
                .font(.system(size: 15, design: .serif))
                .italic()
        }
        .foregroundColor(VPalette.mapsLink)
        .multilineTextAlignment(.center)
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ViagemView()
}

// MARK: - Ponte para o TripEngine

/// Flattens the nested day/event data into resolved `TripStop`s. Everything that
/// needs the itinerary outside this view — alerts, GPS, widgets, the bookings
/// screen — reads it through `TripEngine.shared.stops`, never from `VData`.
enum ViagemBridge {
    static func makeStops() -> [TripStop] {
        var out: [TripStop] = []
        for day in VData.days {
            for (index, event) in day.events.enumerated() {
                let tz = event.timeZone
                out.append(
                    TripStop(
                        id: "\(day.id).\(index)",
                        dayID: day.id,
                        dayTitle: day.title,
                        dayDate: day.date,
                        time: event.time,
                        icon: event.icon,
                        title: event.title,
                        detail: event.desc,
                        address: event.address,
                        ref: event.ref,
                        latitude: event.lat,
                        longitude: event.lon,
                        timeZoneID: event.tz,
                        date: TripParser.date(dateText: day.date, timeText: event.time, timeZone: tz)
                    )
                )
            }
        }
        // Entries with no clock time keep their listed order; the rest sort by instant.
        return out
    }
}
