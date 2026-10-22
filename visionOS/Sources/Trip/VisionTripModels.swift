import Foundation

struct VisionTripDay: Decodable, Identifiable {
    let id: String
    let date: String
    let weekday: String
    let title: String
    let tone: String
    let events: [VisionTripEvent]

    var displayDate: String { "\(date) · \(weekday)" }
}

struct VisionTripEvent: Decodable, Identifiable {
    let id: String
    let time: String
    let icon: String
    let title: String
    let desc: String
    let address: String?
    let lat: Double?
    let lon: Double?
    let tz: String?
    let pending: Bool

    func date(day: VisionTripDay) -> Date? {
        let parts = day.date.split(separator: " ")
        guard parts.count >= 2, let dayNumber = Int(parts[0]),
              let month = ["out": 10, "nov": 11][String(parts[1]).lowercased()],
              let match = time.firstMatch(of: /(\d{1,2}):(\d{2})/),
              let hour = Int(match.1), let minute = Int(match.2),
              let zone = TimeZone(identifier: tz ?? "America/Sao_Paulo") else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: month, day: dayNumber,
                                                  hour: hour, minute: minute))
    }
}

struct VisionTripFlight: Identifiable {
    let event: VisionTripEvent
    let day: VisionTripDay
    let displayCode: String
    let ident: String
    let originCode: String
    let destinationCode: String
    let departure: Date

    var id: String { event.id }
    var route: String { "\(originCode) → \(destinationCode)" }

    var plannedArrival: Date? {
        guard let match = event.desc.firstMatch(of: /(\d{1,2}):(\d{2})/),
              let hour = Int(match.1), let minute = Int(match.2),
              let zone = VisionTripAirport.known[destinationCode]?.timeZone else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var parts = calendar.dateComponents([.year, .month, .day], from: departure)
        if let date = event.desc.firstMatch(of: /(\d{1,2})\/(\d{1,2})/),
           let day = Int(date.1), let month = Int(date.2) {
            parts.day = day
            parts.month = month
        }
        parts.hour = hour
        parts.minute = minute
        guard var arrival = calendar.date(from: parts) else { return nil }
        if arrival <= departure { arrival = calendar.date(byAdding: .day, value: 1, to: arrival) ?? arrival }
        return arrival
    }

    static func flights(in days: [VisionTripDay]) -> [Self] {
        days.flatMap { day in
            day.events.compactMap { event -> Self? in
                guard event.title.hasPrefix("Voo "), !event.pending,
                      let departure = event.date(day: day),
                      let code = event.title.firstMatch(of: /\b([A-Z][A-Z0-9])\s*(\d{2,4})\b/),
                      let route = event.title.firstMatch(of: /\(([A-Z]{3})\).*→.*\(([A-Z]{3})\)/)
                else { return nil }
                let airline = String(code.1)
                let number = String(code.2)
                let stripped = String(number.drop(while: { $0 == "0" }))
                return .init(event: event, day: day,
                             displayCode: "\(airline) \(number)",
                             ident: airline + (stripped.isEmpty ? number : stripped),
                             originCode: String(route.1), destinationCode: String(route.2),
                             departure: departure)
            }
        }.sorted { $0.departure < $1.departure }
    }
}

enum VisionTripItinerary {
    static func load() throws -> [VisionTripDay] {
        guard let url = Bundle.main.url(forResource: "TripItinerary", withExtension: "json") else {
            throw VisionTripError.missingItinerary
        }
        return try JSONDecoder().decode([VisionTripDay].self, from: Data(contentsOf: url))
    }
}

enum VisionTripError: LocalizedError {
    case missingItinerary, weatherUnavailable

    var errorDescription: String? {
        switch self {
        case .missingItinerary: "Roteiro não encontrado no app."
        case .weatherUnavailable: "Previsão do tempo indisponível."
        }
    }
}

struct VisionTripAirport {
    let code: String
    let name: String
    let latitude: Double
    let longitude: Double

