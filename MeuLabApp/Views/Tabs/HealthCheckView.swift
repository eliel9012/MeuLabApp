import SwiftUI

struct HealthCheckView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("health_incident_notes") private var incidentNotes: String = ""
    @State private var currentReport: HealthCheckReport?
    @State private var historyReports: [HealthCheckReport] = []
    @State private var isRunningCheck = false
    @State private var isLoading = false
    @State private var error: String?
    @State private var autoCheckEnabled = false
    @State private var checkInterval: CheckInterval = .hourly
    @State private var autoCheckTimer: Timer?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Current Status
                    if let report = currentReport {
                        currentHealthSection(report)
                    }
                    
                    // Auto Check Settings
                    autoCheckSection
                    
                    // Quick Actions
                    quickActionsSection

                    // Incident Notes (Writing Tools works here)
                    incidentNotesSection
                    
                    // History
                    if !historyReports.isEmpty {
                        historySection
                    }
                    
                    if isLoading {
                        ProgressView("Carregando relatórios...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    
                    if let error = error {
                        ErrorCard(message: error)
                            .onTapGesture {
                                loadHealthReports()
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Health Checks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Histórico Completo") {
                            // Navigate to full history
                        }
                        
                        Button("Exportar Relatório") {
                            exportCurrentReport()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                loadHealthReports()
            }
            .onAppear {
                loadHealthReports()
                setupAutoCheck()
            }
            .onDisappear {
                stopAutoCheck()
            }
        }
    }

    @ViewBuilder
    private var incidentNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notas do Incidente")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if !incidentNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Limpar") {
                        incidentNotes = ""
                    }
                    .font(.subheadline)
                }
            }

            TextEditor(text: $incidentNotes)
                .textInputAutocapitalization(.sentences)
                .frame(minHeight: 140)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func currentHealthSection(_ report: HealthCheckReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Status Atual")
                .font(.title2)
                .fontWeight(.bold)
            
            // Overall Score
            VStack(spacing: 12) {
                HStack {
                    Text("Score de Saúde")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(String(format: "%.0f", report.score))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(scoreColor(report.score))
                }
                
                // Progress Bar
                ProgressView(value: report.score, total: 100)
                    .tint(scoreColor(report.score))
                
                // Overall Status
                HStack {
                    HealthStatusBadge(status: report.overallStatus)
                    
                    Spacer()
                    
                    Text("Verificado em \(formatTime(report.timestamp))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Individual Checks
            VStack(alignment: .leading, spacing: 12) {
                Text("Verificações Individuais")
                    .font(.headline)
                
                ForEach(report.checks) { check in
                    HealthCheckRow(check: check)
                }
            }
        }
    }
    
    @ViewBuilder
    private var autoCheckSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verificação Automática")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                HStack {
                    Toggle("Ativar verificação automática", isOn: $autoCheckEnabled)
                        .onChange(of: autoCheckEnabled) { _, newValue in
                            if newValue {
                                startAutoCheck()
                            } else {
                                stopAutoCheck()
                            }
                        }
                    
                    Spacer()
                }
                
                if autoCheckEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Intervalo de verificação")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Picker("Intervalo", selection: $checkInterval) {
                            ForEach(CheckInterval.allCases, id: \.self) { interval in
                                Text(interval.displayName).tag(interval)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: checkInterval) { _, _ in
                            restartAutoCheck()
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ações Rápidas")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                HealthActionButton(
                    title: "Verificar Agora",
                    description: "Executar verificação completa",
                    icon: "play.circle.fill",
                    color: .blue
                ) {
                    runHealthCheck()
                }
                
                HealthActionButton(
                    title: "Relatório Detalhado",
                    description: "Ver resultados completos",
                    icon: "doc.text.fill",
                    color: .purple
                ) {
                    showDetailedReport()
                }
                
                HealthActionButton(
                    title: "Corrigir Problemas",
                    description: "Executar correções automáticas",
                    icon: "wrench.fill",
                    color: .orange
                ) {
                    autoFixIssues()
                }
                
                HealthActionButton(
                    title: "Configurar Alertas",
                    description: "Notificações de problemas",
                    icon: "bell.fill",
                    color: .red
                ) {
                    configureAlerts()
                }
            }
        }
    }
    
    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Histórico Recente")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ForEach(historyReports.prefix(5), id: \.timestamp) { report in
                    HealthHistoryRow(report: report) {
                        // Show report details
                    }
                }
                
                if historyReports.count > 5 {
                    Button("Ver todo o histórico") {
                        // Navigate to full history
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func loadHealthReports() {
        isLoading = true
        error = nil
        
        Task {
            do {
                async let currentTask = APIService.shared.runHealthCheck()
                async let historyTask = APIService.shared.fetchHealthReports()
                
                let (current, history) = try await (currentTask, historyTask)
                
                await MainActor.run {
                    self.currentReport = current
                    self.historyReports = history
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
    
    private func runHealthCheck() {
        isRunningCheck = true
        
        Task {
            do {
                let report = try await APIService.shared.runHealthCheck()
                
                await MainActor.run {
                    self.currentReport = report
                    self.historyReports.insert(report, at: 0)
                    self.isRunningCheck = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isRunningCheck = false
                }
            }
        }
    }
    
    private func setupAutoCheck() {
        // Load settings from UserDefaults
        autoCheckEnabled = UserDefaults.standard.bool(forKey: "autoHealthCheck")
        checkInterval = CheckInterval(rawValue: UserDefaults.standard.string(forKey: "healthCheckInterval") ?? CheckInterval.hourly.rawValue) ?? .hourly
        
        if autoCheckEnabled {
            startAutoCheck()
        }
    }
    
    private func startAutoCheck() {
        stopAutoCheck()
        
        autoCheckTimer = Timer.scheduledTimer(withTimeInterval: checkInterval.seconds, repeats: true) { _ in
            runHealthCheck()
        }
        
        // Save settings
        UserDefaults.standard.set(true, forKey: "autoHealthCheck")
        UserDefaults.standard.set(checkInterval.rawValue, forKey: "healthCheckInterval")
    }
    
    private func stopAutoCheck() {
        autoCheckTimer?.invalidate()
        autoCheckTimer = nil
        UserDefaults.standard.set(false, forKey: "autoHealthCheck")
    }
    
    private func restartAutoCheck() {
        if autoCheckEnabled {
            startAutoCheck()
        }
    }
    
    private func showDetailedReport() {
        // Navigate to detailed report view
    }
    
    private func autoFixIssues() {
        // Implement auto-fix logic
    }
    
    private func configureAlerts() {
        // Navigate to alert configuration
    }
    
    private func exportCurrentReport() {
        guard let report = currentReport else { return }
        
        Task {
            do {
                let exportRequest = ExportRequest(
                    dataType: .alerts,
                    format: .json,
                    dateFrom: nil,
                    dateTo: nil,
                    filters: ["health_check_report": AnyCodable(report.timestamp)]
                )
                
                let data = try await APIService.shared.exportData(exportRequest)
                
                await MainActor.run {
                    // Share the data
                    print("Health check report exported: \(data.count) bytes")
                }
            } catch {
                await MainActor.run {
                    self.error = "Erro ao exportar relatório: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func formatTime(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct HealthCheckRow: View {
    let check: HealthCheck
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(check.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(check.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HealthStatusBadge(status: check.status)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct HealthStatusBadge: View {
    let status: HealthStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(status.displayName)
                .font(.caption)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct HealthActionButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct HealthHistoryRow: View {
    let report: HealthCheckReport
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(report.timestamp))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formatTimeAgo(report.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.0f", report.score))
                    .font(.headline)
                    .foregroundStyle(scoreColor(report.score))
                
                HealthStatusBadge(status: report.overallStatus)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .short
        return displayFormatter.string(from: date)
    }
    
    private func formatTimeAgo(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        return Formatters.relativeDate.localizedString(for: date, relativeTo: Date())
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Enums

enum CheckInterval: String, CaseIterable {
    case every15min = "15min"
    case every30min = "30min"
    case hourly = "hourly"
    case every6hours = "6hours"
    case daily = "daily"
    
    var displayName: String {
        switch self {
        case .every15min: return "15 min"
        case .every30min: return "30 min"
        case .hourly: return "1 hora"
        case .every6hours: return "6 horas"
        case .daily: return "Diário"
        }
    }
    
    var seconds: TimeInterval {
        switch self {
        case .every15min: return 15 * 60
        case .every30min: return 30 * 60
        case .hourly: return 60 * 60
        case .every6hours: return 6 * 60 * 60
        case .daily: return 24 * 60 * 60
        }
    }
}

// MARK: - Extensions

extension HealthStatus {
    var displayName: String {
        switch self {
        case .healthy: return "Saudável"
        case .warning: return "Aviso"
        case .critical: return "Crítico"
        case .unknown: return "Desconhecido"
        }
    }
    
    var color: Color {
        switch self {
        case .healthy: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }
}

#Preview {
    HealthCheckView()
        .environmentObject(AppState())
}
