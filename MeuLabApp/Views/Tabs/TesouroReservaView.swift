import SwiftUI
import Charts
import UIKit

// ============================================================
// TESOURO RESERVA — LIVRO DE RENDIMENTOS
// Port nativo do simulador (React/TSX) para SwiftUI.
// Capitalização diária (252 d.u.) com curva de Selic editável,
// comparativo Reserva × CDB %CDI × Poupança, calendário de
// rendimentos, gráficos de evolução e câmbio via BrasilAPI.
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

/// Two-tone colour resolved from the interface style. The ledger's gold, mint and
/// red keep their hue in both appearances — only the luminance moves, because a
/// pale mint that glows on deep green vanishes on white.
private func trAdaptive(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
        UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
    })
}

private enum TRPalette {
    // Structure — page, fields, rules and text follow the system appearance; the
    // card surfaces themselves are glass and no longer painted here.
    static let bg = Color(uiColor: .systemGroupedBackground)
    static let panel2 = Color(uiColor: .secondarySystemBackground)
    static let line = Color(uiColor: .separator)
    static let ink = Color(uiColor: .label)
    static let inkDim = Color(uiColor: .secondaryLabel)

    // Identity — the ledger accents.
    static let gold = trAdaptive(light: 0x8A6210, dark: 0xD9A441)
    static let mint = trAdaptive(light: 0x1D6B45, dark: 0x8FD3B0)
    static let red = trAdaptive(light: 0xA1352A, dark: 0xE08A7A)
    /// Gold as a *fill* (the resgate cell, the legend swatch): fixed, because the
    /// dark ink printed on top of it is fixed too.
    static let goldFill = Color(hex: 0xD9A441)

    // The paper receipt is a printed slip inside the screen: always cream stock
    // with dark ink, in either appearance.
    static let paper = Color(hex: 0xF5F1E3)
    static let paperInk = Color(hex: 0x26352C)
    static let paperInkDim = Color(hex: 0x4C5C51)
    static let paperSub = Color(hex: 0x6B7A6F)
    static let paperLine = Color(hex: 0xD8D2BC)
    static let posGreen = Color(hex: 0x1D6B45)
    static let negRed = Color(hex: 0xA1352A)
}

// MARK: - Datas

private enum TRDate {
    static let holidays: Set<String> = [
        "2026-01-01", "2026-02-16", "2026-02-17", "2026-04-03", "2026-04-21",
        "2026-05-01", "2026-06-04", "2026-09-07", "2026-10-12", "2026-11-02",
        "2026-11-15", "2026-11-20", "2026-12-25",
        "2027-01-01", "2027-02-08", "2027-02-09", "2027-03-26", "2027-04-21",
        "2027-05-01", "2027-05-27", "2027-09-07", "2027-10-12", "2027-11-02",
        "2027-11-15", "2027-11-20", "2027-12-25",
    ]

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        return cal
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    static func iso(_ d: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func fromISO(_ s: String) -> Date {
        let parts = s.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return date(2026, 1, 1) }
        return date(parts[0], parts[1], parts[2])
    }

    static func addDays(_ d: Date, _ n: Int) -> Date {
        calendar.date(byAdding: .day, value: n, to: d) ?? d
    }

    static func isBusinessDay(_ d: Date) -> Bool {
        let wd = calendar.component(.weekday, from: d)
        if wd == 1 || wd == 7 { return false }
        return !holidays.contains(iso(d))
    }

    static func calDays(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: a), to: calendar.startOfDay(for: b)
        ).day ?? 0
    }

    static func ddmm(_ d: Date) -> String {
        let c = calendar.dateComponents([.day, .month], from: d)
        return String(format: "%02d/%02d", c.day!, c.month!)
    }

    static func dateBR(_ d: Date) -> String {
        let c = calendar.dateComponents([.day, .month, .year], from: d)
        return String(format: "%02d/%02d/%04d", c.day!, c.month!, c.year!)
    }
}

private let trMonths = [
    "janeiro", "fevereiro", "março", "abril", "maio", "junho",
    "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
]
private let trWeekdays = ["D", "S", "T", "Q", "Q", "S", "S"]

// MARK: - Formatação

private let brlFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "pt_BR")
    f.currencyCode = "BRL"
    return f
}()

private func brl(_ v: Double) -> String {
    brlFormatter.string(from: NSNumber(value: v)) ?? "R$ 0,00"
}

private let brl4Formatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "pt_BR")
    f.currencyCode = "BRL"
    f.minimumFractionDigits = 4
    f.maximumFractionDigits = 4
    return f
}()

private func brl4(_ v: Double) -> String {
    brl4Formatter.string(from: NSNumber(value: v)) ?? "R$ 0,0000"
}

private func brl4NoSymbol(_ v: Double) -> String {
    brl4(v).replacingOccurrences(of: "R$", with: "").trimmingCharacters(in: .whitespaces)
}

private func pct(_ v: Double, _ digits: Int = 2) -> String {
    String(format: "%.\(digits)f%%", v).replacingOccurrences(of: ".", with: ",")
}

// MARK: - Regras tributárias

private let iofTable: [Int] = [
    96, 93, 90, 86, 83, 80, 76, 73, 70, 66, 63, 60, 56, 53, 50,
    46, 43, 40, 36, 33, 30, 26, 23, 20, 16, 13, 10, 6, 3, 0,
]

private func iofPct(_ days: Int) -> Int {
    if days >= 30 || days < 1 { return 0 }
    return iofTable[days - 1]
}

private struct IRBracket {
    let rate: Double
    let label: String
    let next: Int
}

private func irBracket(_ days: Int) -> IRBracket {
    if days <= 180 { return IRBracket(rate: 22.5, label: "até 180 dias", next: 181 - days) }
    if days <= 360 { return IRBracket(rate: 20.0, label: "181 a 360 dias", next: 361 - days) }
    if days <= 720 { return IRBracket(rate: 17.5, label: "361 a 720 dias", next: 721 - days) }
    return IRBracket(rate: 15.0, label: "acima de 720 dias", next: 0)
}

private func safePct(_ value: Double, _ principal: Double) -> Double {
    principal > 0 ? (value / principal - 1) * 100 : 0
}

// MARK: - Constantes

private let trToday = TRDate.calendar.startOfDay(for: Date())
private let trHorizonEnd = TRDate.fromISO("2027-12-31")
private let trCustodyExemption = 10000.0
private let trCustodyRate = 0.002
private let trCDISpread = 0.10

private struct FXFallback {
    let code: String
    let name: String
    let now: Double
    let note: String
}

private let fxFallback: [FXFallback] = [
    FXFallback(
        code: "USD", name: "Dólar", now: 5.21,
        note: "fechou 01/07 a ~R$ 5,21; mínima de 52 semanas R$ 4,89, máxima R$ 5,63 (−4,3% em 12 meses)"
    ),
    FXFallback(
        code: "EUR", name: "Euro", now: 5.90,
        note: "≈ R$ 5,90; mínima do ano R$ 5,7388 em 13/05 (−5,9% em 12 meses)"
    ),
    FXFallback(
        code: "GBP", name: "Libra", now: 6.87,
        note: "≈ R$ 6,87, derivado dos cruzamentos (GBP/USD ~1,32)"
    ),
]

