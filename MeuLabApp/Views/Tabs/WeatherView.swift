import SwiftUI
import UIKit

private func weatherAdaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    )
}

private func weatherRGBA(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1)
    -> UIColor
{
    UIColor(red: red, green: green, blue: blue, alpha: alpha)
}

private enum WeatherTheme {
    static let skyBlue = Color(red: 0.16, green: 0.46, blue: 0.90)
    static let stormBlue = Color(red: 0.14, green: 0.22, blue: 0.46)
    static let rainBlue = Color(red: 0.20, green: 0.58, blue: 0.92)
    static let sunAmber = Color(red: 0.97, green: 0.72, blue: 0.20)
    static let mint = Color(red: 0.36, green: 0.80, blue: 0.72)
    static let violet = Color(red: 0.45, green: 0.35, blue: 0.78)
    static let slate = Color(red: 0.23, green: 0.32, blue: 0.48)
    static let ink = weatherAdaptiveColor(
        light: weatherRGBA(0.08, 0.11, 0.20),
        dark: weatherRGBA(0.92, 0.95, 1.00)
    )
    static let mist = weatherAdaptiveColor(
        light: weatherRGBA(0.95, 0.97, 1.00),
        dark: weatherRGBA(0.09, 0.11, 0.18)
    )
    static let cloud = weatherAdaptiveColor(
        light: weatherRGBA(0.98, 0.99, 1.00),
        dark: weatherRGBA(0.04, 0.06, 0.12)
    )
    static let surfaceTop = weatherAdaptiveColor(
        light: weatherRGBA(1.00, 1.00, 1.00, 0.98),
        dark: weatherRGBA(0.13, 0.16, 0.24, 0.96)
    )
    static let insetSurface = weatherAdaptiveColor(
        light: weatherRGBA(1.00, 1.00, 1.00, 0.72),
        dark: weatherRGBA(0.12, 0.15, 0.23, 0.92)
    )
    static let surfaceStroke = weatherAdaptiveColor(
        light: weatherRGBA(1.00, 1.00, 1.00, 0.92),
        dark: weatherRGBA(0.26, 0.31, 0.42, 0.88)
    )
    static let toolbarBubble = weatherAdaptiveColor(
        light: weatherRGBA(1.00, 1.00, 1.00, 0.78),
        dark: weatherRGBA(0.16, 0.20, 0.28, 0.94)
    )
    static let shadow = weatherAdaptiveColor(
        light: weatherRGBA(0.05, 0.12, 0.26),
        dark: weatherRGBA(0.00, 0.00, 0.00)
    )
}

private struct WeatherPanelBackground: View {
    let cornerRadius: CGFloat
    let highlight: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [WeatherTheme.surfaceTop, WeatherTheme.mist],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [highlight.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [highlight.opacity(0.28), WeatherTheme.surfaceStroke],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
            .shadow(color: WeatherTheme.shadow.opacity(0.08), radius: 24, x: 0, y: 12)
            .shadow(color: highlight.opacity(0.07), radius: 16, x: 0, y: 6)
    }
}

private struct WeatherInsetBackground: View {
    let cornerRadius: CGFloat
    let highlight: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(WeatherTheme.insetSurface)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [highlight.opacity(0.10), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(highlight.opacity(0.16), lineWidth: 1)
            }
    }
}

private extension View {
    func weatherPanel(cornerRadius: CGFloat = 22, highlight: Color = WeatherTheme.skyBlue)
        -> some View
    {
        background(WeatherPanelBackground(cornerRadius: cornerRadius, highlight: highlight))
    }

    func weatherInsetPanel(cornerRadius: CGFloat = 18, highlight: Color = WeatherTheme.skyBlue)
        -> some View
    {
        background(WeatherInsetBackground(cornerRadius: cornerRadius, highlight: highlight))
    }
}

private enum WeatherAtmosphere: Equatable {
    case clearDay
    case cloudyDay
    case rainyDay
    case stormDay
    case fogDay
    case clearNight
    case rainyNight

    init(current: CurrentWeather) {
        let text = current.description.lowercased()
        let isDay = current.isDaylight ?? WeatherClock.isDaylight

        if text.contains("tempestade") || text.contains("granizo") {
            self = .stormDay
            return
        }
        if text.contains("nevoeiro") || text.contains("neblina") {
            self = .fogDay
            return
        }
        if text.contains("garoa") || text.contains("chuva") || current.precipMm >= 0.2 {
            self = isDay ? .rainyDay : .rainyNight
            return
        }
        if text.contains("nublado") {
            self = .cloudyDay
            return
        }
        self = isDay ? .clearDay : .clearNight
    }

