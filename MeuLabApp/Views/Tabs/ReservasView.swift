import SwiftUI
import UIKit

// ============================================================
// RESERVAS — TODOS OS LOCALIZADORES
// Balcão de aeroporto, fila da locadora, recepção do hotel: a tela
// que responde "qual é o código?" sem depender de sinal.
// Lê apenas TripEngine.shared.stops (offline, já em memória) e
// quebra o campo `ref` ("Iberia · 9WAXMR") em fornecedor + código.
// ============================================================

// MARK: - Cores

/// Same palette as ViagemView, redeclared here because that one is file-private.
private enum RPalette {
    static func hex(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Two-tone accent: same hue in both appearances, different luminance, so the
    /// warm sepias of this screen survive on a dark backdrop.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex(traits.userInterfaceStyle == .dark ? dark : light))
        })
    }

    // Structure — follows the system appearance.
    static let bg = Color(uiColor: .systemGroupedBackground)
    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let descColor = Color(uiColor: .secondaryLabel)
    static let cardBorder = Color(uiColor: .separator)

    // Identity — the hero gradient and the cream printed on it stay fixed, since
    // the gradient itself is always dark.
    static let heroStart = hex(0x1B2A4A)
    static let heroMid = hex(0x2E4470)
    static let heroEnd = hex(0x6E5A8E)
    static let heroInk = hex(0xF7F3EB)
    static let titleAccent = adaptive(light: 0x2E4470, dark: 0x9DB6E4)

    // Accents drawn over the adaptive surface.
    static let mapsLink = adaptive(light: 0x6E6452, dark: 0xC2B69C)
    static let mapsDot = adaptive(light: 0xA89C87, dark: 0x9A8F79)
    static let refBase = adaptive(light: 0x2E7D5A, dark: 0x74D3A6)
    /// Badge on the hero gradient — fixed for the same reason as `heroInk`.
    static let heroBadgeBase = hex(0x2E7D5A)
    static let shimmerText = hex(0xCFF3DF)
}

// MARK: - Categoria do fornecedor

/// Only drives colour and icon — a wrong guess costs nothing.
private enum RKind {
    case flight, lodging, rail, car, other

    /// Same five hues in both appearances; only the luminance moves, so a locator
    /// printed in navy on cream is still readable in mid-blue on dark glass.
    var accent: Color {
        switch self {
        case .flight: return RPalette.adaptive(light: 0x2E4470, dark: 0x8FAAD9)
        case .lodging: return RPalette.adaptive(light: 0x6E5A8E, dark: 0xB49CD8)
        case .rail: return RPalette.adaptive(light: 0x2E7D5A, dark: 0x6FCFA0)
        case .car: return RPalette.adaptive(light: 0xB8862D, dark: 0xE3B860)
        case .other: return RPalette.adaptive(light: 0x6E6452, dark: 0xC2B69C)
        }
    }

    var chip: Color { accent.opacity(0.14) }

    var symbol: String {
        switch self {
        case .flight: return "airplane"
        case .lodging: return "bed.double.fill"
        case .rail: return "tram.fill"
        case .car: return "car.fill"
        case .other: return "ticket.fill"
        }
    }

    var label: String {
        switch self {
        case .flight: return "voo"
        case .lodging: return "hospedagem"
        case .rail: return "trem"
        case .car: return "carro"
        case .other: return "reserva"
        }
    }

    static func forSupplier(_ supplier: String) -> RKind {
        let name = supplier.lowercased()
        let flights = ["latam", "iberia", "ryanair", "tap", "gol", "azul", "air", "vueling", "easyjet"]
        let lodging = ["booking", "airbnb", "hotel", "hostel", "hôte", "hote"]
        let rail = ["trainline", "sncf", "trenitalia", "omio", "renfe", "eurostar", "cp ", "trem"]
        let car = ["alamo", "localiza", "hertz", "avis", "europcar", "sixt", "movida"]
        if flights.contains(where: { name.contains($0) }) { return .flight }
        if lodging.contains(where: { name.contains($0) }) { return .lodging }
        if rail.contains(where: { name.contains($0) }) { return .rail }
        if car.contains(where: { name.contains($0) }) { return .car }
        return .other
    }
}

// MARK: - Modelos

private struct RCode: Identifiable {
    let id: String
    /// "PIN", "bilhete", "voo" — the word that precedes the code, when there is one.
    let label: String?
    let value: String
}

private struct RUse: Identifiable {
    let id: String
    let dayDate: String
    let time: String
    let icon: String
    let title: String
}

private struct RBooking: Identifiable {
    let id: String
    let supplier: String
    /// Parts of the ref that carry no copyable code ("comprar no dia", "hôte Yael").
    let notes: [String]
    let codes: [RCode]
    /// Every itinerary entry covered by this same locator.
    var uses: [RUse]

    var kind: RKind { RKind.forSupplier(supplier) }
}

private struct RGroup: Identifiable {
    let id: String
    let supplier: String
    var bookings: [RBooking]

    var kind: RKind { RKind.forSupplier(supplier) }
}

// MARK: - Parser dos refs