private let fxDates = [
    "2026-01-02", "2026-02-02", "2026-03-02", "2026-04-01",
    "2026-05-04", "2026-06-01", "2026-07-01",
]

// MARK: - Motor de cálculo

private struct DayInfo {
    let balance: Double
    let dailyYield: Double
    let rate: Double
}

private struct RatePeriod {
    let from: String
    let rate: Double
}

private struct ResgateResult {
    let gross: Double
    let grossYield: Double
    let days: Int
    let iofP: Int
    let iof: Double
    let ir: IRBracket
    let irValue: Double
    let custody: Double
    let net: Double
    let netYield: Double
}

private struct CompareRow: Identifiable {
    let id = UUID()
    let name: String
    let net: Double
    let gain: Double
    let pctValue: Double
    let obs: String
}

private struct ExtraAporte: Identifiable {
    let id = UUID()
    var dateISO: String
    var valor: Double
}

private struct EvolutionPoint: Identifiable {
    let id = UUID()
    let d: String
    let reserva: Double
    let cdb: Double
    let poupanca: Double
}

private struct YearProjectionPoint: Identifiable {
    let id = UUID()
    let d: String
    let reserva: Double
    let cdb: Double
}

private struct YearProjection {
    let points: [YearProjectionPoint]
    let end: Date
    let days: Int
    let ir: IRBracket
    let grossReserva: Double
    let grossCDB: Double
    let netReserva: Double
    let netCDB: Double
    let custody: Double
}

private struct ExtraAporteInput {
    let date: Date
    let valor: Double
}

private struct TREngine {
    let principal: Double
    let aporte: Date
    let resgate: Date
    let ratePeriods: [RatePeriod]
    let pctCDI: Double
    let trMensal: Double
    /// Aportes adicionais feitos em datas posteriores ao aporte inicial — cada um passa
    /// a compor o saldo (e a render) a partir do dia seguinte à sua própria data.
    let extraAportes: [ExtraAporteInput]

    /// Total efetivamente aplicado até `date` (aporte inicial + adicionais já feitos).
    func totalContributed(upTo date: Date) -> Double {
        principal + extraAportes.filter { $0.date <= date }.reduce(0) { $0 + $1.valor }
    }

    private var extraByDate: [String: Double] {
        Dictionary(grouping: extraAportes, by: { TRDate.iso($0.date) })
            .mapValues { $0.reduce(0) { $0 + $1.valor } }
    }

    func rateAt(_ d: Date) -> Double {
        let s = TRDate.iso(d)
        var r = ratePeriods.first?.rate ?? 0
        for p in ratePeriods where p.from <= s { r = p.rate }
        return r
    }

    /// `history`: fator diário real da Selic (série SGS 11 do BCB, % a.d.) por data ISO,
    /// usado nos dias já decorridos para maior precisão. Dias sem histórico (futuros)
    /// caem de volta na estimativa via `ratePeriods`.
    func buildCurve(history: [String: Double] = [:]) -> [String: DayInfo] {
        var map: [String: DayInfo] = [:]
        guard principal > 0 else { return map }
        let extras = extraByDate
        var balance = principal
        var d = TRDate.addDays(aporte, 1)
        while d <= trHorizonEnd {
            let s = TRDate.iso(d)
            let r = rateAt(d)
            if TRDate.isBusinessDay(d) {
                let y: Double
                if let dailyFactor = history[s] {
                    y = balance * (dailyFactor / 100)
                } else {
                    y = balance * (pow(1 + r / 100, 1.0 / 252) - 1)
                }
                balance += y
                if let extra = extras[s] { balance += extra }
                map[s] = DayInfo(balance: balance, dailyYield: y, rate: r)
            } else {
                if let extra = extras[s] { balance += extra }
                map[s] = DayInfo(balance: balance, dailyYield: 0, rate: r)
            }
            d = TRDate.addDays(d, 1)
        }
        return map
    }

    func buildCDBCurve() -> [String: Double] {
        var map: [String: Double] = [:]
        let extras = extraByDate
        var balance = principal
        var d = TRDate.addDays(aporte, 1)
        while d <= trHorizonEnd {
            let s = TRDate.iso(d)
            if TRDate.isBusinessDay(d) {
                let cdi = max(0, rateAt(d) - trCDISpread) * (pctCDI / 100)
                balance *= pow(1 + cdi / 100, 1.0 / 252)
            }
            if let extra = extras[s] { balance += extra }
            map[s] = balance
            d = TRDate.addDays(d, 1)
        }
        return map
    }

    private func poupancaContribution(valor: Double, from start: Date, to target: Date) -> Double {
        guard start <= target else { return 0 }
        let monthly = 0.005 + trMensal / 100
        let cal = TRDate.calendar
        let startDay = cal.component(.day, from: start)
        var k = 0
        var ann = start
        while true {
            let annComps = cal.dateComponents([.year, .month], from: ann)
            let nextM = cal.date(from: DateComponents(year: annComps.year!, month: annComps.month! + 1, day: 1))!
            let lastDay = cal.range(of: .day, in: .month, for: nextM)?.count ?? 28
            let nextMComps = cal.dateComponents([.year, .month], from: nextM)
            ann = cal.date(from: DateComponents(
                year: nextMComps.year!, month: nextMComps.month!, day: min(startDay, lastDay)
            ))!
            if ann <= target { k += 1 } else { break }
            if k > 60 { break }
        }
        return valor * pow(1 + monthly, Double(k))
    }

    func poupancaAt(_ target: Date) -> Double {
        var total = poupancaContribution(valor: principal, from: aporte, to: target)
        for extra in extraAportes {
            total += poupancaContribution(valor: extra.valor, from: extra.date, to: target)
        }
        return total
    }

    func buildResult(curve: [String: DayInfo]) -> ResgateResult {
        let contributed = totalContributed(upTo: resgate)
        let info = curve[TRDate.iso(resgate)]
        let gross = info?.balance ?? contributed
        let grossYield = max(0, gross - contributed)
        let days = TRDate.calDays(aporte, resgate)
        let iofP = iofPct(days)
        let iof = grossYield * (Double(iofP) / 100)
        let ir = irBracket(days)
        let irValue = (grossYield - iof) * (ir.rate / 100)
        var custody = 0.0
        var d = TRDate.addDays(aporte, 1)
        while d <= resgate {
            if TRDate.isBusinessDay(d) {
                let bal = curve[TRDate.iso(d)]?.balance ?? contributed
                custody += max(0, bal - trCustodyExemption) * (trCustodyRate / 252)
            }
            d = TRDate.addDays(d, 1)
        }
        let net = gross - iof - irValue - custody
        return ResgateResult(
            gross: gross, grossYield: grossYield, days: days, iofP: iofP, iof: iof,
            ir: ir, irValue: irValue, custody: custody, net: net, netYield: net - contributed
        )
    }

