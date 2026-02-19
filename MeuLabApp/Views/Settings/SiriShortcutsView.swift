import SwiftUI
import Intents
import IntentsUI

// MARK: - Siri Shortcuts Configuration

@available(iOS 12.0, *)
class MeuLabIntentHandler: NSObject, MeuLabCheckSystemIntentHandling, MeuLabRunHealthCheckIntentHandling, MeuLabGetStatusIntentHandling {
    
    func handle(intent: MeuLabCheckSystemIntent, completion: @escaping (MeuLabCheckSystemIntentResponse) -> Void) {
        Task {
            do {
                let systemStatus = try await APIService.shared.fetchSystemStatus()
                
                let response = MeuLabCheckSystemIntentResponse(code: .success, userActivity: nil)
                response.systemStatus = formatSystemStatus(systemStatus)
                
                completion(response)
            } catch {
                let response = MeuLabCheckSystemIntentResponse(code: .failure, userActivity: nil)
                response.error = "Erro ao verificar sistema: \(error.localizedDescription)"
                
                completion(response)
            }
        }
    }
    
    func handle(intent: MeuLabRunHealthCheckIntent, completion: @escaping (MeuLabRunHealthCheckIntentResponse) -> Void) {
        Task {
            do {
                let healthReport = try await APIService.shared.runHealthCheck()
                
                let response = MeuLabRunHealthCheckIntentResponse(code: .success, userActivity: nil)
                response.healthScore = Int(healthReport.score)
                response.status = healthReport.overallStatus.rawValue
                
                completion(response)
            } catch {
                let response = MeuLabRunHealthCheckIntentResponse(code: .failure, userActivity: nil)
                response.error = "Erro ao executar health check: \(error.localizedDescription)"
                
                completion(response)
            }
        }
    }
    
    func handle(intent: MeuLabGetStatusIntent, completion: @escaping (MeuLabGetStatusIntentResponse) -> Void) {
        Task {
            do {
                let systemStatus = try await APIService.shared.fetchSystemStatus()
                
                let response = MeuLabGetStatusIntentResponse(code: .success, userActivity: nil)
                response.cpuUsage = systemStatus.cpu?.usagePercent ?? 0
                response.memoryUsage = systemStatus.memory?.usedPercent ?? 0
                response.diskUsage = systemStatus.disk?.usedPercent ?? 0
                
                if let temp = systemStatus.cpu?.temperatureC {
                    response.temperature = temp
                }
                
                completion(response)
            } catch {
                let response = MeuLabGetStatusIntentResponse(code: .failure, userActivity: nil)
                response.error = "Erro ao obter status: \(error.localizedDescription)"
                
                completion(response)
            }
        }
    }
    
    private func formatSystemStatus(_ status: SystemStatus) -> INText {
        let components = [
            "CPU: \(Int(status.cpu?.usagePercent ?? 0))%",
            "RAM: \(Int(status.memory?.usedPercent ?? 0))%",
            "Disco: \(Int(status.disk?.usedPercent ?? 0))%"
        ]
        
        return INText(string: components.joined(separator: " "))
    }
}

// MARK: - Siri Shortcuts Views

