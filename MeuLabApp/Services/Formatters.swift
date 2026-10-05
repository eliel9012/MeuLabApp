import Foundation

struct Formatters {
    static let number: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()
    
    static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()
    
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()
    
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()
    
    static let dayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd/MM"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter
    }()
    
    static let apiDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    static let isoDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    static let isoDateNoFrac: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    /// Formatos sem fuso que a API às vezes manda (interpretados como UTC).
    private static let looseAPIFormatters: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ssZ",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }

    /// Parse de timestamp da API (ISO8601 com/sem fração, ou formatos soltos).
    /// Usa formatters cacheados — criar formatter por chamada é caro em listas/gráficos.
    static func parseAPITimestamp(_ timestamp: String) -> Date? {
        if let date = isoDate.date(from: timestamp) { return date }
        if let date = isoDateNoFrac.date(from: timestamp) { return date }
        for formatter in looseAPIFormatters {
            if let date = formatter.date(from: timestamp) { return date }
        }
        return nil
    }

    static func formatDuration(seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: TimeInterval(seconds)) ?? "\(seconds)s"
    }
    
    // MARK: - Aeronautical vs Metric Units
    
    /// Altitude: ft -> ft and m
    static func altitudeDual(_ ft: Int) -> (aviation: String, metric: String) {
        let meters = Double(ft) * 0.3048
        return ("\(ft.formattedBR()) ft", "\(Int(meters).formattedBR()) m")
    }
    
    /// Speed: kt -> kt and km/h
    static func speedDual(_ kt: Int) -> (aviation: String, metric: String) {
        let kmh = Double(kt) * 1.852
        return ("\(kt.formattedBR()) kt", "\(Int(kmh).formattedBR()) km/h")
    }
    
    /// Distance: nm -> nm and km
    static func distanceDual(_ nm: Double) -> (aviation: String, metric: String) {
        let km = nm * 1.852
        return (String(format: "%.1f nm", nm), String(format: "%.1f km", km))
    }
}

extension Double {
    func formattedBR(decimals: Int = 2) -> String {
        let formatter = Formatters.number
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Int {
    func formattedBR() -> String {
        return Formatters.number.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Date {
    func timeAgoDisplay() -> String {
        let secondsAgo = Int(Date().timeIntervalSince(self))
        
        if secondsAgo < 60 {
            return "agora"
        } else if secondsAgo < 60 * 60 {
            return Formatters.relativeDate.localizedString(for: self, relativeTo: Date())
        } else if Calendar.current.isDateInToday(self) {
            return "hoje às \(Formatters.time.string(from: self))"
        } else if Calendar.current.isDateInYesterday(self) {
            return "ontem às \(Formatters.time.string(from: self))"
        } else {
            return Formatters.date.string(from: self)
        }
    }
}
