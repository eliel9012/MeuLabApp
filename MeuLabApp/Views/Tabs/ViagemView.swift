import Combine
import CoreLocation
import SwiftUI
import UIKit

// ============================================================
// VIAGEM — MADRI, LONDRES E VOLTA
// Port nativo do roteiro (React/TSX "roteiro-madri-2026") para SwiftUI.
// Viagem Out–Nov/2026 — Eliel — Espanha, Inglaterra e Portugal:
// OpenSky Symposium, PostQat e workshop Apple em Londres.
// Timeline dia a dia com voos, hotéis, eventos e endereços
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
    case travel, leisure, event, home

    /// Same four hues in both appearances; only the luminance moves, because a
    /// 0x2E4470 navy that reads as ink on cream disappears against dark glass.
    var accent: Color {
        switch self {
        case .travel: return vAdaptive(light: 0x2E4470, dark: 0x8FAAD9)
        case .leisure: return vAdaptive(light: 0x2E7D5A, dark: 0x6FCFA0)
        case .event: return vAdaptive(light: 0xB8862D, dark: 0xE3B860)
        case .home: return vAdaptive(light: 0x6E5A8E, dark: 0xB49CD8)
        }
    }

    var chip: Color {
        switch self {
        case .event: return accent.opacity(0.16)
        default: return accent.opacity(0.14)
        }
    }

    var label: String {
        switch self {
        case .travel: return "deslocamento"
        case .leisure: return "dia livre"
        case .event: return "evento"
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
    /// Still waiting on a purchase, an approval or a decision — drawn with an amber
    /// tag so it reads as "not settled" next to the green locators.
    let pending: Bool

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
        lounge: String? = nil,
        pending: Bool = false
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
        self.pending = pending
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

// MARK: - Dados da viagem (fonte: roteiro-madri-2026.tsx)

private enum VData {
    static let days: [VDay] = [
        VDay(
            id: "d22", date: "22 out", weekday: "quinta-feira",
            title: "Antes de embarcar", tone: .event,
            events: [
                VEvent(
                    time: "livre", icon: "📄",
                    title: "Short paper JOAS — falta imprimir o pôster",
                    desc: "Pôster A0 já submetido em 01/10; falta só a impressão, por volta de 16 e 17/10. Prazo do short paper: 22/10.",
                    tz: "America/Sao_Paulo",
                    pending: true
                ),
            ]
        ),
        VDay(
            id: "d23", date: "23 out", weekday: "sexta-feira",
            title: "Ribeirão Preto → Londrina", tone: .travel,
            events: [
                VEvent(
                    time: "~05:00", icon: "🚗",
                    title: "Sair para o aeroporto de Ribeirão Preto",
                    desc: "Sair de Franca de madrugada para estar no aeroporto por volta das 5h.",
                    address: "Aeroporto Leite Lopes (RAO), Av. Thomaz Alberto Whately, Ribeirão Preto – SP",
                    maps: "Aeroporto+Leite+Lopes+Ribeirao+Preto",
                    lat: -21.1392477, lon: -47.7765262,
                    tz: "America/Sao_Paulo"
                ),
                VEvent(
                    time: "06:00", icon: "🛫",
                    title: "Voo Azul AD 4211 — Ribeirão Preto (RAO) → Londrina (LDB)",
                    desc: "Chegada às 09:55. Voo com 1 conexão.",
                    address: "Aeroporto Leite Lopes (RAO), Av. Thomaz Alberto Whately, Ribeirão Preto – SP",
                    maps: "Aeroporto+Leite+Lopes+Ribeirao+Preto",
                    lat: -21.1392477, lon: -47.7765262,
                    tz: "America/Sao_Paulo",
                    ref: "Azul · WMLUKZ"
                ),
            ]
        ),
        VDay(
            id: "d24", date: "24 out", weekday: "sábado",
            title: "Londrina → Guarulhos → Madri", tone: .travel,
            events: [
                VEvent(
                    time: "05:15", icon: "✈️",
                    title: "Voo LATAM LA3691 — Londrina (LDB) → Guarulhos (GRU)",
                    desc: "Chegada às 06:35. Voo direto.",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa",
                    lat: -23.328542, lon: -51.1377836,
                    tz: "America/Sao_Paulo",
                    ref: "LATAM · LA3691"
                ),
                VEvent(
                    time: "06:35 → 13:50", icon: "⏱️",
                    title: "Conexão em Guarulhos (~7h) — bem folgada",
                    desc: "⚠️ Bilhetes separados (LATAM + Air Europa): retirar a bagagem, trocar de terminal e despachar de novo no balcão da Air Europa. Janela de 7h15 entre o pouso e a decolagem.",
                    address: "Aeroporto Internacional de Guarulhos (GRU), Rod. Hélio Smidt s/n, Cumbica, Guarulhos – SP",
                    maps: "Aeroporto+Internacional+de+Guarulhos",
                    lat: -23.4262732, lon: -46.4816737,
                    tz: "America/Sao_Paulo"
                ),
                VEvent(
                    time: "13:50", icon: "✈️",
                    title: "Voo Air Europa UX 058 — Guarulhos (GRU) → Madri (MAD)",
                    desc: "Chegada às 04:00 de 25/10 (hora de Madri). Economy Standard, 10h10 de voo noturno. O check-in abre de 24 a 48h antes.",
                    address: "Aeroporto Internacional de Guarulhos (GRU), Rod. Hélio Smidt s/n, Cumbica, Guarulhos – SP",
                    maps: "Aeroporto+Internacional+de+Guarulhos",
                    lat: -23.4262732, lon: -46.4816737,
                    tz: "America/Sao_Paulo",
                    ref: "Air Europa · UX058"
                ),
            ]
        ),
        VDay(
            id: "d25", date: "25 out", weekday: "domingo",
            title: "Madri", tone: .leisure,
            events: [
                VEvent(
                    time: "04:00", icon: "🛬",
                    title: "Chegada a Madri",
                    desc: "A Europa saiu do horário de verão nesta madrugada: Madri fica 4h à frente de Brasília e Londres, 3h. Fila de imigração com biometria do EES.",
                    address: "Aeroporto Adolfo Suárez Madrid-Barajas, Av. de la Hispanidad s/n, 28042 Madrid",
                    maps: "Aeropuerto+Adolfo+Suarez+Madrid+Barajas",
                    lat: 40.4936983, lon: -3.5674678,
                    tz: "Europe/Madrid"
                ),
                VEvent(
                    time: "15:00", icon: "🏨",
                    title: "Check-in — Password to Madrid Plaza España",
                    desc: "1 noite (25 → 26/10), quarto individual econômico, café da manhã incluído, tarifa não reembolsável. Pedir para guardar a mala de manhã, já que o check-in é só às 15h.",
                    address: "Password to Madrid Plaza España, Calle San Leonardo 12, 28015 Madrid",
                    maps: "Calle+San+Leonardo+12+Madrid",
                    lat: 40.4246355, lon: -3.7113767,
                    tz: "Europe/Madrid"
                ),
                VEvent(
                    time: "21:00", icon: "🗳️",
                    title: "Brasil — segundo turno",
                    desc: "As urnas fecham às 17h de Brasília, que são 21h em Madri. Fora do domicílio eleitoral: justificar pelo e-Título no dia ou em até 60 dias.",
                    tz: "Europe/Madrid"
                ),
            ]
        ),
        VDay(
            id: "d26", date: "26 out", weekday: "segunda-feira",
            title: "Madri → Londres", tone: .travel,
            events: [
                VEvent(
                    time: "07:00", icon: "🚇",
                    title: "Sair para o Terminal 4S",
                    desc: "Checkout cedo; confira se o café já está servido nesse horário. O T4S é o satélite, com trem interno, e a saída do Espaço Schengen passa por controle de passaporte. Estar lá umas 2h30 antes do voo.",
                    address: "Password to Madrid Plaza España, Calle San Leonardo 12, 28015 Madrid",
                    maps: "Calle+San+Leonardo+12+Madrid",
                    lat: 40.4246355, lon: -3.7113767,
                    tz: "Europe/Madrid"
                ),
                VEvent(
                    time: "09:30", icon: "✈️",
                    title: "Voo Iberia IB 0983 — Madri (MAD) → Londres (LGW)",
                    desc: "Chegada às 10:50 (hora de Londres), no South Terminal de Gatwick. Economy, com 1 mala de 23 kg e 1 de cabine de 10 kg. Sem reembolso; alteração a 65 € mais a diferença tarifária.",
                    address: "Aeroporto Adolfo Suárez Madrid-Barajas, Terminal 4S, 28042 Madrid",
                    maps: "Aeropuerto+Adolfo+Suarez+Madrid+Barajas+T4S",
                    lat: 40.4944735, lon: -3.5671731,
                    tz: "Europe/Madrid",
                    ref: "Iberia · IB0983"
                ),
                VEvent(
                    time: "a definir", icon: "🏠",
                    title: "Pouso em Londres, 26 a 28/10",
                    desc: "Na casa do Ivan ou hospedagem própria. Ainda por confirmar.",
                    tz: "Europe/London",
                    pending: true
                ),
            ]
        ),
        VDay(
            id: "d27", date: "27 out", weekday: "terça-feira",
            title: "Londres", tone: .leisure,
            events: [
                VEvent(
                    time: "20:00", icon: "🗳️",
                    title: "Israel — eleição para o Knesset",
                    desc: "As urnas fecham às 22h de Israel. Boca de urna às 20h em Londres, 17h em Brasília.",
                    tz: "Europe/London"
                ),
            ]
        ),
        VDay(
            id: "d28", date: "28 out", weekday: "quarta-feira",
            title: "Londres → Madri", tone: .travel,
            events: [
                VEvent(
                    time: "06:45", icon: "🚇",
                    title: "Chegar a Heathrow, Terminal 5",
                    desc: "Saída internacional com despacho de mala: umas 2h30 antes do voo.",
                    address: "Heathrow Terminal 5, Wallis Road, Harmondsworth, London TW6 2GA",
                    maps: "Heathrow+Terminal+5",
                    lat: 51.4725150, lon: -0.4877331,
                    tz: "Europe/London"
                ),
                VEvent(
                    time: "09:15", icon: "✈️",
                    title: "Voo Iberia IB 0712 — Londres (LHR) → Madri (MAD)",
                    desc: "Chegada às 12:50 (hora de Madri), no T4S. Vendido como BA7053 (British Airways) e operado pela Iberia, tarifa Económica Plus. Nova entrada no Espaço Schengen, com nova fila do EES.",
                    address: "Heathrow Terminal 5, Wallis Road, Harmondsworth, London TW6 2GA",
                    maps: "Heathrow+Terminal+5",
                    lat: 51.4725150, lon: -0.4877331,
                    tz: "Europe/London",
                    ref: "Iberia · ZB6CZB"
                ),
                VEvent(
                    time: "13:30", icon: "🚕",
                    title: "Aeroporto → hotel → CRIDA",
                    desc: "Entre imigração, trem do satélite e esteira, conte uns 40 minutos até sair. O hotel fica em Rejas, a poucos minutos do CRIDA, com check-in às 14h: dá para deixar a mala antes do PostQat. Se apertar, o PostQat tem opção online.",
                    address: "Aeroporto Adolfo Suárez Madrid-Barajas, Terminal 4S, 28042 Madrid",
                    maps: "Aeropuerto+Adolfo+Suarez+Madrid+Barajas+T4S",
                    lat: 40.4944735, lon: -3.5671731,
                    tz: "Europe/Madrid"
                ),
                VEvent(
                    time: "14:00", icon: "🏨",
                    title: "Check-in — Compostela Suites",
                    desc: "Apartamento para uso individual, 1 noite (28 → 29/10), checkout às 12h. Cancelar agora custa US$ 114,70.",
                    address: "Compostela Suites, Calle Zambrana 4, Rejas, San Blas-Canillejas, 28042 Madrid",
                    maps: "Compostela+Suites+Calle+Zambrana+4+Madrid",
                    lat: 40.4474260, lon: -3.5803092,
                    tz: "Europe/Madrid"
                ),
                VEvent(
                    time: "15:00 → 18:00", icon: "🎓",
                    title: "Workshop PostQat — Concept Development and Stakeholder Alignment",
                    desc: "Inscrição confirmada. Chegada a partir das 14h. Há opção online se o voo atrasar.",
                    address: "CRIDA AIE (Centro de Referencia I+D+i ATM), Parque Empresarial Las Mercedes, Calle Campezo 1, Edificio 7, 4ª planta, 28022 Madrid",
                    maps: "CRIDA+Calle+Campezo+1+Madrid",
                    lat: 40.4482277, lon: -3.5799175,
                    tz: "Europe/Madrid"
                ),
            ]
        ),
        VDay(
            id: "d29", date: "29 out", weekday: "quinta-feira",
            title: "OpenSky Symposium — dia 1", tone: .event,
            events: [
                VEvent(
                    time: "dia todo", icon: "🎓",
                    title: "OpenSky Symposium, dia 1",
                    desc: "Inscrição confirmada. O pôster também fica exposto nos coffee breaks dos dois dias.",
                    address: "CRIDA AIE (Centro de Referencia I+D+i ATM), Parque Empresarial Las Mercedes, Calle Campezo 1, Edificio 7, 4ª planta, 28022 Madrid",
                    maps: "CRIDA+Calle+Campezo+1+Madrid",
                    lat: 40.4482277, lon: -3.5799175,
                    tz: "Europe/Madrid"
                ),
                VEvent(
                    time: "manhã", icon: "🏨",
                    title: "Emendar as duas reservas do Compostela",
                    desc: "A primeira sai às 12h e a segunda entra às 14h, em tipos de quarto diferentes. Pedir ao hotel para manter o mesmo quarto ou, antes de sair para o simpósio, fazer o checkout e deixar a mala na recepção.",
                    address: "Compostela Suites, Calle Zambrana 4, Rejas, San Blas-Canillejas, 28042 Madrid",
                    maps: "Compostela+Suites+Calle+Zambrana+4+Madrid",
                    lat: 40.4474260, lon: -3.5803092,
                    tz: "Europe/Madrid",
                    pending: true
                ),
                VEvent(
                    time: "16:20 → 17:20", icon: "🖼️",
                    title: "Sessão de pôster",
                    desc: "Pôster A0 do short paper JOAS.",
                    address: "CRIDA AIE (Centro de Referencia I+D+i ATM), Parque Empresarial Las Mercedes, Calle Campezo 1, Edificio 7, 4ª planta, 28022 Madrid",
                    maps: "CRIDA+Calle+Campezo+1+Madrid",
                    lat: 40.4482277, lon: -3.5799175,
                    tz: "Europe/Madrid"
                ),
                VEvent(
                    time: "noite", icon: "🏨",
                    title: "Compostela Suites — segunda reserva",
                    desc: "Apartamento de 1 quarto, 2 noites (29 → 31/10), checkout no sábado às 12h. Tarifa não reembolsável.",
                    address: "Compostela Suites, Calle Zambrana 4, Rejas, San Blas-Canillejas, 28042 Madrid",
                    maps: "Compostela+Suites+Calle+Zambrana+4+Madrid",
                    lat: 40.4474260, lon: -3.5803092,
                    tz: "Europe/Madrid"
                ),
            ]
        ),
        VDay(
            id: "d30", date: "30 out", weekday: "sexta-feira",
            title: "OpenSky Symposium — dia 2", tone: .event,
            events: [
                VEvent(
                    time: "dia todo", icon: "🎓",
                    title: "OpenSky Symposium, dia 2",
                    desc: "Inscrição confirmada. Noite livre em Madri depois do encerramento.",
                    address: "CRIDA AIE (Centro de Referencia I+D+i ATM), Parque Empresarial Las Mercedes, Calle Campezo 1, Edificio 7, 4ª planta, 28022 Madrid",
                    maps: "CRIDA+Calle+Campezo+1+Madrid",
                    lat: 40.4482277, lon: -3.5799175,
                    tz: "Europe/Madrid"
                ),
            ]
        ),
        VDay(
            id: "d31", date: "31 out", weekday: "sábado",
            title: "Madri → Londres", tone: .travel,
            events: [
                VEvent(
                    time: "12:00", icon: "🏨",
                    title: "Check-out — Compostela Suites",
                    desc: "Checkout até as 12h. O hotel fica perto do aeroporto, então um voo a partir do meio da tarde encaixa bem.",
                    address: "Compostela Suites, Calle Zambrana 4, Rejas, San Blas-Canillejas, 28042 Madrid",
                    maps: "Compostela+Suites+Calle+Zambrana+4+Madrid",
                    lat: 40.4474260, lon: -3.5803092,
                    tz: "Europe/Madrid"
                ),
                VEvent(
                    time: "tarde", icon: "🎫",
                    title: "Voo a comprar — Madri → Londres",
                    desc: "Trecho ainda não comprado.",
                    tz: "Europe/Madrid",
                    pending: true
                ),
                VEvent(
                    time: "a definir", icon: "🏠",
                    title: "Pouso em Londres, 31/10 a 2/11",
                    desc: "Na casa do Ivan ou hospedagem própria. Ainda por confirmar.",
                    tz: "Europe/London",
                    pending: true
                ),
            ]
        ),
        VDay(
            id: "d01", date: "01 nov", weekday: "domingo",
            title: "Londres — dia livre com o Ivan", tone: .leisure,
            events: [
                VEvent(
                    time: "livre", icon: "🤝",
                    title: "Dia livre com o Ivan",
                    desc: "Os EUA saem do horário de verão hoje: Nova York passa a ficar 2h atrás de Brasília.",
                    tz: "Europe/London"
                ),
            ]
        ),
        VDay(
            id: "d02", date: "02 nov", weekday: "segunda-feira",
            title: "Londres → Madri", tone: .travel,
            events: [
                VEvent(
                    time: "09:30 → 16:30", icon: "🍎",
                    title: "Workshop Apple: iPhone Duo — Apple Battersea",
                    desc: "Inscrição aguardando aprovação. Resolver onde fica a mala durante o dia.",
                    address: "Apple Battersea, Battersea Power Station, Electric Boulevard, London",
                    maps: "Apple+Battersea+Power+Station+London",
                    lat: 51.4818632, lon: -0.1449057,
                    tz: "Europe/London",
                    pending: true
                ),
                VEvent(
                    time: "16:30", icon: "🚇",
                    title: "Sair para o London City Airport",
                    desc: "De Battersea ao London City Airport são cerca de uma hora de transporte público.",
                    address: "Apple Battersea, Battersea Power Station, Electric Boulevard, London",
                    maps: "Apple+Battersea+Power+Station+London",
                    lat: 51.4818632, lon: -0.1449057,
                    tz: "Europe/London"
                ),
                VEvent(
                    time: "19:15", icon: "✈️",
                    title: "Voo BA Cityflyer BA 3270 — Londres (LCY) → Madri (MAD)",
                    desc: "Chegada às 22:35 (hora de Madri), no Terminal 4S. Voo direto, 2h20, operado pela BA Cityflyer, tarifa Económica Plus.",
                    address: "London City Airport, Hartmann Road, London E16 2PX",
                    maps: "London+City+Airport",
                    lat: 51.5042655, lon: 0.0549024,
                    tz: "Europe/London",
                    ref: "British Airways · YTN55U"
                ),
                VEvent(
                    time: "23:00", icon: "🏨",
                    title: "Check-in — Hotel Don Luis",
                    desc: "Quarto individual, sem café da manhã. Colado no aeroporto. R$ 353.",
                    address: "Hotel Don Luis, Avenida General 12, Barajas, 28042 Madrid",
                    maps: "Hotel+Don+Luis+Avenida+General+12+Madrid",
                    lat: 40.4727052, lon: -3.5786430,
                    tz: "Europe/Madrid"
                ),
            ]
        ),
        VDay(
            id: "d03", date: "03 nov", weekday: "terça-feira",
            title: "Madri → Lisboa → Porto", tone: .travel,
            events: [
                VEvent(
                    time: "08:00", icon: "🧳",
                    title: "Sair para o aeroporto — checkout do Don Luis",
                    desc: "O voo agora sai às 10:25: deixar o hotel por volta das 8h.",
                    address: "Hotel Don Luis, Avenida General 12, Barajas, 28042 Madrid",
                    maps: "Hotel+Don+Luis+Avenida+General+12+Madrid",
                    lat: 40.4727052, lon: -3.5786430,
                    tz: "Europe/Madrid"
                ),
                VEvent(
                    time: "10:25", icon: "✈️",
                    title: "Voo Azul AD 7854 — Madri (MAD) → Lisboa (LIS)",
                    desc: "Chegada às 10:45 (hora de Lisboa, 1h atrás de Madri). Vendido pela Azul e operado pela Air Europa. Voo dentro do Espaço Schengen, sem controle de passaporte.",
                    address: "Aeroporto Adolfo Suárez Madrid-Barajas, Av. de la Hispanidad s/n, 28042 Madrid",
                    maps: "Aeropuerto+Adolfo+Suarez+Madrid+Barajas",
                    lat: 40.4936983, lon: -3.5674678,
                    tz: "Europe/Madrid",
                    ref: "Azul · OWCS5A"
                ),
                VEvent(
                    time: "11:00", icon: "🚇",
                    title: "Aeroporto de Lisboa → Oriente",
                    desc: "Metrô, linha vermelha, uns 10 minutos, ou táxi. Confirme no check-in em Madri que a mala despachada vai direto para Campinas: sem esteira, a janela até o trem fica tranquila; com esteira, aperta.",
                    address: "Aeroporto Humberto Delgado, Alameda das Comunidades Portuguesas, Lisboa",
                    maps: "Aeroporto+Humberto+Delgado+Lisboa",
                    lat: 38.7809981, lon: -9.1318608,
                    tz: "Europe/Lisbon",
                    pending: true
                ),
                VEvent(
                    time: "12:09 → 14:48", icon: "🚆",
                    title: "Trem Alfa Pendular AP 125 — Lisboa Oriente → Porto Campanhã",
                    desc: "Chegada às 14:48. Carruagem 3, lugar 51.",
                    address: "Estação do Oriente, Avenida de Berlim, Lisboa",
                    maps: "Estacao+do+Oriente+Lisboa",
                    lat: 38.7680297, lon: -9.0999227,
                    tz: "Europe/Lisbon",
                    ref: "CP · AP125"
                ),
                VEvent(
                    time: "tarde", icon: "🍽️",
                    title: "Tarde e noite no Porto",
                    desc: "Sem hotel: tudo o que você carregar vai junto até o trem da madrugada.",
                    address: "Estação Porto Campanhã, Largo da Estação, Porto",
                    maps: "Porto+Campanha+estacao",
                    lat: 41.1487410, lon: -8.5854585,
                    tz: "Europe/Lisbon"
                ),
                VEvent(
                    time: "23:00", icon: "🗳️",
                    title: "EUA — eleições de meio de mandato",
                    desc: "As primeiras urnas fecham às 18h de Nova York, 23h em Portugal e 20h em Brasília. Os resultados decisivos saem de madrugada, com você no Porto e depois no trem.",
                    tz: "Europe/Lisbon"
                ),
            ]
        ),
        VDay(
            id: "d04", date: "04 nov", weekday: "quarta-feira",
            title: "Porto → Lisboa → Campinas → Franca", tone: .home,
            events: [
                VEvent(
                    time: "01:08 → 05:50", icon: "🚆",
                    title: "Trem Regional R 3400 — Porto Campanhã → Lisboa Oriente",
                    desc: "Chegada às 05:50. Noite no trem. Vale conferir no app da CP, perto da data, se o horário continua o mesmo.",
                    address: "Estação Porto Campanhã, Largo da Estação, Porto",
                    maps: "Porto+Campanha+estacao",
                    lat: 41.1487410, lon: -8.5854585,
                    tz: "Europe/Lisbon",
                    ref: "CP · R3400"
                ),
                VEvent(
                    time: "05:50", icon: "🚕",
                    title: "Sair para o aeroporto de Lisboa",
                    desc: "O metrô costuma abrir por volta das 6h30; de táxi ou aplicativo são uns 10 minutos. Chegar ao aeroporto até umas 6h15.",
                    address: "Estação do Oriente, Avenida de Berlim, Lisboa",
                    maps: "Estacao+do+Oriente+Lisboa",
                    lat: 38.7680297, lon: -9.0999227,
                    tz: "Europe/Lisbon"
                ),
                VEvent(
                    time: "09:15", icon: "🛫",
                    title: "Voo Azul AD 8751 — Lisboa (LIS) → Campinas (VCP)",
                    desc: "Chegada às 16:50 (hora de Brasília). Saída do Espaço Schengen em Lisboa: estar no aeroporto umas 3h antes.",
                    address: "Aeroporto Humberto Delgado, Alameda das Comunidades Portuguesas, Lisboa",
                    maps: "Aeroporto+Humberto+Delgado+Lisboa",
                    lat: 38.7809981, lon: -9.1318608,
                    tz: "Europe/Lisbon",
                    ref: "Azul · OWCS5A"
                ),
                VEvent(
                    time: "18:00", icon: "🚕",
                    title: "Viracopos → Rodoviária de Campinas",
                    desc: "Entre imigração, bagagem e alfândega, conte cerca de 1h após o pouso. Depois, aplicativo ou táxi, uns 30 a 40 minutos. Sobra por volta de 1h de folga; se o voo atrasar muito, remarque o ônibus.",
                    address: "Terminal Rodoviário de Campinas — Ramos de Azevedo, Rua Doutor Pereira Lima, Campinas – SP",
                    maps: "Terminal+Rodoviario+Campinas+Ramos+de+Azevedo",
                    lat: -22.9058921, lon: -47.0725672,
                    tz: "America/Sao_Paulo"
                ),
                VEvent(
                    time: "20:00", icon: "🚌",
                    title: "Ônibus Cometa — Campinas → Franca",
                    desc: "Chegada à 01:40 de 05/11. Poltrona 22. Embarque direto: vá à plataforma e mostre ao motorista o cartão de embarque que chega por e-mail.",
                    address: "Terminal Rodoviário de Campinas — Ramos de Azevedo, Rua Doutor Pereira Lima, Campinas – SP",
                    maps: "Terminal+Rodoviario+Campinas+Ramos+de+Azevedo",
                    lat: -22.9058921, lon: -47.0725672,
                    tz: "America/Sao_Paulo",
                    ref: "Cometa · 1QJ92VQ8"
                ),
            ]
        ),
    ]

    /// Distinct locators already in hand — the same code on two legs counts once.
    static var bookedCount: Int {
        Set(days.flatMap(\.events).filter { !$0.pending }.compactMap(\.ref)).count
    }

    /// Entries still waiting on a decision, a purchase or an approval.
    static var pendingCount: Int {
        days.flatMap(\.events).filter(\.pending).count
    }
}

// MARK: - Badge "tudo reservado" com shimmer

private struct VShimmerBadge: View {
    @State private var animate = false

    /// Counts come from the itinerary itself, so the badge never claims "tudo
    /// reservado" while a flight or an approval is still open.
    static var summary: String {
        let pending = VData.pendingCount
        let booked = VData.bookedCount
        guard pending > 0 else { return "✅ Tudo reservado — \(booked) reservas confirmadas!" }
        return "✅ \(booked) reservas · ⏳ \(pending) \(pending == 1 ? "pendente" : "pendentes")"
    }

    var body: some View {
        Text(VShimmerBadge.summary)
            .scaledFont(size: 14, weight: .bold)
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
                    .scaledFont(size: 12.5, weight: .bold, design: .monospaced)
                    .foregroundColor(accent)
                    .multilineTextAlignment(.trailing)
                // The itinerary crosses four zones; an unlabelled "17:30" invites
                // reading it as local time.
                if let zone = event.timeZone, zone.identifier != TimeZone.current.identifier {
                    Text(VEventRow.zoneAbbreviation(zone, at: eventDate ?? Date()))
                        .scaledFont(size: 9, weight: .semibold)
                        .foregroundColor(VPalette.muted)
                }
            }
            .frame(width: 74, alignment: .trailing)

            Text(event.icon)
                .scaledFont(size: 19)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .scaledFont(size: 14, weight: .bold)
                    .foregroundColor(VPalette.ink)

                Text(event.desc)
                    .scaledFont(size: 12.8)
                    .foregroundColor(VPalette.descColor)
                    .lineSpacing(3)

                if let address = event.address, let url = mapsURL {
                    Link(destination: url) {
                        HStack(alignment: .top, spacing: 6) {
                            Text("📍").scaledFont(size: 12)
                            Text(address)
                                .scaledFont(size: 11.8, weight: .medium)
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
                    .scaledFont(size: 11.5)
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

                if event.pending {
                    Text("⏳ PENDENTE")
                        .scaledFont(size: 10.5, weight: .bold)
                        .tracking(0.4)
                        .foregroundColor(VPalette.loungeText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(VPalette.loungeBase.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(VPalette.loungeBase.opacity(0.35), lineWidth: 1)
                        )
                        .padding(.top, 7)
                }

                if let ref = event.ref {
                    Text(ref)
                        .scaledFont(size: 10.5, weight: .semibold, design: .monospaced)
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

/// Picks between plain and tinted content card without duplicating the call site.
private struct VDayCardSurface: ViewModifier {
    let tint: Color?

    func body(content: Content) -> some View {
        if let tint {
            content.contentCard(tint: tint, cornerRadius: 18)
        } else {
            content.contentCard(cornerRadius: 18)
        }
    }
}

private struct VDaySection: View {
    let day: VDay
    let isExpanded: Bool
    /// The day the trip is on right now, ringed so it is findable in a long list.
    var isFocused: Bool = false
    let onToggle: () -> Void

    private var dayNumber: String {
        String(day.date.split(separator: " ").first ?? Substring(day.date))
    }

    private var monthLabel: String {
        String(day.date.split(separator: " ").last ?? "")
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
                            .scaledFont(size: 26, weight: .semibold, design: .serif)
                            .foregroundColor(day.tone.accent)
                        Text(monthLabel)
                            .scaledFont(size: 12.5)
                            .italic()
                            .foregroundColor(VPalette.muted)
                    }
                    .frame(minWidth: 54)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(day.title)
                            .scaledFont(size: 17, weight: .bold)
                            .foregroundColor(VPalette.ink)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 6) {
                            Text(day.weekday)
                                .scaledFont(size: 11.5, weight: .medium)
                                .foregroundColor(VPalette.muted)
                            Text(day.tone.label.uppercased())
                                .scaledFont(size: 10, weight: .bold)
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
                        .scaledFont(size: 14, weight: .semibold)
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
    /// Only the day in focus starts open. Opening them all buries the one that matters.
    @State private var expandedDays: Set<String> = []
    @State private var focusDayID: String?
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

                        // Day cards are content: solid surface, no glass.
                        VStack(spacing: 12) {
                            ForEach(VData.days) { day in
                                VDaySection(
                                    day: day,
                                    isExpanded: expandedDays.contains(day.id),
                                    isFocused: day.id == focusDayID,
                                    onToggle: { toggle(day.id) }
                                )
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
                    .scaledFont(size: 10.5, weight: .bold)
                    .tracking(1.4)
                    .foregroundColor(VPalette.muted)
                Spacer()
                if alerts.scheduledCount > 0 {
                    Label("\(alerts.scheduledCount) alertas", systemImage: "bell.fill")
                        .scaledFont(size: 10.5, weight: .semibold)
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
                        .scaledFont(size: 9.5, weight: .bold)
                        .tracking(1.2)
                        .foregroundColor(VPalette.muted)
                    Text("\(next.icon) \(next.title)")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(VPalette.ink)
                    Text("\(next.dayDate) · \(next.time)\(zoneSuffix(next))")
                        .scaledFont(size: 12)
                        .foregroundColor(VPalette.muted)
                }
            }
        }
        .padding(16)
        .contentCard(tint: VTone.leisure.accent, cornerRadius: 18)
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
                .scaledFont(size: 9.5, weight: .bold)
                .tracking(1.0)
                .foregroundColor(VPalette.muted)
            Text(df.string(from: now))
                .scaledFont(size: 22, weight: .semibold, design: .rounded)
                .foregroundColor(highlighted ? VTone.leisure.accent : VPalette.ink)
            Text(gmtOffset(zone, at: now))
                .scaledFont(size: 9.5, weight: .medium)
                .foregroundColor(VPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, highlighted ? 14 : 0)
    }

    private func statusLine(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .scaledFont(size: 11, weight: .semibold)
                .foregroundColor(tint)
            Text(text)
                .scaledFont(size: 12.5)
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
                .scaledFont(size: 14)
            Text("Viagem")
                .scaledFont(size: 17, weight: .bold, design: .serif)
                .foregroundColor(VPalette.titleAccent)
        }
    }

    private var heroHeader: some View {
        VStack(spacing: 12) {
            Text("ROTEIRO · 22 OUT – 04 NOV 2026")
                .scaledFont(size: 11.5, weight: .semibold)
                .tracking(3)
                .foregroundColor(VPalette.heroInk.opacity(0.78))
                .multilineTextAlignment(.center)

            Text("O roteiro, hora a hora")
                .scaledFont(size: 38, weight: .semibold, design: .serif)
                .foregroundColor(VPalette.heroInk)
                .multilineTextAlignment(.center)

            Text("com todos os endereços no mapa")
                .scaledFont(size: 18, design: .serif)
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
            .backgroundExtensionEffect()
        )
    }

    private var footerNote: some View {
        VStack(spacing: 4) {
            Text("Toque em qualquer endereço para abrir no Apple Maps 📍")
                .scaledFont(size: 18, design: .serif)
                .italic()
            Text("Boa viagem, Eliel ✈️")
                .scaledFont(size: 15, design: .serif)
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
        // TripEngine reads `stops` as chronological (first/last for next/current,
        // the following stop as a flight's fallback zone), so sort by instant.
        // Entries with no clock time ride along with the dated entry before them;
        // ties keep the listed order.
        var anchor = Date.distantPast
        var keyed: [(date: Date, index: Int, stop: TripStop)] = []
        for (index, stop) in out.enumerated() {
            if let date = stop.date { anchor = date }
            keyed.append((anchor, index, stop))
        }
        return keyed
            .sorted { ($0.date, $0.index) < ($1.date, $1.index) }
            .map(\.stop)
    }
}
