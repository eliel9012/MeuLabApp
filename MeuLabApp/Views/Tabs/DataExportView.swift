import SwiftUI
import UniformTypeIdentifiers

struct DataExportView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDataType: ExportDataType = .systemMetrics
    @State private var selectedFormat: ExportFormat = .csv
    @State private var dateFrom: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var dateTo: Date = Date()
    @State private var hasDateFilter = false
    @State private var isExporting = false
    @State private var exportedData: Data?
    @State private var showingShareSheet = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tipo de Dados")) {
                    Picker("Dados", selection: $selectedDataType) {
                        ForEach(ExportDataType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Formato")) {
                    Picker("Formato", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Período")) {
                    Toggle("Filtrar por período", isOn: $hasDateFilter)
                    
                    if hasDateFilter {
                        DatePicker("De", selection: $dateFrom, displayedComponents: [.date])
                        DatePicker("Até", selection: $dateTo, displayedComponents: [.date])
                    }
                }
                
                Section(header: Text("Descrição")) {
                    Text(selectedDataType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Button(action: exportData) {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text("Exportar Dados")
                            Spacer()
                        }
                    }
                    .disabled(isExporting)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Exportar Dados")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ajuda") {
                        showHelp()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = exportedData {
                    ShareSheet(activityItems: [data, fileName])
                }
            }
        }
    }
    
    private var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return "\(selectedDataType.rawValue)_\(dateString).\(selectedFormat.rawValue)"
    }
    
    private func exportData() {
        isExporting = true
        errorMessage = nil
        
        let request = ExportRequest(
            dataType: selectedDataType,
            format: selectedFormat,
            dateFrom: hasDateFilter ? ISO8601DateFormatter().string(from: dateFrom) : nil,
            dateTo: hasDateFilter ? ISO8601DateFormatter().string(from: dateTo) : nil,
            filters: nil
        )
        
        Task {
            do {
                let data = try await APIService.shared.exportData(request)
                
                await MainActor.run {
                    self.exportedData = data
                    self.isExporting = false
                    self.showingShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Erro ao exportar dados: \(error.localizedDescription)"
                    self.isExporting = false
                }
            }
        }
    }
    
    private func showHelp() {
        let alert = UIAlertController(
            title: "Ajuda - Exportar Dados",
            message: """
            Use esta ferramenta para exportar dados do sistema em diferentes formatos:
            
            • **CSV**: Ideal para planilhas (Excel, Google Sheets)
            • **JSON**: Para desenvolvimento e análise
            • **XLSX**: Formato nativo do Excel (premium)
            
            Os dados incluem registros históricos baseados no período selecionado.
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - Export Extensions

extension ExportDataType {
    var displayName: String {
        switch self {
        case .systemMetrics: return "Métricas do Sistema"
        case .flights: return "Voos ADS-B"
        case .satellitePasses: return "Passes de Satélite"
        case .alerts: return "Alertas"
        case .dockerLogs: return "Logs Docker"
        }
    }
    
    var description: String {
        switch self {
        case .systemMetrics:
            return "Dados históricos de CPU, memória, disco e temperatura do sistema."
        case .flights:
            return "Registros completos de voos detectados pelo receptor ADS-B."
        case .satellitePasses:
            return "Informações detalhadas sobre passes de satélites e imagens capturadas."
        case .alerts:
            return "Histórico de alertas disparados e seu status de confirmação."
        case .dockerLogs:
            return "Logs de containers Docker para análise e troubleshooting."
        }
    }
}

extension ExportFormat {
    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .json: return "JSON"
        case .xlsx: return "XLSX"
        }
    }
    
    var mimeType: String {
        switch self {
        case .csv: return "text/csv"
        case .json: return "application/json"
        case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Advanced Export Options View

struct AdvancedExportView: View {
    @EnvironmentObject var appState: AppState
    @State private var exportRequests: [ExportRequest] = []
    @State private var showingAddExport = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                if exportRequests.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma exportação",
                        systemImage: "square.and.arrow.up",
                        description: Text("Crie novas exportações personalizadas")
                    )
                } else {
                    ForEach(exportRequests, id: \.dataType) { request in
                        ExportRequestRow(request: request) {
                            executeExport(request)
                        }
                    }
                }
            }
            .navigationTitle("Exportações")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExport = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExport) {
                CustomExportView { request in
                    exportRequests.append(request)
                }
            }
            .refreshable {
                loadRecentExports()
            }
        }
        .onAppear {
            loadRecentExports()
        }
    }
    
    private func executeExport(_ request: ExportRequest) {
        // Implementation for executing export
    }
    
    private func loadRecentExports() {
        // Load recent exports from storage or API
    }
}

struct ExportRequestRow: View {
    let request: ExportRequest
    let onExecute: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.dataType.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text(request.format.rawValue.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)
            }
            
            if let from = request.dateFrom, let to = request.dateTo {
                Text("\(formatDate(from)) - \(formatDate(to))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Button("Executar Exportação") {
                onExecute()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundStyle(.white)
            .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "dd/MM/yyyy"
        return displayFormatter.string(from: date)
    }
}

struct CustomExportView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (ExportRequest) -> Void
    
    @State private var selectedDataType: ExportDataType = .systemMetrics
    @State private var selectedFormat: ExportFormat = .csv
    @State private var dateFrom: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var dateTo: Date = Date()
    @State private var hasDateFilter = false
    @State private var customFilters: [String: AnyCodable] = [:]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Configuração da Exportação")) {
                    Picker("Tipo de Dados", selection: $selectedDataType) {
                        ForEach(ExportDataType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Picker("Formato", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                }
                
                Section(header: Text("Filtros")) {
                    Toggle("Filtrar por período", isOn: $hasDateFilter)
                    
                    if hasDateFilter {
                        DatePicker("De", selection: $dateFrom, displayedComponents: [.date, .hourAndMinute])
                        DatePicker("Até", selection: $dateTo, displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    // Add custom filters based on data type
                    customFilterSection
                }
                
                Section {
                    Button("Salvar Configuração") {
                        saveExport()
                    }
                }
            }
            .navigationTitle("Nova Exportação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var customFilterSection: some View {
        switch selectedDataType {
        case .flights:
            Section(header: Text("Filtres de Voo")) {
                TextField("Tipo de aeronave", text: binding(for: "aircraft_type"))
                TextField("Altitude mínima", text: binding(for: "altitude_min"))
                TextField("Altitude máxima", text: binding(for: "altitude_max"))
            }
        case .satellitePasses:
            Section(header: Text("Filtros de Satélite")) {
                TextField("Nome do satélite", text: binding(for: "satellite"))
                Toggle("Apenas passes com sucesso", isOn: boolBinding(for: "success_only"))
            }
        case .alerts:
            Section(header: Text("Filtros de Alertas")) {
                TextField("Tipo de alerta", text: binding(for: "alert_type"))
                Toggle("Apenas não confirmados", isOn: boolBinding(for: "unacknowledged_only"))
            }
        default:
            EmptyView()
        }
    }
    
    private func binding(for key: String) -> Binding<String> {
        Binding<String>(
            get: { (customFilters[key]?.value as? String) ?? "" },
            set: { customFilters[key] = AnyCodable($0) }
        )
    }

    private func boolBinding(for key: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { (customFilters[key]?.value as? Bool) ?? false },
            set: { customFilters[key] = AnyCodable($0) }
        )
    }
    
    private func saveExport() {
        let request = ExportRequest(
            dataType: selectedDataType,
            format: selectedFormat,
            dateFrom: hasDateFilter ? ISO8601DateFormatter().string(from: dateFrom) : nil,
            dateTo: hasDateFilter ? ISO8601DateFormatter().string(from: dateTo) : nil,
            filters: customFilters.isEmpty ? nil : customFilters
        )
        
        onSave(request)
        dismiss()
    }
}

#Preview {
    DataExportView()
        .environmentObject(AppState())
}