@available(iOS 12.0, *)
struct SiriShortcutsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSetup = false
    @State private var shortcuts: [SiriShortcut] = []
    
    var body: some View {
        NavigationView {
            List {
                Section("Atalhos Disponíveis") {
                    ForEach(shortcuts) { shortcut in
                        SiriShortcutRow(shortcut: shortcut)
                    }
                }
                
                Section("Configuração") {
                    Button("Adicionar Atalhos à Biblioteca") {
                        showingSetup = true
                    }
                    
                    Button("Abrir Configurações do Siri") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
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
                        Text("Compatibilidade")
                        Spacer()
                        Text("iOS 14.0+")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Siri Shortcuts")
            .onAppear {
                loadShortcuts()
            }
            .sheet(isPresented: $showingSetup) {
                SiriShortcutsSetupView(shortcuts: shortcuts)
            }
        }
    }
    
    private func loadShortcuts() {
        shortcuts = [
            SiriShortcut(
                id: "check_system",
                title: "Verificar Sistema MeuLab",
                description: "Mostra status completo do sistema",
                intent: MeuLabCheckSystemIntent(),
                suggestedInvocation: "Verificar sistema MeuLab",
                icon: "cpu",
                category: .checkSystem
            ),
            SiriShortcut(
                id: "health_check",
                title: "Health Check MeuLab",
                description: "Executa verificação de saúde completa",
                intent: MeuLabRunHealthCheckIntent(),
                suggestedInvocation: "Health Check MeuLab",
                icon: "heart.text.square",
                category: .healthCheck
            ),
            SiriShortcut(
                id: "get_status",
                title: "Status Rápido MeuLab",
                description: "Mostra métricas principais do sistema",
                intent: MeuLabGetStatusIntent(),
                suggestedInvocation: "Status MeuLab",
                icon: "speedometer",
                category: .getStatus
            ),
            SiriShortcut(
                id: "restart_service",
                title: "Reiniciar Serviço MeuLab",
                description: "Reinicia serviços do sistema",
                intent: MeuLabRestartServiceIntent(),
                suggestedInvocation: "Reiniciar MeuLab",
                icon: "arrow.clockwise",
                category: .restartService
            ),
            SiriShortcut(
                id: "get_weather",
                title: "Clima MeuLab",
                description: "Mostra informações do clima",
                intent: MeuLabGetWeatherIntent(),
                suggestedInvocation: "Clima MeuLab",
                icon: "cloud.sun",
                category: .getWeather
            ),
            SiriShortcut(
                id: "get_flights",
                title: "Voos MeuLab",
                description: "Mostra tráfego aéreo atual",
                intent: MeuLabGetFlightsIntent(),
                suggestedInvocation: "Voos MeuLab",
                icon: "airplane",
                category: .getFlights
            ),
            SiriShortcut(
                id: "get_alerts",
                title: "Alertas MeuLab",
                description: "Mostra alertas ativos",
                intent: MeuLabGetAlertsIntent(),
                suggestedInvocation: "Alertas MeuLab",
                icon: "bell.badge",
                category: .getAlerts
            ),
            SiriShortcut(
                id: "clear_cache",
                title: "Limpar Cache MeuLab",
                description: "Limpa cache do sistema",
                intent: MeuLabClearCacheIntent(),
                suggestedInvocation: "Limpar Cache MeuLab",
                icon: "trash",
                category: .clearCache
            )
        ]
    }
}

struct SiriShortcutRow: View {
    let shortcut: SiriShortcut
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: shortcut.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(shortcut.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "plus.circle")
                .font(.title2)
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            addShortcut(shortcut)
        }
    }
    
    private func addShortcut(_ shortcut: SiriShortcut) {
        let intent = shortcut.intent
        
        if let shortcut = INShortcut(intent: intent) {
            let voiceShortcut = INVoiceShortcut(identifier: shortcut.id, invocationPhrase: shortcut.suggestedInvocation, shortcut: shortcut)
            
            INVoiceShortcutCenter.shared.setShortcutSuggestions([voiceShortcut])
        }
    }
}

struct SiriShortcutsSetupView: View {
    let shortcuts: [SiriShortcut]
    @Environment(\.dismiss) private var dismiss
    @State private var addingAll = false
    @State private var successCount = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Adicionar Atalhos Siri")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Adicione os atalhos do MeuLab à biblioteca do Siri para usar comandos de voz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    ForEach(shortcuts) { shortcut in
                        SiriSetupRow(shortcut: shortcut)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(addingAll ? "Adicionando..." : "Adicionar Todos") {
                        addAllShortcuts()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(addingAll)
                    
                    if successCount > 0 {
                        Text("✅ \(successCount) atalho\(successCount == 1 ? "" : "s") adicionado\(successCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding()
            .navigationTitle("Configurar Siri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addAllShortcuts() {
        addingAll = true
        successCount = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            for shortcut in shortcuts {
                if let intent = shortcut.intent {
                    if let shortcut = INShortcut(intent: intent) {
                        let voiceShortcut = INVoiceShortcut(identifier: shortcut.id, invocationPhrase: shortcut.suggestedInvocation, shortcut: shortcut)
                        INVoiceShortcutCenter.shared.setShortcutSuggestions([voiceShortcut])
                        successCount += 1
                    }
                }
                
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            addingAll = false
        }
    }
}

struct SiriSetupRow: View {
    let shortcut: SiriShortcut
    @State private var isAdded = false
    
    var body: some View {
        HStack {
            Image(systemName: shortcut.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\"\(shortcut.suggestedInvocation)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            
            Spacer()
            
            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else {
                Button("Adicionar") {
                    addShortcut()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func addShortcut() {
        if let intent = shortcut.intent {
            if let shortcut = INShortcut(intent: intent) {
                let voiceShortcut = INVoiceShortcut(identifier: shortcut.id, invocationPhrase: shortcut.suggestedInvocation, shortcut: shortcut)
                INVoiceShortcutCenter.shared.setShortcutSuggestions([voiceShortcut])
                
                withAnimation {
                    isAdded = true
                }
            }
        }
    }
}

// MARK: - Siri Shortcut Model

struct SiriShortcut {
    let id: String
    let title: String
    let description: String
    let intent: INIntent
    let suggestedInvocation: String
    let icon: String
    let category: SiriShortcutCategory
}

enum SiriShortcutCategory {
    case checkSystem
    case healthCheck
    case getStatus
    case restartService
    case getWeather
    case getFlights
    case getAlerts
    case clearCache
}

#Preview {
    SiriShortcutsView()
        .environmentObject(AppState())
}