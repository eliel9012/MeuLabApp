import Foundation
import Combine

/// Módulo de estado para Sistema
@MainActor
class SystemStateModule: ObservableObject {
    @Published var status: SystemStatus?
    @Published var error: String?
    @Published var isLoading = false

    private let api: APIServiceProtocol

    init(api: APIServiceProtocol) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let status = try await api.fetchSystemStatus()

            if self.status != status {
                self.status = status
            }
            self.error = nil
            Logger.info("System refresh: \(status.uptime) uptime")
        } catch {
            if status == nil {
                self.error = error.localizedDescription
                Logger.error("System refresh error: \(error.localizedDescription)")
            }
        }
    }
}