    func buildCompare(result: ResgateResult, cdbCurve: [String: Double]) -> [CompareRow] {
        let contributed = totalContributed(upTo: resgate)
        let ir = irBracket(result.days)
        let cdbGross = cdbCurve[TRDate.iso(resgate)] ?? contributed
        let cdbYield = max(0, cdbGross - contributed)
        let cdbIof = cdbYield * (Double(iofPct(result.days)) / 100)
        let cdbIr = (cdbYield - cdbIof) * (ir.rate / 100)
        let cdbNet = cdbGross - cdbIof - cdbIr
        let poupNet = poupancaAt(resgate)
        return [
            CompareRow(
                name: "Tesouro Reserva", net: result.net, gain: result.netYield,
                pctValue: safePct(result.net, contributed), obs: "IR + custódia B3 (isenta até R$10k)"
            ),
            CompareRow(
                name: "CDB \(Int(pctCDI))% CDI", net: cdbNet, gain: cdbNet - contributed,
                pctValue: safePct(cdbNet, contributed), obs: "CDI ≈ Selic − 0,10 p.p.; IR igual; sem custódia"
            ),
            CompareRow(
                name: "Poupança", net: poupNet, gain: poupNet - contributed,
                pctValue: safePct(poupNet, contributed),
                obs: "0,5% a.m. + TR (\(pct(trMensal)) a.m.); só paga no aniversário; isenta de IR"
            ),
        ]
    }

    func buildEvolution(curve: [String: DayInfo], cdbCurve: [String: Double]) -> [EvolutionPoint] {
        var pts: [EvolutionPoint] = []
        let totalDays = max(1, TRDate.calDays(aporte, resgate))
        let step = max(1, totalDays / 120)
        var d = aporte
        while d <= resgate {
            pts.append(EvolutionPoint(
                d: TRDate.ddmm(d),
                reserva: curve[TRDate.iso(d)]?.balance ?? principal,
                cdb: cdbCurve[TRDate.iso(d)] ?? principal,
                poupanca: poupancaAt(d)
            ))
            d = TRDate.addDays(d, step)
        }
        if pts.last?.d != TRDate.ddmm(resgate) {
            pts.append(EvolutionPoint(
                d: TRDate.ddmm(resgate),
                reserva: curve[TRDate.iso(resgate)]?.balance ?? principal,
                cdb: cdbCurve[TRDate.iso(resgate)] ?? principal,
                poupanca: poupancaAt(resgate)
            ))
        }
        return pts
    }

    func buildYearProjection(curve: [String: DayInfo], cdbCurve: [String: Double]) -> YearProjection {
        let end0 = TRDate.addDays(aporte, 365)
        let end = end0 > trHorizonEnd ? trHorizonEnd : end0
        let contributed = totalContributed(upTo: end)
        var pts: [YearProjectionPoint] = []
        var d = aporte
        while d <= end {
            pts.append(YearProjectionPoint(
                d: TRDate.ddmm(d),
                reserva: curve[TRDate.iso(d)]?.balance ?? principal,
                cdb: cdbCurve[TRDate.iso(d)] ?? principal
            ))
            d = TRDate.addDays(d, 3)
        }
        let grossReserva = curve[TRDate.iso(end)]?.balance ?? contributed
        let grossCDB = cdbCurve[TRDate.iso(end)] ?? contributed
        let days = TRDate.calDays(aporte, end)
        let ir = irBracket(days)
        var custody = 0.0
        var cd = TRDate.addDays(aporte, 1)
        while cd <= end {
            if TRDate.isBusinessDay(cd) {
                let bal = curve[TRDate.iso(cd)]?.balance ?? contributed
                custody += max(0, bal - trCustodyExemption) * (trCustodyRate / 252)
            }
            cd = TRDate.addDays(cd, 1)
        }
        let netReserva = grossReserva - (grossReserva - contributed) * (ir.rate / 100) - custody
        let netCDB = grossCDB - (grossCDB - contributed) * (ir.rate / 100)
        return YearProjection(
            points: pts, end: end, days: days, ir: ir,
            grossReserva: grossReserva, grossCDB: grossCDB,
            netReserva: netReserva, netCDB: netCDB, custody: custody
        )
    }

    func buildDailyRows(curve: [String: DayInfo]) -> [(date: Date, info: DayInfo)] {
        var rows: [(Date, DayInfo)] = []
        var d = resgate
        while rows.count < 20 && d > aporte {
            if let info = curve[TRDate.iso(d)], TRDate.isBusinessDay(d), info.dailyYield > 0 {
                rows.append((d, info))
            }
            d = TRDate.addDays(d, -1)
        }
        return rows.reversed()
    }
}

// MARK: - Câmbio (BrasilAPI, com fallback)

private struct FXPoint: Identifiable {
    let id = UUID()
    let label: String
    var usd: Double?
    var eur: Double?
    var gbp: Double?
}

@MainActor
private final class FXLoader: ObservableObject {
    enum Status { case loading, ok, fallback }

    @Published var series: [FXPoint] = []
    @Published var status: Status = .loading
    private var didLoad = false

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        let codes = ["USD", "EUR", "GBP"]
        var raw: [String: [Double?]] = [:]
        for code in codes {
            var values: [Double?] = []
            for date in fxDates {
                values.append(await Self.fetchOne(code: code, date: date))
            }
            raw[code] = values
        }
        let base: [String: Double?] = Dictionary(uniqueKeysWithValues: codes.map { code in
            (code, (raw[code] ?? []).compactMap { $0 }.first)
        })
        guard base.values.contains(where: { $0 != nil }) else {
            status = .fallback
            return
        }
        var points: [FXPoint] = []
        for (i, dateStr) in fxDates.enumerated() {
            let parts = dateStr.split(separator: "-")
            var point = FXPoint(label: parts.count == 3 ? "\(parts[2])/\(parts[1])" : dateStr)
            for code in codes {
                guard let v = raw[code]?[i] ?? nil, let b = base[code] ?? nil, b != 0 else { continue }
                let variation = ((v / b) - 1) * 100
                switch code {
                case "USD": point.usd = variation
                case "EUR": point.eur = variation
                case "GBP": point.gbp = variation
                default: break
                }
            }
            points.append(point)
        }
        series = points
        status = .ok
    }

    private static func fetchOne(code: String, date: String) async -> Double? {
        guard let url = URL(string: "https://brasilapi.com.br/api/cambio/v1/cotacao/\(code)/\(date)") else {
            return nil
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let cotacoes = json["cotacoes"] as? [[String: Any]],
                let last = cotacoes.last
            else { return nil }
            if let venda = last["cotacao_venda"] as? Double { return venda }
            if let compra = last["cotacao_compra"] as? Double { return compra }
            return nil
        } catch {
            return nil
        }
    }
}

// MARK: - Selic ao vivo (BCB, série SGS 432 — Meta Selic definida pelo Copom)

@MainActor
private final class BCBSelicLoader: ObservableObject {
    enum Status { case loading, ok, error }

