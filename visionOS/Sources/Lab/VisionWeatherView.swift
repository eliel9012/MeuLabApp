import Charts
import SwiftUI

private struct OpenMeteoForecast: Decodable {
    let hourly: Hourly
    let daily: Daily

    struct Hourly: Decodable {
        let time: [String]
        let temperature: [Double]
        let humidity: [Int]
        let rainChance: [Int]
        let rain: [Double]
        let wind: [Double]
        let uv: [Double]
        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case humidity = "relative_humidity_2m"
            case rainChance = "precipitation_probability"
            case rain = "precipitation"
            case wind = "wind_speed_10m"
            case uv = "uv_index"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let max: [Double]
        let min: [Double]
        let rain: [Double]
        let rainChance: [Int]
        let uv: [Double]
        let sunrise: [String]
        let sunset: [String]
        enum CodingKeys: String, CodingKey {
            case time, sunrise, sunset
            case max = "temperature_2m_max"
            case min = "temperature_2m_min"
            case rain = "precipitation_sum"
            case rainChance = "precipitation_probability_max"
            case uv = "uv_index_max"
        }
    }

    struct HourPoint: Identifiable {
        let time: String
        let temperature: Double
        let humidity: Int
        let rainChance: Int
        let rain: Double
        let wind: Double
        let uv: Double
        var id: String { time }
        var day: String { String(time.prefix(10)) }
        var hour: String { String(time.suffix(5)) }
    }

    struct DayPoint: Identifiable {
        let date: String
        let max: Double
        let min: Double
        let rain: Double
        let rainChance: Int
        let uv: Double
        let sunrise: String
        let sunset: String
        var id: String { date }
    }

    var hours: [HourPoint] {
        let h = hourly
        let count = [h.time.count, h.temperature.count, h.humidity.count, h.rainChance.count,
                     h.rain.count, h.wind.count, h.uv.count].min() ?? 0
        return (0..<count).map { i in
            HourPoint(time: h.time[i], temperature: h.temperature[i], humidity: h.humidity[i],
                      rainChance: h.rainChance[i], rain: h.rain[i], wind: h.wind[i], uv: h.uv[i])
        }
    }

    var days: [DayPoint] {
        let d = daily
        let count = [d.time.count, d.max.count, d.min.count, d.rain.count, d.rainChance.count,
                     d.uv.count, d.sunrise.count, d.sunset.count].min() ?? 0
        return (0..<count).map { i in
            DayPoint(date: d.time[i], max: d.max[i], min: d.min[i], rain: d.rain[i],
                     rainChance: d.rainChance[i], uv: d.uv[i], sunrise: d.sunrise[i], sunset: d.sunset[i])
        }
    }
}

