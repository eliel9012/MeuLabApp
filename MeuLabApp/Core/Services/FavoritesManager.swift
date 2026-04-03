import Foundation
import Combine

// MARK: - Favorites Manager

@MainActor
final class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    private let key = "radar_favorite_aircraft"
    @Published var favorites: Set<String> = []

    private init() {
        load()
    }

    func isFavorite(_ identifier: String) -> Bool {
        favorites.contains(identifier.uppercased())
    }

    func toggle(_ identifier: String) {
        let id = identifier.uppercased()
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.insert(id)
        }
        save()
    }

    /// Check if aircraft matches any favorite (hex or callsign)
    func isFavorite(aircraft: Aircraft) -> Bool {
        if let hex = aircraft.hex, favorites.contains(hex.uppercased()) { return true }
        let cs = aircraft.callsign.trimmingCharacters(in: .whitespaces).uppercased()
        if !cs.isEmpty && favorites.contains(cs) { return true }
        return false
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) else { return }
        favorites = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
