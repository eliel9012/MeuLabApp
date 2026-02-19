import SwiftUI

struct RemoteControlView: View {
    @EnvironmentObject var appState: AppState
    @State private var commands: [RemoteCommand] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingCommandSheet = false
    @State private var selectedCommand: RemoteCommand?
    @State private var commandToExecute: CommandType?
    @State private var targetService: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Commands
                    recentCommandsSection
                    
                    if isLoading {
                        ProgressView("Carregando comandos...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    
                    if let error = error {
                        ErrorCard(message: error)
                            .onTapGesture {
                                loadCommands()
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Controle Remoto")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Histórico") {
                        // Show command history
                    }
                }
            }
            .refreshable {
                loadCommands()
            }
        }
        .onAppear {
            loadCommands()
        }
        .sheet(isPresented: $showingCommandSheet) {
            if let command = selectedCommand {
                CommandDetailView(command: command)
            }
        }
        .alert("Confirmar Comando", isPresented: .constant(commandToExecute != nil)) {
            if let command = commandToExecute {
                Button("Cancelar", role: .cancel) {
                    commandToExecute = nil
                }
                Button("Executar") {
                    executeCommand(command)
                    commandToExecute = nil
                }
            }
        } message: {
            if let command = commandToExecute {
                Text("Tem certeza que deseja executar '\(command.displayName)'?")
            }
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ações Rápidas")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(quickActions, id: \.type) { action in
                    QuickActionCard(
                        title: action.title,
                        description: action.description,
                        icon: action.icon,
                        color: action.color,
                        isDestructive: action.isDestructive
                    ) {
                        if action.requiresTarget {
                            // Show target selection
                            targetService = "adsb-receiver" // Default
                            commandToExecute = action.type
                        } else {
                            commandToExecute = action.type
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var recentCommandsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Comandos Recentes")
                .font(.title2)
                .fontWeight(.bold)
            
            if commands.isEmpty {
                EmptyStateCard(
                    title: "Nenhum comando recente",
                    description: "Os comandos executados aparecerão aqui",
                    systemImage: "terminal"
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(commands.prefix(5), id: \.id) { command in
                        CommandRow(command: command) {
                            selectedCommand = command
                            showingCommandSheet = true
                        }
                    }
                    
                    if commands.count > 5 {
                        Button("Ver todos os comandos") {
                            // Navigate to full command history
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var quickActions: [(type: CommandType, title: String, description: String, icon: String, color: Color, isDestructive: Bool, requiresTarget: Bool)] {
        [
            (.restartService, "Restart Serviço", "Reiniciar serviço específico", "arrow.clockwise", .orange, false, true),
            (.clearCache, "Limpar Cache", "Limpar cache do sistema", "trash", .blue, false, false),
            (.runHealthCheck, "Health Check", "Verificar saúde do sistema", "heart.text.square", .green, false, false),
            (.backupConfig, "Backup", "Fazer backup das configurações", "square.and.arrow.up", .purple, false, false),
            (.cleanupLogs, "Limpar Logs", "Limpar logs antigos", "doc.text.magnifyingglass", .yellow, false, false),
            (.updateSystem, "Atualizar", "Atualizar sistema", "arrow.down.circle", .indigo, false, false)
        ]
    }
    
    private func loadCommands() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let loadedCommands = try await APIService.shared.fetchRemoteCommands()
                await MainActor.run {
                    self.commands = loadedCommands
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
    
    private func executeCommand(_ type: CommandType) {
        let command = RemoteCommand(
            id: UUID().uuidString,
            command: type,
            target: type == .restartService ? targetService : nil,
            parameters: nil,
            status: .pending,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            startedAt: nil,
            completedAt: nil,
            output: nil,
            error: nil
        )
        
        Task {
            do {
                let executedCommand = try await APIService.shared.executeRemoteCommand(command)
                await MainActor.run {
                    commands.insert(executedCommand, at: 0)
                }
            } catch {
                await MainActor.run {
                    self.error = "Erro ao executar comando: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isDestructive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(isDestructive ? .white : color)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(isDestructive ? Color.red : color.opacity(0.1))
                    )
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Command Row

struct CommandRow: View {
    let command: RemoteCommand
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(command.command.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                CommandStatusBadge(status: command.status)
            }
            
            if let target = command.target {
                Text("Target: \(target)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(formatDate(command.createdAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            if let output = command.output, !output.isEmpty {
                Text(output.prefix(100) + (output.count > 100 ? "..." : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            
            if let error = command.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
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
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

// MARK: - Command Status Badge

struct CommandStatusBadge: View {
    let status: CommandStatus
    
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

// MARK: - Command Detail View

struct CommandDetailView: View {
    let command: RemoteCommand
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false
    @State private var updatedCommand: RemoteCommand?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    commandHeader
                    
                    // Status
                    statusSection
                    
                    // Output
                    if let output = (updatedCommand?.output ?? command.output), !output.isEmpty {
                        outputSection(output)
                    }
                    
                    // Error
                    if let error = (updatedCommand?.error ?? command.error) {
                        errorSection(error)
                    }
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Detalhes do Comando")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Concluído") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                updatedCommand = command
            }
        }
    }
    
    @ViewBuilder
    private var commandHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(command.command.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                CommandStatusBadge(status: updatedCommand?.status ?? command.status)
            }
            
            if let target = command.target {
                Text("Target: \(target)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Text("Criado em: \(formatFullDate(command.createdAt))")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            if let startedAt = command.startedAt {
                Text("Iniciado em: \(formatFullDate(startedAt))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            if let completedAt = command.completedAt {
                Text("Concluído em: \(formatFullDate(completedAt))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
            
            HStack {
                Image(systemName: statusIconName)
                    .font(.title2)
                    .foregroundStyle((updatedCommand?.status ?? command.status).color)
                
                Text((updatedCommand?.status ?? command.status).displayName)
                    .font(.subheadline)
                
                Spacer()
                
                if (updatedCommand?.status ?? command.status) == .running {
                    Button("Atualizar") {
                        refreshCommand()
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func outputSection(_ output: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saída")
                .font(.headline)
            
            Text(output)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color.black)
                .foregroundStyle(.green)
                .cornerRadius(8)
                .textSelection(.enabled)
        }
    }
    
    @ViewBuilder
    private func errorSection(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Erro")
                .font(.headline)
                .foregroundStyle(.red)
            
            Text(error)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
    }
    
    @ViewBuilder
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if (updatedCommand?.status ?? command.status) == .failed {
                Button("Tentar Novamente") {
                    retryCommand()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            
            if (updatedCommand?.status ?? command.status) == .pending {
                Button("Cancelar") {
                    cancelCommand()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
    }
    
    private var statusIconName: String {
        switch updatedCommand?.status ?? command.status {
        case .pending: return "clock"
        case .running: return "gear.badge"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .cancelled: return "stop.circle"
        }
    }
    
    private func formatFullDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .medium
        return displayFormatter.string(from: date)
    }
    
    private func refreshCommand() {
        isRefreshing = true
        
        Task {
            do {
                let refreshedCommand = try await APIService.shared.fetchRemoteCommand(id: command.id)
                await MainActor.run {
                    self.updatedCommand = refreshedCommand
                    self.isRefreshing = false
                }
            } catch {
                await MainActor.run {
                    self.isRefreshing = false
                }
            }
        }
    }
    
    private func retryCommand() {
        // Implement retry logic
    }
    
    private func cancelCommand() {
        Task {
            do {
                _ = try await APIService.shared.cancelRemoteCommand(id: command.id)
                refreshCommand()
            } catch {
                // Handle error
            }
        }
    }
}

// MARK: - Extensions

extension CommandType {
    var displayName: String {
        switch self {
        case .restartService: return "Reiniciar Serviço"
        case .stopService: return "Parar Serviço"
        case .startService: return "Iniciar Serviço"
        case .clearCache: return "Limpar Cache"
        case .runHealthCheck: return "Health Check"
        case .backupConfig: return "Backup Config"
        case .restoreConfig: return "Restaurar Config"
        case .cleanupLogs: return "Limpar Logs"
        case .updateSystem: return "Atualizar Sistema"
        }
    }
}

extension CommandStatus {
    var displayName: String {
        switch self {
        case .pending: return "Pendente"
        case .running: return "Executando"
        case .completed: return "Concluído"
        case .failed: return "Falhou"
        case .cancelled: return "Cancelado"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

#Preview {
    RemoteControlView()
        .environmentObject(AppState())
}