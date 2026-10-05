import Foundation

// MARK: - Cargo

/// Cargos das Eleições Gerais 2026 (1º turno) e as regras de URL do JSON oficial do TSE.
enum ApuracaoCargo: String, CaseIterable, Identifiable, Sendable {
    case presidente, governador, senador, depFederal, depEstadual, depDistrital

    var id: String { rawValue }

    /// Cargos oferecidos no seletor. O Distrital entra sozinho quando o DF é escolhido com Estadual.
    static let selecionaveis: [ApuracaoCargo] = [.presidente, .governador, .senador, .depFederal, .depEstadual]

    var codigo: String {
        switch self {
        case .presidente: "0001"
        case .governador: "0003"
        case .senador: "0005"
        case .depFederal: "0006"
        case .depEstadual: "0007"
        case .depDistrital: "0008"
        }
    }

    var eleicao: String { self == .presidente ? "6257" : "6259" }

    var titulo: String {
        switch self {
        case .presidente: "Presidente"
        case .governador: "Governador"
        case .senador: "Senador"
        case .depFederal: "Deputado Federal"
        case .depEstadual: "Deputado Estadual"
        case .depDistrital: "Deputado Distrital"
        }
    }

    var isProporcional: Bool { self == .depFederal || self == .depEstadual || self == .depDistrital }

    /// Majoritários mudam rápido e são leves; deputados têm arquivos de ~300 KB.
    var intervalo: Duration { isProporcional ? .seconds(60) : .seconds(20) }

    func aceita(uf: String) -> Bool {
        switch self {
        case .presidente: uf == "br" || ApuracaoUF.siglas.contains(uf)
        case .depEstadual: uf != "df" && ApuracaoUF.siglas.contains(uf)
        case .depDistrital: uf == "df"
        default: ApuracaoUF.siglas.contains(uf)
        }
    }

    /// Cargo realmente consultado: Estadual no DF vira Distrital.
    static func efetivo(_ cargo: ApuracaoCargo, uf: String) -> ApuracaoCargo {
        cargo == .depEstadual && uf == "df" ? .depDistrital : cargo
    }

    /// Ajusta combinações que não existem no TSE (ex.: Brasil fora de Presidente).
    static func normalizar(_ cargo: ApuracaoCargo, uf: String) -> (cargo: ApuracaoCargo, uf: String) {
        let cargo = cargo == .depDistrital ? .depEstadual : cargo
        var uf = uf.lowercased()
        if uf == "br" && cargo != .presidente { uf = "sp" }
        if uf != "br" && !ApuracaoUF.siglas.contains(uf) { uf = cargo == .presidente ? "br" : "sp" }
        return (cargo, uf)
    }

    static let baseURL = "https://eleicoes.meulab.fun/tse/oficial/ele2026"

    func url(uf: String) -> URL? {
        let cargo = ApuracaoCargo.efetivo(self, uf: uf)
        guard cargo.aceita(uf: uf) else { return nil }
        let eleicao6 = String(repeating: "0", count: max(0, 6 - cargo.eleicao.count)) + cargo.eleicao
        return URL(string: "\(Self.baseURL)/\(cargo.eleicao)/dados/\(uf)/\(uf)-c\(cargo.codigo)-e\(eleicao6)-u.json")
    }
}

enum ApuracaoUF {
    static let todas: [(sigla: String, nome: String)] = [
        ("ac", "Acre"), ("al", "Alagoas"), ("ap", "Amapá"), ("am", "Amazonas"), ("ba", "Bahia"),
        ("ce", "Ceará"), ("df", "Distrito Federal"), ("es", "Espírito Santo"), ("go", "Goiás"),
        ("ma", "Maranhão"), ("mt", "Mato Grosso"), ("ms", "Mato Grosso do Sul"), ("mg", "Minas Gerais"),
        ("pa", "Pará"), ("pb", "Paraíba"), ("pr", "Paraná"), ("pe", "Pernambuco"), ("pi", "Piauí"),
        ("rj", "Rio de Janeiro"), ("rn", "Rio Grande do Norte"), ("rs", "Rio Grande do Sul"),
        ("ro", "Rondônia"), ("rr", "Roraima"), ("sc", "Santa Catarina"), ("sp", "São Paulo"),
        ("se", "Sergipe"), ("to", "Tocantins"),
    ]
    static let siglas = Set(todas.map(\.sigla))

