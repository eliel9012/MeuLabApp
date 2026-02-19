import Foundation
import UserNotifications
import WidgetKit

  final class NotificationService: UNNotificationServiceExtension {
      private var contentHandler: ((UNNotificationContent) -> Void)?
      private var bestAttemptContent: UNMutableNotificationContent?

      private let appGroup = "group.com.meulab"
      private let dataKey = "widget_shared_data"

      override func didReceive(
          _ request: UNNotificationRequest,
          withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
      ) {
          self.contentHandler = contentHandler
          self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

          guard let bestAttemptContent else {
              contentHandler(request.content)
              return
          }

          // Update widgets from the push payload (works even when the app isn't running).
          applyWidgetUpdate(userInfo: bestAttemptContent.userInfo)

          // API payload: userInfo["data"]["screenshot_public"]["public_url"]
          let userInfo = bestAttemptContent.userInfo
          let urlString =
              (((userInfo["data"] as? [String: Any])?["screenshot_public"] as? [String: Any])?["public_url"] as? String)
              ?? ((userInfo["data"] as? [String: Any])?["image_url"] as? String)

          guard
              let urlString,
              let url = URL(string: urlString),
              url.scheme?.lowercased() == "https"
          else {
              contentHandler(bestAttemptContent)
              return
          }

          URLSession.shared.downloadTask(with: url) { tmpURL, _, _ in
              defer { contentHandler(bestAttemptContent) }
              guard let tmpURL else { return }

              do {
                  let fileManager = FileManager.default
                  let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
                  let localURL = URL(fileURLWithPath: NSTemporaryDirectory())
                      .appendingPathComponent("meulab_push_image.\(ext)")

                  if fileManager.fileExists(atPath: localURL.path) {
                      try fileManager.removeItem(at: localURL)
                  }
                  try fileManager.moveItem(at: tmpURL, to: localURL)

                  let attachment = try UNNotificationAttachment(identifier: "image", url: localURL, options: nil)
                  bestAttemptContent.attachments = [attachment]
              } catch {
                  // se falhar, manda sem imagem
              }
          }.resume()
      }

      override func serviceExtensionTimeWillExpire() {
          if let contentHandler, let bestAttemptContent {
              contentHandler(bestAttemptContent)
          }
      }

      private func applyWidgetUpdate(userInfo: [AnyHashable: Any]) {
          let update =
              (userInfo["widget_update"] as? [String: Any])
              ?? ((userInfo["data"] as? [String: Any])?["widget_update"] as? [String: Any])
          guard let update else { return }

          guard let defaults = UserDefaults(suiteName: appGroup) else { return }
          var current = loadCurrentData(defaults: defaults)
          var changed = false

          if let system = update["system"] as? [String: Any] {
              if let v = Self.double(system["cpu_usage"]), current.cpuUsage != v {
                  current.cpuUsage = v
                  changed = true
              }
              if let v = Self.double(system["memory_usage"]), current.memoryUsage != v {
                  current.memoryUsage = v
                  changed = true
              }
              if let v = Self.double(system["disk_usage"]), current.diskUsage != v {
                  current.diskUsage = v
                  changed = true
              }
          }

          guard changed else { return }

          current.lastUpdate = Date()
          if let encoded = try? JSONEncoder().encode(current) {
              defaults.set(encoded, forKey: dataKey)
              defaults.synchronize()
              WidgetCenter.shared.reloadAllTimelines()
          }
      }

      private func loadCurrentData(defaults: UserDefaults) -> WidgetSharedData {
          if let data = defaults.data(forKey: dataKey),
             let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data) {
              return decoded
          }
          return WidgetSharedData(lastUpdate: Date())
      }

      private static func double(_ any: Any?) -> Double? {
          switch any {
          case let n as NSNumber:
              return n.doubleValue
          case let d as Double:
              return d
          case let i as Int:
              return Double(i)
          case let s as String:
              return Double(s.replacingOccurrences(of: ",", with: "."))
          default:
              return nil
          }
      }
  }

  // MARK: - Shared Data Model (must match the widget/app)

  private struct WidgetSharedData: Codable {
      var cpuUsage: Double?
      var memoryUsage: Double?
      var diskUsage: Double?

      var adsbTotal: Int?
      var adsbWithPos: Int?

      var radioFrequency: String?
      var radioDescription: String?
      var radioSignal: Int?

      var acarsLastMessage: String?
      var acarsTotalMessages: Int?
      var acarsLastTime: String?

      var satName: String?
      var satNextPass: String?
      var satElevation: String?

      var lastUpdate: Date
  }
