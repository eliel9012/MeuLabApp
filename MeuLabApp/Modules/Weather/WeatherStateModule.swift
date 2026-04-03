import Foundation
import Combine

/// Módulo de estado para Clima
@MainActor
class WeatherStateModule: ObservableObject {
    @Published var weather: WeatherData?
    @Published var error: String?
    @Published var isLoading = false

    private let api: APIServiceProtocol

    init(api: APIServiceProtocol) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await api.fetchWeather()

            if self.weather != data {
                self.weather = data
            }
            self.error = nil
            Logger.info("Weather refresh: \(data.temperature)°C")
        } catch {
            if weather == nil {
                self.error = error.localizedDescription
                Logger.error("Weather refresh error: \(error.localizedDescription)")
            }
        }
    }
}
