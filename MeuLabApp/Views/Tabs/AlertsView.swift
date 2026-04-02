import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var appState: AppState
    @State private var alertRules: [AlertRule] = []
    @State private var alertTriggers: [AlertTrigger] = []
    @State private var showingAddAlert = false
    @State private var showingEditAlert = false
    @State private var selectedRule: AlertRule?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Alert Rules Section
                    alertRulesSection

                    // Recent Triggers Section
                    recentTriggersSection

                    if isLoading {
                        ProgressView("Carregando alertas...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    if let error = error {
                        ErrorCard(message: error)
                            .onTapGesture {
                                loadAlerts()
                            }
                    }
                }
                .padding()
            }
            .refreshable {
                loadAlerts()
            }
            .navigationTitle("Alertas")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddAlert = true
                    } label: {
                        Image(systemName: "plus")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Adicionar alerta")
                }
            }
            .sheet(isPresented: $showingAddAlert) {
                AddEditAlertView(
                    isEditing: false,
                    alertRule: nil,
                    onSave: { rule in
                        saveAlertRule(rule)
                    }
                )
            }
            .sheet(isPresented: $showingEditAlert) {
                if let rule = selectedRule {
                    AddEditAlertView(
                        isEditing: true,
                        alertRule: rule,
                        onSave: { updatedRule in
                            updateAlertRule(updatedRule)
                        }
                    )
                }
            }
        }
        .onAppear {
            hydrateAlertsFromCache()
            loadAlerts()
        }
    }

    @ViewBuilder
    private var alertRulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Regras de Alerta")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text("\(alertRules.filter(\.enabled).count) ativas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }

            if alertRules.isEmpty {
                EmptyStateCard(
                    title: "Nenhuma regra de alerta",
                    description:
                        "Crie regras para ser notificado sobre eventos importantes do sistema",
                    systemImage: "bell.slash"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(alertRules) { rule in
                        AlertRuleCard(
                            rule: rule,
                            onToggle: {
                                toggleAlertRule(rule)
                            },
                            onEdit: {
                                selectedRule = rule
                                showingEditAlert = true
                            },
                            onDelete: {
                                deleteAlertRule(rule)
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentTriggersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Disparos Recentes")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if !alertTriggers.isEmpty {
                    Button("Ver todos") {
                        // Navigate to full triggers list
                    }
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            }

            if alertTriggers.isEmpty {
                EmptyStateCard(
                    title: "Nenhum disparo recente",
                    description: "Os disparos de alerta aparecerão aqui quando ocorrerem",
                    systemImage: "clock"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(alertTriggers.prefix(5)) { trigger in
                        AlertTriggerCard(
                            trigger: trigger,
                            onAcknowledge: {
                                acknowledgeAlert(trigger)
                            }
                        )
                    }
                }
            }
        }
    }

    private func loadAlerts() {
        isLoading = true
        error = nil

        Task {
            do {
                async let rulesTask = APIService.shared.fetchAlertRules()
                async let triggersTask = APIService.shared.fetchAlertTriggers(limit: 10)

                let (rules, triggers) = try await (rulesTask, triggersTask)

                await MainActor.run {
                    self.alertRules = rules
                    self.alertTriggers = triggers
                    AlertsScreenCache.payload = .init(rules: rules, triggers: triggers)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func hydrateAlertsFromCache() {
        guard let cached = AlertsScreenCache.payload else { return }
        alertRules = cached.rules
        alertTriggers = cached.triggers
    }

    private func saveAlertRule(_ rule: AlertRule) {
        Task {
            do {
                let savedRule = try await APIService.shared.createAlertRule(rule)
                await MainActor.run {
                    alertRules.append(savedRule)
                }
            } catch {
                await MainActor.run {
                    self.error = "Erro ao salvar regra: \(error.localizedDescription)"
                }
            }
        }
    }

    private func updateAlertRule(_ rule: AlertRule) {
        Task {
            do {
                let updatedRule = try await APIService.shared.updateAlertRule(rule)
                await MainActor.run {
                    if let index = alertRules.firstIndex(where: { $0.id == rule.id }) {
                        alertRules[index] = updatedRule
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Erro ao atualizar regra: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteAlertRule(_ rule: AlertRule) {
        Task {
            do {
                try await APIService.shared.deleteAlertRule(id: rule.id)
                await MainActor.run {
                    alertRules.removeAll { $0.id == rule.id }
                }
            } catch {
                await MainActor.run {
                    self.error = "Erro ao deletar regra: \(error.localizedDescription)"
                }
            }
        }
    }

    private func toggleAlertRule(_ rule: AlertRule) {
        var updatedRule = rule
        updatedRule.enabled.toggle()
        updateAlertRule(updatedRule)
    }

    private func acknowledgeAlert(_ trigger: AlertTrigger) {
        Task {
            do {
                _ = try await APIService.shared.acknowledgeAlert(id: trigger.id)
                await MainActor.run {
                    if let index = alertTriggers.firstIndex(where: { $0.id == trigger.id }) {
                        alertTriggers[index].acknowledged = true
                        alertTriggers[index].acknowledgedAt = ISO8601DateFormatter().string(
                            from: Date())
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Erro ao confirmar alerta: \(error.localizedDescription)"
                }
            }
        }
    }
}

private struct AlertsScreenCachePayload {
    let rules: [AlertRule]
    let triggers: [AlertTrigger]
}

private enum AlertsScreenCache {
    static var payload: AlertsScreenCachePayload?
}

// MARK: - Add/Edit Alert View

struct AddEditAlertView: View {
    let isEditing: Bool
    let alertRule: AlertRule?
    let onSave: (AlertRule) -> Void

    @State private var name: String = ""
    @State private var type: AlertType = .cpuUsage
    @State private var condition: AlertCondition = .greaterThan
    @State private var threshold: String = "80"
    @State private var notificationChannels: Set<NotificationChannel> = [.push]
    @State private var cooldownMinutes: String = "15"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Informações Básicas")) {

                    TextField("Nome do Alerta", text: $name)

                    Picker("Tipo de Alerta", selection: $type) {
                        ForEach(AlertType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section(header: Text("Condição")) {
                    Picker("Condição", selection: $condition) {
                        ForEach(AlertCondition.allCases, id: \.self) { condition in
                            Text(condition.displayName).tag(condition)
                        }
                    }

                    HStack {
                        Text("Valor Limite")
                        TextField("0", text: $threshold)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Notificação")) {
                    ForEach(NotificationChannel.allCases, id: \.self) { channel in
                        Toggle(channel.displayName, isOn: binding(for: channel))
                    }
                }

                Section(header: Text("Configurações Avançadas")) {
                    HStack {
                        Text("Cooldown (minutos)")
                        TextField("15", text: $cooldownMinutes)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(isEditing ? "Editar Alerta" : "Novo Alerta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        saveAlert()
                    }
                    .disabled(name.isEmpty || threshold.isEmpty)
                }
            }
            .onAppear {
                if let rule = alertRule {
                    name = rule.name
                    type = rule.type
                    condition = rule.condition
                    threshold = String(rule.threshold)
                    notificationChannels = Set(rule.notificationChannels)
                    cooldownMinutes = String(rule.cooldownMinutes)
                }
            }
        }
    }

    private func binding(for channel: NotificationChannel) -> Binding<Bool> {
        Binding<Bool>(
            get: { notificationChannels.contains(channel) },
            set: { isOn in
                if isOn {
                    notificationChannels.insert(channel)
                } else {
                    notificationChannels.remove(channel)
                }
            }
        )
    }

    private func saveAlert() {
        let rule = AlertRule(
            id: alertRule?.id ?? UUID().uuidString,
            name: name,
            type: type,
            condition: condition,
            threshold: Double(threshold) ?? 0,
            alertOperator: .and,
            enabled: true,
            notificationChannels: Array(notificationChannels),
            cooldownMinutes: Int(cooldownMinutes) ?? 15,
            createdAt: alertRule?.createdAt ?? ISO8601DateFormatter().string(from: Date()),
            lastTriggered: alertRule?.lastTriggered
        )

        onSave(rule)
        dismiss()
    }
}

// MARK: - Supporting Views

struct AlertRuleCard: View {
    let rule: AlertRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(rule.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Use a stateful toggle to avoid non-interactive constraint updates
                Toggle(
                    isOn: Binding(
                        get: { rule.enabled },
                        set: { _ in onToggle() }
                    )
                ) {
                    EmptyView()
                }
                .labelsHidden()
            }

            HStack {
                Text("\(rule.condition.displayName) \(Int(rule.threshold))\(rule.unit)")
                    .font(.subheadline)
                    .foregroundStyle(rule.enabled ? .primary : .secondary)

                Spacer()

                Text("\(rule.cooldownMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Notification Channels
            HStack {
                ForEach(rule.notificationChannels, id: \.self) { channel in
                    Text(channel.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .cornerRadius(4)
                }

                Spacer()

                // Action Buttons
                Menu {
                    Button("Editar", systemImage: "pencil") {
                        onEdit()
                    }
                    Button("Deletar", systemImage: "trash", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .opacity(rule.enabled ? 1.0 : 0.6)
    }
}

struct AlertTriggerCard: View {
    let trigger: AlertTrigger
    let onAcknowledge: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trigger.ruleName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(trigger.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    Formatters.relativeDate.localizedString(
                        for:
                            Formatters.isoDate.date(from: trigger.triggeredAt) ?? Date(),
                        relativeTo: Date())
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            if !trigger.acknowledged {
                Button("Confirmar") {
                    onAcknowledge()
                }
                .font(.caption)
                .adaptiveGlassProminentButton()
                .controlSize(.small)
            } else {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Confirmado")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 12)
    }
}

struct EmptyStateCard: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Extensions

extension AlertType {
    var displayName: String {
        switch self {
        case .cpuUsage: return "Uso de CPU"
        case .memoryUsage: return "Uso de Memória"
        case .diskUsage: return "Uso de Disco"
        case .temperature: return "Temperatura"
        case .aircraftCount: return "Contagem de Aeronaves"
        case .satellitePass: return "Passagem de Satélite"
        case .systemUptime: return "Uptime do Sistema"
        case .dockerContainer: return "Container Docker"
        }
    }
}

extension AlertCondition {
    var displayName: String {
        switch self {
        case .greaterThan: return "Maior que"
        case .lessThan: return "Menor que"
        case .equals: return "Igual a"
        case .notEquals: return "Diferente de"
        }
    }
}

extension NotificationChannel {
    var displayName: String {
        switch self {
        case .push: return "Push"
        case .email: return "Email"
        case .webhook: return "Webhook"
        }
    }
}

extension AlertRule {
    var unit: String {
        switch self.type {
        case .cpuUsage, .memoryUsage, .diskUsage: return "%"
        case .temperature: return "°C"
        case .aircraftCount, .systemUptime, .satellitePass, .dockerContainer: return ""
        }
    }
}

#Preview {
    AlertsView()
        .environmentObject(AppState())
}