    @Published var status: Status = .loading
    @Published var rate: Double?
    @Published var effectiveDateISO: String?
    @Published var decisionDateBR: String?
    private var didLoad = false

    func loadIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        guard let url = URL(
            string: "https://api.bcb.gov.br/dados/serie/bcdata.sgs.432/dados/ultimos/1?formato=json"
        ) else {
            status = .error
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                status = .error
                return
            }
            guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                let last = arr.last,
                let dataStr = last["data"] as? String,
                let valorStr = last["valor"] as? String,
                let valor = Double(valorStr.replacingOccurrences(of: ",", with: "."))
            else {
                status = .error
                return
            }
            let parts = dataStr.split(separator: "/").compactMap { Int($0) }
            guard parts.count == 3 else {
                status = .error
                return
            }
            rate = valor
            effectiveDateISO = String(format: "%04d-%02d-%02d", parts[2], parts[1], parts[0])
            decisionDateBR = dataStr
            status = .ok
        } catch {
            status = .error
        }
    }
}

// MARK: - Histórico diário da Selic (BCB, série SGS 11 — Selic efetiva % a.d.)

@MainActor
private final class BCBSelicHistoryLoader: ObservableObject {
    enum Status { case idle, loading, ok, error }

    @Published var dailyRates: [String: Double] = [:]
    @Published var status: Status = .idle
    private var loadedKey: String?

    func load(fromISO startISO: String, toISO endISO: String) async {
        guard startISO <= endISO else { return }
        let key = "\(startISO)|\(endISO)"
        guard loadedKey != key else { return }
        loadedKey = key
        status = .loading
        guard let startBR = Self.brDate(fromISO: startISO), let endBR = Self.brDate(fromISO: endISO),
            let url = URL(
                string: "https://api.bcb.gov.br/dados/serie/bcdata.sgs.11/dados?dataInicial=\(startBR)&dataFinal=\(endBR)&formato=json"
            )
        else {
            status = .error
            return
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                status = .error
                return
            }
            guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                status = .error
                return
            }
            var rates: [String: Double] = [:]
            for item in arr {
                guard let dataStr = item["data"] as? String,
                    let valorStr = item["valor"] as? String,
                    let valor = Double(valorStr.replacingOccurrences(of: ",", with: "."))
                else { continue }
                let parts = dataStr.split(separator: "/").compactMap { Int($0) }
                guard parts.count == 3 else { continue }
                let iso = String(format: "%04d-%02d-%02d", parts[2], parts[1], parts[0])
                rates[iso] = valor
            }
            dailyRates = rates
            status = rates.isEmpty ? .error : .ok
        } catch {
            status = .error
        }
    }

    private static func brDate(fromISO iso: String) -> String? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return String(format: "%02d/%02d/%04d", parts[2], parts[1], parts[0])
    }
}

// MARK: - Componentes visuais reutilizáveis

private struct TRCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(.title3, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundColor(TRPalette.ink)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 10)
    }
}

private struct TRField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(TRPalette.inkDim)
            TextField("", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(TRPalette.ink)
                .padding(10)
                .background(TRPalette.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(TRPalette.line, lineWidth: 1))
        }
    }
}

private struct TRDateField: View {
    let label: String
    @Binding var date: Date
    var range: ClosedRange<Date>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(TRPalette.inkDim)
            Group {
                if let range {
                    DatePicker("", selection: $date, in: range, displayedComponents: .date)
                } else {
                    DatePicker("", selection: $date, displayedComponents: .date)
                }
            }
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(TRPalette.gold)
            .padding(6)
            .background(TRPalette.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(TRPalette.line, lineWidth: 1))
        }
    }
}

private struct TRNavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(TRPalette.ink)
            .frame(width: 32, height: 32)
            .background(TRPalette.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(TRPalette.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

private struct TRReceiptRow: View {
    enum Tone { case neutral, pos, neg }

    let key: String
    let value: String
    var tone: Tone = .neutral

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.system(size: 13.5))
                .foregroundColor(TRPalette.paperInkDim)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(TRPalette.paperLine.opacity(0.7)).frame(height: 1)
        }
    }

    private var color: Color {
        switch tone {
        case .neutral: return TRPalette.paperInk
        case .pos: return TRPalette.posGreen
        case .neg: return TRPalette.negRed
        }
    }
}

// MARK: - View principal

struct TesouroReservaView: View {
    @State private var principal: Double = 10000
    @State private var aporteISO: String = "2026-05-04"
    @State private var resgateISO: String = TRDate.iso(trToday)
    @State private var viewMonth: Date = {
        let c = TRDate.calendar.dateComponents([.year, .month], from: trToday)
        return TRDate.date(c.year ?? 2026, c.month ?? 1, 1)
    }()

    @State private var projAug: Double = 14.0
    @State private var projSep: Double = 13.75
    @State private var projNov: Double = 13.5
    @State private var projDec: Double = 13.5

    @State private var pctCDI: Double = 100
    @State private var trMensal: Double = 0.17
    @State private var extraAportes: [ExtraAporte] = []

    @StateObject private var fx = FXLoader()
    @StateObject private var selicLoader = BCBSelicLoader()
    @StateObject private var selicHistory = BCBSelicHistoryLoader()

    private var aporte: Date { TRDate.fromISO(aporteISO) }
    private var resgate: Date { TRDate.fromISO(resgateISO) }

    private var ratePeriods: [RatePeriod] {
        var periods = [
            RatePeriod(from: "2026-01-01", rate: 14.5),
            RatePeriod(from: "2026-06-18", rate: 14.25),
            RatePeriod(from: "2026-08-06", rate: projAug),
            RatePeriod(from: "2026-09-17", rate: projSep),
            RatePeriod(from: "2026-11-05", rate: projNov),
            RatePeriod(from: "2026-12-10", rate: projDec),
        ]
        // Sobrepõe a projeção manual pelo valor oficial assim que o BCB confirma.
        if selicLoader.status == .ok, let rate = selicLoader.rate, let from = selicLoader.effectiveDateISO {
            periods.append(RatePeriod(from: from, rate: rate))
            periods.sort { $0.from < $1.from }
        }
        return periods
    }

    private var extraAportesResolved: [ExtraAporteInput] {
        extraAportes
            .map { ExtraAporteInput(date: TRDate.fromISO($0.dateISO), valor: $0.valor) }
            .filter { $0.date > aporte }
            .sorted { $0.date < $1.date }
    }

    private var engine: TREngine {
        TREngine(
            principal: principal, aporte: aporte, resgate: resgate,
            ratePeriods: ratePeriods, pctCDI: pctCDI, trMensal: trMensal,
            extraAportes: extraAportesResolved
        )
    }

