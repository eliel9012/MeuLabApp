import SwiftUI

/// Controle remoto das apresentações FDF 2026 (GT3 / GT8).
/// Os comandos vão para app.meulab.fun/api/slides/... e chegam à tela aberta no navegador.
struct SlidesControlView: View {
    @AppStorage("slides.selectedDeck") private var deckRaw = SlideDeck.gt3.rawValue
    @State private var state: SlidesState?
    @State private var error: String?
    @State private var isSending = false
    @State private var showGoto = false
    @State private var gotoText = ""
    @State private var feedback = 0

    private var deck: SlideDeck { SlideDeck(rawValue: deckRaw) ?? .gt3 }
    private var hasScreen: Bool { (state?.screens ?? 0) > 0 }

    var body: some View {
        VStack(spacing: 20) {
            Picker("Apresentação", selection: $deckRaw) {
                ForEach(SlideDeck.allCases) { d in
                    Text(d.shortTitle).tag(d.rawValue)
                }
            }
            .pickerStyle(.segmented)

            statusCard

            Spacer(minLength: 0)

            controls

            secondaryActions

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .navigationTitle("Slides FDF")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .medium), trigger: feedback)
        .task(id: deckRaw) { await poll() }
        .onChange(of: deckRaw) { state = nil; error = nil }
        .alert("Ir para o slide", isPresented: $showGoto) {
            TextField("Número", text: $gotoText)
                .keyboardType(.numberPad)
            Button("Cancelar", role: .cancel) {}
            Button("Ir") {
                if let n = Int(gotoText), n > 0 {
                    Task { await send { try await APIService.shared.gotoSlide(n, deck: deck) } }
                }
            }
        }
    }

    // MARK: - Subviews

    private var statusCard: some View {
        VStack(spacing: 8) {
            Text(deck.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(slideLabel)
                .scaledFont(size: 64, weight: .light, design: .serif)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: state?.slide)

            Label(screenLabel, systemImage: hasScreen ? "display" : "display.trianglebadge.exclamationmark")
                .font(.footnote)
                .foregroundStyle(hasScreen ? .green : .orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .contentCard()
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button {
                Task { await act(.prev) }
            } label: {
                Image(systemName: "chevron.left")
                    .scaledFont(size: 34, weight: .semibold)
                    .frame(maxWidth: .infinity, minHeight: 150)
            }
            .adaptiveGlassButton()
            .accessibilityLabel("Slide anterior")

            Button {
                Task { await act(.next) }
            } label: {
                Image(systemName: "chevron.right")
                    .scaledFont(size: 44, weight: .semibold)
                    .frame(maxWidth: .infinity, minHeight: 150)
            }
            .adaptiveGlassProminentButton()
            .layoutPriority(1)
            .accessibilityLabel("Próximo slide")
        }
        .disabled(isSending)
    }

    private var secondaryActions: some View {
        HStack(spacing: 10) {
            Button("Início", systemImage: "backward.end") { Task { await act(.first) } }
            Button("Ir para…", systemImage: "number") { gotoText = ""; showGoto = true }
            Button("Recarregar", systemImage: "arrow.clockwise") { Task { await act(.reload) } }
        }
        .font(.footnote)
        .labelStyle(.titleAndIcon)
        .adaptiveGlassButton()
        .disabled(isSending)
    }

    private var slideLabel: String {
        guard let slide = state?.slide else { return "–" }
        return "\(slide) / \(state?.total.map(String.init) ?? "?")"
    }

    private var screenLabel: String {
        guard let state else { return "Conectando…" }
        switch state.screens {
        case 0: return "Nenhuma tela aberta (\(deck.lanURL))"
        case 1: return "1 tela conectada"
        default: return "\(state.screens) telas conectadas"
        }
    }

    // MARK: - Actions

    private func act(_ action: SlideAction) async {
        await send { try await APIService.shared.sendSlidesAction(action, deck: deck) }
    }

    private func send(_ call: @escaping () async throws -> SlidesState) async {
        guard !isSending else { return }
        isSending = true
        feedback += 1
        defer { isSending = false }
        do {
            state = try await call()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func poll() async {
        while !Task.isCancelled {
            if !isSending {
                do {
                    state = try await APIService.shared.fetchSlidesState(deck)
                    error = nil
                } catch is CancellationError {
                    return
                } catch {
                    self.error = error.localizedDescription
                }
            }
            try? await Task.sleep(for: .seconds(2))
        }
    }
}

#Preview {
    NavigationStack { SlidesControlView() }
}
