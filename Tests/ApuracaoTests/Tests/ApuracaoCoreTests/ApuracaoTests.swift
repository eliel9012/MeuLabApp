import Foundation
import Testing

@testable import ApuracaoCore

// MARK: - Helpers

private func fixture(_ nome: String) throws -> Data {
    let url = try #require(
        Bundle.module.url(forResource: nome, withExtension: "json", subdirectory: "Fixtures"),
        "Fixture \(nome).json ausente")
    return try Data(contentsOf: url)
}

private let urlFicticia = URL(string: "https://example.invalid/teste.json")!

private func decodificar(_ json: String) throws -> ApuracaoSnapshot {
    try ApuracaoSnapshot.decodificar(Data(json.utf8), url: urlFicticia)
}

// MARK: - 1. Decode dos JSONs reais (espelho do TSE, zerados antes de domingo)

@Suite("Decode dos arquivos reais do TSE")
struct DecodeReais {
    static let arquivos: [(arquivo: String, cargo: String, minimoCandidatos: Int)] = [
        ("br-c0001-e006257-u", "Presidente", 2),
        ("sp-c0001-e006257-u", "Presidente", 2),
        ("sp-c0003-e006259-u", "Governador", 2),
        ("sp-c0005-e006259-u", "Senador", 2),
        ("sp-c0006-e006259-u", "Deputado Federal", 1000),
        ("sp-c0007-e006259-u", "Deputado Estadual", 1000),
        ("df-c0008-e006259-u", "Deputado Distrital", 100),
    ]

    @Test("Decodifica sem erro e acha o cargo e os candidatos", arguments: arquivos)
    func decodifica(_ caso: (arquivo: String, cargo: String, minimoCandidatos: Int)) throws {
        let s = try ApuracaoSnapshot.decodificar(fixture(caso.arquivo), url: urlFicticia)
        #expect(s.cargoNome == caso.cargo)
        #expect(s.candidatos.count >= caso.minimoCandidatos)
        #expect(s.vagas > 0)
        #expect(s.secoesTotal > 0)
        #expect(!s.hora.isEmpty && !s.data.isEmpty)
        #expect(s.candidatos.allSatisfy { !$0.nomeUrna.isEmpty && !$0.partido.isEmpty && !$0.numero.isEmpty })
        // IDs únicos: a List do SwiftUI depende disso.
        #expect(Set(s.candidatos.map(\.id)).count == s.candidatos.count)
        // Posições sequenciais após ordenar.
        #expect(s.candidatos.map(\.posicao) == Array(1...s.candidatos.count))
    }

    @Test("Arquivos de hoje estão zerados e a tela mostra o aviso das 17h", arguments: arquivos.map(\.arquivo))
    func zerado(_ arquivo: String) throws {
        let s = try ApuracaoSnapshot.decodificar(fixture(arquivo), url: urlFicticia)
        #expect(s.percentualSecoes == 0)
        #expect(s.apuracaoIniciada == false)
        #expect(ApuracaoSnapshot.mensagemAntesDoInicio == "Apuração começa às 17h (horário de Brasília)")
    }

    @Test("Senador 2026 tem 2 vagas; Dep. Federal SP tem 70")
    func vagas() throws {
        #expect(try ApuracaoSnapshot.decodificar(fixture("sp-c0005-e006259-u"), url: urlFicticia).vagas == 2)
        #expect(try ApuracaoSnapshot.decodificar(fixture("sp-c0006-e006259-u"), url: urlFicticia).vagas == 70)
    }

    @Test("Suplentes de senador e vice vêm de vs")
    func vices() throws {
        let senado = try ApuracaoSnapshot.decodificar(fixture("sp-c0005-e006259-u"), url: urlFicticia)
        #expect(senado.candidatos.contains { $0.vices.contains { $0.tp == "s1" } })
        let presidente = try ApuracaoSnapshot.decodificar(fixture("br-c0001-e006257-u"), url: urlFicticia)
        #expect(presidente.candidatos.contains { $0.vices.contains { $0.tp == "v" } })
    }
}

// MARK: - 1b. JSON com campos vazios ou ausentes (números fictícios, só no teste)

