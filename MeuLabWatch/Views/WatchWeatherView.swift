import SwiftUI

/// Detalhes do Clima para watchOS
struct WatchWeatherView: View {
    @State private var isLoading = true
    @State private var weather: WatchWeatherData?
    @State private var error: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isLoading {
                    ProgressView("Carregando...")
                } else if let error {
                    ErrorView(message: error) {
                        Task { await loadData() }
                    }
                } else if let weather {
                    // Clima atual
                    if let current = weather.current {
                        VStack(spacing: 4) {
                            Image(systemName: iconForCondition(current.condition))
                                .font(.largeTitle)
                                .foregroundStyle(colorForCondition(current.condition))
                            
                            Text("\(Int(current.temperature))°C")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(current.condition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Detalhes
                        VStack(spacing: 6) {
                            if let humidity = current.humidity {
                                WeatherDetailRow(icon: "humidity", label: "Umidade", value: "\(humidity)%")
                            }
                            if let wind = current.windSpeed {
                                WeatherDetailRow(icon: "wind", label: "Vento", value: String(format: "%.0f km/h", wind))
                            }
                        }
                    }
                    
                    // Previsão
                    if let forecast = weather.forecast, !forecast.isEmpty {
                        Divider()
                        
                        Text("Previsão")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        ForEach(forecast.prefix(3)) { day in
                            HStack {
                                Text(day.date)
                                    .font(.caption2)
                                Spacer()
                                Text("\(Int(day.tempMin))° / \(Int(day.tempMax))°")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Clima")
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
            weather = try await WatchAPIService.shared.fetchWeather()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func iconForCondition(_ condition: String) -> String {
        let c = condition.lowercased()
        if c.contains("sun") || c.contains("clear") || c.contains("limpo") { return "sun.max.fill" }
        if c.contains("cloud") || c.contains("nublado") { return "cloud.fill" }
        if c.contains("rain") || c.contains("chuva") { return "cloud.rain.fill" }
        if c.contains("storm") || c.contains("tempest") { return "cloud.bolt.fill" }
        return "cloud.sun.fill"
    }
    
    private func colorForCondition(_ condition: String) -> Color {
        let c = condition.lowercased()
        if c.contains("sun") || c.contains("clear") || c.contains("limpo") { return .yellow }
        if c.contains("rain") || c.contains("chuva") { return .blue }
        if c.contains("storm") { return .purple }
        return .gray
    }
}

/// Linha de detalhe do clima
struct WeatherDetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.blue)
            Text(label)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    WatchWeatherView()
}
