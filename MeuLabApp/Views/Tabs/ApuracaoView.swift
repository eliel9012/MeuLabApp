import SwiftUI

/// Apuração ao vivo das Eleições Gerais 2026 (1º turno), com dados oficiais do TSE.
struct ApuracaoView: View {
    @AppStorage("apuracao.cargo") private var cargoRaw = ApuracaoCargo.presidente.rawValue
    @AppStorage("apuracao.uf") private var ufRaw = "br"
    @Environment(\.scenePhase) private var scenePhase

    @State private var vm: ApuracaoViewModel
    @State private var mostrarTodos = false
    /// O TabView mantém abas vivas fora da tela; o polling só roda com a aba visível.
    @State private var visivel = false

    private static let limiteInicial = 100

    init() {
        let defaults = UserDefaults.standard
        let cargo = ApuracaoCargo(rawValue: defaults.string(forKey: "apuracao.cargo") ?? "") ?? .presidente
        let uf = defaults.string(forKey: "apuracao.uf") ?? "br"
        _vm = State(initialValue: ApuracaoViewModel(cargo: cargo, uf: uf))
    }

    init(previewModel: ApuracaoViewModel) {
        _vm = State(initialValue: previewModel)
    }

    var body: some View {
        // No NavigationStack here: the tab is hosted by the "Mais" navigation on
        // iPhone and by the split view on iPad; a second stack stacks a second bar.
        Group {
            List {
                seletor
                cabecalho
                conteudo
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Apuração 2026")
            .navigationBarTitleDisplayMode(.inline)
            // Title as a principal item: the "Mais" navigation bar shows only that,
            // next to the back button.
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Apuração 2026").font(.headline)
                }
            }
            .modifier(BuscaCandidatos(ativa: vm.cargoEfetivo.isProporcional, texto: $vm.busca))
            .refreshable { await vm.atualizar() }
            .onAppear {
                visivel = true
                if scenePhase == .active { vm.iniciar() }
            }
            .onDisappear {
                visivel = false
                vm.parar()
            }
            .onChange(of: scenePhase) { _, fase in
                if fase == .active && visivel { vm.iniciar() } else if fase != .active { vm.parar() }
            }
            .onChange(of: vm.url) { _, _ in mostrarTodos = false }
        }
    }

    // MARK: - Seletor

    private var cargoBinding: Binding<ApuracaoCargo> {
        Binding(
            get: { vm.cargo },
            set: { novo in
                vm.selecionar(cargo: novo, uf: vm.uf)
                cargoRaw = vm.cargo.rawValue
                ufRaw = vm.uf
            }
        )
    }

    private var ufBinding: Binding<String> {
        Binding(
            get: { vm.uf },
            set: { nova in
                vm.selecionar(cargo: vm.cargo, uf: nova)
                ufRaw = vm.uf
            }
        )
    }

    private var seletor: some View {
        Section {
            Picker("Cargo", selection: cargoBinding) {
                ForEach(ApuracaoCargo.selecionaveis) { cargo in
                    Text(cargo == .depEstadual && vm.uf == "df" ? "Deputado Distrital" : cargo.titulo)
                        .tag(cargo)
                }
            }
            Picker("Estado", selection: ufBinding) {
                if vm.cargo == .presidente {
                    Text("Brasil").tag("br")
                }
                ForEach(ApuracaoUF.todas, id: \.sigla) { uf in
                    Text(uf.nome).tag(uf.sigla)
                }
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Cabeçalho

    @ViewBuilder
    private var cabecalho: some View {
        Section {
            if let s = vm.snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(s.cargoNome.isEmpty ? vm.cargoEfetivo.titulo : s.cargoNome)
                            .font(.headline)
                        if vm.cargoEfetivo == .senador || vm.cargoEfetivo.isProporcional, s.vagas > 0 {
                            Text(s.vagas == 1 ? "1 vaga" : "\(s.vagas) vagas")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.15), in: Capsule())
                        }
                        Spacer()
                        Text(ApuracaoUF.nome(vm.uf))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text(ApuracaoFormato.percentual(s.percentualSecoes))
                            .font(.title2.weight(.bold).monospacedDigit())
                        Text("das seções apuradas")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(max(s.percentualSecoes / 100, 0), 1))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        if !s.hora.isEmpty {
                            Text("Atualizado às \(s.hora)\(s.data.isEmpty ? "" : " de \(s.data)") (Brasília)")
                        }
                        Text("Dados oficiais do TSE")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(ApuracaoFormato.percentual(s.percentualSecoes)) das seções apuradas. Atualizado às \(s.hora). Dados oficiais do TSE."
                )
            } else if vm.carregando {
                HStack {
                    ProgressView()
                    Text("Carregando dados do TSE…")
                        .foregroundStyle(.secondary)
                }
            }

            if let aviso = vm.aviso {
                Label(vm.snapshot == nil ? aviso : "\(aviso) Mostrando os últimos dados.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Conteúdo

    @ViewBuilder
    private var conteudo: some View {
        if let s = vm.snapshot {
            if !s.apuracaoIniciada {
                Section {
                    // Custom instead of ContentUnavailableView: its title is one line and
                    // truncated "(horário de Brasília)".
                    VStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(ApuracaoSnapshot.mensagemAntesDoInicio)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Os números aparecem aqui assim que o TSE divulgar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .accessibilityElement(children: .combine)
                }
            } else if vm.cargoEfetivo.isProporcional {
                deputados(s)
                rodape(s)
            } else {
                Section("Candidatos") {
                    ForEach(s.candidatos) { CandidatoRow(candidato: $0) }
                }
                rodape(s)
            }
        } else if !vm.carregando, vm.aviso != nil {
            Section {
                ContentUnavailableView(
                    "Sem dados",
                    systemImage: "wifi.exclamationmark",
                    description: Text("Puxe para atualizar ou aguarde a próxima tentativa.")
                )
            }
        }
    }

    @ViewBuilder
    private func deputados(_ s: ApuracaoSnapshot) -> some View {
        if !s.vagasPorAgrupamento.isEmpty && vm.busca.isEmpty {
            Section("Vagas por partido/federação") {
                ForEach(s.vagasPorAgrupamento) { agr in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(agr.nome).font(.subheadline.weight(.semibold))
                            if !agr.composicao.isEmpty && agr.composicao != agr.nome {
                                Text(agr.composicao)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(agr.vagas)")
                            .font(.title3.weight(.bold).monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(agr.nome): \(agr.vagas) \(agr.vagas == 1 ? "vaga" : "vagas")")
                }
            }
        }

        // Lista já filtrada no ViewModel; aqui só se corta para os 100 primeiros.
        let filtrados = vm.candidatosFiltrados
        let visiveis = mostrarTodos || !vm.busca.isEmpty ? filtrados : Array(filtrados.prefix(Self.limiteInicial))

        Section {
            Toggle("Só eleitos", isOn: $vm.soEleitos)
            if visiveis.isEmpty {
                Text(vm.busca.isEmpty ? "Nenhum eleito definido pelo TSE ainda." : "Nenhum candidato encontrado.")
                    .foregroundStyle(.secondary)
            }
            ForEach(visiveis) { CandidatoRow(candidato: $0) }
            if visiveis.count < filtrados.count {
                Button("Ver todos (\(ApuracaoFormato.votos(filtrados.count)))") { mostrarTodos = true }
            }
        } header: {
            Text("Candidatos")
        } footer: {
            Text("Eleitos conforme situação divulgada pelo TSE.")
        }
    }

    private func rodape(_ s: ApuracaoSnapshot) -> some View {
        Section("Votos") {
            linhaVotos("Válidos", s.votos.vv, s.votos.pvv)
            linhaVotos("Brancos", s.votos.vb, s.votos.pvb)
            linhaVotos("Nulos", s.votos.tvn, s.votos.ptvn)
            if s.eleitores > 0 {
                LabeledContent("Eleitorado", value: ApuracaoFormato.votos(s.eleitores))
            }
        }
    }

    private func linhaVotos(_ titulo: String, _ votos: Int, _ pct: Double) -> some View {
        LabeledContent(titulo) {
            Text("\(ApuracaoFormato.votos(votos)) · \(ApuracaoFormato.percentual(pct))")
                .monospacedDigit()
        }
    }
}

// MARK: - Linha do candidato

private struct CandidatoRow: View {
    let candidato: ApuracaoCandidato

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(candidato.posicao)º")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidato.nomeUrna)
                        .font(.headline)
                    Text("\(candidato.partido) · \(candidato.numero)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let vice = candidato.vices.first(where: { $0.tp == "v" }) {
                        Text("Vice: \(vice.nmu) (\(vice.sgp))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ApuracaoFormato.percentual(candidato.percentual))
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text("\(ApuracaoFormato.votos(candidato.votos)) votos")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: min(max(candidato.percentual / 100, 0), 1))
                .tint(corSelo)
                .accessibilityHidden(true)
            if let selo = candidato.selo {
                Text(textoSelo(selo))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .foregroundStyle(corSelo)
                    .background(corSelo.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rotuloAcessivel)
    }

    private func textoSelo(_ selo: ApuracaoCandidato.Selo) -> String {
        switch selo {
        case .eleito(let texto): texto
        case .segundoTurno: "2º turno"
        }
    }

    private var corSelo: Color {
        switch candidato.selo {
        case .eleito: .green
        case .segundoTurno: .orange
        case nil: .accentColor
        }
    }

    private var rotuloAcessivel: String {
        var partes = [
            "\(candidato.posicao)º lugar",
            candidato.nomeUrna,
            "partido \(candidato.partido)",
            "número \(candidato.numero)",
            "\(ApuracaoFormato.percentual(candidato.percentual)) dos válidos",
            "\(ApuracaoFormato.votos(candidato.votos)) votos",
        ]
        if let selo = candidato.selo { partes.append(textoSelo(selo)) }
        return partes.joined(separator: ", ")
    }
}

// MARK: - Busca só para deputados

private struct BuscaCandidatos: ViewModifier {
    let ativa: Bool
    @Binding var texto: String

    func body(content: Content) -> some View {
        if ativa {
            content.searchable(text: $texto, prompt: "Nome ou número")
        } else {
            content
        }
    }
}

// MARK: - Previews (dados de EXEMPLO, não oficiais)

#if DEBUG
/// Só existe em DEBUG e só é usado pelos #Preview abaixo: nunca entra no app distribuído.
private enum ApuracaoPreviewData {
    static let url = URL(string: "https://example.invalid/preview.json")!

    /// Arquivo como o TSE publica antes das 17h: tudo zerado.
    static let zerado = """
        {"dg":"03/10/2026","hg":"12:00:00","s":{"st":"0","ts":"100","pst":"0,00"},"e":{"te":"1000"},
        "v":{"vv":"0","vb":"0","tvn":"0","van":"0","pvv":"0,00","pvb":"0,00","ptvn":"0,00"},
        "carg":[{"nmn":"Presidente","nv":"1","agr":[{"n":"1","nm":"EXEMPLO","com":"","vag":"0",
        "par":[{"n":"99","sg":"EXEMPLO","nm":"EXEMPLO","tvan":"0","cand":[
        {"n":"99","sqcand":"1","nmu":"CANDIDATO EXEMPLO","vap":"0","pvap":"0,00","st":"","e":"n"}]}]}]}]}
        """

    /// Números FICTÍCIOS, só para ver o layout. Não representam nenhum resultado real.
    static let exemplo = """
        {"dg":"04/10/2026","hg":"20:15:00","s":{"st":"62","ts":"100","pst":"62,00"},"e":{"te":"1000"},
        "v":{"vv":"700","vb":"20","tvn":"30","van":"0","pvv":"93,33","pvb":"2,67","ptvn":"4,00"},
        "carg":[{"nmn":"Presidente","nv":"1","agr":[{"n":"1","nm":"EXEMPLO A","com":"","vag":"0",
        "par":[{"n":"91","sg":"EXA","nm":"PARTIDO EXEMPLO A","tvan":"400","cand":[
        {"n":"91","sqcand":"1","nmu":"CANDIDATA EXEMPLO A","vap":"400","pvap":"57,14","st":"","e":"n",
         "vs":[{"tp":"v","nmu":"VICE EXEMPLO A","sgp":"EXA"}]}]}]},
        {"n":"2","nm":"EXEMPLO B","com":"","vag":"0","par":[{"n":"92","sg":"EXB","nm":"PARTIDO EXEMPLO B","tvan":"300","cand":[
        {"n":"92","sqcand":"2","nmu":"CANDIDATO EXEMPLO B","vap":"300","pvap":"42,86","st":"","e":"n"}]}]}]}]}
        """

    @MainActor static func modelo(_ json: String) -> ApuracaoViewModel {
        let snapshot = try! ApuracaoSnapshot.decodificar(Data(json.utf8), url: url)
        return ApuracaoViewModel(preview: snapshot, cargo: .presidente, uf: "br")
    }
}

#Preview("Antes das 17h") {
    ApuracaoView(previewModel: ApuracaoPreviewData.modelo(ApuracaoPreviewData.zerado))
}

#Preview("Exemplo fictício") {
    ApuracaoView(previewModel: ApuracaoPreviewData.modelo(ApuracaoPreviewData.exemplo))
}
#endif
