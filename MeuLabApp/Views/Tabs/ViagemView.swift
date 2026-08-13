import SwiftUI

// ============================================================
// VIAGEM — CRONOLOGIA FINAL
// Port nativo do roteiro (React/JSX "Cronologia") para SwiftUI,
// restilizado com o design system Mac OS 9.
// Viagem Set/2026 — Eliel & Ana Paula — França, Portugal, Inglaterra.
// Timeline dia a dia com voos, hotéis, casamento e endereços
// que abrem no Google Maps. Todo o conteúdo do roteiro é mantido
// verbatim — apenas a camada visual foi trocada.
// ============================================================

// MARK: - Tons por categoria de dia
// Reaproveita a paleta de status do Mac OS 9 em vez de cores bespoke.

private enum VTone {
    case travel, leisure, wedding, home

    var accent: Color {
        switch self {
        case .travel: return MacOS9Colors.statusBlue
        case .leisure: return MacOS9Colors.statusGreen
        case .wedding: return MacOS9Colors.statusOrange
        case .home: return MacOS9Colors.accentBorder
        }
    }

    var chip: Color { accent.opacity(0.15) }

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
    let ref: String?
    let lounge: String?

    init(
        time: String,
        icon: String,
        title: String,
        desc: String,
        address: String? = nil,
        maps: String? = nil,
        ref: String? = nil,
        lounge: String? = nil
    ) {
        self.time = time
        self.icon = icon
        self.title = title
        self.desc = desc
        self.address = address
        self.mapsQuery = maps
        self.ref = ref
        self.lounge = lounge
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

// MARK: - Dados da viagem (fonte: cronologia_final.jsx) — mantidos verbatim

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
                    ref: "LATAM · voo 4211"
                ),
                VEvent(
                    time: "10:15", icon: "🤝",
                    title: "Chegada em Londrina — reencontro com a Ana",
                    desc: "Pernoite em Londrina. Amanhã (07/09) vocês seguem juntos para Guarulhos.",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa"
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
                    maps: "Aeroporto+de+Londrina+Jose+Richa"
                ),
                VEvent(
                    time: "05:45", icon: "✈️",
                    title: "Voo LATAM LA3691 — Londrina (LDB) → São Paulo (GRU)",
                    desc: "Voo direto, Eliel + Ana Paula. Chegada em Guarulhos às 07:05.",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa",
                    ref: "LATAM · LA3691"
                ),
                VEvent(
                    time: "07:05 → 14:10", icon: "⏱️",
                    title: "Conexão em Guarulhos (~7h) — bem folgada",
                    desc: "⚠️ Reservas separadas (LATAM + Iberia): retirem a bagagem na esteira do desembarque doméstico e RE-DESPACHEM no balcão da Iberia, no Terminal 3. A LATAM não transfere direto. Só que o balcão da Iberia abre ~3h antes, por volta das 11:10 — ou seja, sobram ~4h de espera na área pública antes do check-in.",
                    address: "Aeroporto de Guarulhos (GRU), Terminal 3, Guarulhos – SP",
                    maps: "Aeroporto+de+Guarulhos+Terminal+3"
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
                    maps: "Aeroporto+de+Guarulhos+Terminal+3"
                ),
                VEvent(
                    time: "14:10 BRT", icon: "✈️",
                    title: "Voo IB 268 — Guarulhos → Madrid",
                    desc: "Voo noturno. Chegada dia 08/09 às 05:35 (hora de Madri).",
                    address: "Aeroporto Internacional de Guarulhos, Rod. Hélio Smidt s/n, Cumbica, Guarulhos – SP",
                    maps: "Aeroporto+Internacional+de+Guarulhos",
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
                    ref: "Iberia · 9WAXMR",
                    lounge: "Conexão no T4 (voo Schengen): Iberia Dalí Premium Lounge, após a segurança (5h30–23h) — acesso via classe executiva ou status oneworld Sapphire/Emerald. Com Priority Pass, a alternativa no T4 é a Sala Plaza Mayor."
                ),
                VEvent(
                    time: "~12:30", icon: "🚌",
                    title: "Navette 91 — Aeroporto de Marseille → Gare St-Charles",
                    desc: "Após desembarque e retirada de bagagem. A navette (linha 91) sai do ponto entre os terminais T1 e T2, a cada ~10 min, ~25 min de viagem, €10/pessoa. Deixa vocês direto na estação de trem St-Charles (plataformas 13/14).",
                    address: "Navette 91, Aéroport Marseille Provence → Gare Saint-Charles",
                    maps: "Navette+91+Marseille+Aeroport+Saint+Charles"
                ),
                VEvent(
                    time: "13:25", icon: "🚆",
                    title: "Trem TER — Marseille St-Charles → Montpellier St-Roch",
                    desc: "Chegada às 15:00. Margem de ~55 min entre a chegada do voo (12:00) e o trem, contando a navette — justo mas viável se a bagagem sair rápido. Se atrasar, há trens ~a cada 30-60 min.",
                    address: "Gare de Marseille St-Charles, Square Narvik, 13001 Marseille",
                    maps: "Gare+de+Marseille+Saint-Charles",
                    ref: "Trainline · F3F5WA"
                ),
                VEvent(
                    time: "15:30", icon: "🏨",
                    title: "Check-in — Ibis Budget Montpellier Centre Millenaire",
                    desc: "2 noites (08 → 10/09). Check-in a partir das 14:00, check-out até 11:00.",
                    address: "Rue des Frères Lumière, ZA Blaise Pascal, 34000 Montpellier",
                    maps: "Ibis+Budget+Montpellier+Centre+Millenaire",
                    ref: "Booking · 6850519282"
                ),
            ]
        ),
        VDay(
            id: "d09", date: "09 set", weekday: "quarta-feira",
            title: "Montpellier — visitas & passeio", tone: .leisure,
            events: [
                VEvent(
                    time: "manhã", icon: "🫖",
                    title: "Visita à Mme Maleville",
                    desc: "Visita à Place Jean Bène. O Tram 1 ou 2 deixa perto, dependendo do ponto de partida.",
                    address: "33 Place Jean Bène, 34000 Montpellier",
                    maps: "33+Place+Jean+Bene+Montpellier"
                ),
                VEvent(
                    time: "tarde", icon: "🏫",
                    title: "Visita à Accent Français",
                    desc: "A escola de francês no coração de Montpellier — a 2 min da Place de la Comédie.",
                    address: "Accent Français, 2 Rue de Verdun, 34000 Montpellier",
                    maps: "Accent+Francais+Montpellier"
                ),
                VEvent(
                    time: "fim de tarde", icon: "🌞",
                    title: "Passeio pelo centro histórico",
                    desc: "Place de la Comédie, Arco do Triunfo, Promenade du Peyrou — tudo a pé entre as visitas.",
                    address: "Place de la Comédie, 34000 Montpellier",
                    maps: "Place+de+la+Comedie+Montpellier"
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
                    ref: "Alamo · voucher no app"
                ),
                VEvent(
                    time: "~10:45", icon: "🛣️",
                    title: "Estrada: Montpellier → Aix-en-Provence",
                    desc: "~170 km pela A9 + A7/A8, ~1h50. Chegada em Aix por volta das 12:40."
                ),
                VEvent(
                    time: "~12:45", icon: "🥐",
                    title: "Almoço em Aix-en-Provence",
                    desc: "Estacionar no Parking Mignet ou Rotonde e almoçar no Cours Mirabeau, a avenida mais charmosa da Provence — fontes, platanas e cafés históricos como Les Deux Garçons, frequentado por Cézanne.",
                    address: "Cours Mirabeau, 13100 Aix-en-Provence",
                    maps: "Cours+Mirabeau+Aix-en-Provence"
                ),
                VEvent(
                    time: "~14:15", icon: "🛣️",
                    title: "Estrada: Aix → Montmeyan",
                    desc: "~75 km, ~1h por estradas provençais (D560/D13). Paisagem linda de vinhedos e oliveiras."
                ),
                VEvent(
                    time: "~15:30", icon: "🏡",
                    title: "Check-in — Airbnb Montmeyan (hôte: Yael)",
                    desc: "3 noites (10 → 13/09). Check-in a partir das 15:00. Gîte tranquilo com vista para o Parque do Verdon.",
                    address: "56 Route de Riez, 83670 Montmeyan, França",
                    maps: "56+Route+de+Riez+83670+Montmeyan",
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
                    maps: "Place+Montelupo+Moustiers-Sainte-Marie"
                ),
                VEvent(
                    time: "~11:00", icon: "⭐",
                    title: "Capela Notre-Dame de Beauvoir & a estrela suspensa",
                    desc: "Trilha curta (~20 min de subida) até a capela com vista panorâmica do vilarejo e da estrela dourada suspensa entre as falésias — a lenda do cavaleiro de Blacas.",
                    address: "Chapelle Notre-Dame de Beauvoir, Moustiers-Sainte-Marie",
                    maps: "Chapelle+Notre-Dame+de+Beauvoir+Moustiers"
                ),
                VEvent(
                    time: "~12:30", icon: "🍽️",
                    title: "Almoço em Moustiers",
                    desc: "Terraços com vista nas ruelas de pedra. Provar a truta local e os vinhos de Provence.",
                    address: "Centro de Moustiers-Sainte-Marie, 04360",
                    maps: "Restaurants+Moustiers-Sainte-Marie"
                ),
                VEvent(
                    time: "~14:30", icon: "🛶",
                    title: "Lac de Sainte-Croix — pedalinho na entrada do cânion",
                    desc: "Alugar pedalinho ou caiaque na Pont du Galetas (~€20-30/h) e remar para DENTRO das Gorges du Verdon — águas turquesa entre falésias de 700m. Imperdível!",
                    address: "Pont du Galetas, Lac de Sainte-Croix, 83630 Aiguines",
                    maps: "Pont+du+Galetas+Lac+Sainte-Croix"
                ),
                VEvent(
                    time: "~17:00", icon: "🌄",
                    title: "Mirantes de Aiguines ou Route des Crêtes",
                    desc: "Fim de tarde com vista: o vilarejo de Aiguines (famoso pelos torneiros de madeira) ou, se sobrar fôlego, a Route des Crêtes em La Palud — 14 belvederes sobre o cânion. Golden hour espetacular.",
                    address: "Aiguines, 83630, Var",
                    maps: "Aiguines+village+Verdon"
                ),
                VEvent(
                    time: "23:00", icon: "💻",
                    title: "Icatalk — 18:00 de Brasília",
                    desc: "⚠️ Única sexta da viagem que cai fora do Brasil. 23h no horário francês, já de volta ao Airbnb em Montmeyan. Confirmar a qualidade do Wi-Fi com a Yael antes — é zona rural. Lembrar que o casamento é no dia seguinte.",
                    address: "56 Route de Riez, 83670 Montmeyan",
                    maps: "56+Route+de+Riez+83670+Montmeyan"
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
                    maps: "Montmeyan+to+Aups"
                ),
                VEvent(
                    time: "14:30", icon: "⛪",
                    title: "Missa — Collégiale Saint-Pancrace d'Aups",
                    desc: "Cerimônia religiosa de Bastien & Anne-Clotilde, celebrada pelo Abbé Joseph-Marie Sallé.",
                    address: "Collégiale Saint-Pancrace, Place de la Collégiale, 83630 Aups",
                    maps: "Collegiale+Saint-Pancrace+Aups"
                ),
                VEvent(
                    time: "17:30", icon: "🥂",
                    title: "Cocktail — Domaine de la Roquette",
                    desc: "Coquetel das 17h30 às 19h30 nos jardins do domaine, em Montmeyan (~12 min de Aups).",
                    address: "Domaine de la Roquette, 3173 Route de Riez, 83670 Montmeyan",
                    maps: "Domaine+de+la+Roquette+3173+Route+de+Riez+Montmeyan"
                ),
                VEvent(
                    time: "19:30", icon: "🍽️",
                    title: "Jantar à mesa (dîner placé)",
                    desc: "Jantar com lugares marcados, seguido de festa. À noite, arrumar as malas: amanhã a saída é cedo!",
                    address: "Domaine de la Roquette, 3173 Route de Riez, 83670 Montmeyan",
                    maps: "Domaine+de+la+Roquette+Montmeyan"
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
                    desc: "Dirigir ~1h30 até Marseille. Abastecer o tanque antes de devolver (posto perto da estação)."
                ),
                VEvent(
                    time: "09:00", icon: "🚗",
                    title: "Devolver carro — Alamo, Gare de Marseille St-Charles",
                    desc: "Margem de 1h até o trem. Conferir instruções de devolução no voucher.",
                    address: "Alamo — Gare de Marseille St-Charles, Square Narvik, 13001 Marseille",
                    maps: "Alamo+Gare+Marseille+Saint+Charles",
                    ref: "Alamo · devolução"
                ),
                VEvent(
                    time: "10:11", icon: "🚄",
                    title: "Frecciarossa 6104 — Marseille → Paris Gare de Lyon",
                    desc: "Vagão 7, assentos 8A e 8B (Standard Silêncio). Chegada às 13:34.",
                    address: "Paris Gare de Lyon, Place Louis-Armand, 75012 Paris",
                    maps: "Paris+Gare+de+Lyon",
                    ref: "Trenitalia/Omio · DMDKRN"
                ),
                VEvent(
                    time: "~14:15", icon: "👋",
                    title: "Visita à prima da Ana — Mitry-Mory",
                    desc: "De Gare de Lyon: Metrô L14 até Châtelet (~5 min) + RER B direção Mitry-Claye até a estação Villeparisis–Mitry-le-Neuf (~30 min) + ~6 min a pé. Total ~50 min. Tarde em família.",
                    address: "Mitry-Mory, 77290, Île-de-France",
                    maps: "Villeparisis+Mitry+le+Neuf+RER"
                ),
                VEvent(
                    time: "~20:00", icon: "🚇",
                    title: "Volta para o Mercure Levallois",
                    desc: "RER B (Villeparisis → Gare du Nord ~28 min) + Metrô L3 (Gare du Nord → Louise Michel ~18 min) + 3 min a pé. Total ~55 min. Último RER B de Mitry passa à meia-noite, sem stress.",
                    address: "48 Rue Chaptal, 92300 Levallois-Perret",
                    maps: "Mercure+Paris+Levallois+48+Rue+Chaptal",
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
                    maps: "Parking+Pershing+Porte+Maillot+Beauvais+shuttle"
                ),
                VEvent(
                    time: "09:00", icon: "🚌",
                    title: "Shuttle Aérobus — Porte Maillot → Beauvais",
                    desc: "Bilhetes já comprados (2 idas). Viagem ~1h15, chegada ~10:15. Guichês abertos das 3h às 19h30 e só aceitam cartão.",
                    address: "Parking Pershing, 22-24 Boulevard Pershing, 75017 Paris",
                    maps: "Navette+Beauvais+Porte+Maillot",
                    ref: "Aéroport Beauvais · 8WCM8N"
                ),
                VEvent(
                    time: "~10:15", icon: "🛬",
                    title: "Chegada ao Aéroport de Beauvais-Tillé",
                    desc: "2h40 de folga até o voo. Check-in Ryanair + segurança. Beauvais é pequeno, mas as filas podem surpreender.",
                    address: "Aéroport de Beauvais-Tillé, 60004 Beauvais",
                    maps: "Aeroport+Beauvais+Tille"
                ),
                VEvent(
                    time: "12:55", icon: "✈️",
                    title: "Voo Ryanair FR 595 — Beauvais → Porto",
                    desc: "Chegada ~14:10 (hora de Portugal, -1h vs França).",
                    address: "Aéroport de Beauvais-Tillé, 60004 Beauvais",
                    maps: "Aeroport+Beauvais+Tille",
                    ref: "Ryanair · X5I2TQ",
                    lounge: "Beauvais é um aeroporto low-cost básico — sem sala VIP. Levem lanches e água (depois da segurança as opções são limitadas e caras)."
                ),
                VEvent(
                    time: "~14:30", icon: "🤝",
                    title: "Porto — chegada e encontro com Pastor Roberto",
                    desc: "Metrô Linha E (violeta) do aeroporto até o centro (Trindade) ~27 min, €2,30 (bilhete Z4). Hospedagem com conhecidos.",
                    address: "Aeroporto Francisco Sá Carneiro, Pedras Rubras, 4470-558 Maia",
                    maps: "Aeroporto+Francisco+Sa+Carneiro"
                ),
            ]
        ),
        VDay(
            id: "d15", date: "15 set", weekday: "terça-feira",
            title: "Porto — dia inteiro", tone: .leisure,
            events: [
                VEvent(
                    time: "dia todo", icon: "🍷",
                    title: "Porto com o Pastor Roberto",
                    desc: "Livraria Lello, Estação São Bento, Ponte Dom Luís I, cruzeiro no Douro. Dormir cedo: amanhã o voo é às 07:05!",
                    address: "Ribeira do Porto, 4050 Porto",
                    maps: "Ribeira+Porto+Portugal"
                ),
            ]
        ),
        VDay(
            id: "d16", date: "16 set", weekday: "quarta-feira",
            title: "Porto → Londres", tone: .travel,
            events: [
                VEvent(
                    time: "~04:15", icon: "🚕",
                    title: "Uber/táxi até o aeroporto do Porto (3h antes)",
                    desc: "⚠️ O metrô só abre às 5h57 — tarde demais para o voo das 7h05! De táxi/Uber do centro são ~15 min, ~€20-25. Combinar na véspera com os anfitriões ou pré-agendar. Chegar ~04:30 (2h30-3h antes).",
                    address: "Aeroporto Francisco Sá Carneiro, Pedras Rubras, 4470-558 Maia",
                    maps: "Aeroporto+Francisco+Sa+Carneiro"
                ),
                VEvent(
                    time: "07:05", icon: "✈️",
                    title: "Voo Ryanair FR 1262 — Porto → London Stansted",
                    desc: "Vocês 3 na mesma reserva: Eliel (15A), Ana Paula (15B) e José Roberto Dos Santos (15C). Todos com 20kg despachados. Chegada 09:30 (hora UK, mesmo fuso que Portugal).",
                    address: "London Stansted Airport, Bassingbourn Rd, Stansted CM24 1QW",
                    maps: "London+Stansted+Airport",
                    ref: "Ryanair · Q67BHK",
                    lounge: "Porto: ANA Lounge, nível 3 junto aos portões 31–32, abre às 4h (perfeito pro voo das 7h05). Priority Pass/DragonPass ou reserva avulsa ~€22–38 em ana.pt — vista pra pista e café da manhã."
                ),
                VEvent(
                    time: "~09:50", icon: "🚆",
                    title: "Imigração UK + Stansted Express → Liverpool Street",
                    desc: "Fila de imigração UK para brasileiros: ~30-60 min. Depois, Stansted Express (~47 min, ~£20/pessoa, trens a cada 15 min) até Liverpool Street. Dia inteiro com seu amigo em Londres.",
                    address: "Liverpool Street Station, London EC2M 7QH",
                    maps: "Liverpool+Street+Station+London"
                ),
                VEvent(
                    time: "14:00+", icon: "🏨",
                    title: "Check-in — Brick Lane Hotel",
                    desc: "1 noite. Check-in 14:00–23:00. A ~10 min a pé de Liverpool Street, no coração do East End — rua famosa pelos currys e arte de rua.",
                    address: "13 Brick Lane, Tower Hamlets, London E1 6PU",
                    maps: "Brick+Lane+Hotel+13+Brick+Lane+London",
                    ref: "Booking · Brick Lane Hotel"
                ),
                VEvent(
                    time: "21:15", icon: "🛫",
                    title: "Pastor Roberto volta — TAP TP 1331, Gatwick → Porto",
                    desc: "Só ele. Terminal S, check-in fecha 20:30. Chegada no Porto 23:40.",
                    address: "London Gatwick Airport, South Terminal, Horley RH6 0NP",
                    maps: "London+Gatwick+South+Terminal",
                    ref: "TAP · YZIMAB",
                    lounge: "Para o Pastor: Gatwick South Terminal tem o No1 Lounge (Priority Pass/pré-reserva ~£35). A TAP em tarifa Discount não inclui lounge."
                ),
            ]
        ),
        VDay(
            id: "d17", date: "17 set", weekday: "quinta-feira",
            title: "Londres → Marselha → Madrid → 🇧🇷", tone: .travel,
            events: [
                VEvent(
                    time: "08:00", icon: "🚶",
                    title: "Check-out Brick Lane + caminhada até Liverpool Street",
                    desc: "Check-out a partir das 08:00. ~10 min a pé do Brick Lane Hotel até a estação de Liverpool Street.",
                    address: "13 Brick Lane → Liverpool Street Station",
                    maps: "Brick+Lane+to+Liverpool+Street+Station"
                ),
                VEvent(
                    time: "08:25", icon: "🚆",
                    title: "Stansted Express → Stansted Airport",
                    desc: "~47 min, ~£20/pessoa (trens a cada 15 min). Chegada ~09:12 — ~2h antes do voo, ideal para Ryanair internacional.",
                    address: "Liverpool Street Station, London EC2M 7QH",
                    maps: "Stansted+Express+Liverpool+Street"
                ),
                VEvent(
                    time: "11:15", icon: "✈️",
                    title: "Voo Ryanair FR 1468 — Stansted → Marseille",
                    desc: "Assentos 14A e 14B, tarifa Plus com mala de 20kg. Chegada 14:15 (hora França).",
                    address: "London Stansted Airport, CM24 1QW",
                    maps: "London+Stansted+Airport",
                    ref: "Ryanair · K512SN",
                    lounge: "Stansted: Escape Lounge, após a segurança (Priority Pass ou pré-reserva ~£30-40). Chegando às ~09:12, dá quase 2h de lounge antes do embarque."
                ),
                VEvent(
                    time: "17:55", icon: "✈️",
                    title: "Voo IB 1172 — Marseille → Madrid",
                    desc: "⚠️ Troca de terminal em MRS: vocês chegam no Terminal 2 (Ryanair) e a Iberia parte do Terminal 1 — são vizinhos, ~5-10 min a pé. Margem de 3h40, tranquilo. Chegada em Madri 19:45.",
                    address: "Aéroport Marseille Provence, 13700 Marignane",
                    maps: "Aeroport+Marseille+Provence",
                    ref: "Iberia · N1L14",
                    lounge: "Marseille Terminal 1 (após a troca de terminal): Salon Lubéron (Priority Pass/pré-reserva) — ótimo pra passar parte das 3h40 de espera com conforto."
                ),
                VEvent(
                    time: "23:55", icon: "🌙",
                    title: "Voo IB 267 — Madrid → Guarulhos",
                    desc: "Passageiros: FELIPEJUNIOR/ELIEL + PEREIRADEALMEIDA/ANAPAULA. Chegada 18/09 às 05:55 (BRT).",
                    address: "Aeropuerto Adolfo Suárez Madrid-Barajas, 28042 Madrid",
                    maps: "Aeropuerto+Madrid+Barajas",
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
                    maps: "Aeroporto+de+Guarulhos"
                ),
                VEvent(
                    time: "~07:30", icon: "🚕",
                    title: "Uber/táxi — Guarulhos → Congonhas",
                    desc: "⚠️ Aeroportos diferentes! ~40 min a 1h de trajeto, mais carregado numa sexta de manhã. Custo ~R$ 80–120. Chegada em CGH por volta das 08:30.",
                    address: "GRU → Aeroporto de Congonhas, Av. Washington Luís s/n, São Paulo – SP",
                    maps: "Aeroporto+de+Congonhas+Sao+Paulo"
                ),
                VEvent(
                    time: "~08:30", icon: "🧳",
                    title: "Check-in LATAM em Congonhas",
                    desc: "Reserva separada da internacional: é preciso re-despachar as malas no balcão da LATAM. Voo às 11:10 — margem confortável de ~2h30. Se puderem levar só bagagem de mão neste trecho, ganham tempo.",
                    address: "Aeroporto de Congonhas (CGH), Av. Washington Luís s/n, São Paulo – SP",
                    maps: "Aeroporto+de+Congonhas+Sao+Paulo"
                ),
                VEvent(
                    time: "11:10", icon: "✈️",
                    title: "Voo LATAM LA3120 — Congonhas (CGH) → Londrina (LDB)",
                    desc: "Voo direto, 1h15. Chegada em Londrina às 12:25.",
                    address: "Aeroporto de Congonhas (CGH), São Paulo – SP",
                    maps: "Aeroporto+de+Congonhas+Sao+Paulo",
                    ref: "LATAM · QJBWJF"
                ),
                VEvent(
                    time: "12:25", icon: "🏠",
                    title: "Chegada em Londrina",
                    desc: "11 dias, 4 países, 1 casamento inesquecível. Bem-vindos de volta!",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa"
                ),
                VEvent(
                    time: "18:00", icon: "💻",
                    title: "Icatalk — de volta ao horário normal",
                    desc: "✅ Já em casa, no fuso de Brasília. Chegando ao meio-dia, dá tempo de descansar antes. Boa deixa para contar da viagem!"
                ),
            ]
        ),
        VDay(
            id: "d19", date: "21 set", weekday: "segunda-feira",
            title: "Londrina → Ribeirão Preto (só Eliel)", tone: .home,
            events: [
                VEvent(
                    time: "07:20", icon: "✈️",
                    title: "GOL G3 1209 — Londrina (LDB) → Congonhas (CGH)",
                    desc: "Tarifa Classic. Assento 7C. Chegada às 08:30. Bagagem: 10kg de mão + 12kg pequena + 23kg despachada.",
                    address: "Aeroporto de Londrina — José Richa (LDB), Av. dos Estudantes 1000, Londrina – PR",
                    maps: "Aeroporto+de+Londrina+Jose+Richa",
                    ref: "GOL · QZDFUX"
                ),
                VEvent(
                    time: "08:30 → 10:10", icon: "⏱️",
                    title: "Conexão em Congonhas (1h40)",
                    desc: "Troca de avião, mas mesma reserva — a bagagem segue direto até Ribeirão Preto. Sem re-despacho.",
                    address: "Aeroporto de Congonhas (CGH), Av. Washington Luís s/n, São Paulo – SP",
                    maps: "Aeroporto+de+Congonhas+Sao+Paulo"
                ),
                VEvent(
                    time: "10:10", icon: "🏡",
                    title: "GOL G3 1338 — Congonhas (CGH) → Ribeirão Preto (RAO)",
                    desc: "Assento 8C. Chegada às 11:15. Fim da viagem — 3h55 de duração total com a conexão.",
                    address: "Aeroporto Leite Lopes (RAO), Av. Thomaz Alberto Whately, Ribeirão Preto – SP",
                    maps: "Aeroporto+Leite+Lopes+Ribeirao+Preto",
                    ref: "GOL · QZDFUX"
                ),
            ]
        ),
    ]
}

