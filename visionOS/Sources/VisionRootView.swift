import SwiftUI

struct VisionRootView: View {
    @Environment(VisionLabStore.self) private var lab
    @Environment(FlightStore.self) private var flights
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        HStack(spacing: 14) {
            sidebar
                .frame(width: 220)
            Group {
                if lab.selection == .radar {
                    DashboardView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if lab.selection == .trip {
                    VisionTripView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VisionDataView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.035, green: 0.045, blue: 0.07).opacity(0.82), in: RoundedRectangle(cornerRadius: 32))
        .task {
            lab.start()
            flights.start()
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled, lab.selection == .radar, !flights.isVolumeOpen {
                openWindow(id: "radar-volume")
            }
        }
        .onChange(of: lab.selection) { _, section in
            if section == .radar { openWindow(id: "radar-volume") }
            else {
                dismissWindow(id: "radar-volume")
                dismissWindow(id: "radar-map")
                dismissWindow(id: "flight-search")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { lab.start() }
            else { lab.stop() }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image("RadarLocalIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 29, height: 29)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text("MeuLab")
                    .font(.title2.bold())
            }
            .padding(.bottom, 20)
            Text("CENTRAL")
                .font(.caption2.bold())
                .tracking(2)
                .foregroundStyle(.secondary)
            ForEach(VisionSection.allCases) { section in
                Button {
                    lab.select(section)
                } label: {
                    Label(section.rawValue, systemImage: section.symbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(lab.selection == section ? Color.blue.opacity(0.42) : .clear, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("Dados ao vivo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26))
    }

}

struct VisionDataView: View {
    @Environment(VisionLabStore.self) private var lab

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(lab.selection.rawValue, systemImage: lab.selection.symbol)
                    .font(.largeTitle.bold())
                Spacer()
                if lab.isLoading { ProgressView() }
                Button("Atualizar", systemImage: "arrow.clockwise") { Task { await lab.refresh() } }
            }
            if let error = lab.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .padding(12)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch lab.selection {
                    case .radar: EmptyView()
                    case .trip: EmptyView()
                    case .system: systemContent
                    case .infrastructure: infrastructureContent
                    case .radio: radioContent
                    case .weather: weatherContent
                    case .acars: acarsContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let time = lab.updatedAt {
                Text("Atualizado \(time.formatted(date: .omitted, time: .standard)) · MeuLab API")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    private var systemContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let system = lab.system {
                HStack(spacing: 16) {
                    metric("CPU", value: system.cpu?.usagePercent.map { "\(Int($0))%" } ?? "—", symbol: "cpu")
                    metric("Memória", value: system.memory?.usedPercent.map { "\(Int($0))%" } ?? "—", symbol: "memorychip")
                    metric("Disco", value: system.disk?.usedPercent.map { "\(Int($0))%" } ?? "—", symbol: "internaldrive")
                    metric("Temperatura", value: system.cpu?.temperatureC.map { "\(Int($0))°C" } ?? "—", symbol: "thermometer")
                }
                detail("Host", system.hostname)
                detail("Local", system.location)
                detail("Uptime", system.uptime?.formatted ?? "—")
                detail("Wi-Fi", system.wifi?.ssid ?? "—")
            } else { placeholder }
        }
    }

    private var infrastructureContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            systemContent
            Text("Processos").font(.title2.bold())
            ForEach(lab.processes) { item in
                detail(item.command, "PID \(item.pid) · CPU \(item.cpuPercent.formatted(.number.precision(.fractionLength(1))))% · RAM \(item.memPercent.formatted(.number.precision(.fractionLength(1))))%")
            }
            Text("Partições").font(.title2.bold())
            ForEach(lab.partitions) { item in detail(item.mount, "\(item.filesystem) · \(item.usedPercent) usado") }
            Text("Rede").font(.title2.bold())
            ForEach(lab.interfaces) { item in detail(item.iface, "↓ \(ByteCountFormatter.string(fromByteCount: item.rxBytes, countStyle: .file)) · ↑ \(ByteCountFormatter.string(fromByteCount: item.txBytes, countStyle: .file))") }
        }
    }

    private var radioContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let radio = lab.radio {
                HStack(spacing: 26) {
                    if let artwork = radio.artworkURL {
                        AsyncImage(url: artwork) { image in image.resizable().scaledToFill() } placeholder: { Color.blue.opacity(0.2) }
                            .frame(width: 160, height: 160).clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(radio.radioName).font(.title3).foregroundStyle(.secondary)
                        Text(radio.title).font(.largeTitle.bold())
                        Text(radio.artist).font(.title2)
                        Button(lab.isPlaying ? "Pausar" : "Ouvir ao vivo", systemImage: lab.isPlaying ? "pause.fill" : "play.fill") { lab.toggleRadio() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                detail("Fonte", "Stream ao vivo do MeuLab")
            } else { placeholder }
            Text("Histórico recente").font(.title2.bold())
            if lab.radioHistory.isEmpty {
                Text("Sem músicas recentes registradas.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(lab.radioHistory.enumerated()), id: \.offset) { _, track in
                    HStack(spacing: 14) {
                        if let artwork = track.artworkURL {
                            AsyncImage(url: artwork) { image in image.resizable().scaledToFill() }
                                placeholder: { Color.blue.opacity(0.2) }
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        } else {
                            Image(systemName: "music.note")
                                .frame(width: 52, height: 52)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title).font(.headline)
                            Text(track.artist).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let date = ISO8601DateFormatter().date(from: track.timestamp) {
                            Text(date, style: .relative).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var weatherContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let weather = lab.weather {
                Text(weather.location).font(.title2)
                HStack(spacing: 16) {
                    metric("Agora", value: "\(weather.current.tempC)°C", symbol: "thermometer.sun")
                    metric("Sensação", value: "\(weather.current.feelsLikeC)°C", symbol: "person.crop.circle")
                    metric("Vento", value: "\(weather.current.windKmh) km/h", symbol: "wind")
                    metric("Umidade", value: "\(weather.current.humidity)%", symbol: "humidity")
                }
                Text(weather.current.description).font(.title2)
                detail("Hoje", "\(weather.today.minTempC)° – \(weather.today.maxTempC)° · chuva \(weather.today.rainChance)%")
                Text("Próximos dias").font(.title2.bold())
                ForEach(weather.forecast) { day in detail(day.formattedDate, "\(day.minTempC)° – \(day.maxTempC)° · chuva \(day.rainChance)%") }
            } else { placeholder }
        }
    }

    private var acarsContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let acars = lab.acars {
                HStack(spacing: 16) {
                    metric("Mensagens hoje", value: "\(acars.today.messages)", symbol: "text.bubble")
                    metric("Última hora", value: "\(acars.lastHour)", symbol: "clock")
                    metric("Voos", value: "\(acars.today.flights)", symbol: "airplane")
                    metric("Aeronaves", value: "\(acars.today.aircraft)", symbol: "antenna.radiowaves.left.and.right")
                }
                Text("Mensagens recentes").font(.title2.bold())
                ForEach(lab.acarsMessages) { message in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(message.flight ?? message.tail ?? "Sem ID").bold()
                            Text(message.label ?? "—").foregroundStyle(.cyan)
                            Spacer()
                            Text(message.time).foregroundStyle(.secondary)
                        }
                        if let text = message.text { Text(text).lineLimit(3).foregroundStyle(.secondary) }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            } else { placeholder }
        }
    }

    private var placeholder: some View {
        ContentUnavailableView("Aguardando dados reais", systemImage: "network", description: Text("Conectando ao MeuLab…"))
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title.bold()).monospacedDigit().minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.headline)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}
