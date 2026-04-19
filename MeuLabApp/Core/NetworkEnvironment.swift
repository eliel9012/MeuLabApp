import Foundation

/// Provides the base API URL. Always uses the production remote endpoint.
@MainActor
final class NetworkEnvironment: ObservableObject {
    static let shared = NetworkEnvironment()

    // MARK: - Published URLs

    @Published private(set) var apiBaseURL: String = "https://app.meulab.fun"

    /// Always false — local network probing has been removed.
    @Published private(set) var isLocal: Bool = false

    private init() {}
}
