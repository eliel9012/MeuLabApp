import SwiftUI

struct ThemeManagerView: View {
    @EnvironmentObject var appState: AppState
    @State private var themeSettings: ThemeSettings
    @State private var isLoading = false
    @State private var error: String?
    @State private var lightModeTime: Date = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: "06:00") ?? Date()
    }()
    @State private var darkModeTime: Date = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: "20:00") ?? Date()
    }()

    init() {
        // Initialize with default values
        let defaultSettings = ThemeSettings(
            mode: .system,
            autoSwitch: false,
            switchTime: SwitchTime(lightMode: "06:00", darkMode: "20:00"),
            followSystem: true
        )
        _themeSettings = State(initialValue: defaultSettings)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Modo de Aparência")) {
                    Picker("Tema", selection: $themeSettings.mode) {
                        Text("Claro").tag(ThemeMode.light)
                        Text("Escuro").tag(ThemeMode.dark)
                        Text("Sistema").tag(ThemeMode.system)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: themeSettings.mode) { _, _ in
                        saveThemeSettings()
                    }
                }
                
                Section(header: Text("Configurações Automáticas")) {
                    Toggle("Seguir sistema", isOn: $themeSettings.followSystem)
                        .onChange(of: themeSettings.followSystem) { _, _ in
                            saveThemeSettings()
                        }
                    
                    Toggle("Troca automática", isOn: $themeSettings.autoSwitch)
                        .onChange(of: themeSettings.autoSwitch) { _, _ in
                            saveThemeSettings()
                        }
                    
                    if themeSettings.autoSwitch {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Modo claro:")
                                    .font(.subheadline)
                                
                                DatePicker("", selection: $lightModeTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            
                            HStack {
                                Text("Modo escuro:")
                                    .font(.subheadline)
                                
                                DatePicker("", selection: $darkModeTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        .padding(.vertical, 4)
                        .onChange(of: lightModeTime) { _, _ in
                            updateSwitchTime()
                        }
                        .onChange(of: darkModeTime) { _, _ in
                            updateSwitchTime()
                        }
                    }
                }
                
                Section(header: Text("Preview")) {
                    ThemePreviewCards()
                        .environment(\.colorScheme, currentColorScheme)
                }
                
                Section(header: Text("Informações")) {
                    Text("Modo atual: \(currentColorScheme == .dark ? "Escuro" : "Claro")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if themeSettings.autoSwitch {
                        Text("Próxima troca: \(nextSwitchTime)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Aparência")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Restaurar") {
                        restoreDefaults()
                    }
                }
            }
            .onAppear {
                loadThemeSettings()
                setupThemeObserver()
            }
        }
    }
    
    private var currentColorScheme: ColorScheme {
        switch themeSettings.mode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return themeSettings.followSystem ? 
                (UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light) :
                shouldUseDarkMode() ? .dark : .light
        }
    }
    
    
    private var nextSwitchTime: String {
        guard let switchTime = themeSettings.switchTime else { return "Não definido" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let now = Date()
        let calendar = Calendar.current
        
        let lightTime = formatter.date(from: switchTime.lightMode) ?? Date()
        let darkTime = formatter.date(from: switchTime.darkMode) ?? Date()
        
        // Convert to today's date
        var lightToday = calendar.date(bySettingHour: calendar.component(.hour, from: lightTime),
                                    minute: calendar.component(.minute, from: lightTime),
                                    second: 0,
                                    of: now) ?? now
        
        var darkToday = calendar.date(bySettingHour: calendar.component(.hour, from: darkTime),
                                    minute: calendar.component(.minute, from: darkTime),
                                    second: 0,
                                    of: now) ?? now
        
        if shouldUseDarkMode() {
            // Currently dark, next switch is to light
            if lightToday <= now {
                lightToday = calendar.date(byAdding: .day, value: 1, to: lightToday) ?? lightToday
            }
            return "Claro em \(formatter.string(from: lightToday))"
        } else {
            // Currently light, next switch is to dark
            if darkToday <= now {
                darkToday = calendar.date(byAdding: .day, value: 1, to: darkToday) ?? darkToday
            }
            return "Escuro em \(formatter.string(from: darkToday))"
        }
    }
    
    private func shouldUseDarkMode() -> Bool {
        guard themeSettings.autoSwitch, let switchTime = themeSettings.switchTime else {
            return false
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let currentTime = formatter.string(from: Date())
        
        return currentTime >= switchTime.darkMode || currentTime < switchTime.lightMode
    }
    
    private func loadThemeSettings() {
        isLoading = true
        
        Task {
            do {
                let settings = try await APIService.shared.fetchThemeSettings()
                await MainActor.run {
                    self.themeSettings = settings
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    // Load from local storage as fallback
                    loadLocalThemeSettings()
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadLocalThemeSettings() {
        let defaults = UserDefaults.standard
        
        if let modeRaw = defaults.string(forKey: "themeMode"),
           let mode = ThemeMode(rawValue: modeRaw) {
            themeSettings.mode = mode
        }
        
        themeSettings.followSystem = defaults.bool(forKey: "followSystem")
        themeSettings.autoSwitch = defaults.bool(forKey: "autoSwitch")
        
        if defaults.bool(forKey: "autoSwitch") {
            let lightMode = defaults.string(forKey: "lightModeTime") ?? "06:00"
            let darkMode = defaults.string(forKey: "darkModeTime") ?? "20:00"
            themeSettings.switchTime = SwitchTime(lightMode: lightMode, darkMode: darkMode)
        }
    }
    
    private func saveThemeSettings() {
        Task {
            do {
                _ = try await APIService.shared.updateThemeSettings(themeSettings)
                await MainActor.run {
                    saveLocalThemeSettings()
                    applyTheme()
                }
            } catch {
                await MainActor.run {
                    self.error = "Erro ao salvar configurações: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func saveLocalThemeSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(themeSettings.mode.rawValue, forKey: "themeMode")
        defaults.set(themeSettings.followSystem, forKey: "followSystem")
        defaults.set(themeSettings.autoSwitch, forKey: "autoSwitch")
        
        if let switchTime = themeSettings.switchTime {
            defaults.set(switchTime.lightMode, forKey: "lightModeTime")
            defaults.set(switchTime.darkMode, forKey: "darkModeTime")
        }
    }
    
    private func applyTheme() {
        // This would typically update the app's appearance
        // In a real app, you might use UIAppearance or update @Environment values
        DispatchQueue.main.async {
            // Force appearance update
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = themeSettings.mode == .system ? .unspecified :
                        themeSettings.mode == .dark ? .dark : .light
                }
            }
        }
    }
    
    private func updateSwitchTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let lightTime = formatter.string(from: lightModeTime)
        let darkTime = formatter.string(from: darkModeTime)
        
        themeSettings.switchTime = SwitchTime(lightMode: lightTime, darkMode: darkTime)
        saveThemeSettings()
    }
    
    private func restoreDefaults() {
        themeSettings = ThemeSettings(
            mode: .system,
            autoSwitch: false,
            switchTime: SwitchTime(lightMode: "06:00", darkMode: "20:00"),
            followSystem: true
        )
        saveThemeSettings()
    }
    
    private func setupThemeObserver() {
        // Set up timer for automatic theme switching
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            if themeSettings.autoSwitch {
                applyTheme()
            }
        }
    }
}

// MARK: - Theme Preview Cards

struct ThemePreviewCards: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            // System Status Card Preview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status do Sistema")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("CPU: 45% | RAM: 2.1GB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Circle()
                    .fill(.green)
                    .frame(width: 12, height: 12)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            // Analytics Chart Preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Gráfico de Exemplo")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.blue)
                            .frame(width: 8, height: CGFloat.random(in: 20...60))
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            // Alert Card Preview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alerta de CPU")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("CPU > 80% detectado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button("Resolver") {
                    // Preview action
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Theme Extension for App

extension View {
    func adaptiveTheme() -> some View {
        self.modifier(AdaptiveThemeModifier())
    }
}

struct AdaptiveThemeModifier: ViewModifier {
    @AppStorage("themeMode") private var themeModeRaw: String = "system"
    @AppStorage("autoSwitch") private var autoSwitch: Bool = false
    @AppStorage("lightModeTime") private var lightModeTime: String = "06:00"
    @AppStorage("darkModeTime") private var darkModeTime: String = "20:00"
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(preferredColorScheme)
            .onAppear {
                setupThemeTimer()
            }
    }
    
    private var preferredColorScheme: ColorScheme? {
        guard let themeMode = ThemeMode(rawValue: themeModeRaw) else { return nil }
        
        switch themeMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            if autoSwitch && shouldUseDarkMode() {
                return .dark
            }
            return nil
        }
    }
    
    private func shouldUseDarkMode() -> Bool {
        guard autoSwitch else { return false }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let currentTime = formatter.string(from: Date())
        
        return currentTime >= darkModeTime || currentTime < lightModeTime
    }
    
    private func setupThemeTimer() {
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            // Force view update when theme changes
            DispatchQueue.main.async {
                // This will trigger the preferredColorScheme update
            }
        }
    }
}

#Preview {
    ThemeManagerView()
        .environmentObject(AppState())
}