private enum RParser {
    /// Refs are written as "Fornecedor · CÓDIGO", separator U+00B7. Some carry a
    /// third part ("Booking · 5508609912 · PIN 8588").
    static func parts(of ref: String) -> [String] {
        ref.split(separator: "\u{00B7}")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// A locator-looking token: 4+ chars, only uppercase letters and digits, and
    /// either carrying a digit ("LA3691", "8588") or long enough to be a pure
    /// letter PNR ("DMDKRN"). Rules out prose ("comprar", "hôte", "Yael") and
    /// short labels ("PIN", "voo"), which become the code's label instead.
    static func isCodeToken(_ token: String) -> Bool {
        guard token.count >= 4 else { return false }
        var hasDigit = false
        for ch in token.unicodeScalars {
            if CharacterSet.decimalDigits.contains(ch) {
                hasDigit = true
            } else if !CharacterSet.uppercaseLetters.contains(ch) {
                return false
            }
        }
        return hasDigit || token.count >= 5
    }

    /// Splits one part into its copyable code (joined code tokens) and the plain
    /// words around it. No code tokens at all means the part is just a note.
    static func code(from part: String, id: String) -> RCode? {
        let tokens = part.split(separator: " ").map(String.init)
        let codeTokens = tokens.filter(isCodeToken)
        guard !codeTokens.isEmpty else { return nil }
        let labelTokens = tokens.filter { !isCodeToken($0) }
        let label = labelTokens.isEmpty ? nil : labelTokens.joined(separator: " ")
        return RCode(id: id, label: label, value: codeTokens.joined(separator: " "))
    }

    /// Titles are long ("Voo LATAM LA3691 — Londrina (LDB) → São Paulo (GRU)").
    /// At a counter only the head of the phrase is worth reading.
    static func shortTitle(_ title: String) -> String {
        for dash in [" — ", " – ", " - "] {
            if let head = title.components(separatedBy: dash).first, head.count >= 6 {
                return head.trimmingCharacters(in: .whitespaces)
            }
        }
        return title
    }

    /// One card per distinct ref, grouped by supplier, both in itinerary order.
    static func groups(from stops: [TripStop]) -> [RGroup] {
        var groups: [RGroup] = []
        var groupIndex: [String: Int] = [:]
        var bookingIndex: [String: (group: Int, booking: Int)] = [:]

        for stop in stops {
            guard let ref = stop.ref?.trimmingCharacters(in: .whitespacesAndNewlines),
                !ref.isEmpty
            else { continue }

            let segments = parts(of: ref)
            guard let supplier = segments.first else { continue }
            let rest = Array(segments.dropFirst())

            let use = RUse(
                id: stop.id,
                dayDate: stop.dayDate,
                time: stop.time,
                icon: stop.icon,
                title: shortTitle(stop.title)
            )

            // Same locator seen again on a later day: just add the entry to it.
            if let hit = bookingIndex[ref] {
                groups[hit.group].bookings[hit.booking].uses.append(use)
                continue
            }

            var codes: [RCode] = []
            var notes: [String] = []
            for (index, part) in rest.enumerated() {
                if let code = code(from: part, id: "\(ref)#\(index)") {
                    codes.append(code)
                } else {
                    notes.append(part)
                }
            }

            let booking = RBooking(
                id: ref,
                supplier: supplier,
                notes: notes,
                codes: codes,
                uses: [use]
            )

            if let index = groupIndex[supplier] {
                groups[index].bookings.append(booking)
                bookingIndex[ref] = (index, groups[index].bookings.count - 1)
            } else {
                groups.append(RGroup(id: supplier, supplier: supplier, bookings: [booking]))
                groupIndex[supplier] = groups.count - 1
                bookingIndex[ref] = (groups.count - 1, 0)
            }
        }

        return groups
    }
}

// MARK: - Chip de código copiável

private struct RCodeChip: View {
    let code: RCode
    let accent: Color
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    if let label = code.label {
                        Text(label.uppercased())
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(accent.opacity(0.75))
                    }
                    Text(code.value)
                        .font(.system(size: 21, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(accent)
                        .textSelection(.enabled)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                    Text(isCopied ? "copiado" : "copiar")
                        .font(.system(size: 11.5, weight: .bold))
                }
                .foregroundColor(isCopied ? RPalette.refBase : accent.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(accent.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        (isCopied ? RPalette.refBase : accent).opacity(isCopied ? 0.55 : 0.28),
                        lineWidth: 1.2
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Copiar código \(code.value)"))
    }
}

// MARK: - Card de uma reserva

private struct RBookingCard: View {
    let booking: RBooking
    let copiedID: String?
    let onCopy: (RCode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if booking.codes.isEmpty {
                noCodeBadge
            } else {
                ForEach(booking.codes) { code in
                    RCodeChip(
                        code: code,
                        accent: booking.kind.accent,
                        isCopied: copiedID == code.id,
                        onCopy: { onCopy(code) }
                    )
                }
            }

            if !booking.notes.isEmpty {
                Text(booking.notes.joined(separator: " · "))
                    .font(.system(size: 12.5))
                    .foregroundColor(RPalette.descColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(booking.uses) { use in
                    HStack(alignment: .top, spacing: 8) {
                        Text(use.icon)
                            .font(.system(size: 13))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(use.dayDate) · \(use.time)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(booking.kind.accent.opacity(0.85))
                            Text(use.title)
                                .font(.system(size: 12.5))
                                .foregroundColor(RPalette.descColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Nested inside the supplier's glass section, so the lighter material
        // rather than a second sheet of glass.
        .materialCard(cornerRadius: 14)
    }

    private var noCodeBadge: some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12.5))
            Text("Sem localizador — resolver no local")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(RPalette.mapsLink)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(RPalette.mapsDot.opacity(0.22))
        .clipShape(Capsule())
    }
}

// MARK: - Seção de um fornecedor

private struct RGroupSection: View {
    let group: RGroup
    let copiedID: String?
    let onCopy: (RCode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(spacing: 12) {
                ForEach(group.bookings) { booking in
                    RBookingCard(booking: booking, copiedID: copiedID, onCopy: onCopy)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .glassCard(cornerRadius: 18)
        .shadow(color: Color.black.opacity(0.10), radius: 16, y: 9)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(group.kind.accent)
                .frame(width: 5)

            HStack(alignment: .center, spacing: 13) {
                Image(systemName: group.kind.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(group.kind.accent)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.supplier)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(RPalette.ink)

                    Text(group.kind.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundColor(group.kind.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .background(group.kind.chip)
                        .clipShape(Capsule())
                }

                Spacer(minLength: 8)

                Text("\(group.bookings.count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(RPalette.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - View principal

struct ReservasView: View {
    @State private var groups: [RGroup] = []
    @State private var copiedID: String?
    /// Cancels the previous "copiado" reset when two codes are tapped in a row.
    @State private var copyResetTask: Task<Void, Never>?

    private var bookingCount: Int { groups.reduce(0) { $0 + $1.bookings.count } }
    private var codeCount: Int {
        groups.reduce(0) { $0 + $1.bookings.reduce(0) { $0 + $1.codes.count } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader

                VStack(spacing: 16) {
                    if groups.isEmpty {
                        emptyState
                    } else {
                        ForEach(groups) { group in
                            RGroupSection(
                                group: group,
                                copiedID: copiedID,
                                onCopy: copy
                            )
                        }
                        footerNote
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(RPalette.bg.ignoresSafeArea())
        .navigationTitle("Reservas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                styledNavTitle
            }
        }
        .onAppear(perform: reload)
    }

    // MARK: - Dados

    private func reload() {
        if TripEngine.shared.stops.isEmpty {
            TripEngine.shared.load(ViagemBridge.makeStops())
        }
        groups = RParser.groups(from: TripEngine.shared.stops)
    }

    private func copy(_ code: RCode) {
        UIPasteboard.general.string = code.value
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.18)) { copiedID = code.id }

        copyResetTask?.cancel()
        copyResetTask = Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { copiedID = nil }
        }
    }

    // MARK: - Cabeçalho e rodapé

    private var styledNavTitle: some View {
        HStack(spacing: 6) {
            Text("🎫")
                .font(.system(size: 14))
            Text("Reservas")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(RPalette.titleAccent)
        }
    }

    private var heroHeader: some View {
        VStack(spacing: 12) {
            Text("LOCALIZADORES · SET 2026")
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(3)
                .foregroundColor(RPalette.heroInk.opacity(0.78))
                .multilineTextAlignment(.center)

            Text("Todos os códigos")
                .font(.system(size: 38, weight: .semibold, design: .serif))
                .foregroundColor(RPalette.heroInk)
                .multilineTextAlignment(.center)

            Text("no balcão, sem internet")
                .font(.system(size: 18, design: .serif))
                .italic()
                .foregroundColor(RPalette.heroInk.opacity(0.9))
                .multilineTextAlignment(.center)

            if !groups.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(bookingCount) reservas · \(codeCount) códigos offline")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(RPalette.shimmerText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(RPalette.heroBadgeBase.opacity(0.28)))
                .overlay(Capsule().stroke(RPalette.shimmerText.opacity(0.45), lineWidth: 1))
                .padding(.top, 6)
            }
        }
        .padding(.top, 56)
        .padding(.bottom, 46)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [RPalette.heroStart, RPalette.heroMid, RPalette.heroEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🎫")
                .font(.system(size: 40))
            Text("Nenhum localizador no roteiro")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(RPalette.ink)
            Text("As reservas aparecem aqui assim que a cronologia da viagem for carregada.")
                .font(.system(size: 13.5))
                .foregroundColor(RPalette.descColor)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 18)
    }

    private var footerNote: some View {
        VStack(spacing: 4) {
            Text("Toque no código para copiar 📋")
                .font(.system(size: 18, design: .serif))
                .italic()
            Text("Tudo guardado no app — funciona no modo avião")
                .font(.system(size: 15, design: .serif))
                .italic()
        }
        .foregroundColor(RPalette.mapsLink)
        .multilineTextAlignment(.center)
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        ReservasView()
    }
}
