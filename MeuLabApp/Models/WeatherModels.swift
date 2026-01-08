import Foundation

struct WeatherData: Codable, Equatable {
    let timestamp: String
    let location: String
    let current: CurrentWeather
    let today: TodayWeather
    let forecast: [ForecastDay]
}

struct CurrentWeather: Codable, Equatable {
    let tempC: Int
    let feelsLikeC: Int
    let humidity: Int
    let windKmh: Int
    let windDir: String
    let description: String
    let precipMm: Double
    let uvIndex: Int

    enum CodingKeys: String, CodingKey {
        case tempC = "temp_c"
        case feelsLikeC = "feels_like_c"
        case humidity
        case windKmh = "wind_kmh"
        case windDir = "wind_dir"
        case description
        case precipMm = "precip_mm"
        case uvIndex = "uv_index"
    }
}

struct TodayWeather: Codable, Equatable {
    let maxTempC: Int
    let minTempC: Int
    let rainChance: Int
    let rainMm: Double
    let uvIndex: Int

    enum CodingKeys: String, CodingKey {
        case maxTempC = "max_temp_c"
        case minTempC = "min_temp_c"
        case rainChance = "rain_chance"
        case rainMm = "rain_mm"
        case uvIndex = "uv_index"
    }
}

struct ForecastDay: Codable, Identifiable, Equatable {
    let date: String
    let maxTempC: Int
    let minTempC: Int
    let rainChance: Int
    let rainMm: Double
    let uvIndex: Int

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case maxTempC = "max_temp_c"
        case minTempC = "min_temp_c"
        case rainChance = "rain_chance"
        case rainMm = "rain_mm"
        case uvIndex = "uv_index"
    }

    var formattedDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        guard let date = inputFormatter.date(from: date) else {
            return self.date
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "pt_BR")
        outputFormatter.dateFormat = "EEE dd/MM"

        return outputFormatter.string(from: date).capitalized
    }

    var weatherIcon: String {
        if rainChance >= 70 {
            return "cloud.rain.fill"
        } else if rainChance >= 40 {
            return "cloud.sun.rain.fill"
        } else if rainChance >= 20 {
            return "cloud.sun.fill"
        } else {
            return "sun.max.fill"
        }
    }
}