@Suite("Decode tolerante")
struct DecodeTolerante {
    @Test("Campos vazios e ausentes não quebram o decode")
    func camposFaltando() throws {
        let s = try decodificar("""
            {"dg":"","s":{"pst":""},"v":{},"carg":[{"nmn":"Senador","agr":[{"par":[{"sg":"XX",
            "cand":[{"n":"123","nmu":"TESTE","st":"","vap":"","pvap":""},{"nmu":"SEM NUMERO"}]}]}]}]}
            """)
        #expect(s.cargoNome == "Senador")
        #expect(s.vagas == 0)
        #expect(s.hora == "" && s.data == "")
        #expect(s.eleitores == 0)
        #expect(s.votos == .vazio)
        #expect(s.candidatos.count == 2)
        #expect(s.candidatos.allSatisfy { $0.vices.isEmpty && $0.votos == 0 && $0.selo == nil })
        #expect(s.apuracaoIniciada == false)
    }

    @Test("JSON sem carg, s, e, v vira snapshot vazio")
    func objetoVazio() throws {
        let s = try decodificar("{}")
        #expect(s.candidatos.isEmpty && s.vagasPorAgrupamento.isEmpty)
        #expect(s.apuracaoIniciada == false)
    }

    @Test("Números como String com vírgula decimal e também como número JSON")
    func conversaoNumerica() throws {
        let s = try decodificar("""
            {"s":{"st":"10","ts":"20","pst":"45,23"},"e":{"te":1000},
             "v":{"vv":"12345678","pvv":"93,10","vb":"5","pvb":"1,5","tvn":"7","ptvn":"0,25"},
             "carg":[{"nmn":"Presidente","nv":"1","agr":[{"par":[{"sg":"XX","cand":[
               {"n":"10","sqcand":"1","nmu":"A","vap":"12345678","pvap":"45,23"}]}]}]}]}
            """)
        #expect(s.percentualSecoes == 45.23)
        #expect(s.secoesTotalizadas == 10 && s.secoesTotal == 20)
        #expect(s.eleitores == 1000)
        #expect(s.votos.vv == 12_345_678 && s.votos.pvv == 93.10)
        #expect(s.candidatos.first?.votos == 12_345_678)
        #expect(s.candidatos.first?.percentual == 45.23)
        #expect(s.apuracaoIniciada)
    }

    @Test("Só 0,01% apurado já conta como iniciada")
    func detectaInicio() throws {
        #expect(try decodificar(#"{"s":{"pst":"0,01"}}"#).apuracaoIniciada)
        #expect(try decodificar(#"{"s":{"pst":"0,00"}}"#).apuracaoIniciada == false)
    }

    @Test("Selo segue só st/e do TSE", arguments: [
        ("Eleito", "n", "eleito"),
        ("Eleito por QP", "n", "eleito"),
        ("Eleito por média", "n", "eleito"),
        ("2º turno", "n", "2turno"),
        ("", "s", "eleito"),
        ("Suplente", "n", "nenhum"),
        ("Não eleito", "n", "nenhum"),
        ("", "n", "nenhum"),
    ])
    func selo(_ caso: (st: String, e: String, esperado: String)) throws {
        let s = try decodificar("""
            {"carg":[{"agr":[{"par":[{"sg":"XX","cand":[{"n":"1","nmu":"A","st":"\(caso.st)","e":"\(caso.e)"}]}]}]}]}
            """)
        let selo = try #require(s.candidatos.first).selo
        switch caso.esperado {
        case "eleito":
            guard case .eleito = selo else { Issue.record("esperava eleito, veio \(String(describing: selo))"); return }
        case "2turno": #expect(selo == .segundoTurno)
        default: #expect(selo == nil)
        }
    }

    @Test("Ordena por votos decrescente e só lista agrupamentos com vagas")
    func ordenacaoEVagas() throws {
        let s = try decodificar("""
            {"carg":[{"agr":[
              {"n":"1","nm":"A","vag":"0","par":[{"sg":"PA","cand":[{"n":"11","sqcand":"1","nmu":"POUCO","vap":"5"}]}]},
              {"n":"2","nm":"B","vag":"3","par":[{"sg":"PB","cand":[{"n":"22","sqcand":"2","nmu":"MUITO","vap":"50"}]}]},
              {"n":"3","nm":"C","vag":"7","par":[]}]}]}
            """)
        #expect(s.candidatos.map(\.nomeUrna) == ["MUITO", "POUCO"])
        #expect(s.candidatos.map(\.partido) == ["PB", "PA"])
        #expect(s.vagasPorAgrupamento.map(\.nome) == ["C", "B"])
    }
}

