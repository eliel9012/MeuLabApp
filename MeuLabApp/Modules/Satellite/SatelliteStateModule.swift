import Foundation
import Combine

/// Módulo de estado para Satélites
@MainActor
class SatelliteStateModule: ObservableObject {
    @Published var lastImages: LastImages?
    @Published var passes: [SatellitePass] = []
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
            async let imagesTask = api.fetchLastImages()
            async let passesTask = api.fetchPasses()

            let images = try await imagesTask
            let passesList = try await passesTask

            if self.lastImages != images {
                self.lastImages = images
            }

            let newPasses = passesList.passes
            if self.passes != newPasses {
                self.passes = newPasses
            }

            self.error = nil
            Logger.info("Satellite refresh: \(images.passes.count) passes")
        } catch {
            if lastImages == nil {
                self.error = error.localizedDescription
                Logger.error("Satellite refresh error: \(error.localizedDescription)")
            }
        }
    }
}
