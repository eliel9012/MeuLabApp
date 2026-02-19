import Foundation

// MARK: - Open-Meteo Models

struct OpenMeteoResponse: Codable {
    let latitude: Double
    let longitude: Double
    let current: OpenMeteoCurrent
    let hourly: OpenMeteoHourly
    let daily: OpenMeteoDaily
    let current_units: OpenMeteoCurrentUnits
}

struct OpenMeteoCurrentUnits: Codable {
    let temperature_2m: String
    let relative_humidity_2m: String
    let precipitation: String
    let weather_code: String
    let wind_speed_10m: String
}

struct OpenMeteoCurrent: Codable {
    let time: String
    let interval: Int
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let precipitation: Double
    let weather_code: Int
    let wind_speed_10m: Double
    let wind_direction_10m: Int
}

struct OpenMeteoHourly: Codable {
    let time: [String]
    let temperature_2m: [Double]
    let relative_humidity_2m: [Int]
    let weather_code: [Int]
    let uv_index: [Double]
}

struct OpenMeteoDaily: Codable {
    let time: [String]
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_sum: [Double]
    let precipitation_probability_max: [Int]
    let uv_index_max: [Double]
}