    static func nome(_ sigla: String) -> String {
        sigla == "br" ? "Brasil" : todas.first { $0.sigla == sigla }?.nome ?? sigla.uppercased()
    }
}

// MARK: - Decodificação tolerante

/// O TSE manda números como String, com vírgula decimal. Campo ausente ou vazio vira 0/"".
private extension KeyedDecodingContainer {
    func tseString(_ key: Key) -> String {
        if let s = try? decodeIfPresent(String.self, forKey: key) { return s }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return String(i) }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return String(d) }
        return ""
    }

    func tseInt(_ key: Key) -> Int {
        Int(tseString(key).trimmingCharacters(in: .whitespaces)) ?? 0
    }

    func tseDouble(_ key: Key) -> Double {
        Double(tseString(key).replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0
    }

    func tseArray<T: Decodable>(_ key: Key) -> [T] {
        (try? decodeIfPresent([T].self, forKey: key)) ?? []
    }
}

// MARK: - JSON do TSE

struct TSEResultado: Decodable, Sendable {
    let dg: String
    let hg: String
    let s: TSESecoes
    let e: TSEEleitorado
    let v: TSEVotos
    let carg: [TSECargo]

    enum CodingKeys: String, CodingKey { case dg, hg, s, e, v, carg }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dg = c.tseString(.dg)
        hg = c.tseString(.hg)
        s = (try? c.decodeIfPresent(TSESecoes.self, forKey: .s)) ?? .vazio
        e = (try? c.decodeIfPresent(TSEEleitorado.self, forKey: .e)) ?? .vazio
        v = (try? c.decodeIfPresent(TSEVotos.self, forKey: .v)) ?? .vazio
        carg = c.tseArray(.carg)
    }
}

struct TSESecoes: Decodable, Sendable, Equatable {
    let st: Int
    let ts: Int
    let pst: Double

    static let vazio = TSESecoes(st: 0, ts: 0, pst: 0)

    init(st: Int, ts: Int, pst: Double) {
        self.st = st
        self.ts = ts
        self.pst = pst
    }

    enum CodingKeys: String, CodingKey { case st, ts, pst }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        st = c.tseInt(.st)
        ts = c.tseInt(.ts)
        pst = c.tseDouble(.pst)
    }
}

struct TSEEleitorado: Decodable, Sendable {
    let te: Int

    static let vazio = TSEEleitorado(te: 0)

    init(te: Int) { self.te = te }

    enum CodingKeys: String, CodingKey { case te }

    init(from decoder: Decoder) throws {
        te = try decoder.container(keyedBy: CodingKeys.self).tseInt(.te)
    }
}

struct TSEVotos: Decodable, Sendable, Equatable {
    let vv: Int
    let vb: Int
    let tvn: Int
    let van: Int
    let pvv: Double
    let pvb: Double
    let ptvn: Double

    static let vazio = TSEVotos(vv: 0, vb: 0, tvn: 0, van: 0, pvv: 0, pvb: 0, ptvn: 0)

    init(vv: Int, vb: Int, tvn: Int, van: Int, pvv: Double, pvb: Double, ptvn: Double) {
        self.vv = vv
        self.vb = vb
        self.tvn = tvn
        self.van = van
        self.pvv = pvv
        self.pvb = pvb
        self.ptvn = ptvn
    }