// MARK: - 2. URLs

@Suite("Montagem de URL")
struct URLs {
    static let ufs = ApuracaoUF.todas.map(\.sigla)

    /// Todas as combinações válidas, como o seletor permite.
    static var combinacoesValidas: [(ApuracaoCargo, String)] {
        var r: [(ApuracaoCargo, String)] = [(.presidente, "br")]
        r += ufs.map { (.presidente, $0) }
        for cargo in [ApuracaoCargo.governador, .senador, .depFederal] { r += ufs.map { (cargo, $0) } }
        r += ufs.filter { $0 != "df" }.map { (.depEstadual, $0) }
        r.append((.depDistrital, "df"))
        return r
    }

    @Test("27 UFs")
    func vinteESeteUFs() {
        #expect(Self.ufs.count == 27)
        #expect(Set(Self.ufs).count == 27)
    }

    @Test("Todas as 136 combinações válidas geram URL no formato do espelho")
    func todasValidas() throws {
        let combos = Self.combinacoesValidas
        #expect(combos.count == 136)
        let padrao = #/^https://eleicoes\.meulab\.fun/tse/oficial/ele2026/(6257|6259)/dados/([a-z]{2})/\2-c(\d{4})-e00(6257|6259)-u\.json$/#
        for (cargo, uf) in combos {
            let url = try #require(cargo.url(uf: uf), "\(cargo) \(uf) sem URL")
            let m = try #require(url.absoluteString.wholeMatch(of: padrao), "formato: \(url)")
            #expect(String(m.output.1) == cargo.eleicao && String(m.output.4) == cargo.eleicao)
            #expect(String(m.output.2) == uf)
            #expect(String(m.output.3) == cargo.codigo)
        }
    }

    @Test("Exemplos do enunciado")
    func exemplos() {
        let base = "https://eleicoes.meulab.fun/tse/oficial/ele2026"
        #expect(ApuracaoCargo.presidente.url(uf: "br")?.absoluteString == "\(base)/6257/dados/br/br-c0001-e006257-u.json")
        #expect(ApuracaoCargo.presidente.url(uf: "sp")?.absoluteString == "\(base)/6257/dados/sp/sp-c0001-e006257-u.json")
        #expect(ApuracaoCargo.governador.url(uf: "sp")?.absoluteString == "\(base)/6259/dados/sp/sp-c0003-e006259-u.json")
        #expect(ApuracaoCargo.senador.url(uf: "sp")?.absoluteString == "\(base)/6259/dados/sp/sp-c0005-e006259-u.json")
        #expect(ApuracaoCargo.depFederal.url(uf: "sp")?.absoluteString == "\(base)/6259/dados/sp/sp-c0006-e006259-u.json")
        #expect(ApuracaoCargo.depDistrital.url(uf: "df")?.absoluteString == "\(base)/6259/dados/df/df-c0008-e006259-u.json")
    }

    @Test("Brasil só existe para Presidente")
    func brasilSoPresidente() {
        for cargo in ApuracaoCargo.allCases where cargo != .presidente {
            #expect(cargo.url(uf: "br") == nil, "\(cargo) não pode ter br")
            #expect(cargo.aceita(uf: "br") == false)
            #expect(ApuracaoCargo.normalizar(cargo, uf: "br").uf != "br")
        }
        #expect(ApuracaoCargo.normalizar(.presidente, uf: "br").uf == "br")
    }

    @Test("Deputado Estadual + DF vira Distrital (c0008)")
    func estadualDFViraDistrital() throws {
        #expect(ApuracaoCargo.efetivo(.depEstadual, uf: "df") == .depDistrital)
        let url = try #require(ApuracaoCargo.depEstadual.url(uf: "df"))
        #expect(url.lastPathComponent == "df-c0008-e006259-u.json")
        #expect(ApuracaoCargo.efetivo(.depEstadual, uf: "sp") == .depEstadual)
    }

    @Test("Combinações inexistentes não geram URL")
    func invalidas() {
        #expect(ApuracaoCargo.depDistrital.url(uf: "sp") == nil)
        #expect(ApuracaoCargo.governador.url(uf: "br") == nil)
        #expect(ApuracaoCargo.senador.url(uf: "xx") == nil)
    }