private enum VisionForecastService {
    static func fetch() async throws -> OpenMeteoForecast {
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        parts.queryItems = [
            .init(name: "latitude", value: "-20.512504"),
            .init(name: "longitude", value: "-47.400830"),
            .init(name: "hourly", value: "temperature_2m,relative_humidity_2m,precipitation_probability,precipitation,wind_speed_10m,uv_index"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,uv_index_max,sunrise,sunset"),
            .init(name: "timezone", value: "America/Sao_Paulo"),
            .init(name: "forecast_days", value: "10")
        ]
        let (data, response) = try await URLSession.shared.data(from: parts.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(OpenMeteoForecast.self, from: data)
    }
}

struct VisionWeatherView: View {
    @State private var current: WeatherData?
    @State private var forecast: OpenMeteoForecast?
    @State private var selectedDay: String?
    @State private var currentError: String?
    @State private var forecastError: String?
    @State private var updatedAt: Date?
    @State private var loading = false

    private var day: OpenMeteoForecast.DayPoint? {
        forecast?.days.first { $0.date == selectedDay } ?? forecast?.days.first
    }
    private var hours: [OpenMeteoForecast.HourPoint] {
        guard let day else { return [] }
        return forecast?.hours.filter { $0.day == day.date } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Clima · Franca", systemImage: "cloud.sun").font(.largeTitle.bold())
                    Spacer()
                    if loading { ProgressView() }
                    Button("Atualizar", systemImage: "arrow.clockwise") { Task { await refresh() } }
                }
                if let current {
                    HStack(spacing: 14) {
                        metric("Agora", "\(current.current.tempC)°C", "thermometer.sun")
                        metric("Sensação", "\(current.current.feelsLikeC)°C", "person.crop.circle")
                        metric("Umidade", "\(current.current.humidity)%", "humidity")
                        metric("Vento", "\(current.current.windKmh) km/h", "wind")
                    }
                    panel("Condição atual") {
                        Text(current.current.description).font(.title2)
                        HStack {
                            Text("Chuva: \(current.current.precipMm.formatted()) mm")
                            Text("UV: \(current.current.uvIndex)")
                            Text("Direção do vento: \(current.current.windDir)")
                        }
                        .foregroundStyle(.secondary)
                    }
                } else if let currentError {
                    Label("Agora: \(currentError)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }

                if let forecast {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Próximos 10 dias").font(.title2.bold())
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(forecast.days) { item in
                                    Button {
                                        selectedDay = item.date
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(dayLabel(item.date)).font(.headline)
                                            Text("\(Int(item.min.rounded()))°–\(Int(item.max.rounded()))°")
                                                .font(.title3.bold()).monospacedDigit()
                                            Text("Chuva \(item.rainChance)%").font(.caption)
                                        }
                                        .padding(14)
                                        .background(selectedDay == item.date ? .cyan.opacity(0.22) : .white.opacity(0.07),
                                                    in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if let day {
                        panel("\(dayLabel(day.date)) · detalhes") {
                            HStack(spacing: 15) {
                                metric("Mínima", "\(Int(day.min.rounded()))°C", "thermometer.low")
                                metric("Máxima", "\(Int(day.max.rounded()))°C", "thermometer.high")
                                metric("Chuva", "\(day.rain.formatted(.number.precision(.fractionLength(1)))) mm", "cloud.rain")
                                metric("Chance", "\(day.rainChance)%", "drop")
                                metric("UV máx.", "\(Int(day.uv.rounded()))", "sun.max")
                            }
                            HStack(spacing: 24) {
                                Label("Nascer \(String(day.sunrise.suffix(5)))", systemImage: "sunrise")
                                Label("Pôr \(String(day.sunset.suffix(5)))", systemImage: "sunset")
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    panel("Previsão por hora") {
                        if hours.isEmpty { Text("Sem previsão horária.").foregroundStyle(.secondary) }
                        else {
                            Chart(hours) { point in
                                LineMark(x: .value("Hora", point.hour), y: .value("Temperatura", point.temperature))
                                    .foregroundStyle(.orange)
                                PointMark(x: .value("Hora", point.hour), y: .value("Temperatura", point.temperature))
                                    .foregroundStyle(.orange)
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 170)
                            ForEach(hours) { point in
                                HStack(spacing: 14) {
                                    Text(point.hour).font(.headline.monospacedDigit()).frame(width: 64, alignment: .leading)
                                    Text("\(Int(point.temperature.rounded()))°C").frame(width: 70, alignment: .leading)
                                    Label("\(point.rainChance)%", systemImage: "drop")
                                    Text("\(point.rain.formatted(.number.precision(.fractionLength(1)))) mm")
                                    Spacer()
                                    Label("\(Int(point.wind.rounded())) km/h", systemImage: "wind")
                                    Text("UV \(Int(point.uv.rounded()))").foregroundStyle(.secondary)
                                }
                                .font(.callout)
                                .padding(9)
                                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }
                } else if let forecastError {
                    Label("Previsão: \(forecastError)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if let updatedAt {
                    Text("Atualizado \(updatedAt.formatted(date: .omitted, time: .standard)) · atual MeuLab API · previsão Open-Meteo")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .task {
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(120)) } catch { break }
            }
        }
    }

    private func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do { current = try await VisionAPIClient().fetch("api/weather/current"); currentError = nil }
        catch { currentError = error.localizedDescription }
        do {
            forecast = try await VisionForecastService.fetch()
            if !Task.isCancelled, selectedDay == nil { selectedDay = forecast?.days.first?.date }
            forecastError = nil
        } catch { forecastError = error.localizedDescription }
        updatedAt = Date()
    }

    private func metric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title2.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func dayLabel(_ raw: String) -> String {
        guard let date = Formatters.apiDate.date(from: raw) else { return raw }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "pt_BR")))
    }
}