    var accent: Color {
        switch self {
        case .clearDay: return WeatherTheme.sunAmber
        case .cloudyDay: return WeatherTheme.skyBlue
        case .rainyDay, .rainyNight: return WeatherTheme.rainBlue
        case .stormDay: return WeatherTheme.violet
        case .fogDay: return WeatherTheme.mint
        case .clearNight: return WeatherTheme.violet
        }
    }

    var gradients: [Color] {
        switch self {
        case .clearDay:
            return [
                Color(red: 0.72, green: 0.85, blue: 1.00),
                Color(red: 0.86, green: 0.96, blue: 1.00),
                Color(red: 0.99, green: 0.96, blue: 0.88),
            ]
        case .cloudyDay:
            return [
                Color(red: 0.66, green: 0.76, blue: 0.90),
                Color(red: 0.84, green: 0.90, blue: 0.95),
                Color(red: 0.93, green: 0.95, blue: 0.99),
            ]
        case .rainyDay:
            return [
                Color(red: 0.28, green: 0.45, blue: 0.70),
                Color(red: 0.45, green: 0.60, blue: 0.78),
                Color(red: 0.70, green: 0.82, blue: 0.92),
            ]
        case .stormDay:
            return [
                Color(red: 0.14, green: 0.18, blue: 0.32),
                Color(red: 0.25, green: 0.28, blue: 0.46),
                Color(red: 0.41, green: 0.43, blue: 0.63),
            ]
        case .fogDay:
            return [
                Color(red: 0.76, green: 0.83, blue: 0.88),
                Color(red: 0.88, green: 0.92, blue: 0.95),
                Color(red: 0.97, green: 0.98, blue: 0.99),
            ]
        case .clearNight:
            return [
                Color(red: 0.05, green: 0.10, blue: 0.24),
                Color(red: 0.12, green: 0.18, blue: 0.36),
                Color(red: 0.19, green: 0.24, blue: 0.48),
            ]
        case .rainyNight:
            return [
                Color(red: 0.07, green: 0.12, blue: 0.25),
                Color(red: 0.14, green: 0.20, blue: 0.38),
                Color(red: 0.22, green: 0.30, blue: 0.48),
            ]
        }
    }

    var showsSun: Bool {
        self == .clearDay
    }

    var showsStars: Bool {
        self == .clearNight || self == .rainyNight
    }

    var showsRain: Bool {
        self == .rainyDay || self == .rainyNight || self == .stormDay
    }

    var showsClouds: Bool {
        self != .clearNight
    }
}

private struct WeatherAtmosphereBackground: View {
    let style: WeatherAtmosphere
    @State private var animate = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: style.gradients,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [style.accent.opacity(0.18), .clear],
                    center: .topTrailing,
                    startRadius: 30,
                    endRadius: 360
                )

                if style.showsSun {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [WeatherTheme.sunAmber.opacity(0.75), .clear],
                                center: .center,
                                startRadius: 12,
                                endRadius: 140
                            )
                        )
                        .frame(width: 220, height: 220)
                        .offset(x: geometry.size.width * 0.24, y: -geometry.size.height * 0.26)
                }

                if style.showsStars {
                    ForEach(0..<18, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(index.isMultiple(of: 3) ? 0.80 : 0.45))
                            .frame(width: index.isMultiple(of: 4) ? 4 : 2, height: index.isMultiple(of: 4) ? 4 : 2)
                            .offset(
                                x: starX(index: index, size: geometry.size),
                                y: starY(index: index, size: geometry.size)
                            )
                    }
                }

                if style.showsClouds {
                    ForEach(0..<4, id: \.self) { index in
                        cloudBlob(index: index, size: geometry.size)
                    }
                }

                if style.showsRain {
                    ForEach(0..<18, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(style == .stormDay ? 0.28 : 0.18))
                            .frame(width: 2, height: CGFloat(26 + (index % 3) * 14))
                            .rotationEffect(.degrees(12))
                            .offset(
                                x: rainX(index: index, size: geometry.size),
                                y: animate ? geometry.size.height / 2 + 220 : -geometry.size.height / 2 - 120
                            )
                            .animation(
                                .linear(duration: 1.3 + Double(index) * 0.05)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.06),
                                value: animate
                            )
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }

    private func cloudBlob(index: Int, size: CGSize) -> some View {
        Ellipse()
            .fill(Color.white.opacity(style == .stormDay ? 0.10 : 0.18))
            .frame(
                width: CGFloat(180 + (index * 26)),
                height: CGFloat(74 + (index * 10))
            )
            .blur(radius: CGFloat(26 + index * 4))
            .offset(
                x: animate ? size.width * 0.18 : -size.width * 0.18,
                y: CGFloat(-120 + (index * 100))
            )
            .animation(
                .easeInOut(duration: 8.0 + Double(index))
                    .repeatForever(autoreverses: true),
                value: animate
            )
    }

    private func rainX(index: Int, size: CGSize) -> CGFloat {
        let fraction = CGFloat(index % 9) / 8
        let lane = (fraction * size.width) - (size.width / 2)
        return lane + CGFloat((index / 9) * 44)
    }

    private func starX(index: Int, size: CGSize) -> CGFloat {
        let base = CGFloat(index % 6) / 5
        return (base * size.width) - (size.width / 2) + CGFloat((index / 6) * 18)
    }

    private func starY(index: Int, size: CGSize) -> CGFloat {
        let row = CGFloat(index / 6)
        return -size.height / 2 + 80 + row * 54 + CGFloat(index % 3) * 10
    }
}

