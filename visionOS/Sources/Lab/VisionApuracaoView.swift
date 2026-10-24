import SwiftUI

/// Shares the iPhone decoder, ETag cache and polling model. Never invents votes.
struct VisionApuracaoView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("apuracao.cargo") private var savedCargo = ApuracaoCargo.presidente.rawValue
    @AppStorage("apuracao.uf") private var savedUF = "br"
    @State private var model: ApuracaoViewModel
    @State private var showAll = false

    init() {
        let defaults = UserDefaults.standard
        let cargo = ApuracaoCargo(rawValue: defaults.string(forKey: "apuracao.cargo") ?? "") ?? .presidente
        let uf = defaults.string(forKey: "apuracao.uf") ?? "br"
        _model = State(initialValue: ApuracaoViewModel(cargo: cargo, uf: uf))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Label("Apuração 2026", systemImage: "chart.bar.xaxis").font(.largeTitle.bold())
                    Spacer()
                    if model.carregando { ProgressView() }
                    Button("Atualizar", systemImage: "arrow.clockwise") { Task { await model.atualizar() } }
                }

                HStack(spacing: 18) {
                    Picker("Cargo", selection: Binding(
                        get: { model.cargo },
                        set: { select($0, model.uf) }
                    )) {
                        ForEach(ApuracaoCargo.selecionaveis) { cargo in
                            Text(cargo == .depEstadual && model.uf == "df" ? "Deputado Distrital" : cargo.titulo).tag(cargo)
                        }
                    }
                    Picker("Estado", selection: Binding(
                        get: { model.uf },
                        set: { select(model.cargo, $0) }
                    )) {
                        if model.cargo == .presidente { Text("Brasil").tag("br") }
                        ForEach(ApuracaoUF.todas, id: \.sigla) { state in
                            Text(state.nome).tag(state.sigla)
                        }
                    }
                }
                .pickerStyle(.menu)

                if let snapshot = model.snapshot {
                    overview(snapshot)
                    if snapshot.apuracaoIniciada {
                        if model.cargoEfetivo.isProporcional { proportionalControls(snapshot) }
                        candidates(snapshot)
                        votes(snapshot)
                    } else {
                        Label(ApuracaoSnapshot.mensagemAntesDoInicio, systemImage: "clock")
                            .font(.title3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(22)
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                    }
                } else if model.carregando {
                    ProgressView("Carregando dados do TSE…").padding(24)
                } else {
                    ContentUnavailableView("Sem dados", systemImage: "network",
                                           description: Text(model.aviso ?? "Aguardando publicação do TSE."))
                }

                if let warning = model.aviso, model.snapshot != nil {
                    Label("\(warning) Mostrando último arquivo recebido.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                Link("Fonte: resultados do TSE", destination: URL(string: "https://dadosabertos.tse.jus.br/dataset/resultados-2026")!)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .onAppear { if scenePhase == .active { model.iniciar() } }
        .onDisappear { model.parar() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.iniciar() } else { model.parar() }
        }
    }

    private func select(_ cargo: ApuracaoCargo, _ uf: String) {
        model.selecionar(cargo: cargo, uf: uf)
        savedCargo = model.cargo.rawValue
        savedUF = model.uf
        showAll = false
    }

    private func overview(_ snapshot: ApuracaoSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(snapshot.cargoNome.isEmpty ? model.cargoEfetivo.titulo : snapshot.cargoNome).font(.title2.bold())
                if snapshot.vagas > 0 { Text("\(snapshot.vagas) vagas").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text(ApuracaoUF.nome(model.uf)).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(ApuracaoFormato.percentual(snapshot.percentualSecoes)).font(.largeTitle.bold()).monospacedDigit()
                Text("das seções apuradas").foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(snapshot.percentualSecoes / 100, 0), 1))
            Text("\(snapshot.data) · \(snapshot.hora) (Brasília) · TSE")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func proportionalControls(_ snapshot: ApuracaoSnapshot) -> some View {
        if !snapshot.vagasPorAgrupamento.isEmpty && model.busca.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Vagas por partido/federação").font(.title2.bold())
                ForEach(snapshot.vagasPorAgrupamento) { group in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(group.nome).font(.headline)
                            if group.composicao != group.nome { Text(group.composicao).font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Text("\(group.vagas)").font(.title3.bold()).monospacedDigit()
                    }
                }
            }
            .padding(20)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        }
        HStack {
            TextField("Buscar candidato por nome ou número", text: Binding(
                get: { model.busca }, set: { model.busca = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            Toggle("Só eleitos", isOn: Binding(
                get: { model.soEleitos }, set: { model.soEleitos = $0 }
            ))
            .fixedSize()
        }
    }

    private func candidates(_ snapshot: ApuracaoSnapshot) -> some View {
        let filtered = model.cargoEfetivo.isProporcional ? model.candidatosFiltrados : snapshot.candidatos
        let visible = showAll || !model.busca.isEmpty ? filtered : Array(filtered.prefix(100))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Candidatos").font(.title2.bold())
            if visible.isEmpty { Text("Nenhum candidato divulgado.").foregroundStyle(.secondary) }
            ForEach(visible) { candidate in
                HStack(alignment: .top, spacing: 16) {
                    Text("\(candidate.posicao)º").font(.headline.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 45, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.nomeUrna).font(.headline)
                        Text("\(candidate.partido) · \(candidate.numero)").font(.caption).foregroundStyle(.secondary)
                        if let vice = candidate.vices.first(where: { $0.tp == "v" }) {
                            Text("Vice: \(vice.nmu) (\(vice.sgp))").font(.caption).foregroundStyle(.secondary)
                        }
                        if let badge = candidate.selo {
                            Text(badgeText(badge)).font(.caption.bold())
                                .foregroundStyle(candidate.isEleito ? .green : .orange)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(ApuracaoFormato.percentual(candidate.percentual)).font(.title3.bold()).monospacedDigit()
                        Text("\(ApuracaoFormato.votos(candidate.votos)) votos").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(13)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }
            if visible.count < filtered.count {
                Button("Ver todos (\(ApuracaoFormato.votos(filtered.count)))") { showAll = true }
            }
        }
        .padding(20)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func votes(_ snapshot: ApuracaoSnapshot) -> some View {
        HStack(spacing: 18) {
            vote("Válidos", snapshot.votos.vv, snapshot.votos.pvv)
            vote("Brancos", snapshot.votos.vb, snapshot.votos.pvb)
            vote("Nulos", snapshot.votos.tvn, snapshot.votos.ptvn)
            if snapshot.eleitores > 0 { vote("Eleitores", snapshot.eleitores, nil) }
        }
    }

    private func vote(_ name: String, _ count: Int, _ percentage: Double?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(ApuracaoFormato.votos(count)).font(.title3.bold()).monospacedDigit()
            if let percentage { Text(ApuracaoFormato.percentual(percentage)).font(.caption) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func badgeText(_ badge: ApuracaoCandidato.Selo) -> String {
        switch badge {
        case .eleito(let text): text
        case .segundoTurno: "2º turno"
        }
    }
}
