import Foundation
import Combine

/// Módulo de estado para ACARS
@MainActor
class ACARSStateModule: ObservableObject {
    @Published var summary: ACARSSummary?
    @Published var messages: [ACARSMessage] = []
    @Published var hourlyStats: [ACARSHourStat] = []
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
            async let summaryTask = api.fetchACARSSummary()
            async let messagesTask = api.fetchACARSMessages(limit: 20)
            async let hourlyTask = api.fetchACARSHourly()

            let summary = try await summaryTask
            let messageList = try await messagesTask
            let hourly = try await hourlyTask

            if self.summary != summary {
                self.summary = summary
            }

            let newMessages = messageList.messages
            if self.messages != newMessages {
                self.messages = newMessages
            }

            let newHourly = hourly.hours
            if self.hourlyStats != newHourly {
                self.hourlyStats = newHourly
            }

            self.error = nil
            Logger.info("ACARS refresh: \(newMessages.count) mensagens, \(newHourly.count) horas")
        } catch {
            if summary == nil {
                self.error = error.localizedDescription
                Logger.error("ACARS refresh error: \(error.localizedDescription)")
            }
        }
    }
}