private struct WeatherToolbarTitle: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [WeatherTheme.sunAmber.opacity(0.18), WeatherTheme.skyBlue.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WeatherTheme.skyBlue)
            }

            Text("Clima")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(
                    LinearGradient(
                        colors: [WeatherTheme.sunAmber, WeatherTheme.skyBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clima")
    }
}

private struct WeatherMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WeatherTheme.ink.opacity(0.56))
            }

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(WeatherTheme.ink)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .weatherInsetPanel(cornerRadius: 18, highlight: tint)
    }
}

private struct WeatherDayChip: View {
    let day: WeatherDayCardModel
    let isSelected: Bool
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(day.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.88) : WeatherTheme.ink.opacity(0.62))

                Spacer()

                Image(systemName: day.icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? .white : day.rainChance >= 45 ? WeatherTheme.rainBlue : WeatherTheme.sunAmber)
            }

            Text(day.maxTempLabel)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(isSelected ? .white : WeatherTheme.ink)

            HStack(spacing: 8) {
                Label("\(day.rainChance)%", systemImage: "drop.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : WeatherTheme.ink.opacity(0.56))

                Text(day.shortDate)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.74) : WeatherTheme.ink.opacity(0.50))
            }
        }
        .padding(14)
        .frame(width: 128, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isSelected
                        ? LinearGradient(
                            colors: [tint, tint.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [WeatherTheme.surfaceTop.opacity(0.92), WeatherTheme.mist],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? tint.opacity(0.22) : tint.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: isSelected ? tint.opacity(0.18) : .clear, radius: 10, x: 0, y: 4)
    }
}

private struct WeatherInsightCard: View {
    let title: String
    let icon: String
    let tint: Color
    let rows: [(String, String)]
    let highlight: String
    let highlightCaption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 34, height: 34)

                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(WeatherTheme.ink)

                    Text(highlightCaption)
                        .font(.caption)
                        .foregroundStyle(WeatherTheme.ink.opacity(0.56))
                }
            }

            Text(highlight)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()

            VStack(spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 12) {
                        Text(row.0)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WeatherTheme.ink.opacity(0.54))

                        Spacer()

                        Text(row.1)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(WeatherTheme.ink)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weatherInsetPanel(cornerRadius: 20, highlight: tint)
    }
}

private struct HourlyForecastCell: View {
    let hour: HourlyWeatherPoint
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            Text(hour.timeLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WeatherTheme.ink.opacity(0.54))

            Image(systemName: hour.weatherIcon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(hour.rainChance >= 45 ? WeatherTheme.rainBlue : tint)

            Text("\(hour.tempC)°")
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(WeatherTheme.ink)

            VStack(spacing: 4) {
                Text("\(hour.rainChance)%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WeatherTheme.rainBlue)
                    .monospacedDigit()

                Text("\(hour.rainMm.formattedBR(decimals: 1)) mm")
                    .font(.caption2)
                    .foregroundStyle(WeatherTheme.ink.opacity(0.54))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(width: 82)
        .weatherInsetPanel(cornerRadius: 18, highlight: tint)
    }
}

private struct WeatherForecastRow: View {
    let day: WeatherDayCardModel
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: day.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(day.rainChance >= 45 ? WeatherTheme.rainBlue : WeatherTheme.sunAmber)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(day.rowTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WeatherTheme.ink)

                Text(day.description)
                    .font(.caption)
                    .foregroundStyle(WeatherTheme.ink.opacity(0.56))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Label("\(day.rainChance)%", systemImage: "drop.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeatherTheme.rainBlue)

                    Text("\(day.rainMm.formattedBR(decimals: 1)) mm")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeatherTheme.ink.opacity(0.54))
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    Text(day.minTempLabel)
                        .foregroundStyle(WeatherTheme.skyBlue)

                    TemperatureRail(min: day.minTempC, max: day.maxTempC)
                        .frame(width: 58)

                    Text(day.maxTempLabel)
                        .foregroundStyle(Color.red.opacity(0.82))
                }
                .font(.caption.weight(.bold))
                .monospacedDigit()
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(WeatherTheme.mint)
                    .font(.body.weight(.bold))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? WeatherTheme.skyBlue.opacity(0.08) : .clear)
        )
    }
}