    @Test("Intervalos: 20 s majoritários, 60 s deputados")
    func intervalos() {
        for cargo in [ApuracaoCargo.presidente, .governador, .senador] { #expect(cargo.intervalo == .seconds(20)) }
        for cargo in [ApuracaoCargo.depFederal, .depEstadual, .depDistrital] { #expect(cargo.intervalo == .seconds(60)) }
    }
}

// MARK: - 4. Busca e filtro sobre a lista já processada

@Suite("Busca e filtro de deputados")
struct Filtro {
    @Test("Federal SP (>1.000 candidatos): busca por número, nome sem acento e Só eleitos")
    func federalSP() throws {
        let s = try ApuracaoSnapshot.decodificar(fixture("sp-c0006-e006259-u"), url: urlFicticia)
        #expect(s.candidatos.count > 1000)
        let alvo = try #require(s.candidatos.first { $0.nomeUrna.contains { "ÁÉÍÓÚÂÊÔÃÕÇ".contains($0) } })

        let porNumero = ApuracaoCandidato.filtrar(s.candidatos, busca: alvo.numero, soEleitos: false)
        #expect(porNumero.contains(alvo))
        #expect(porNumero.allSatisfy { $0.numero.hasPrefix(alvo.numero) || $0.nomeBusca.contains(alvo.numero) })

        let semAcento = alvo.nomeUrna.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        #expect(ApuracaoCandidato.filtrar(s.candidatos, busca: semAcento, soEleitos: false).contains(alvo))

        // Antes da apuração ninguém tem situação de eleito.
        #expect(ApuracaoCandidato.filtrar(s.candidatos, busca: "", soEleitos: true).isEmpty)
        // Sem busca e sem filtro devolve a mesma lista, na mesma ordem.
        #expect(ApuracaoCandidato.filtrar(s.candidatos, busca: "  ", soEleitos: false) == s.candidatos)
    }

    @Test("Filtro mantém posição original")
    func mantemPosicao() throws {
        let s = try ApuracaoSnapshot.decodificar(fixture("df-c0008-e006259-u"), url: urlFicticia)
        let ultimo = try #require(s.candidatos.last)
        let r = ApuracaoCandidato.filtrar(s.candidatos, busca: ultimo.numero, soEleitos: false)
        #expect(r.first { $0.id == ultimo.id }?.posicao == s.candidatos.count)
    }
}

// MARK: - 3. ViewModel: filtro e ciclo de vida do polling

@Suite("ViewModel")
@MainActor
struct ViewModelTests {
    @Test("ViewModel filtra uma vez por mudança de busca/filtro")
    func filtraNoViewModel() throws {
        let s = try ApuracaoSnapshot.decodificar(fixture("sp-c0006-e006259-u"), url: urlFicticia)
        let vm = ApuracaoViewModel(preview: s, cargo: .depFederal, uf: "sp")
        #expect(vm.candidatosFiltrados.count == s.candidatos.count)
        let alvo = s.candidatos[500]
        vm.busca = alvo.numero
        #expect(vm.candidatosFiltrados.contains(alvo))
        #expect(vm.candidatosFiltrados.count < s.candidatos.count)
        vm.busca = ""
        vm.soEleitos = true
        #expect(vm.candidatosFiltrados.isEmpty)
    }

    @Test("Polling para ao sair e reinicia ao trocar cargo/UF, zerando a tela")
    func cicloDeVida() {
        let vm = ApuracaoViewModel(cargo: .presidente, uf: "br")
        #expect(vm.pollingEmExecucao == false)
        vm.iniciar()
        #expect(vm.pollingEmExecucao)
        vm.busca = "abc"
        vm.selecionar(cargo: .depEstadual, uf: "df")
        #expect(vm.cargoEfetivo == .depDistrital)
        #expect(vm.busca == "" && vm.snapshot == nil)
        #expect(vm.pollingEmExecucao, "troca de cargo reinicia o polling")
        vm.parar()
        #expect(vm.pollingEmExecucao == false)
        // Trocar com o polling parado não religa sozinho.
        vm.selecionar(cargo: .senador, uf: "rj")
        #expect(vm.pollingEmExecucao == false)
    }

    @Test("Trocar para cargo sem Brasil move a UF")
    func normalizaUF() {
        let vm = ApuracaoViewModel(cargo: .presidente, uf: "br")
        vm.selecionar(cargo: .governador, uf: "br")
        #expect(vm.uf != "br")
        #expect(vm.url != nil)
    }
}
