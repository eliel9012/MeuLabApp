import SwiftUI

// MARK: - Remote Radio View (Vintage SDR)

struct RemoteRadioView: View {
    @StateObject private var vm = RemoteRadioViewModel()
    @State private var showPresets = false
    @State private var gainIsAuto = true
    @State private var manualGain: Double = 30

    // Vintage color palette
    private let woodDark = Color(red: 0.25, green: 0.15, blue: 0.08)
    private let woodMid = Color(red: 0.35, green: 0.22, blue: 0.12)
    private let woodLight = Color(red: 0.45, green: 0.30, blue: 0.18)
    private let amber = Color(red: 1.0, green: 0.85, blue: 0.55)
    private let amberDim = Color(red: 0.8, green: 0.65, blue: 0.35)
    private let amberGlow = Color(red: 1.0, green: 0.9, blue: 0.6)
    private let cream = Color(red: 0.96, green: 0.93, blue: 0.86)
    private let brass = Color(red: 0.72, green: 0.60, blue: 0.35)
    private let dialBg = Color(red: 0.12, green: 0.10, blue: 0.08)

    var body: some View {
        NavigationStack {
            ZStack {
                // Wood cabinet background
                woodBackground

                ScrollView {
                    VStack(spacing: 0) {
                        // Backend unavailable or hardware warning banner
                        if vm.backendAvailable == false {
                            backendBanner(
                                title: "Backend Indisponível",
                                icon: "xmark.circle.fill",
                                tint: .red
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        } else if vm.backendAvailable == true && vm.errorMessage != nil {
                            backendBanner(
                                title: "Aviso de Hardware",
                                icon: "exclamationmark.triangle.fill",
                                tint: .orange
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }

                        // Frequency display panel
                        frequencyPanel
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        // Mode selector
                        modeSelector
                            .padding(.top, 14)

                        // Tuning controls
                        tuningControls
                            .padding(.top, 14)
                            .padding(.horizontal, 16)

                        // Gain & Squelch knobs
                        knobSection
                            .padding(.top, 16)
                            .padding(.horizontal, 16)

                        // Preset buttons
                        presetGrid
                            .padding(.top, 16)
                            .padding(.horizontal, 16)

                        // Connection & Play controls
                        mainControls
                            .padding(.top, 18)
                            .padding(.horizontal, 16)

                        // Status bar
                        statusBar
                            .padding(.top, 14)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 50)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(amber)
                            .font(.subheadline)
                        Text("SDR Remote")
                            .font(.headline)
                            .foregroundStyle(cream)
                    }
                }
            }
            .toolbarBackground(woodDark, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await vm.fetchStatus()
            }
        }
    }

    // MARK: - Backend Status Banner

    private func backendBanner(title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(cream)
                Spacer()
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(cream.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Status detail pills
            if vm.backendAvailable == true {
                HStack(spacing: 12) {
                    statusPill(
                        label: "Dongle",
                        ok: vm.donglePresent == true,
                        icon: "cpu"
                    )
                    statusPill(
                        label: "Audio",
                        ok: vm.donglePresent == true,
                        icon: "waveform"
                    )
                    Spacer()
                }
            }

            Button {
                Task {
                    vm.errorMessage = nil
                    vm.backendAvailable = nil
                    await vm.fetchStatus()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Verificar Novamente")
                }
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(brass.opacity(0.6))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tint.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func statusPill(label: String, ok: Bool, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
            Circle()
                .fill(ok ? Color.green : Color.red)
                .frame(width: 6, height: 6)
        }
        .foregroundStyle(cream.opacity(0.6))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(dialBg.opacity(0.8))
        )
    }

    // MARK: - Wood Background

    private var woodBackground: some View {
        ZStack {
            LinearGradient(
                colors: [woodDark, woodMid, woodDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle wood grain texture overlay
            GeometryReader { geo in
                Canvas { context, size in
                    // Horizontal grain lines
                    for i in stride(from: 0, to: size.height, by: 8) {
                        let opacity = Double.random(in: 0.02...0.06)
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: i))
                        path.addLine(to: CGPoint(x: size.width, y: i + Double.random(in: -1...1)))
                        context.stroke(path, with: .color(.black.opacity(opacity)), lineWidth: 0.5)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Frequency Display Panel

    private var frequencyPanel: some View {
        VStack(spacing: 4) {
            // Retro display panel
            ZStack {
                // Panel frame
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(dialBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(brass.opacity(0.6), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 4)

                // Inner glow effect
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [amber.opacity(isDisplayGlowing ? 0.08 : 0.02), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 140
                        )
                    )
                    .padding(3)

                VStack(spacing: 2) {
                    // Band indicator
                    Text(vm.mode.displayName)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(amberDim.opacity(0.7))
                        .tracking(4)

                    // Main frequency
                    Text(vm.freqDisplayString)
                        .font(
                            .system(
                                size: vm.mode == .wfm ? 52 : 38, weight: .light, design: .monospaced
                            )
                        )
                        .foregroundStyle(amber)
                        .shadow(color: amberGlow.opacity(isDisplayGlowing ? 0.6 : 0.0), radius: 12)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: vm.freqHz)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    // Unit label
                    Text(vm.freqUnitLabel)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(amberDim.opacity(0.5))
                        .tracking(3)
                }
                .padding(.vertical, 16)
            }
            .frame(height: 140)
        }
    }

    private var isDisplayGlowing: Bool {
        vm.connectionState == .connected || vm.connectionState == .running
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 12) {
            ForEach(RadioMode.allCases) { radioMode in
                Button {
                    vm.mode = radioMode
                    if vm.connectionState == .running {
                        Task { await vm.tune() }
                    }
                } label: {
                    Text(radioMode.displayName)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(vm.mode == radioMode ? woodDark : cream.opacity(0.7))
                        .frame(width: 60, height: 36)
                        .background {
                            if vm.mode == radioMode {
                                Capsule()
                                    .fill(amber)
                                    .shadow(color: amberGlow.opacity(0.4), radius: 6)
                            } else {
                                Capsule()
                                    .fill(woodLight.opacity(0.3))
                                    .overlay(
                                        Capsule().stroke(brass.opacity(0.4), lineWidth: 1)
                                    )
                            }
                        }
                }
            }
        }
    }

    // MARK: - Tuning Controls

    private var tuningControls: some View {
        VStack(spacing: 10) {
            // Top row: coarse tuning
            HStack(spacing: 12) {
                tuningButton(label: "−1M", delta: -1_000_000)
                tuningButton(label: "−100k", delta: -100_000)
                tuningButton(label: "+100k", delta: 100_000)
                tuningButton(label: "+1M", delta: 1_000_000)
            }

            // Bottom row: fine tuning
            HStack(spacing: 12) {
                tuningButton(label: "−25k", delta: -25_000)
                tuningButton(label: "−10k", delta: -10_000)
                tuningButton(label: "+10k", delta: 10_000)
                tuningButton(label: "+25k", delta: 25_000)
            }
        }
    }

    private func tuningButton(label: String, delta: Int) -> some View {
        Button {
            Task { await vm.stepFrequency(by: delta) }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(cream)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(woodLight.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(brass.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Gain & Squelch Section

    private var knobSection: some View {
        HStack(spacing: 20) {
            // Gain control
            VStack(spacing: 6) {
                Text("GAIN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(amberDim)
                    .tracking(2)

                // Auto/Manual toggle
                Button {
                    gainIsAuto.toggle()
                    vm.gain = gainIsAuto ? .auto : .manual(manualGain)
                    if vm.connectionState == .running {
                        Task { await vm.tune() }
                    }
                } label: {
                    Text(gainIsAuto ? "AUTO" : String(format: "%.0f", manualGain))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(gainIsAuto ? amber : cream)
                        .frame(width: 64, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(gainIsAuto ? amber.opacity(0.15) : woodLight.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(brass.opacity(0.4), lineWidth: 1)
                                )
                        )
                }

                if !gainIsAuto {
                    Slider(value: $manualGain, in: 0...49.6, step: 0.1)
                        .tint(amber)
                        .onChange(of: manualGain) { _, val in
                            vm.gain = .manual(val)
                        }
                }
            }
            .frame(maxWidth: .infinity)

            // Squelch control
            VStack(spacing: 6) {
                Text("SQUELCH")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(amberDim)
                    .tracking(2)

                Text("\(vm.squelch)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(cream)
                    .frame(width: 64, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(woodLight.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(brass.opacity(0.4), lineWidth: 1)
                            )
                    )

                Slider(
                    value: Binding(
                        get: { Double(vm.squelch) },
                        set: { vm.squelch = Int($0) }
                    ), in: 0...100, step: 1
                )
                .tint(amber)
                .onChange(of: vm.squelch) { _, _ in
                    if vm.connectionState == .running {
                        Task { await vm.tune() }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Presets Grid

    private var presetGrid: some View {
        VStack(spacing: 8) {
            HStack {
                Text("PRESETS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(amberDim)
                    .tracking(3)
                Spacer()
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                ], spacing: 10
            ) {
                ForEach(RadioPreset.presets) { preset in
                    presetButton(preset)
                }
            }
        }
    }

    private func presetButton(_ preset: RadioPreset) -> some View {
        Button {
            Task { await vm.applyPreset(preset) }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: preset.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isPresetActive(preset) ? woodDark : amber)

                Text(preset.name)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isPresetActive(preset) ? woodDark : cream.opacity(0.8))

                Text(String(format: "%.1f", preset.freqMHz))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(
                        isPresetActive(preset) ? woodDark.opacity(0.7) : amberDim.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isPresetActive(preset) ? amber : woodLight.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(brass.opacity(isPresetActive(preset) ? 0.6 : 0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func isPresetActive(_ preset: RadioPreset) -> Bool {
        vm.freqHz == preset.freqHz && vm.mode == preset.mode
    }

    // MARK: - Main Controls (Connect / Play / Stop)

    private var mainControls: some View {
        VStack(spacing: 12) {
            if vm.connectionState == .disconnected || vm.connectionState.isErrorState {
                mainActionButton(
                    label: "CONECTAR",
                    icon: "power",
                    color: .green,
                    action: { Task { await vm.connect() } }
                )
            } else if vm.connectionState == .connecting {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(amber)
                    Text("Conectando ao SDR…")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(amber)
                }
                .padding(.vertical, 4)
            } else {
                mainActionButton(
                    label: "DESCONECTAR",
                    icon: "power",
                    color: .red.opacity(0.8),
                    action: { Task { await vm.disconnect() } }
                )
            }
        }
    }

    private func mainActionButton(
        label: String, icon: String, color: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 6, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        VStack(spacing: 6) {
            // Connection state LED + text
            HStack(spacing: 8) {
                // Status LED
                Circle()
                    .fill(statusLEDColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusLEDColor.opacity(0.6), radius: 4)

                Text(vm.connectionState.displayText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(cream.opacity(0.8))

                Spacer()

                // Audio streaming indicator
                if vm.isAudioPlaying {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 9))
                        Text("\(vm.audioFrameCount)f")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(amber.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(dialBg.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(brass.opacity(0.2), lineWidth: 0.5)
                    )
            )

            // Error message
            if let errorMsg = vm.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.system(size: 11))
                    Text(errorMsg)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.red.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.red.opacity(0.1))
                )
            }

            // Backend info
            if !vm.backendType.isEmpty {
                HStack(spacing: 8) {
                    Label(vm.backendType.uppercased(), systemImage: "cpu")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(amberDim.opacity(0.5))

                    if !vm.rtlSerial.isEmpty {
                        Text("SN: \(vm.rtlSerial)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(amberDim.opacity(0.5))
                    }
                    Spacer()
                }
            }
        }
    }

    private var statusLEDColor: Color {
        switch vm.connectionState {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .running: return .green
        case .error: return .red
        }
    }
}

// MARK: - Helpers

extension RemoteRadioConnectionState {
    fileprivate var isErrorState: Bool {
        if case .error = self { return true }
        return false
    }
}

#Preview {
    RemoteRadioView()
}