    enum CodingKeys: String, CodingKey { case vv, vb, tvn, van, pvv, pvb, ptvn }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        vv = c.tseInt(.vv)
        vb = c.tseInt(.vb)
        tvn = c.tseInt(.tvn)
        van = c.tseInt(.van)
        pvv = c.tseDouble(.pvv)
        pvb = c.tseDouble(.pvb)
        ptvn = c.tseDouble(.ptvn)
    }
}

struct TSECargo: Decodable, Sendable {
    let nmn: String
    let nv: Int
    let agr: [TSEAgrupamento]

    enum CodingKeys: String, CodingKey { case nmn, nv, agr }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nmn = c.tseString(.nmn)
        nv = c.tseInt(.nv)
        agr = c.tseArray(.agr)
    }
}

struct TSEAgrupamento: Decodable, Sendable {
    let n: String
    let nm: String
    let com: String
    let vag: Int
    let par: [TSEPartido]

    enum CodingKeys: String, CodingKey { case n, nm, com, vag, par }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        n = c.tseString(.n)
        nm = c.tseString(.nm)
        com = c.tseString(.com)
        vag = c.tseInt(.vag)
        par = c.tseArray(.par)
    }
}

struct TSEPartido: Decodable, Sendable {
    let n: String
    let sg: String
    let nm: String
    let tvan: Int
    let cand: [TSECandidato]

    enum CodingKeys: String, CodingKey { case n, sg, nm, tvan, cand }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        n = c.tseString(.n)
        sg = c.tseString(.sg)
        nm = c.tseString(.nm)
        tvan = c.tseInt(.tvan)
        cand = c.tseArray(.cand)
    }
}

struct TSECandidato: Decodable, Sendable {
    let n: String
    let sqcand: String
    let nmu: String
    let seq: Int
    let vap: Int
    let pvap: Double
    let st: String
    let e: String
    let vs: [TSEVice]

    enum CodingKeys: String, CodingKey { case n, sqcand, nmu, seq, vap, pvap, st, e, vs }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        n = c.tseString(.n)
        sqcand = c.tseString(.sqcand)
        nmu = c.tseString(.nmu)
        seq = c.tseInt(.seq)
        vap = c.tseInt(.vap)
        pvap = c.tseDouble(.pvap)
        st = c.tseString(.st)
        e = c.tseString(.e)
        vs = c.tseArray(.vs)
    }
}

struct TSEVice: Decodable, Sendable, Equatable {
    let tp: String
    let nmu: String
    let sgp: String

    enum CodingKeys: String, CodingKey { case tp, nmu, sgp }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tp = c.tseString(.tp)
        nmu = c.tseString(.nmu)
        sgp = c.tseString(.sgp)
    }
}

// MARK: - Snapshot pronto para a tela

struct ApuracaoCandidato: Identifiable, Sendable, Equatable {
    let id: String
    let posicao: Int
    let numero: String
    let nomeUrna: String
    /// Nome de urna sem acento e em minúsculas, calculado uma vez no decode para a busca.
    let nomeBusca: String
    let partido: String
    let votos: Int
    let percentual: Double
    /// Situação dada pelo TSE. Nunca calculada no app.
    let situacao: String
    let eleitoFlag: Bool
    let vices: [TSEVice]

    enum Selo: Equatable {
        case eleito(String)
        case segundoTurno
    }

    var selo: Selo? {
        let st = situacao.lowercased()
        if st.contains("2º turno") || st.contains("2o turno") { return .segundoTurno }
        if eleitoFlag || (st.hasPrefix("eleito")) { return .eleito(situacao.isEmpty ? "Eleito" : situacao) }
        return nil
    }

    var isEleito: Bool {
        if case .eleito = selo { return true }
        return false
    }

    static func chaveBusca(_ texto: String) -> String {
        texto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_BR"))
    }