    var timeZone: TimeZone? {
        let identifier: String
        switch code {
        case "RAO", "LDB", "GRU", "VCP": identifier = "America/Sao_Paulo"
        case "MAD": identifier = "Europe/Madrid"
        case "LGW", "LHR", "LCY": identifier = "Europe/London"
        case "LIS": identifier = "Europe/Lisbon"
        default: return nil
        }
        return TimeZone(identifier: identifier)
    }

    static let known: [String: Self] = [
        "RAO": .init(code: "RAO", name: "Ribeirão Preto", latitude: -21.1392477, longitude: -47.7765262),
        "LDB": .init(code: "LDB", name: "Londrina", latitude: -23.328542, longitude: -51.1377836),
        "GRU": .init(code: "GRU", name: "Guarulhos", latitude: -23.4262732, longitude: -46.4816737),
        "MAD": .init(code: "MAD", name: "Madri", latitude: 40.4944735, longitude: -3.5671731),
        "LGW": .init(code: "LGW", name: "Londres Gatwick", latitude: 51.1537, longitude: -0.1821),
        "LHR": .init(code: "LHR", name: "Londres Heathrow", latitude: 51.472515, longitude: -0.4877331),
        "LCY": .init(code: "LCY", name: "London City", latitude: 51.5042655, longitude: 0.0549024),
        "LIS": .init(code: "LIS", name: "Lisboa", latitude: 38.7809981, longitude: -9.1318608),
        "VCP": .init(code: "VCP", name: "Campinas Viracopos", latitude: -23.0074, longitude: -47.1344)
    ]
}

struct VisionTripWeather {
    let airport: VisionTripAirport
    let temperature: Double
    let weatherCode: Int
    let hours: [Hour]
    let fetchedAt: Date

    struct Hour: Identifiable {
        let time: Date
        let temperature: Double
        let rainChance: Int
        let weatherCode: Int
        var id: Date { time }
    }

    var description: String {
        switch weatherCode {
        case 0: "Céu limpo"
        case 1...3: "Nuvens"
        case 45, 48: "Nevoeiro"
        case 51...67, 80...82: "Chuva"
        case 71...77, 85, 86: "Neve"
        case 95...99: "Tempestade"
        default: "Condição atual"
        }
    }

    var symbol: String {
        switch weatherCode {
        case 0: "sun.max.fill"
        case 1...3: "cloud.sun.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }
}

private struct OpenMeteoTripResponse: Decodable {
    struct Current: Decodable { let temperature_2m: Double; let weather_code: Int }
    struct Hourly: Decodable {
        let time: [Int]
        let temperature_2m: [Double]
        let precipitation_probability: [Int]
        let weather_code: [Int]
    }
    let current: Current
    let hourly: Hourly
}

enum VisionTripWeatherService {
    static func fetch(_ airport: VisionTripAirport) async throws -> VisionTripWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(airport.latitude)),
            .init(name: "longitude", value: String(airport.longitude)),
            .init(name: "current", value: "temperature_2m,weather_code"),
            .init(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code"),
            .init(name: "timezone", value: "auto"),
            .init(name: "timeformat", value: "unixtime"),
            .init(name: "forecast_days", value: "16")
        ]
        guard let url = components.url else { throw VisionTripError.weatherUnavailable }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw VisionTripError.weatherUnavailable
        }
        let result = try JSONDecoder().decode(OpenMeteoTripResponse.self, from: data)
        let count = min(result.hourly.time.count, result.hourly.temperature_2m.count,
                        result.hourly.precipitation_probability.count, result.hourly.weather_code.count)
        let hours = (0..<count).map { index in
            VisionTripWeather.Hour(time: Date(timeIntervalSince1970: TimeInterval(result.hourly.time[index])),
                                   temperature: result.hourly.temperature_2m[index],
                                   rainChance: result.hourly.precipitation_probability[index],
                                   weatherCode: result.hourly.weather_code[index])
        }
        return .init(airport: airport, temperature: result.current.temperature_2m,
                     weatherCode: result.current.weather_code, hours: hours, fetchedAt: Date())
    }
}
