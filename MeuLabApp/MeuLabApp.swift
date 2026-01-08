import SwiftUI
import UserNotifications

@main
struct MeuLabApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var pushManager = PushNotificationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(pushManager)
                .onAppear {
                    setupPushNotifications()
                }
                .onReceive(NotificationCenter.default.publisher(for: .pushNotificationReceived)) { notification in
                    handlePushNotification(notification)
                }
        }
    }

    private func setupPushNotifications() {
        // Configura categorias
        pushManager.setupNotificationCategories()

        // Solicita permissão se ainda não tem
        Task {
            await pushManager.updatePermissionStatus()

            if pushManager.permissionStatus == .notDetermined {
                _ = await pushManager.requestPermission()
            } else if pushManager.permissionStatus == .authorized {
                // Já autorizado, registra novamente
                await UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func handlePushNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let category = userInfo["category"] as? String else {
            return
        }

        // Navega para a aba apropriada baseado na categoria
        switch category {
        case "adsb_alert":
            // Navega para tab ADS-B ou Radar
            NotificationCenter.default.post(name: .navigateToTab, object: nil, userInfo: ["tab": "radar"])
        case "acars_alert":
            NotificationCenter.default.post(name: .navigateToTab, object: nil, userInfo: ["tab": "acars"])
        case "weather_alert":
            NotificationCenter.default.post(name: .navigateToTab, object: nil, userInfo: ["tab": "weather"])
        case "satellite":
            NotificationCenter.default.post(name: .navigateToTab, object: nil, userInfo: ["tab": "satellite"])
        default:
            break
        }
    }
}

// MARK: - AppDelegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configura delegate de notificações
        UNUserNotificationCenter.current().delegate = PushNotificationManager.shared
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationManager.shared.handleRegistrationError(error)
    }
}

// MARK: - Navigation Notification

extension Notification.Name {
    static let navigateToTab = Notification.Name("navigateToTab")
}