private struct TemperatureRail: View {
    let min: Int
    let max: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.16))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [WeatherTheme.skyBlue, WeatherTheme.sunAmber, Color.red.opacity(0.80)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * normalizedWidth)
            }
        }
        .frame(height: 4)
    }

    private var normalizedWidth: Double {
        let range = Double(max - min)
        return Swift.min(Swift.max(range / 24.0, 0.22), 1.0)
    }
}

private struct WeatherDayCardModel: Identifiable, Equatable {
    let id: String
    let title: String
    let shortDate: String
    let rowTitle: String
    let description: String
    let icon: String
    let maxTempC: Int
    let minTempC: Int
    let rainChance: Int
    let rainMm: Double
    let uvIndex: Int
    let sunrise: String?
    let sunset: String?
    let isToday: Bool

    var maxTempLabel: String { "\(maxTempC)°" }
    var minTempLabel: String { "\(minTempC)°" }
}

private struct WeatherDayInsights {
    let hourly: [HourlyWeatherPoint]
    let rainWindowText: String
    let wettestHourText: String
    let maxRainChance: Int
    let rainTotal: Double
    let dryHoursCount: Int
    let humidityAverage: Int?
    let peakWindKmh: Int?
}

private enum WeatherClock {
    static let apiDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let weekdayShort: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "dd/MM"
        return formatter
    }()

    static let detailDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, dd 'de' MMMM"
        return formatter
    }()

    static let localDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()

    static var isDaylight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return (6..<18).contains(hour)
    }

    static func parseDateTime(_ raw: String) -> Date? {
        if let iso = Formatters.isoDate.date(from: raw) ?? Formatters.isoDateNoFrac.date(from: raw) {
            return iso
        }
        return localDateTime.date(from: raw)
    }
}

