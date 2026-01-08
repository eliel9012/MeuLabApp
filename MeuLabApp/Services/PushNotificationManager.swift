import Foundation
import UserNotifications
import UIKit

/// Gerenciador de Push Notifications para o MeuLab App
@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()

    @Published var isRegistered = false
    @Published var deviceToken: String?
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
    }

    // MARK: - Permission Request

    /// Solicita permissão para notificações
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await updatePermissionStatus()

            if granted {
                await registerForRemoteNotifications()
            }

            return granted
        } catch {
            print("Erro ao solicitar permissão: \(error)")
            return false
        }
    }

    /// Atualiza o status de permissão
    func updatePermissionStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        permissionStatus = settings.authorizationStatus
    }

    /// Registra para notificações remotas
    private func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Token Registration

    /// Processa o device token recebido do APNs
    func handleDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        print("Device token: \(tokenString)")

        // Envia para o servidor
        Task {
            await registerTokenWithServer(tokenString)
        }
    }

    /// Registra o token no servidor
    private func registerTokenWithServer(_ token: String) async {
        do {
            var deviceInfo: [String: Any] = [
                "device_name": await UIDevice.current.name,
                "device_model": await UIDevice.current.model,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                "os_version": await UIDevice.current.systemVersion
            ]

            // Adiciona localização se disponível
            if let userLocation = LocationManager.shared.userLocation {
                deviceInfo["latitude"] = userLocation.coordinate.latitude
                deviceInfo["longitude"] = userLocation.coordinate.longitude
            }

            try await APIService.shared.registerDeviceToken(token: token, deviceInfo: deviceInfo)
            isRegistered = true
            print("Token registrado no servidor")
        } catch {
            print("Erro ao registrar token no servidor: \(error)")
            isRegistered = false
        }
    }

    /// Processa erro de registro
    func handleRegistrationError(_ error: Error) {
        print("Erro no registro APNs: \(error)")
        isRegistered = false
    }

    // MARK: - Notification Categories

    /// Configura categorias de notificações
    func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        // Categoria: Alerta ADS-B
        let adsbCategory = UNNotificationCategory(
            identifier: "adsb_alert",
            actions: [
                UNNotificationAction(identifier: "view_radar", title: "Ver no Radar", options: .foreground)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Categoria: Alerta ACARS
        let acarsCategory = UNNotificationCategory(
            identifier: "acars_alert",
            actions: [
                UNNotificationAction(identifier: "view_acars", title: "Ver Mensagem", options: .foreground)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Categoria: Alerta Meteorológico
        let weatherCategory = UNNotificationCategory(
            identifier: "weather_alert",
            actions: [
                UNNotificationAction(identifier: "view_weather", title: "Ver Detalhes", options: .foreground)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        // Categoria: Satélite
        let satelliteCategory = UNNotificationCategory(
            identifier: "satellite",
            actions: [
                UNNotificationAction(identifier: "view_images", title: "Ver Imagens", options: .foreground)
            ],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        center.setNotificationCategories([adsbCategory, acarsCategory, weatherCategory, satelliteCategory])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationManager: UNUserNotificationCenterDelegate {
    /// Notificação recebida enquanto app está em foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Mostra banner e som mesmo com app aberto
        return [.banner, .sound, .badge]
    }

    /// Usuário interagiu com a notificação
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let category = response.notification.request.content.categoryIdentifier
        let actionId = response.actionIdentifier

        print("Notificação recebida - categoria: \(category), ação: \(actionId)")

        // Processa dados da notificação
        if let data = userInfo["data"] as? [String: Any] {
            await handleNotificationData(category: category, data: data)
        }
    }

    /// Processa dados da notificação
    @MainActor
    private func handleNotificationData(category: String, data: [String: Any]) {
        // Envia notificação para navegação no app
        NotificationCenter.default.post(
            name: .pushNotificationReceived,
            object: nil,
            userInfo: ["category": category, "data": data]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let pushNotificationReceived = Notification.Name("pushNotificationReceived")
}

// MARK: - APIService Extension

extension APIService {
    /// Registra device token no servidor
    func registerDeviceToken(token: String, deviceInfo: [String: Any]) async throws {
        let url = baseURL.appendingPathComponent("notifications/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_token": token,
            "device_info": deviceInfo
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("Registro push: \(json)")
        }
    }

    /// Remove device token do servidor
    func unregisterDeviceToken(token: String) async throws {
        let url = baseURL.appendingPathComponent("notifications/unregister")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["device_token": token]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
