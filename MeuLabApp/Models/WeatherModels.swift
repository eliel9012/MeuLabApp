import Foundation

struct WeatherData: Codable, Equatable {
    let timestamp: String
    let location: String
    let current: CurrentWeather
    let today: TodayWeather
    let forecast: [ForecastDay]
    var hourly: [HourlyWeatherPoint]? = nil
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
    var weatherCode: Int? = nil
    var isDaylight: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case tempC = "temp_c"
        case feelsLikeC = "feels_like_c"
        case humidity
        case windKmh = "wind_kmh"
        case windDir = "wind_dir"
        case description
        case precipMm = "precip_mm"
        case uvIndex = "uv_index"
        case weatherCode = "weather_code"
        case isDaylight = "is_daylight"
    }
}

struct TodayWeather: Codable, Equatable {
    let maxTempC: Int
    let minTempC: Int
    let rainChance: Int
    let rainMm: Double
    let uvIndex: Int
    var description: String? = nil
    var sunrise: String? = nil
    var sunset: String? = nil

    enum CodingKeys: String, CodingKey {
        case maxTempC = "max_temp_c"
        case minTempC = "min_temp_c"
        case rainChance = "rain_chance"
        case rainMm = "rain_mm"
        case uvIndex = "uv_index"
        case description
        case sunrise
        case sunset
    }
}

struct ForecastDay: Codable, Identifiable, Equatable {
    let date: String
    let maxTempC: Int
    let minTempC: Int
    let rainChance: Int
    let rainMm: Double
    let uvIndex: Int
    var description: String? = nil
    var sunrise: String? = nil
    var sunset: String? = nil

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date
        case maxTempC = "max_temp_c"
        case minTempC = "min_temp_c"
        case rainChance = "rain_chance"
        case rainMm = "rain_mm"
        case uvIndex = "uv_index"
        case description
        case sunrise
        case sunset
    }

    var formattedDate: String {
        guard let date = Formatters.apiDate.date(from: date) else {
            return self.date
        }
        return Formatters.dayMonth.string(from: date).capitalized
    }

    var weatherIcon: String {
        weatherSymbol(description: description, rainChance: rainChance)
    }
}

struct HourlyWeatherPoint: Codable, Identifiable, Equatable {
    let time: String
    let tempC: Int
    let humidity: Int?
    let rainChance: Int
    let rainMm: Double
    let uvIndex: Int
    let windKmh: Int?
    var description: String? = nil

    var id: String { time }

    enum CodingKeys: String, CodingKey {
        case time
        case tempC = "temp_c"
        case humidity
        case rainChance = "rain_chance"
        case rainMm = "rain_mm"
        case uvIndex = "uv_index"
        case windKmh = "wind_kmh"
        case description
    }

    var weatherIcon: String {
        weatherSymbol(description: description, rainChance: rainChance)
    }

    var dateValue: Date? {
        WeatherTimeParser.dateTime(from: time)
    }

    var timeLabel: String {
        guard let date = dateValue else { return String(time.suffix(5)) }
        return Formatters.time.string(from: date)
    }

    var dayKey: String {
        guard let date = dateValue else { return String(time.prefix(10)) }
        return WeatherTimeParser.apiDay.string(from: date)
    }
}

private enum WeatherTimeParser {
    static let apiDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let localDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    static func dateTime(from raw: String) -> Date? {
        if let iso = Formatters.isoDate.date(from: raw) ?? Formatters.isoDateNoFrac.date(from: raw) {
            return iso
        }
        return localDateTime.date(from: raw)
    }
}

private func weatherSymbol(description: String?, rainChance: Int) -> String {
    let normalized = description?.lowercased() ?? ""

    if normalized.contains("tempestade") || normalized.contains("granizo") {
        return "cloud.bolt.rain.fill"
    }
    if normalized.contains("neve") {
        return "cloud.snow.fill"
    }
    if normalized.contains("garoa") || normalized.contains("chuva") || rainChance >= 70 {
        return "cloud.rain.fill"
    }
    if normalized.contains("nublado") || normalized.contains("nevoeiro") || rainChance >= 40 {
        return "cloud.sun.fill"
    }
    if rainChance >= 20 {
        return "cloud.sun.fill"
    }
    return "sun.max.fill"
}
