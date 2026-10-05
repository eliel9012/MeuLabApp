import Foundation
import Observation

/// Polling do arquivo em tela, só enquanto a tela está visível e o app ativo.
///
/// Achatar e ordenar acontece no decode (fora da main, uma vez por resposta nova).
/// Busca e "Só eleitos" filtram aqui, uma vez por mudança, nunca no `body`.
@Observable
@MainActor
final class ApuracaoViewModel {
    private(set) var cargo: ApuracaoCargo
    private(set) var uf: String
    private(set) var snapshot: ApuracaoSnapshot? {
        didSet { if snapshot != oldValue { refiltrar() } }
    }
    private(set) var carregando = false
    /// Aviso discreto: dados antigos mantidos após falha.
    private(set) var aviso: String?

    var busca = "" {
        didSet { if busca != oldValue { refiltrar() } }
    }
    var soEleitos = false {
        didSet { if soEleitos != oldValue { refiltrar() } }
    }
    /// Candidatos do snapshot após busca e filtro, na ordem de votos.
    private(set) var candidatosFiltrados: [ApuracaoCandidato] = []

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private let service: ApuracaoService
    @ObservationIgnored private let pollingAtivo: Bool

    var cargoEfetivo: ApuracaoCargo { ApuracaoCargo.efetivo(cargo, uf: uf) }
    var url: URL? { cargoEfetivo.url(uf: uf) }
    /// Exposto para os testes conferirem o ciclo de vida do polling.
    var pollingEmExecucao: Bool { pollTask != nil }

    init(cargo: ApuracaoCargo, uf: String, service: ApuracaoService = .shared) {
        let n = ApuracaoCargo.normalizar(cargo, uf: uf)
        self.cargo = n.cargo
        self.uf = n.uf
        self.service = service
        self.pollingAtivo = true
    }

    /// Só para #Preview e testes: dados fixos, sem rede.
    init(preview snapshot: ApuracaoSnapshot, cargo: ApuracaoCargo, uf: String) {
        self.cargo = cargo
        self.uf = uf
        self.service = .shared
        self.pollingAtivo = false
        self.snapshot = snapshot
        refiltrar()
    }

    func selecionar(cargo: ApuracaoCargo, uf: String) {
        let n = ApuracaoCargo.normalizar(cargo, uf: uf)
        guard n.cargo != self.cargo || n.uf != self.uf else { return }
        let estavaAtivo = pollTask != nil
        // Cancela já a Task do arquivo anterior; a resposta dela é descartada.
        parar()
        self.cargo = n.cargo
        self.uf = n.uf
        busca = ""
        soEleitos = false
        snapshot = nil
        aviso = nil
        if estavaAtivo { iniciar() }
    }

    /// Começa (ou reinicia) o polling: busca na hora e depois a cada `cargoEfetivo.intervalo`.
    func iniciar() {
        guard pollingAtivo else { return }
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.atualizar()
                try? await Task.sleep(for: self.cargoEfetivo.intervalo)
            }
        }
    }

    /// Chamado ao sair da tela e quando o app deixa de estar ativo.
    func parar() {
        pollTask?.cancel()
        pollTask = nil
    }

    func atualizar() async {
        guard pollingAtivo, let url else { return }
        if snapshot?.url != url, let emCache = await service.cached(url) {
            snapshot = emCache
        }
        carregando = snapshot == nil
        defer { if url == self.url { carregando = false } }
        do {
            let novo = try await service.buscar(url)
            guard url == self.url, !Task.isCancelled else { return }
            snapshot = novo
            aviso = nil
        } catch is CancellationError {
        } catch {
            guard url == self.url, !Task.isCancelled else { return }
            aviso = (error as? LocalizedError)?.errorDescription ?? "Falha ao atualizar."
        }
    }

    private func refiltrar() {
        candidatosFiltrados = ApuracaoCandidato.filtrar(
            snapshot?.candidatos ?? [], busca: busca, soEleitos: soEleitos)
    }
}