// MARK: - Badge "tudo reservado"
// Mac OS 9 lilac label badge com um leve pisca clássico (System 7/9 blink) em
// vez do shimmer moderno do original.

private struct VReservedBadge: View {
    @State private var blink = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11))
            Text("Tudo reservado — 17 reservas confirmadas!")
        }
        .font(MacOS9Typography.bodyBold(12))
        .foregroundStyle(MacOS9Colors.labelBadgeText)
        .padding(.horizontal, MacOS9Metrics.badgePaddingH + 4)
        .padding(.vertical, MacOS9Metrics.badgePaddingV + 3)
        .background(MacOS9Colors.labelBadge)
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth))
        .opacity(blink ? 1 : 0.55)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                blink = true
            }
        }
    }
}

// MARK: - Linha de evento

private struct VEventRow: View {
    let event: VEvent
    let accent: Color
    let showTopDivider: Bool

    private var mapsURL: URL? {
        guard let query = event.mapsQuery else { return nil }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://maps.google.com/?q=\(encoded)")
    }

    var body: some View {
        VStack(spacing: 0) {
            if showTopDivider {
                MacOS9Divider()
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 2) {
                    Text(event.icon)
                        .font(.system(size: 16))
                    Text(event.time)
                        .font(MacOS9Typography.finePrint(9))
                        .foregroundStyle(accent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(MacOS9Typography.bodyBold(13))
                        .foregroundStyle(MacOS9Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(event.desc)
                        .font(MacOS9Typography.body(12))
                        .foregroundStyle(MacOS9Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let address = event.address, let url = mapsURL {
                        Link(destination: url) {
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "mappin.circle")
                                    .font(.system(size: 11))
                                Text(address)
                                    .font(MacOS9Typography.caption(11))
                                    .underline()
                            }
                            .foregroundStyle(MacOS9Colors.selection)
                        }
                        .padding(.top, 2)
                    }

                    if let lounge = event.lounge {
                        HStack(alignment: .top, spacing: 4) {
                            Image(systemName: "sofa")
                                .font(.system(size: 10))
                            Text(lounge)
                        }
                        .font(MacOS9Typography.caption(10))
                        .foregroundStyle(MacOS9Colors.primaryText)
                        .padding(8)
                        .background(MacOS9Colors.labelBadge.opacity(0.55))
                        .overlay(
                            Rectangle().strokeBorder(
                                MacOS9Colors.border.opacity(0.4), lineWidth: MacOS9Metrics.borderWidth)
                        )
                        .padding(.top, 4)
                    }

                    if let ref = event.ref {
                        Text(ref)
                            .font(MacOS9Typography.finePrint(9))
                            .foregroundStyle(MacOS9Colors.statusGreen)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(MacOS9Colors.statusGreen.opacity(0.12))
                            .overlay(
                                Rectangle().strokeBorder(
                                    MacOS9Colors.statusGreen.opacity(0.4), lineWidth: MacOS9Metrics.borderWidth)
                            )
                            .padding(.top, 3)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Seção de um dia (colapsável) — janela Mac OS 9

private struct VDaySection: View {
    let day: VDay
    let isExpanded: Bool
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
                        VEventRow(event: ev, accent: day.tone.accent, showTopDivider: idx != 0)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .background(MacOS9Colors.contentPanel)
            }
        }
        .background(MacOS9Colors.panelBackground)
        .overlay(Mac9BevelBorder(isRaised: true, width: MacOS9Metrics.bevelWidth))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth))
        .shadow(color: MacOS9Colors.dropShadow, radius: 0, x: 2, y: 2)
    }

    private var headerButton: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(day.tone.accent)
                    .frame(width: 5)

                VStack(spacing: 0) {
                    Text(dayNumber)
                        .font(MacOS9Typography.editorialBold(22))
                        .foregroundStyle(day.tone.accent)
                    Text("set")
                        .font(MacOS9Typography.finePrint(10))
                        .foregroundStyle(MacOS9Colors.secondaryText)
                }
                .frame(minWidth: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(day.title)
                        .font(MacOS9Typography.bodyBold(14))
                        .foregroundStyle(MacOS9Colors.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(day.weekday)
                            .font(MacOS9Typography.caption(11))
                            .foregroundStyle(MacOS9Colors.secondaryText)
                        Text(day.tone.label.uppercased())
                            .font(MacOS9Typography.finePrint(9))
                            .foregroundStyle(day.tone.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(day.tone.chip)
                            .overlay(Rectangle().strokeBorder(day.tone.accent.opacity(0.4), lineWidth: 1))
                    }
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MacOS9Colors.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View principal

struct ViagemView: View {
    @State private var expandedDays: Set<String> = Set(VData.days.map(\.id))

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    heroHeader

                    ForEach(VData.days) { day in
                        VDaySection(
                            day: day,
                            isExpanded: expandedDays.contains(day.id),
                            onToggle: { toggle(day.id) }
                        )
                    }

                    footerNote
                }
                .padding(MacOS9Metrics.windowPadding)
            }
            .background(MacOS9Colors.windowBackground.ignoresSafeArea())
            .navigationTitle("Viagem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    styledNavTitle
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if expandedDays.contains(id) {
            expandedDays.remove(id)
        } else {
            expandedDays.insert(id)
        }
    }

    private var styledNavTitle: some View {
        HStack(spacing: 6) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(MacOS9Colors.selection)
            Text("Viagem")
                .font(MacOS9Typography.windowTitle(16))
                .foregroundStyle(MacOS9Colors.primaryText)
        }
    }

    private var heroHeader: some View {
        VStack(spacing: 10) {
            MacOS9Label(text: "CRONOLOGIA FINAL · 7–18 SET 2026")

            Text("O roteiro, hora a hora")
                .font(MacOS9Typography.editorialTitle(24))
                .foregroundStyle(MacOS9Colors.primaryText)
                .multilineTextAlignment(.center)

            Text("com todos os endereços no mapa")
                .font(MacOS9Typography.editorialItalic(15))
                .foregroundStyle(MacOS9Colors.secondaryText)
                .multilineTextAlignment(.center)

            VReservedBadge()
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .mac9Panel()
    }

    private var footerNote: some View {
        VStack(spacing: 4) {
            Text("Toque em qualquer endereço para abrir no Google Maps 📍")
                .font(MacOS9Typography.editorialItalic(15))
            Text("Boa viagem, Eliel & Ana 🤍")
                .font(MacOS9Typography.editorialItalic(13))
        }
        .foregroundStyle(MacOS9Colors.secondaryText)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

#Preview {
    ViagemView()
}
