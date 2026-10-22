import SwiftUI

private struct VisionAlertRule: Decodable, Identifiable {
    let id: String
    let name: String
    let type: String
    let threshold: Double
    let enabled: Bool
    let lastTriggered: String?
}

private struct VisionAlertTrigger: Decodable, Identifiable {
    let id: String
    let ruleName: String
    let triggeredAt: String
    let value: Double
    let threshold: Double
    let message: String
    let acknowledged: Bool
}

struct VisionAlertsView: View {
    @State private var rules: [VisionAlertRule] = []
    @State private var triggers: [VisionAlertTrigger] = []
    @State private var error: String?
    @State private var loading = false
    @State private var acknowledging: Set<String> = []
    @State private var updatedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Alertas", systemImage: "bell.badge").font(.largeTitle.bold())
                    Spacer()
                    if loading { ProgressView() }
                    Button("Atualizar", systemImage: "arrow.clockwise") { Task { await refresh() } }
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                HStack(spacing: 14) {
                    countCard("Regras ativas", rules.filter(\.enabled).count, symbol: "checkmark.shield")
                    countCard("Não reconhecidos", triggers.filter { !$0.acknowledged }.count, symbol: "bell.fill")
                }
                section("Disparos recentes", symbol: "bolt.badge.clock") {
                    if triggers.isEmpty {
                        empty("Nenhum disparo registrado.")
                    } else {
                        ForEach(triggers) { trigger in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: trigger.acknowledged ? "checkmark.circle" : "exclamationmark.circle.fill")
                                    .foregroundStyle(trigger.acknowledged ? .green : .orange)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(trigger.ruleName).font(.headline)
                                    Text(trigger.message).font(.callout)
                                    Text("Valor \(trigger.value.formatted()) · limite \(trigger.threshold.formatted())")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(trigger.triggeredAt.replacingOccurrences(of: "T", with: " "))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if !trigger.acknowledged {
                                    Button("Reconhecer") { Task { await acknowledge(trigger) } }
                                        .disabled(acknowledging.contains(trigger.id))
                                }
                            }
                            .padding(14)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                section("Regras do servidor", symbol: "slider.horizontal.3") {
                    if rules.isEmpty {
                        empty("Nenhuma regra cadastrada.")
                    } else {
                        ForEach(rules) { rule in
                            HStack {
                                Image(systemName: rule.enabled ? "checkmark.circle.fill" : "pause.circle")
                                    .foregroundStyle(rule.enabled ? .green : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(rule.name).font(.headline)
                                    Text("\(rule.type.replacingOccurrences(of: "_", with: " ")) · limite \(rule.threshold.formatted())")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(rule.enabled ? "Ativa" : "Pausada")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                if let updatedAt {
                    Text("Atualizado \(updatedAt.formatted(date: .omitted, time: .standard)) · MeuLab API")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .task {
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(30)) }
                catch { break }
            }
        }
    }

    private func section<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol).font(.title2.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func countCard(_ title: String, _ count: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text("\(count)").font(.title.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func empty(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).padding(12)
    }

    private func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let api = try VisionAPIClient()
            async let fetchedRules: [VisionAlertRule] = api.fetch("api/alerts/rules")
            async let fetchedTriggers: [VisionAlertTrigger] = api.fetch("api/alerts/triggers?limit=40")
            (rules, triggers) = try await (fetchedRules, fetchedTriggers)
            error = nil
            updatedAt = Date()
        } catch { self.error = error.localizedDescription }
    }

    private func acknowledge(_ trigger: VisionAlertTrigger) async {
        guard let id = trigger.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        acknowledging.insert(trigger.id)
        defer { acknowledging.remove(trigger.id) }
        do {
            let _: VisionAlertTrigger = try await VisionAPIClient().post("api/alerts/triggers/\(id)/ack")
            await refresh()
        } catch { self.error = error.localizedDescription }
    }
}