    var body: some View {
        let curve = engine.buildCurve(history: selicHistory.dailyRates)
        let cdbCurve = engine.buildCDBCurve()
        let result = engine.buildResult(curve: curve)
        let compare = engine.buildCompare(result: result, cdbCurve: cdbCurve)
        let evolutionData = engine.buildEvolution(curve: curve, cdbCurve: cdbCurve)
        let yearProjection = engine.buildYearProjection(curve: curve, cdbCurve: cdbCurve)
        let dailyRows = engine.buildDailyRows(curve: curve)
        let best = compare.max(by: { $0.net < $1.net }) ?? compare[0]

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(result: result)
                parametrosCard
                extraAportesCard
                projecaoSelicCard
                extratoCard(result: result)
                comparativoCard(compare: compare, best: best)
                calendarCard(curve: curve)
                evolutionChartCard(data: evolutionData)
                yearProjectionCard(projection: yearProjection)
                dailyTableCard(rows: dailyRows)
                fxCard
                equivalenciasCard
                footerNote
            }
            .padding(16)
        }
        .background(TRPalette.bg.ignoresSafeArea())
        .navigationTitle("Tesouro Reserva")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                styledNavTitle
            }
        }
        .task { await fx.loadIfNeeded() }
        .task { await selicLoader.loadIfNeeded() }
        .task(id: aporteISO) {
            await selicHistory.load(fromISO: aporteISO, toISO: TRDate.iso(trToday))
        }
    }

    private var styledNavTitle: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(TRPalette.goldFill)
                .frame(width: 6, height: 6)
            Text("Tesouro")
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundColor(TRPalette.inkDim)
            Text("Reserva")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(TRPalette.gold)
        }
    }

    private var selicHistoryNote: String {
        switch selicHistory.status {
        case .ok:
            return "· \(selicHistory.dailyRates.count) dias com Selic diária oficial do BCB (série 11)"
        case .loading:
            return "· consultando histórico diário da Selic no BCB…"
        case .error, .idle:
            return "· histórico do BCB indisponível — usando estimativa por período"
        }
    }

    // MARK: Cabeçalho

    private func header(result: ResgateResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TÍTULO PÚBLICO FEDERAL · 100% SELIC · SEM MARCAÇÃO A MERCADO")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundColor(TRPalette.gold)
                .tracking(1.1)

            HStack(spacing: 0) {
                Text("Tesouro Reserva ")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(TRPalette.ink)
                Text("— livro de rendimentos")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .italic()
                    .foregroundColor(TRPalette.gold)
            }

            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(pct(engine.rateAt(resgate))) a.a.")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(TRPalette.mint)
                    Text("SELIC VIGENTE NA DATA DE RESGATE")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(TRPalette.inkDim)
                    selicStatusBadge
                }
            }
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(TRPalette.line).frame(height: 1)
        }
    }

    @ViewBuilder
    private var selicStatusBadge: some View {
        HStack(spacing: 4) {
            switch selicLoader.status {
            case .loading:
                ProgressView().scaleEffect(0.5)
                Text("verificando no Banco Central…")
            case .ok:
                Image(systemName: "checkmark.seal.fill").font(.system(size: 8))
                Text("confirmado no BCB · Copom \(selicLoader.decisionDateBR ?? "")")
            case .error:
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 8))
                Text("BCB indisponível · usando projeção local")
            }
        }
        .font(.system(size: 9))
        .foregroundColor(selicLoader.status == .ok ? TRPalette.mint : TRPalette.inkDim)
    }

    // MARK: Parâmetros

    private var parametrosCard: some View {
        TRCard(title: "Parâmetros do aporte") {
            VStack(alignment: .leading, spacing: 12) {
                TRField(label: "Valor aplicado (R$)", value: $principal)

                HStack(spacing: 12) {
                    TRDateField(
                        label: "Data do aporte",
                        date: Binding(
                            get: { aporte },
                            set: { newDate in
                                let newISO = TRDate.iso(newDate)
                                aporteISO = newISO
                                if newISO >= resgateISO {
                                    resgateISO = TRDate.iso(TRDate.addDays(newDate, 1))
                                }
                            }
                        ),
                        range: TRDate.date(2026, 5, 1)...TRDate.date(2027, 12, 30)
                    )
                    TRDateField(
                        label: "Data do resgate",
                        date: Binding(
                            get: { resgate },
                            set: { resgateISO = TRDate.iso($0) }
                        ),
                        range: aporte...TRDate.date(2027, 12, 31)
                    )
                }

                HStack(spacing: 12) {
                    TRField(label: "CDB — % do CDI", value: $pctCDI)
                    TRField(label: "TR poupança (% a.m.)", value: $trMensal)
                }
            }
        }
    }

    // MARK: Aportes adicionais

    private var extraAportesCard: some View {
        TRCard(title: "Aportes adicionais") {
            VStack(alignment: .leading, spacing: 12) {
                if extraAportes.isEmpty {
                    Text("Fez novas compras do título depois do aporte inicial? Adicione as datas e valores abaixo — cada aporte passa a render a partir do dia seguinte à sua própria data.")
                        .font(.system(size: 11.5))
                        .foregroundColor(TRPalette.inkDim)
                } else {
                    ForEach($extraAportes) { $item in
                        HStack(alignment: .bottom, spacing: 10) {
                            TRDateField(
                                label: "Data",
                                date: Binding(
                                    get: { TRDate.fromISO(item.dateISO) },
                                    set: { item.dateISO = TRDate.iso($0) }
                                ),
                                range: TRDate.addDays(aporte, 1)...TRDate.date(2027, 12, 31)
                            )
                            TRField(label: "Valor (R$)", value: $item.valor)
                            Button {
                                extraAportes.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(TRPalette.red)
                                    .frame(width: 34, height: 34)
                                    .background(TRPalette.panel2)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(TRPalette.line, lineWidth: 1))
                            }
                        }
                    }
                }

                Button {
                    let lastDate = extraAportes
                        .map { TRDate.fromISO($0.dateISO) }
                        .max() ?? aporte
                    let proposed = TRDate.addDays(lastDate, 30)
                    let clamped = min(max(proposed, TRDate.addDays(aporte, 1)), TRDate.date(2027, 12, 31))
                    extraAportes.append(ExtraAporte(dateISO: TRDate.iso(clamped), valor: 1000))
                } label: {
                    Label("Adicionar aporte", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .padding(.vertical, 6)
                .foregroundColor(TRPalette.gold)
            }
        }
    }

    // MARK: Projeção Selic

    private var projecaoSelicCard: some View {
        TRCard(title: "Projeção da Selic — reuniões do Copom") {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    copomField("04–05/ago/2026", value: $projAug)
                    copomField("15–16/set/2026", value: $projSep)
                    copomField("03–04/nov/2026", value: $projNov)
                    copomField("08–09/dez/2026", value: $projDec)
                }
                Text("Histórico real embutido: 14,50% a.a. em maio e corte para 14,25% a.a. no Copom de 17/06/2026 (vigente desde 18/06). As taxas acima são projeções editáveis (padrão ≈ Focus, Selic a 13,50% no fim de 2026), valendo do 1º dia útil após cada reunião.")
                    .font(.system(size: 11.5))
                    .foregroundColor(TRPalette.inkDim)
            }
        }
    }

    private func copomField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(TRPalette.inkDim)
            TextField("", value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(TRPalette.gold)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TRPalette.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(TRPalette.line, style: StrokeStyle(lineWidth: 1, dash: [3]))
        )
    }

    // MARK: Extrato (recibo)

    private func extratoCard(result: ResgateResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Extrato simulado de resgate")
                .font(.system(.subheadline, design: .serif))
                .fontWeight(.semibold)
                .foregroundColor(TRPalette.paperInk)
            Text("\(TRDate.dateBR(aporte)) → \(TRDate.dateBR(resgate)) · \(result.days) dias corridos")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(TRPalette.paperSub)
            Text(selicHistoryNote)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TRPalette.paperSub)
                .padding(.bottom, 8)

            TRReceiptRow(key: "Aporte inicial (\(TRDate.dateBR(aporte)))", value: brl(principal))
            ForEach(extraAportesResolved.filter { $0.date <= resgate }, id: \.date) { extra in
                TRReceiptRow(key: "+ Aporte em \(TRDate.dateBR(extra.date))", value: brl(extra.valor))
            }
            TRReceiptRow(key: "Total aplicado", value: brl(engine.totalContributed(upTo: resgate)))
            TRReceiptRow(key: "Rendimento bruto", value: "+\(brl(result.grossYield))", tone: .pos)
            TRReceiptRow(key: "Valor bruto no resgate", value: brl(result.gross))
            TRReceiptRow(
                key: result.iofP > 0 ? "IOF (\(result.iofP)% do rendimento)" : "IOF (isento após 30 dias)",
                value: result.iof > 0 ? "−\(brl(result.iof))" : brl(0),
                tone: result.iof > 0 ? .neg : .neutral
            )
            TRReceiptRow(
                key: "IR \(pct(result.ir.rate, 1)) · \(result.ir.label)",
                value: "−\(brl(result.irValue))", tone: .neg
            )
            TRReceiptRow(
                key: "Custódia B3 0,20% a.a. (isento até \(brl(trCustodyExemption)))",
                value: result.custody > 0.005 ? "−\(brl(result.custody))" : brl(0),
                tone: result.custody > 0.005 ? .neg : .neutral
            )

            HStack(alignment: .firstTextBaseline) {
                Text("Valor líquido")
                    .font(.system(.subheadline))
                    .fontWeight(.semibold)
                    .foregroundColor(TRPalette.paperInk)
                Spacer()
                Text(brl(result.net))
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(TRPalette.paperInk)
            }
            .padding(.top, 10)
            .overlay(alignment: .top) {
                Rectangle().fill(TRPalette.paperInk).frame(height: 2)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("Ganho líquido no período")
                    .font(.system(size: 13.5))
                    .foregroundColor(TRPalette.paperInkDim)
                Spacer()
                Text("+\(brl(result.netYield))")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(TRPalette.posGreen)
            }
            .padding(.top, 6)

            Text(
                result.ir.next > 0
                    ? "Faltam \(result.ir.next) dias para a próxima faixa de IR."
                    : "Alíquota mínima de IR (15%) já alcançada."
            )
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundColor(TRPalette.paperSub)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 10)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TRPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(TRPalette.paperLine, lineWidth: 1)
                .padding(6)
        )
        .shadow(color: .black.opacity(0.22), radius: 12, y: 8)
    }

    // MARK: Comparativo

    private func comparativoCard(compare: [CompareRow], best: CompareRow) -> some View {
        TRCard(title: "Comparativo líquido no resgate") {
            VStack(spacing: 0) {
                HStack {
                    Text("Aplicação").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Líquido").frame(width: 82, alignment: .trailing)
                    Text("Ganho").frame(width: 72, alignment: .trailing)
                    Text("%").frame(width: 46, alignment: .trailing)
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(TRPalette.inkDim)
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) { Rectangle().fill(TRPalette.line).frame(height: 1) }

                ForEach(compare) { row in
                    let isBest = row.name == best.name
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if isBest {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                            }
                            Text(row.name)
                                .lineLimit(1)
                        }
                        HStack {
                            Text(" ").frame(maxWidth: .infinity, alignment: .leading)
                            Text(brl(row.net)).frame(width: 82, alignment: .trailing)
                            Text("+\(brl(row.gain))").frame(width: 72, alignment: .trailing)
                            Text(pct(row.pctValue)).frame(width: 46, alignment: .trailing)
                        }
                        .font(.system(size: 11.5, design: .monospaced))
                    }
                    .font(.system(size: 12))
                    .foregroundColor(isBest ? TRPalette.mint : TRPalette.ink)
                    .fontWeight(isBest ? .semibold : .regular)
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(TRPalette.line.opacity(0.4)).frame(height: 1)
                    }
                }

                Text(
                    compare.map { "\($0.name): \($0.obs)" }.joined(separator: ". ")
                        + ". A poupança sobe em degraus: entre aniversários o dinheiro não rende nada — por isso ela costuma perder mesmo isenta de IR."
                )
                .font(.system(size: 11.5))
                .foregroundColor(TRPalette.inkDim)
                .padding(.top, 10)
            }
        }
    }

    // MARK: Calendário

    private func calendarGrid(for month: Date) -> [Date?] {
        let cal = TRDate.calendar
        let comps = cal.dateComponents([.year, .month], from: month)
        let first = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1))!
        let firstWeekday = cal.component(.weekday, from: first)
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        let range = cal.range(of: .day, in: .month, for: first) ?? 1..<29
        for day in range {
            cells.append(cal.date(from: DateComponents(year: comps.year, month: comps.month, day: day)))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func monthYield(curve: [String: DayInfo], month: Date) -> Double {
        let cal = TRDate.calendar
        let comps = cal.dateComponents([.year, .month], from: month)
        let range = cal.range(of: .day, in: .month, for: month) ?? 1..<29
        var sum = 0.0
        for day in range {
            let s = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, day)
            if let info = curve[s] { sum += info.dailyYield }
        }
        return sum
    }

    private func monthEndBalance(curve: [String: DayInfo], month: Date) -> Double {
        let cal = TRDate.calendar
        let comps = cal.dateComponents([.year, .month], from: month)
        let range = cal.range(of: .day, in: .month, for: month) ?? 1..<29
        for day in range.reversed() {
            let s = String(format: "%04d-%02d-%02d", comps.year!, comps.month!, day)
            if let info = curve[s] { return info.balance }
        }
        return principal
    }

    private func calendarCard(curve: [String: DayInfo]) -> some View {
        let cal = TRDate.calendar
        let comps = cal.dateComponents([.year, .month], from: viewMonth)
        let monthName = trMonths[(comps.month ?? 1) - 1]
        let year = comps.year ?? 2026
        let cells = calendarGrid(for: viewMonth)
        let canPrev = viewMonth > TRDate.date(2026, 5, 1)
        let canNext = viewMonth < TRDate.date(2027, 12, 1)

        return TRCard(title: "") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 0) {
                        Text(monthName).foregroundColor(TRPalette.ink)
                        Text(verbatim: " \(year)").foregroundColor(TRPalette.gold)
                    }
                        .font(.system(.title3, design: .serif))
                        .fontWeight(.semibold)
                    Spacer()
                    Button {
                        if canPrev { viewMonth = cal.date(byAdding: .month, value: -1, to: viewMonth)! }
                    } label: { Image(systemName: "chevron.left") }
                        .disabled(!canPrev)
                        .buttonStyle(TRNavButtonStyle())

                    Button {
                        if canNext { viewMonth = cal.date(byAdding: .month, value: 1, to: viewMonth)! }
                    } label: { Image(systemName: "chevron.right") }
                        .disabled(!canNext)
                        .buttonStyle(TRNavButtonStyle())
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 5) {
                    ForEach(trWeekdays.indices, id: \.self) { i in
                        Text(trWeekdays[i])
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(TRPalette.inkDim)
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cellDate in
                        calendarCell(cellDate, curve: curve)
                    }
                }

                HStack(spacing: 14) {
                    legendItem(color: TRPalette.goldFill, filled: true, label: "resgate")
                    legendItem(color: TRPalette.goldFill, filled: false, label: "aporte")
                    legendItem(color: TRPalette.mint, filled: false, label: "hoje")
                    Spacer()
                }

                Text("mês: +\(brl(monthYield(curve: curve, month: viewMonth))) · saldo fim do mês: \(brl(monthEndBalance(curve: curve, month: viewMonth)))")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(TRPalette.mint)
            }
        }
    }

    @ViewBuilder
    private func calendarCell(_ date: Date?, curve: [String: DayInfo]) -> some View {
        if let date {
            let s = TRDate.iso(date)
            let info = curve[s]
            let biz = TRDate.isBusinessDay(date)
            let before = date <= aporte
            let isAporte = s == aporteISO || extraAportes.contains { $0.dateISO == s }
            let isResgate = s == resgateISO
            let isToday = s == TRDate.iso(trToday)
            let day = TRDate.calendar.component(.day, from: date)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundColor(isResgate ? TRPalette.paperInk : TRPalette.inkDim)
                if let info, biz, !before, info.dailyYield > 0 {
                    Text("+\(brl4NoSymbol(info.dailyYield))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(isResgate ? TRPalette.paperInk : TRPalette.mint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .topLeading)
            .padding(6)
            .background(isResgate ? TRPalette.goldFill : TRPalette.panel2)
            .opacity(before ? 0.35 : (biz ? 1 : 0.55))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isAporte ? TRPalette.goldFill : (isToday ? TRPalette.mint : TRPalette.line),
                        lineWidth: isToday ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !before && date <= trHorizonEnd { resgateISO = s }
            }
        } else {
            Color.clear.frame(minHeight: 46)
        }
    }

    private func legendItem(color: Color, filled: Bool, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(filled ? color : Color.clear)
                .frame(width: 9, height: 9)
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(color, lineWidth: filled ? 0 : 1))
            Text(label).font(.caption2).foregroundColor(TRPalette.inkDim)
        }
    }

    // MARK: Gráfico de evolução

    private func evolutionChartCard(data: [EvolutionPoint]) -> some View {
        TRCard(title: "Evolução do saldo bruto — Reserva × CDB × Poupança") {
            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    ForEach(data) { p in
                        LineMark(x: .value("Data", p.d), y: .value("Reserva", p.reserva))
                            .foregroundStyle(by: .value("Série", "Reserva"))
                            .interpolationMethod(.monotone)
                    }
                    ForEach(data) { p in
                        LineMark(x: .value("Data", p.d), y: .value("CDB", p.cdb))
                            .foregroundStyle(by: .value("Série", "CDB"))
                            .interpolationMethod(.monotone)
                    }
                    ForEach(data) { p in
                        LineMark(x: .value("Data", p.d), y: .value("Poupança", p.poupanca))
                            .foregroundStyle(by: .value("Série", "Poupança"))
                            .interpolationMethod(.stepEnd)
                    }
                }
                .chartForegroundStyleScale([
                    "Reserva": TRPalette.gold, "CDB": TRPalette.mint, "Poupança": TRPalette.red,
                ])
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine().foregroundStyle(TRPalette.line)
                        AxisValueLabel().foregroundStyle(TRPalette.inkDim)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(TRPalette.line)
                        AxisValueLabel().foregroundStyle(TRPalette.inkDim)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 230)

                Text("Valores brutos, do aporte até o resgate. A escada vermelha é a poupança creditando só nos aniversários mensais.")
                    .font(.system(size: 11.5))
                    .foregroundColor(TRPalette.inkDim)
            }
        }
    }

    // MARK: Projeção de 1 ano

    private func yearProjectionCard(projection: YearProjection) -> some View {
        TRCard(title: "Projeção de 1 ano — Reserva × CDB \(Int(pctCDI))% CDI") {
            VStack(alignment: .leading, spacing: 10) {
                Chart {
                    ForEach(projection.points) { p in
                        LineMark(x: .value("Data", p.d), y: .value("Reserva", p.reserva))
                            .foregroundStyle(by: .value("Série", "Reserva"))
                            .interpolationMethod(.monotone)
                    }
                    ForEach(projection.points) { p in
                        LineMark(x: .value("Data", p.d), y: .value("CDB", p.cdb))
                            .foregroundStyle(by: .value("Série", "CDB"))
                            .interpolationMethod(.monotone)
                    }
                }
                .chartForegroundStyleScale(["Reserva": TRPalette.gold, "CDB": TRPalette.mint])
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine().foregroundStyle(TRPalette.line)
                        AxisValueLabel().foregroundStyle(TRPalette.inkDim)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(TRPalette.line)
                        AxisValueLabel().foregroundStyle(TRPalette.inkDim)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 230)

                VStack(spacing: 0) {
                    HStack {
                        Text("Em \(TRDate.dateBR(projection.end)) (\(projection.days)d)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("Bruto").frame(width: 78, alignment: .trailing)
                        Text("Líquido").frame(width: 78, alignment: .trailing)
                        Text("Ganho").frame(width: 78, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(TRPalette.inkDim)
                    .padding(.bottom, 4)
                    .overlay(alignment: .bottom) { Rectangle().fill(TRPalette.line).frame(height: 1) }

                    projectionRow(
                        "Tesouro Reserva", gross: projection.grossReserva, net: projection.netReserva,
                        gain: projection.netReserva - principal, win: projection.netReserva >= projection.netCDB
                    )
                    projectionRow(
                        "CDB \(Int(pctCDI))% CDI", gross: projection.grossCDB, net: projection.netCDB,
                        gain: projection.netCDB - principal, win: projection.netCDB > projection.netReserva
                    )
                }

                Text("Horizonte fixo de 365 dias a partir do aporte, independente da data de resgate escolhida no calendário, seguindo a trajetória de Selic projetada. No líquido do Reserva já entra a custódia B3 sobre o excedente de R$ 10 mil (\(brl(projection.custody)) no período). Aos 365 dias, a alíquota de IR é 17,5% — a faixa de 15% só chega após 720 dias.")
                    .font(.system(size: 11.5))
                    .foregroundColor(TRPalette.inkDim)
            }
        }
    }

    private func projectionRow(_ name: String, gross: Double, net: Double, gain: Double, win: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if win {
                    Image(systemName: "star.fill").font(.system(size: 9))
                }
                Text(name).font(.system(size: 11.5)).lineLimit(1)
            }
            HStack {
                Text(" ").frame(maxWidth: .infinity, alignment: .leading)
                Text(brl(gross)).frame(width: 78, alignment: .trailing)
                Text(brl(net)).frame(width: 78, alignment: .trailing)
                Text("+\(brl(gain))").frame(width: 78, alignment: .trailing)
            }
            .font(.system(size: 11, design: .monospaced))
        }
        .foregroundColor(win ? TRPalette.mint : TRPalette.ink)
        .fontWeight(win ? .semibold : .regular)
        .padding(.vertical, 5)
    }

    // MARK: Rendimento diário

    private func dailyTableCard(rows: [(date: Date, info: DayInfo)]) -> some View {
        TRCard(title: "Rendimento diário — últimos \(rows.count) dias úteis") {
            VStack(spacing: 0) {
                HStack {
                    Text("Dia útil").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Selic").frame(width: 60, alignment: .trailing)
                    Text("Rend. dia").frame(width: 86, alignment: .trailing)
                    Text("Saldo").frame(width: 86, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(TRPalette.inkDim)
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) { Rectangle().fill(TRPalette.line).frame(height: 1) }

                ScrollView {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack {
                            Text(TRDate.dateBR(row.date)).frame(maxWidth: .infinity, alignment: .leading)
                            Text(pct(row.info.rate)).frame(width: 60, alignment: .trailing)
                            Text("+\(brl4(row.info.dailyYield))")
                                .foregroundColor(TRPalette.mint)
                                .frame(width: 86, alignment: .trailing)
                            Text(brl(row.info.balance)).frame(width: 86, alignment: .trailing)
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(TRPalette.ink)
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(TRPalette.line.opacity(0.4)).frame(height: 1)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }

    // MARK: Câmbio

    private var fxCard: some View {
        TRCard(title: "Câmbio × Real no ano — USD · EUR · GBP") {
            switch fx.status {
            case .loading:
                Text("Buscando série do ano na BrasilAPI…")
                    .font(.system(size: 12))
                    .foregroundColor(TRPalette.inkDim)

            case .ok:
                VStack(alignment: .leading, spacing: 10) {
                    Chart {
                        ForEach(fx.series) { p in
                            if let v = p.usd {
                                LineMark(x: .value("Data", p.label), y: .value("USD", v))
                                    .foregroundStyle(by: .value("Moeda", "USD"))
                            }
                        }
                        ForEach(fx.series) { p in
                            if let v = p.eur {
                                LineMark(x: .value("Data", p.label), y: .value("EUR", v))
                                    .foregroundStyle(by: .value("Moeda", "EUR"))
                            }
                        }
                        ForEach(fx.series) { p in
                            if let v = p.gbp {
                                LineMark(x: .value("Data", p.label), y: .value("GBP", v))
                                    .foregroundStyle(by: .value("Moeda", "GBP"))
                            }
                        }
                        RuleMark(y: .value("Zero", 0))
                            .foregroundStyle(TRPalette.inkDim.opacity(0.6))
                    }
                    .chartForegroundStyleScale([
                        "USD": TRPalette.mint, "EUR": TRPalette.gold, "GBP": TRPalette.red,
                    ])
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(TRPalette.line)
                            AxisValueLabel().foregroundStyle(TRPalette.inkDim)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisGridLine().foregroundStyle(TRPalette.line)
                            AxisValueLabel().foregroundStyle(TRPalette.inkDim)
                        }
                    }
                    .frame(height: 210)

                    Text("Variação % acumulada desde 02/01/2026 (cotação de venda PTAX, BrasilAPI/Banco Central). Linha caindo = real se valorizando frente à moeda.")
                        .font(.system(size: 11.5))
                        .foregroundColor(TRPalette.inkDim)
                }

            case .fallback:
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(fxFallback, id: \.code) { f in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("\(f.name) (\(f.code))")
                                    .font(.system(size: 13))
                                    .fontWeight(.medium)
                                    .foregroundColor(TRPalette.ink)
                                Spacer()
                                Text("R$ \(String(format: "%.2f", f.now).replacingOccurrences(of: ".", with: ","))")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(TRPalette.ink)
                            }
                            Text(f.note)
                                .font(.system(size: 11))
                                .foregroundColor(TRPalette.inkDim)
                        }
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(TRPalette.line.opacity(0.4)).frame(height: 1)
                        }
                    }
                    Text("Não foi possível carregar a série do ano na BrasilAPI agora. Os valores acima são checkpoints verificados em 02/07/2026, usados como referência quando a chamada externa falha.")
                        .font(.system(size: 11.5))
                        .foregroundColor(TRPalette.inkDim)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: Equivalências

    private var equivalenciasCard: some View {
        let selic = engine.rateAt(resgate)
        let dailyFactor = (pow(1 + selic / 100, 1.0 / 252) - 1) * 100
        let monthEquiv = (pow(1 + selic / 100, 21.0 / 252) - 1) * 100
        return TRCard(title: "Equivalências na data de resgate") {
            VStack(spacing: 0) {
                equivRow("Selic vigente", "\(pct(selic)) a.a.")
                equivRow("Fator por dia útil", String(format: "%.4f", dailyFactor).replacingOccurrences(of: ".", with: ",") + "%")
                equivRow("Equivalente mensal (~21 d.u.)", pct(monthEquiv))
                equivRow("Sobre \(brl(principal)) / mês (bruto)", "≈ \(brl(principal * monthEquiv / 100))")
            }
        }
    }

    private func equivRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).frame(maxWidth: .infinity, alignment: .leading)
            Text(v).font(.system(.body, design: .monospaced))
        }
        .font(.system(size: 13))
        .foregroundColor(TRPalette.ink)
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(TRPalette.line.opacity(0.4)).frame(height: 1)
        }
    }

    // MARK: Rodapé

    private var footerNote: some View {
        Text("Capitalização composta por dia útil (base 252) a partir do 1º dia útil após o aporte, sem marcação a mercado — o resgate vale sempre o aplicado + rendimentos acumulados. Feriados nacionais/B3 de 2026–2027 descontados. Custódia B3 de 0,20% a.a. pro-rata apenas sobre o que exceder R$ 10.000,00. CDB modelado com CDI ≈ Selic − 0,10 p.p. e mesma tributação; poupança com 0,5% a.m. + TR, crédito no aniversário, isenta de IR. Câmbio via BrasilAPI (PTAX/Banco Central) quando disponível. Simulação educativa com taxas futuras projetadas — não é recomendação de investimento.")
            .font(.system(size: 11))
            .foregroundColor(TRPalette.inkDim)
            .padding(.top, 6)
    }
}

#Preview {
    TesouroReservaView()
}
