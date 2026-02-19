import SwiftUI
import UserNotifications

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingNotifications = false
    @State private var pendingNotifications = 0
    
    var body: some View {
        NavigationStack {
            List {
                // Home Enhanced
                NavigationLink {
                    EnhancedHomeView()
                } label: {
                    Label("Resumo", systemImage: "square.grid.2x2")
                        .badge(pendingNotifications > 0 ? pendingNotifications : nil)
                }
                
                // Quick Actions
                Section("Ações Rápidas") {
                    NavigationLink {
                        QuickActionsView()
                    } label: {
                        Label("Ações Rápidas", systemImage: "bolt.circle")
                    }
                    
                    NavigationLink {
                        WatchAlertsView()
                    } label: {
                        Label("Alertas", systemImage: "bell.badge")
                            .badge(pendingNotifications > 0 ? pendingNotifications : nil)
                    }
                }
                
                // Enhanced Categories
                Section("Monitoramento") {
                    NavigationLink {
                        EnhancedWatchADSBView()
                    } label: {
                        Label("ADS-B", systemImage: "airplane.radar")
                    }
                    
                    NavigationLink {
                        EnhancedWatchSystemView()
                    } label: {
                        Label("Sistema", systemImage: "cpu")
                    }
                    
                    NavigationLink {
                        EnhancedWatchInfraView()
                    } label: {
                        Label("Infra", systemImage: "server.rack")
                    }
                }
                
                Section("Dados") {
                    NavigationLink {
                        EnhancedWatchACARSView()
                    } label: {
                        Label("ACARS", systemImage: "envelope.badge")
                    }
                    
                    NavigationLink {
                        EnhancedWatchWeatherView()
                    } label: {
                        Label("Clima", systemImage: "cloud.sun")
                    }
                    
                    NavigationLink {
                        EnhancedWatchSatDumpView()
                    } label: {
                        Label("SatDump", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
                
                Section("Configurações") {
                    NavigationLink {
                        WatchSettingsView()
                    } label: {
                        Label("Configurações", systemImage: "gear")
                    }
                    
                    NavigationLink {
                        WatchAboutView()
                    } label: {
                        Label("Sobre", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("MeuLab")
            .onAppear {
                setupNotifications()
                loadPendingNotifications()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    loadPendingNotifications()
                }
            }
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private func loadPendingNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            DispatchQueue.main.async {
                pendingNotifications = notifications.count
            }
        }
    }
}

// MARK: - Enhanced Home View

struct EnhancedHomeView: View {
    @State private var isLoading = true
    @State private var error: String?
    @State private var healthScore: Double = 0
    @State private var lastUpdate: Date = Date()
    @State private var quickStats: QuickStats?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Health Score
                HealthScoreCard(score: healthScore, lastUpdate: lastUpdate)
                
                if isLoading {
                    ProgressView("Carregando...")
                        .padding(.top, 20)
                } else if let error {
                    ErrorCard(message: error) {
                        Task { await loadData() }
                    }
                } else if let stats = quickStats {
                    // Quick Stats
                    QuickStatsGrid(stats: stats)
                    
                    // Critical Alerts
                    if stats.criticalAlerts > 0 {
                        CriticalAlertsCard(count: stats.criticalAlerts)
                    }
                    
                    // Quick Actions
                    QuickActionsRow()
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Resumo")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        error = nil
        
        do {
            async let systemTask = WatchAPIService.shared.fetchSystemStatus()
            async let adsbTask = WatchAPIService.shared.fetchADSBSummary()
            async let alertsTask = WatchAPIService.shared.fetchAlertsSummary()
            
            let (system, adsb, alerts) = try await (systemTask, adsbTask, alertsTask)
            
            await MainActor.run {
                self.healthScore = calculateHealthScore(system: system, adsb: adsb, alerts: alerts)
                self.lastUpdate = Date()
                self.quickStats = QuickStats(
                    system: system,
                    adsb: adsb,
                    alerts: alerts
                )
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func calculateHealthScore(system: WatchSystemData?, adsb: WatchADSBData?, alerts: Any) -> Double {
        var score: Double = 100
        
        if let system = system {
            if system.cpuPercent > 80 { score -= 20 }
            if system.memoryPercent > 80 { score -= 20 }
            if system.cpuTemp > 70 { score -= 15 }
        }
        
        return max(0, score)
    }
}

// MARK: - Quick Actions View

struct QuickActionsView: View {
    var body: some View {
        List {
            Section("Sistema") {
                Button("Reiniciar Serviço") {
                    Task { await restartService() }
                }
                .foregroundStyle(.red)
                
                Button("Limpar Cache") {
                    Task { await clearCache() }
                }
                
                Button("Health Check") {
                    Task { await runHealthCheck() }
                }
            }
            
            Section("Notificações") {
                Button("Enviar Teste") {
                    Task { await sendTestNotification() }
                }
                
                Button("Limpar Notificações") {
                    clearAllNotifications()
                }
            }
        }
        .navigationTitle("Ações Rápidas")
    }
    
    private func restartService() async {
        // Implementation
    }
    
    private func clearCache() async {
        // Implementation
    }
    
    private func runHealthCheck() async {
        // Implementation
    }
    
    private func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "MeuLab Test"
        content.body = "Notificação de teste do MeuLab"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// MARK: - Enhanced Views Components

struct HealthScoreCard: View {
    let score: Double
    let lastUpdate: Date
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Saúde do Sistema")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.3), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: score)
                
                Text("\(Int(score))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(scoreColor)
            }
            .frame(width: 60, height: 60)
            
            Text("Atualizado \(formatTime(lastUpdate))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }
    
    private var scoreColor: Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct QuickStatsGrid: View {
    let stats: QuickStats
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
            StatGridItem(
                title: "CPU",
                value: "\(Int(stats.system?.cpuPercent ?? 0))%",
                icon: "cpu",
                color: .blue
            )
            
            StatGridItem(
                title: "RAM",
                value: "\(Int(stats.system?.memoryPercent ?? 0))%",
                icon: "memorychip",
                color: .purple
            )
            
            StatGridItem(
                title: "Voos",
                value: "\(stats.adsb?.totalNow ?? 0)",
                icon: "airplane",
                color: .green
            )
            
            StatGridItem(
                title: "Alertas",
                value: "\(stats.alerts?.activeCount ?? 0)",
                icon: "bell.badge",
                color: .orange
            )
        }
    }
}

struct StatGridItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(8)
    }
}

struct CriticalAlertsCard: View {
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Alertas Críticos")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                
                Text("\(count) alert\(count == 1 ? "a" : "as") precisando atenção")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.red.opacity(0.2))
        .cornerRadius(8)
    }
}

struct QuickActionsRow: View {
    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                icon: "arrow.clockwise",
                title: "Restart",
                color: .orange
            ) {
                // Action
            }
            
            QuickActionButton(
                icon: "heart.text.square",
                title: "Health",
                color: .green
            ) {
                // Action
            }
            
            QuickActionButton(
                icon: "bell",
                title: "Alertas",
                color: .red
            ) {
                // Action
            }
        }
        .padding(.horizontal)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.darkGray).opacity(0.3))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct ErrorCard: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title)
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
            
            Button("Tentar novamente") {
                retry()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(.darkGray).opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Models

struct QuickStats {
    let system: WatchSystemData?
    let adsb: WatchADSBData?
    let alerts: AlertsSummary?
}

struct AlertsSummary {
    let activeCount: Int
    let criticalCount: Int
}

// MARK: - Watch Settings

struct WatchSettingsView: View {
    @AppStorage("watchAutoRefresh") private var autoRefresh: Bool = true
    @AppStorage("watchRefreshInterval") private var refreshInterval: Int = 30
    @AppStorage("watchNotifications") private var notifications: Bool = true
    
    var body: some View {
        List {
            Section("Atualização") {
                Toggle("Auto-refresh", isOn: $autoRefresh)
                
                if autoRefresh {
                    HStack {
                        Text("Intervalo")
                        Spacer()
                        Text("\(refreshInterval)s")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Notificações") {
                Toggle("Notificações", isOn: $notifications)
                
                if notifications {
                    Button("Configurar no iPhone") {
                        // Open companion app
                    }
                }
            }
            
            Section("Sobre") {
                HStack {
                    Text("Versão")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("API")
                    Spacer()
                    Text("app.meulab.fun")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Configurações")
    }
}

struct WatchAboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "cpu")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                    
                    Text("MeuLab Watch")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Monitoramento do sistema MeuLab no seu pulso")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            
            Section("Informações") {
                HStack {
                    Text("Versão")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Desenvolvimento")
                    Spacer()
                    Text("MeuLab.fun")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Sobre")
    }
}

// MARK: - Enhanced Category Views (placeholders for existing views)

struct EnhancedWatchADSBView: View {
    var body: some View {
        Text("Enhanced ADS-B View")
            .navigationTitle("ADS-B")
    }
}

struct EnhancedWatchSystemView: View {
    var body: some View {
        Text("Enhanced System View")
            .navigationTitle("Sistema")
    }
}

struct EnhancedWatchInfraView: View {
    var body: some View {
        Text("Enhanced Infra View")
            .navigationTitle("Infra")
    }
}

struct EnhancedWatchACARSView: View {
    var body: some View {
        Text("Enhanced ACARS View")
            .navigationTitle("ACARS")
    }
}

struct EnhancedWatchWeatherView: View {
    var body: some View {
        Text("Enhanced Weather View")
            .navigationTitle("Clima")
    }
}

struct EnhancedWatchSatDumpView: View {
    var body: some View {
        Text("Enhanced SatDump View")
            .navigationTitle("SatDump")
    }
}

struct WatchAlertsView: View {
    var body: some View {
        Text("Alerts View")
            .navigationTitle("Alertas")
    }
}

#Preview {
    EnhancedWatchContentView()
}