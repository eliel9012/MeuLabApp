import SwiftUI

struct WeatherView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let weather = appState.weather {
                        weatherContent(weather)
                    } else if let error = appState.weatherError {
                        ErrorCard(message: error)
                    } else {
                        LoadingCard()
                    }
                }
                .padding()
            }
            .navigationTitle("Clima")
        }
    }

    @ViewBuilder
    private func weatherContent(_ weather: WeatherData) -> some View {
        // Current Weather
        currentWeatherSection(weather)

        // Today's forecast
        todaySection(weather.today)

        // 7-day forecast
        forecastSection(weather.forecast)
    }

    @ViewBuilder
    private func currentWeatherSection(_ weather: WeatherData) -> some View {
        VStack(spacing: 16) {
            // Location
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
                Text(weather.location)
                    .font(.headline)
            }

            // Temperature
            HStack(alignment: .top) {
                Text("\(weather.current.tempC)")
                    .font(.system(size: 72, weight: .thin))

                Text("°C")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text(weather.current.description)
                .font(.title3)
                .foregroundStyle(.secondary)

            // Details grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                WeatherDetailCard(
                    icon: "thermometer",
                    title: "Sensação",
                    value: "\(weather.current.feelsLikeC)°C"
                )

                WeatherDetailCard(
                    icon: "humidity",
                    title: "Umidade",
                    value: "\(weather.current.humidity)%"
                )

                WeatherDetailCard(
                    icon: "wind",
                    title: "Vento",
                    value: "\(weather.current.windKmh) km/h \(weather.current.windDir)"
                )

                WeatherDetailCard(
                    icon: "sun.max",
                    title: "UV",
                    value: "\(weather.current.uvIndex)"
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.blue.opacity(0.3), .cyan.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    @ViewBuilder
    private func todaySection(_ today: TodayWeather) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hoje")
                .font(.headline)

            HStack(spacing: 20) {
                // Temperature range
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(.red)
                        Text("\(today.maxTempC)°")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(.blue)
                        Text("\(today.minTempC)°")
                            .fontWeight(.semibold)
                    }
                }
                .font(.title3)

                Divider()

                // Rain
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: rainIcon(for: today.rainChance))
                            .foregroundStyle(.blue)
                        Text("\(today.rainChance)%")
                            .fontWeight(.semibold)
                    }

                    if today.rainMm > 0 {
                        Text("\(String(format: "%.1f", today.rainMm)) mm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.title3)

                Divider()

                // UV
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(uvColor(today.uvIndex))
                        Text("UV \(today.uvIndex)")
                            .fontWeight(.semibold)
                    }

                    Text(uvDescription(today.uvIndex))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.title3)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func forecastSection(_ forecast: [ForecastDay]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Próximos Dias")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(forecast.enumerated()), id: \.element.id) { index, day in
                    ForecastRow(day: day, isToday: index == 0)

                    if index < forecast.count - 1 {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func rainIcon(for chance: Int) -> String {
        if chance >= 70 { return "cloud.rain.fill" }
        if chance >= 40 { return "cloud.sun.rain.fill" }
        if chance >= 20 { return "cloud.sun.fill" }
        return "sun.max.fill"
    }

    private func uvColor(_ index: Int) -> Color {
        if index <= 2 { return .green }
        if index <= 5 { return .yellow }
        if index <= 7 { return .orange }
        return .red
    }

    private func uvDescription(_ index: Int) -> String {
        if index <= 2 { return "Baixo" }
        if index <= 5 { return "Moderado" }
        if index <= 7 { return "Alto" }
        if index <= 10 { return "Muito Alto" }
        return "Extremo"
    }
}

struct WeatherDetailCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
}

struct ForecastRow: View {
    let day: ForecastDay
    let isToday: Bool

    var body: some View {
        HStack {
            Text(isToday ? "Hoje" : day.formattedDate)
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .frame(width: 80, alignment: .leading)

            Image(systemName: day.weatherIcon)
                .foregroundStyle(day.rainChance >= 40 ? .blue : .orange)
                .frame(width: 30)

            Text("\(day.rainChance)%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 35)
                .monospacedDigit()

            Spacer()

            HStack(spacing: 8) {
                Text("\(day.minTempC)°")
                    .foregroundStyle(.blue)

                TemperatureBar(min: day.minTempC, max: day.maxTempC)
                    .frame(width: 50)

                Text("\(day.maxTempC)°")
                    .foregroundStyle(.red)
            }
            .font(.subheadline)
            .monospacedDigit()
        }
        .padding(.vertical, 8)
    }
}

struct TemperatureBar: View {
    let min: Int
    let max: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .yellow, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * normalizedWidth)
            }
        }
        .frame(height: 4)
    }

    private var normalizedWidth: Double {
        // Normalize between 10-40°C range
        let range = Double(max - min)
        return min(max(range / 30.0, 0.2), 1.0)
    }
}

#Preview {
    WeatherView()
        .environmentObject(AppState())
}
