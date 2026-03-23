import SwiftUI
import UserNotifications

@main
struct MeuLabApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var pushManager = PushNotificationManager.shared
    @StateObject private var notificationFeed = NotificationFeedManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var startupTask: Task<Void, Never>?
    @State private var didConfigurePushNotifications = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .radarSplash()
                .environmentObject(appState)
                .environmentObject(pushManager)
                .environmentObject(notificationFeed)
                .onAppear {
                    scheduleDeferredStartup()
                }
                .onReceive(NotificationCenter.default.publisher(for: .pushNotificationReceived)) { notification in
                    handlePushNotification(notification)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        scheduleDeferredStartup()
                        notificationFeed.start()
                        appState.setRefreshEnabled(true)
                    } else if newPhase == .background {
                        startupTask?.cancel()
                        startupTask = nil
                        notificationFeed.stop()
                        appState.setRefreshEnabled(false)
                    }
                }
        }
    }

    private func scheduleDeferredStartup() {
        guard startupTask == nil else { return }

        startupTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            _ = NetworkEnvironment.shared
            appState.bootstrapIfNeeded()
            setupPushNotificationsIfNeeded()
            notificationFeed.start()
            appState.setRefreshEnabled(true)
            if #available(iOS 18.0, *) {
                Task {
                    await LabEntityIndexer.shared.reindexIfNeeded()
                }
            }
            startupTask = nil
        }
    }

    private func setupPushNotificationsIfNeeded() {
        guard !didConfigurePushNotifications else { return }
        didConfigurePushNotifications = true
        setupPushNotifications()
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
                UIApplication.shared.registerForRemoteNotifications()
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

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Handle silent/background pushes used to keep widgets fresh.
        let updated = WidgetDataManager.shared.applyWidgetUpdateFromPush(userInfo: userInfo)
        completionHandler(updated ? .newData : .noData)
    }
}

// MARK: - Navigation Notification

extension Notification.Name {
    static let meulabNavigateToTab = Notification.Name("meulab.navigateToTab")
    static let meulabOpenContext = Notification.Name("meulab.openContext")
    static let navigateToTab = Notification.Name.meulabNavigateToTab
}