struct WeatherView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDayID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if let weather = appState.weather {
                        weatherContent(weather)
                    } else if let error = appState.weatherError {
                        ErrorCard(message: error)
                    } else {
                        LoadingCard()
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background {
                WeatherAtmosphereBackground(
                    style: appState.weather.map { WeatherAtmosphere(current: $0.current) } ?? .clearDay
                )
            }
            .navigationTitle("Clima")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    WeatherToolbarTitle()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.weatherLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(WeatherTheme.toolbarBubble)
                            )
                    } else {
                        Button {
                            Task { await appState.refreshWeather() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(WeatherTheme.skyBlue)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(WeatherTheme.toolbarBubble)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            syncSelectedDay()
        }
        .onChange(of: appState.weather?.timestamp) { _, _ in
            syncSelectedDay()
        }
        .onChange(of: appState.intelligenceContext) { _, context in
            guard
                let context,
                context["tab"] == ContentView.Tab.weather.rawValue,
                context["kind"] == "weather_day",
                let identifier = context["identifier"],
                let weather = appState.weather
            else { return }

            let days = weatherDayCards(from: weather)
            if days.contains(where: { $0.id == identifier }) {
                selectedDayID = identifier
                appState.intelligenceContext = nil
            }
        }
    }

    @ViewBuilder
    private func weatherContent(_ weather: WeatherData) -> some View {
        let style = WeatherAtmosphere(current: weather.current)
        let days = weatherDayCards(from: weather)
        let selectedDay = selectedDayCard(from: weather) ?? days.first

        currentWeatherSection(weather, style: style)

        if !days.isEmpty {
            daySelectorSection(days: days, tint: style.accent)
        }

        if let selectedDay {
            let insights = weatherInsights(for: selectedDay, weather: weather)
            selectedDaySection(day: selectedDay, insights: insights, tint: style.accent)
            hourlySection(day: selectedDay, insights: insights, tint: style.accent)
        }

        if !days.isEmpty {
            forecastSection(days: days, tint: style.accent)
        }
    }

    @ViewBuilder
    private func currentWeatherSection(_ weather: WeatherData, style: WeatherAtmosphere) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Label("Condição atual", systemImage: "cloud.sun.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WeatherTheme.ink.opacity(0.82))

                        Text(styleBadgeTitle(for: style))
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(style.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(style.accent.opacity(0.14), in: Capsule())
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(WeatherTheme.skyBlue)

                        Text(weather.location)
                            .font(.headline)
                            .foregroundStyle(WeatherTheme.ink)
                    }
                    .onTapGesture {
                        if !LocationManager.shared.isAuthorized {
                            LocationManager.shared.requestPermission()
                        }
                    }

                    Text(updatedWeatherText(weather.timestamp))
                        .font(.caption)
                        .foregroundStyle(WeatherTheme.ink.opacity(0.56))
                }

                Spacer(minLength: 12)

                if !LocationManager.shared.isAuthorized {
                    Button("Usar minha localização") {
                        LocationManager.shared.requestPermission()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WeatherTheme.skyBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(WeatherTheme.toolbarBubble, in: Capsule())
                    .buttonStyle(.plain)
                }
            }

            HStack(alignment: .center, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(weather.current.tempC)")
                            .font(.system(size: 78, weight: .thin, design: .rounded))
                            .foregroundStyle(WeatherTheme.ink)

                        Text("°C")
                            .font(.title.weight(.medium))
                            .foregroundStyle(WeatherTheme.ink.opacity(0.56))
                    }

                    Text(weather.current.description)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(WeatherTheme.ink)

                    Text(heroSummary(for: weather.current))
                        .font(.subheadline)
                        .foregroundStyle(WeatherTheme.ink.opacity(0.62))
                }

                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(style.accent.opacity(0.12))
                        .frame(width: 96, height: 96)

                    Circle()
                        .stroke(style.accent.opacity(0.18), lineWidth: 1.2)
                        .frame(width: 96, height: 96)

                    Image(systemName: currentWeatherIcon(for: weather.current))
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(style.accent)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    WeatherMetricTile(
                        title: "Sensação",
                        value: "\(weather.current.feelsLikeC)°C",
                        icon: "thermometer.medium",
                        tint: Color.red.opacity(0.82)
                    )
                    WeatherMetricTile(
                        title: "Umidade",
                        value: "\(weather.current.humidity)%",
                        icon: "humidity.fill",
                        tint: WeatherTheme.mint
                    )
                    WeatherMetricTile(
                        title: "Vento",
                        value: "\(weather.current.windKmh) km/h \(weather.current.windDir)",
                        icon: "wind",
                        tint: WeatherTheme.skyBlue
                    )
                    WeatherMetricTile(
                        title: "Chuva agora",
                        value: "\(weather.current.precipMm.formattedBR(decimals: 1)) mm",
                        icon: "drop.fill",
                        tint: WeatherTheme.rainBlue
                    )
                    WeatherMetricTile(
                        title: "UV",
                        value: "UV \(weather.current.uvIndex)",
                        icon: "sun.max.fill",
                        tint: uvColor(weather.current.uvIndex)
                    )
                }

                VStack(spacing: 12) {
                    WeatherMetricTile(
                        title: "Sensação",
                        value: "\(weather.current.feelsLikeC)°C",
                        icon: "thermometer.medium",
                        tint: Color.red.opacity(0.82)
                    )
                    WeatherMetricTile(
                        title: "Umidade",
                        value: "\(weather.current.humidity)%",
                        icon: "humidity.fill",
                        tint: WeatherTheme.mint
                    )
                    WeatherMetricTile(
                        title: "Vento",
                        value: "\(weather.current.windKmh) km/h \(weather.current.windDir)",
                        icon: "wind",
                        tint: WeatherTheme.skyBlue
                    )
                    WeatherMetricTile(
                        title: "Chuva agora",
                        value: "\(weather.current.precipMm.formattedBR(decimals: 1)) mm",
                        icon: "drop.fill",
                        tint: WeatherTheme.rainBlue
                    )
                    WeatherMetricTile(
                        title: "UV",
                        value: "UV \(weather.current.uvIndex)",
                        icon: "sun.max.fill",
                        tint: uvColor(weather.current.uvIndex)
                    )
                }
            }
        }
        .padding(24)
        .weatherPanel(cornerRadius: 28, highlight: style.accent)
    }

    @ViewBuilder
    private func daySelectorSection(days: [WeatherDayCardModel], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Dias clicáveis",
                subtitle: "Escolha um dia para aprofundar chuva, UV e janela horária",
                icon: "calendar"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(days) { day in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                selectedDayID = day.id
                            }
                        } label: {
                            WeatherDayChip(
                                day: day,
                                isSelected: selectedDayID == day.id,
                                tint: tint
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(20)
        .weatherPanel(cornerRadius: 24, highlight: tint)
    }

    @ViewBuilder
    private func selectedDaySection(
        day: WeatherDayCardModel,
        insights: WeatherDayInsights,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.rowTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WeatherTheme.ink.opacity(0.56))

                    Text(day.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(WeatherTheme.ink)

                    Text(day.description)
                        .font(.subheadline)
                        .foregroundStyle(WeatherTheme.ink.opacity(0.62))
                }

                Spacer(minLength: 12)

                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 72, height: 72)

                    Image(systemName: day.icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    WeatherMetricTile(
                        title: "Máxima",
                        value: day.maxTempLabel,
                        icon: "arrow.up",
                        tint: Color.red.opacity(0.80)
                    )
                    WeatherMetricTile(
                        title: "Mínima",
                        value: day.minTempLabel,
                        icon: "arrow.down",
                        tint: WeatherTheme.skyBlue
                    )
                    WeatherMetricTile(
                        title: "Chance de chuva",
                        value: "\(insights.maxRainChance)%",
                        icon: "drop.triangle.fill",
                        tint: WeatherTheme.rainBlue
                    )
                    WeatherMetricTile(
                        title: "UV",
                        value: "UV \(day.uvIndex)",
                        icon: "sun.max.fill",
                        tint: uvColor(day.uvIndex)
                    )
                }

                VStack(spacing: 12) {
                    WeatherMetricTile(
                        title: "Máxima",
                        value: day.maxTempLabel,
                        icon: "arrow.up",
                        tint: Color.red.opacity(0.80)
                    )
                    WeatherMetricTile(
                        title: "Mínima",
                        value: day.minTempLabel,
                        icon: "arrow.down",
                        tint: WeatherTheme.skyBlue
                    )
                    WeatherMetricTile(
                        title: "Chance de chuva",
                        value: "\(insights.maxRainChance)%",
                        icon: "drop.triangle.fill",
                        tint: WeatherTheme.rainBlue
                    )
                    WeatherMetricTile(
                        title: "UV",
                        value: "UV \(day.uvIndex)",
                        icon: "sun.max.fill",
                        tint: uvColor(day.uvIndex)
                    )
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    WeatherInsightCard(
                        title: "Chuva",
                        icon: "cloud.rain.fill",
                        tint: WeatherTheme.rainBlue,
                        rows: [
                            ("Acumulado", "\(insights.rainTotal.formattedBR(decimals: 1)) mm"),
                            ("Janela", insights.rainWindowText),
                            ("Pico", insights.wettestHourText),
                            ("Horas secas", "\(insights.dryHoursCount) h"),
                        ],
                        highlight: "\(insights.maxRainChance)%",
                        highlightCaption: rainNarrative(for: day, insights: insights)
                    )

                    WeatherInsightCard(
                        title: "Leitura do dia",
                        icon: "sun.max.fill",
                        tint: tint,
                        rows: [
                            ("Risco UV", uvDescription(day.uvIndex)),
                            ("Nascer do sol", formattedClock(day.sunrise)),
                            ("Pôr do sol", formattedClock(day.sunset)),
                            ("Vento pico", insights.peakWindKmh.map { "\($0) km/h" } ?? "N/D"),
                            ("Umidade média", insights.humidityAverage.map { "\($0)%" } ?? "N/D"),
                        ],
                        highlight: day.detailTemperatureRange,
                        highlightCaption: "Faixa térmica prevista para o período"
                    )
                }

                VStack(spacing: 12) {
                    WeatherInsightCard(
                        title: "Chuva",
                        icon: "cloud.rain.fill",
                        tint: WeatherTheme.rainBlue,
                        rows: [
                            ("Acumulado", "\(insights.rainTotal.formattedBR(decimals: 1)) mm"),
                            ("Janela", insights.rainWindowText),
                            ("Pico", insights.wettestHourText),
                            ("Horas secas", "\(insights.dryHoursCount) h"),
                        ],
                        highlight: "\(insights.maxRainChance)%",
                        highlightCaption: rainNarrative(for: day, insights: insights)
                    )

                    WeatherInsightCard(
                        title: "Leitura do dia",
                        icon: "sun.max.fill",
                        tint: tint,
                        rows: [
                            ("Risco UV", uvDescription(day.uvIndex)),
                            ("Nascer do sol", formattedClock(day.sunrise)),
                            ("Pôr do sol", formattedClock(day.sunset)),
                            ("Vento pico", insights.peakWindKmh.map { "\($0) km/h" } ?? "N/D"),
                            ("Umidade média", insights.humidityAverage.map { "\($0)%" } ?? "N/D"),
                        ],
                        highlight: day.detailTemperatureRange,
                        highlightCaption: "Faixa térmica prevista para o período"
                    )
                }
            }
        }
        .padding(20)
        .weatherPanel(cornerRadius: 24, highlight: tint)
    }

    @ViewBuilder
    private func hourlySection(day: WeatherDayCardModel, insights: WeatherDayInsights, tint: Color)
        -> some View
    {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Ritmo do dia",
                subtitle: insights.hourly.isEmpty
                    ? "Sem detalhamento horário para esse dia na origem atual"
                    : "Detalhe por hora com temperatura, chuva e ícone de condição",
                icon: "clock"
            )

            if insights.hourly.isEmpty {
                Text("Esse dia ainda não tem previsão horária detalhada disponível. A leitura acima usa os dados diários consolidados.")
                    .font(.subheadline)
                    .foregroundStyle(WeatherTheme.ink.opacity(0.62))
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .weatherInsetPanel(cornerRadius: 20, highlight: tint)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(insights.hourly) { hour in
                            HourlyForecastCell(hour: hour, tint: tint)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding(20)
        .weatherPanel(cornerRadius: 24, highlight: tint)
    }

    @ViewBuilder
    private func forecastSection(days: [WeatherDayCardModel], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Próximos dias",
                subtitle: "Toque em qualquer linha para trocar o foco da análise",
                icon: "calendar.badge.clock"
            )

            VStack(spacing: 0) {
                ForEach(days) { day in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedDayID = day.id
                        }
                    } label: {
                        WeatherForecastRow(day: day, isSelected: selectedDayID == day.id)
                    }
                    .buttonStyle(.plain)

                    if day.id != days.last?.id {
                        Divider()
                    }
                }
            }
            .padding(18)
            .weatherInsetPanel(cornerRadius: 20, highlight: tint)
        }
        .padding(20)
        .weatherPanel(cornerRadius: 24, highlight: tint)
    }

    private func sectionHeader(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(WeatherTheme.skyBlue.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WeatherTheme.skyBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(WeatherTheme.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(WeatherTheme.ink.opacity(0.56))
            }
        }
    }

    private func weatherDayCards(from weather: WeatherData) -> [WeatherDayCardModel] {
        var days: [WeatherDayCardModel] = []

        let todayDate = WeatherClock.parseDateTime(weather.timestamp) ?? Date()
        let todayKey = WeatherClock.apiDay.string(from: todayDate)
        let todayShortDate = WeatherClock.shortDate.string(from: todayDate)

        days.append(
            WeatherDayCardModel(
                id: todayKey,
                title: "Hoje",
                shortDate: todayShortDate,
                rowTitle: "Hoje, \(todayShortDate)",
                description: weather.today.description ?? weather.current.description,
                icon: currentWeatherIcon(for: weather.current),
                maxTempC: weather.today.maxTempC,
                minTempC: weather.today.minTempC,
                rainChance: weather.today.rainChance,
                rainMm: weather.today.rainMm,
                uvIndex: weather.today.uvIndex,
                sunrise: weather.today.sunrise,
                sunset: weather.today.sunset,
                isToday: true
            )
        )

        days.append(
            contentsOf: weather.forecast.map { day in
                let date = Formatters.apiDate.date(from: day.date)
                let weekday = date.map { WeatherClock.weekdayShort.string(from: $0).capitalized } ?? day.formattedDate
                let shortDate = date.map { WeatherClock.shortDate.string(from: $0) } ?? day.date

                return WeatherDayCardModel(
                    id: day.date,
                    title: weekday,
                    shortDate: shortDate,
                    rowTitle: date.map { WeatherClock.detailDate.string(from: $0).capitalized } ?? day.formattedDate,
                    description: day.description ?? rainSummary(chance: day.rainChance, mm: day.rainMm),
                    icon: day.weatherIcon,
                    maxTempC: day.maxTempC,
                    minTempC: day.minTempC,
                    rainChance: day.rainChance,
                    rainMm: day.rainMm,
                    uvIndex: day.uvIndex,
                    sunrise: day.sunrise,
                    sunset: day.sunset,
                    isToday: false
                )
            }
        )

        return days
    }

    private func selectedDayCard(from weather: WeatherData) -> WeatherDayCardModel? {
        let days = weatherDayCards(from: weather)
        return days.first(where: { $0.id == selectedDayID }) ?? days.first
    }

    private func weatherInsights(for day: WeatherDayCardModel, weather: WeatherData) -> WeatherDayInsights {
        let hourly = (weather.hourly ?? []).filter { $0.dayKey == day.id }
        let rainyHours = hourly.filter { $0.rainChance >= 35 || $0.rainMm >= 0.15 }
        let peakRain = hourly.max(by: { $0.rainMm < $1.rainMm })
        let totalRain = hourly.isEmpty ? day.rainMm : hourly.reduce(0) { $0 + $1.rainMm }
        let maxChance = max(day.rainChance, hourly.map(\.rainChance).max() ?? 0)
        let dryHours = hourly.isEmpty ? max(0, 24 - Int(Double(day.rainChance) / 100 * 24)) :
            hourly.filter { $0.rainChance < 20 && $0.rainMm < 0.1 }.count
        let humidityValues = hourly.compactMap(\.humidity)
        let humidityAverage = humidityValues.isEmpty ? nil :
            Int(round(Double(humidityValues.reduce(0, +)) / Double(humidityValues.count)))

        let rainWindow: String
        if let first = rainyHours.first, let last = rainyHours.last {
            rainWindow = first.timeLabel == last.timeLabel ?
                first.timeLabel : "\(first.timeLabel) - \(last.timeLabel)"
        } else if day.rainChance >= 40 {
            rainWindow = "Chance distribuida ao longo do dia"
        } else {
            rainWindow = "Sem janela forte prevista"
        }

        let wettestHourText: String
        if let peakRain, peakRain.rainMm > 0.05 {
            wettestHourText = "\(peakRain.timeLabel) • \(peakRain.rainMm.formattedBR(decimals: 1)) mm"
        } else if day.rainMm > 0 {
            wettestHourText = "Volume leve distribuído"
        } else {
            wettestHourText = "Sem pico relevante"
        }

        return WeatherDayInsights(
            hourly: hourly,
            rainWindowText: rainWindow,
            wettestHourText: wettestHourText,
            maxRainChance: maxChance,
            rainTotal: totalRain,
            dryHoursCount: max(dryHours, 0),
            humidityAverage: humidityAverage,
            peakWindKmh: hourly.compactMap(\.windKmh).max()
        )
    }

    private func currentWeatherIcon(for current: CurrentWeather) -> String {
        let text = current.description.lowercased()
        if text.contains("tempestade") || text.contains("granizo") {
            return "cloud.bolt.rain.fill"
        }
        if text.contains("nevoeiro") || text.contains("neblina") {
            return "cloud.fog.fill"
        }
        if text.contains("garoa") || text.contains("chuva") || current.precipMm >= 0.2 {
            return current.isDaylight == false ? "cloud.moon.rain.fill" : "cloud.rain.fill"
        }
        if text.contains("nublado") {
            return current.isDaylight == false ? "cloud.moon.fill" : "cloud.sun.fill"
        }
        return current.isDaylight == false ? "moon.stars.fill" : "sun.max.fill"
    }

    private func uvColor(_ index: Int) -> Color {
        if index <= 2 { return WeatherTheme.mint }
        if index <= 5 { return WeatherTheme.sunAmber }
        if index <= 7 { return .orange }
        if index <= 10 { return .red }
        return WeatherTheme.violet
    }

    private func uvDescription(_ index: Int) -> String {
        if index <= 2 { return "Baixo" }
        if index <= 5 { return "Moderado" }
        if index <= 7 { return "Alto" }
        if index <= 10 { return "Muito alto" }
        return "Extremo"
    }

    private func rainSummary(chance: Int, mm: Double) -> String {
        if chance >= 70 || mm >= 10 {
            return "Chuva frequente"
        }
        if chance >= 45 || mm >= 4 {
            return "Pancadas possíveis"
        }
        if chance >= 20 || mm > 0 {
            return "Chance leve de chuva"
        }
        return "Tempo mais seco"
    }

    private func rainNarrative(for day: WeatherDayCardModel, insights: WeatherDayInsights) -> String {
        if insights.maxRainChance >= 75 || insights.rainTotal >= 12 {
            return "Chance alta de chuva consistente"
        }
        if insights.maxRainChance >= 45 || insights.rainTotal >= 4 {
            return "Janela de pancadas ao longo do dia"
        }
        if day.rainChance >= 20 || day.rainMm > 0 {
            return "Pode pingar em momentos isolados"
        }
        return "Baixo risco de precipitação"
    }

    private func heroSummary(for current: CurrentWeather) -> String {
        let rainText = current.precipMm > 0
            ? "\(current.precipMm.formattedBR(decimals: 1)) mm agora"
            : "sem chuva no momento"
        return "Sensação de \(current.feelsLikeC)°C, \(rainText) e UV \(current.uvIndex)."
    }

    private func updatedWeatherText(_ timestamp: String) -> String {
        guard let date = WeatherClock.parseDateTime(timestamp) else { return "Atualização indisponível" }
        return "Atualizado \(Formatters.relativeDate.localizedString(for: date, relativeTo: Date()))"
    }

    private func formattedClock(_ raw: String?) -> String {
        guard let raw, let date = WeatherClock.parseDateTime(raw) else { return "N/D" }
        return Formatters.time.string(from: date)
    }

    private func styleBadgeTitle(for style: WeatherAtmosphere) -> String {
        switch style {
        case .clearDay: return "ABERTO"
        case .cloudyDay: return "NUBLADO"
        case .rainyDay, .rainyNight: return "CHUVA"
        case .stormDay: return "TEMPESTADE"
        case .fogDay: return "NÉVOA"
        case .clearNight: return "NOITE"
        }
    }

    private func syncSelectedDay() {
        guard let weather = appState.weather else { return }
        let days = weatherDayCards(from: weather)
        guard let first = days.first else { return }

        if let selectedDayID, days.contains(where: { $0.id == selectedDayID }) {
            return
        }
        self.selectedDayID = first.id
    }
}

private extension WeatherDayCardModel {
    var detailTemperatureRange: String {
        "\(minTempLabel) - \(maxTempLabel)"
    }
}

#Preview {
    WeatherView()
        .environmentObject(AppState())
}