    /// Busca por nome (sem acento) ou prefixo do número, e filtro "Só eleitos" pela situação do TSE.
    /// Mantém a ordem e a posição originais.
    static func filtrar(_ candidatos: [ApuracaoCandidato], busca: String, soEleitos: Bool) -> [ApuracaoCandidato] {
        let termo = busca.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !termo.isEmpty || soEleitos else { return candidatos }
        let chave = chaveBusca(termo)
        return candidatos.filter { c in
            (!soEleitos || c.isEleito)
                && (chave.isEmpty || c.numero.hasPrefix(termo) || c.nomeBusca.contains(chave))
        }
    }
}

struct ApuracaoVagas: Identifiable, Sendable, Equatable {
    let id: String
    let nome: String
    let composicao: String
    let vagas: Int
}

struct ApuracaoSnapshot: Sendable, Equatable {
    let url: URL
    let cargoNome: String
    let vagas: Int
    let data: String
    let hora: String
    let secoesTotalizadas: Int
    let secoesTotal: Int
    let percentualSecoes: Double
    let eleitores: Int
    let votos: TSEVotos
    /// Ordenados por votos, decrescente.
    let candidatos: [ApuracaoCandidato]
    /// Só agrupamentos com vagas > 0, ordenados por vagas.
    let vagasPorAgrupamento: [ApuracaoVagas]

    static let mensagemAntesDoInicio = "Apuração começa às 17h (horário de Brasília)"

    /// Antes das 17h os arquivos existem zerados (pst "0,00", vap "0").
    var apuracaoIniciada: Bool {
        secoesTotalizadas > 0 || percentualSecoes > 0 || votos.vv > 0 || candidatos.contains { $0.votos > 0 }
    }

    static func decodificar(_ data: Data, url: URL) throws -> ApuracaoSnapshot {
        let r = try JSONDecoder().decode(TSEResultado.self, from: data)
        let cargo = r.carg.first

        var linhas: [(TSECandidato, String)] = []
        for agr in cargo?.agr ?? [] {
            for par in agr.par {
                for cand in par.cand { linhas.append((cand, par.sg)) }
            }
        }
        linhas.sort {
            $0.0.vap != $1.0.vap
                ? $0.0.vap > $1.0.vap
                : $0.0.nmu.localizedStandardCompare($1.0.nmu) == .orderedAscending
        }
        let candidatos = linhas.enumerated().map { index, item in
            let (c, partido) = item
            return ApuracaoCandidato(
                id: c.sqcand.isEmpty ? "\(partido)-\(c.n)-\(index)" : c.sqcand,
                posicao: index + 1,
                numero: c.n,
                nomeUrna: c.nmu,
                nomeBusca: ApuracaoCandidato.chaveBusca(c.nmu),
                partido: partido,
                votos: c.vap,
                percentual: c.pvap,
                situacao: c.st,
                eleitoFlag: c.e.lowercased() == "s",
                vices: c.vs
            )
        }

        let vagas = (cargo?.agr ?? [])
            .filter { $0.vag > 0 }
            .map { ApuracaoVagas(id: $0.n.isEmpty ? $0.nm : $0.n, nome: $0.nm, composicao: $0.com, vagas: $0.vag) }
            .sorted { $0.vagas != $1.vagas ? $0.vagas > $1.vagas : $0.nome < $1.nome }

        return ApuracaoSnapshot(
            url: url,
            cargoNome: cargo?.nmn ?? "",
            vagas: cargo?.nv ?? 0,
            data: r.dg,
            hora: r.hg,
            secoesTotalizadas: r.s.st,
            secoesTotal: r.s.ts,
            percentualSecoes: r.s.pst,
            eleitores: r.e.te,
            votos: r.v,
            candidatos: candidatos,
            vagasPorAgrupamento: vagas
        )
    }
}

// MARK: - Formatação pt-BR

enum ApuracaoFormato {
    private static let ptBR = Locale(identifier: "pt_BR")

    static func votos(_ n: Int) -> String {
        n.formatted(.number.locale(ptBR))
    }

    static func percentual(_ p: Double) -> String {
        p.formatted(.number.precision(.fractionLength(2)).locale(ptBR)) + "%"
    }
}
