import Foundation

struct SatellitePass: Codable, Identifiable, Equatable {
    let name: String
    let imageFolder: String
    let imageCount: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case imageFolder = "image_folder"
        case imageCount = "image_count"
    }

    var formattedDate: String {
        // Format: 2026-01-07_04-53_meteor_m2-x_lrpt_137.9 MHz
        let components = name.split(separator: "_")
        guard components.count >= 2 else { return name }

        let dateStr = String(components[0])
        let timeStr = String(components[1]).replacingOccurrences(of: "-", with: ":")

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        guard let date = inputFormatter.date(from: dateStr) else {
            return "\(dateStr) \(timeStr)"
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "pt_BR")
        outputFormatter.dateFormat = "dd/MM/yyyy"

        return "\(outputFormatter.string(from: date)) \(timeStr)"
    }

    var satelliteName: String {
        if name.contains("meteor_m2-x") {
            return "Meteor M2-x"
        } else if name.contains("meteor_m2-4") {
            return "Meteor M2-4"
        } else if name.contains("noaa") {
            return "NOAA"
        }
        return "Satélite"
    }
}

struct SatelliteImage: Codable, Identifiable, Equatable {
    let name: String
    let legend: String
    let passName: String
    let folderName: String

    var id: String { "\(passName)/\(folderName)/\(name)" }

    enum CodingKeys: String, CodingKey {
        case name, legend
        case passName = "pass_name"
        case folderName = "folder_name"
    }

    var cleanLegend: String {
        // Remove markdown formatting
        legend
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    var shortName: String {
        // Extract meaningful part from filename
        name
            .replacingOccurrences(of: "msu_mr_", with: "")
            .replacingOccurrences(of: "_corrected_map.png", with: "")
            .replacingOccurrences(of: "_corrected.png", with: "")
            .replacingOccurrences(of: ".png", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }
}

struct LastImages: Codable, Equatable {
    let timestamp: String
    let passName: String
    let images: [SatelliteImage]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case passName = "pass_name"
        case images
    }
}

struct PassesList: Codable {
    let timestamp: String
    let count: Int
    let passes: [SatellitePass]
}
