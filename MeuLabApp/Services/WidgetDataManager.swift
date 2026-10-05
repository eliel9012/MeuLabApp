import Foundation
import WidgetKit

// MARK: - Shared Data Model
// Note: This struct must match the one in MeuLabWidgets.swift
struct WidgetSharedData: Codable {
    // System
    var cpuUsage: Double?
    var memoryUsage: Double?
    var diskUsage: Double?
    
    // ADS-B
    var adsbTotal: Int?
    var adsbWithPos: Int?
    
    // Radio
    var radioFrequency: String?
    var radioDescription: String?
    var radioSignal: Int? // 0-100
    
    // ACARS
    var acarsLastMessage: String?
    var acarsTotalMessages: Int?
    var acarsLastTime: String?
    
    // Satellite
    var satName: String?
    var satNextPass: String? // "14:30"
    var satElevation: String? // "45°"

    // Trip (next itinerary event)
    // All optional so previously persisted payloads keep decoding.
    var tripNextTitle: String?
    var tripNextTime: String? // "12 set · 17:30"
    var tripNextIcon: String? // SF Symbol name
    var tripNextDate: Date?

    var lastUpdate: Date
}

extension WidgetSharedData: Equatable {}

/// Persiste os dados dos widgets no App Group.
///
/// Chamado a cada poll (ADS-B, sistema, rádio, ACARS). Para não fazer IO + IPC com o
/// WidgetKit na main thread a cada segundo:
/// - mantém o estado em memória e ignora updates sem mudança real;
/// - grava em fila própria, agrupando updates próximos (`flushDelay`);
/// - recarrega as timelines no máximo a cada `minReloadInterval`.
final class WidgetDataManager: @unchecked Sendable {
    static let shared = WidgetDataManager()
    private let appGroup = "group.com.meulab"
    private let dataKey = "widget_shared_data"

    private let flushDelay: TimeInterval = 2
    private let minReloadInterval: TimeInterval = 60

    // Estado abaixo só é acessado dentro de `queue`.
    private let queue = DispatchQueue(label: "com.meulab.widget-data", qos: .utility)
    private lazy var defaults = UserDefaults(suiteName: appGroup)
    private var current: WidgetSharedData?
    private var flushScheduled = false
    private var lastReload: Date = .distantPast
    private var reloadScheduled = false

    // MARK: - Private Helpers

    private func loadLocked() -> WidgetSharedData {
        if let current { return current }
        let loaded: WidgetSharedData
        if let data = defaults?.data(forKey: dataKey),
            let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data)
        {
            loaded = decoded
        } else {
            loaded = WidgetSharedData(lastUpdate: Date())
        }
        current = loaded
        return loaded
    }

    /// Aplica `mutate`; só agenda gravação se algo mudou. Retorna se mudou.
    @discardableResult
    private func updateLocked(immediate: Bool, _ mutate: (inout WidgetSharedData) -> Void) -> Bool {
        var data = loadLocked()
        let before = data
        mutate(&data)
        guard data != before else { return false }
        current = data
        if immediate {
            flushLocked(forceReload: true)
        } else if !flushScheduled {
            flushScheduled = true
            queue.asyncAfter(deadline: .now() + flushDelay) { [self] in
                flushScheduled = false
                flushLocked(forceReload: false)
            }
        }
        return true
    }

    private func update(immediate: Bool = false, _ mutate: @escaping (inout WidgetSharedData) -> Void) {
        queue.async { [self] in updateLocked(immediate: immediate, mutate) }
    }

    private func flushLocked(forceReload: Bool) {
        guard var data = current, let defaults else { return }
        data.lastUpdate = Date()
        current = data
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: dataKey)
        // Chaves legadas (compatibilidade)
        if let cpu = data.cpuUsage { defaults.set(cpu, forKey: "widget_cpu_usage") }
        if let adsb = data.adsbTotal { defaults.set(adsb, forKey: "widget_adsb_total") }
        scheduleReloadLocked(force: forceReload)
    }

    private func scheduleReloadLocked(force: Bool) {
        let elapsed = Date().timeIntervalSince(lastReload)
        if force || elapsed >= minReloadInterval {
            lastReload = Date()
            WidgetCenter.shared.reloadAllTimelines()
        } else if !reloadScheduled {
            reloadScheduled = true
            queue.asyncAfter(deadline: .now() + (minReloadInterval - elapsed)) { [self] in
                reloadScheduled = false
                lastReload = Date()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    // MARK: - Public Updaters

    func updateSystem(cpu: Double, memory: Double, disk: Double) {
        update {
            $0.cpuUsage = cpu
            $0.memoryUsage = memory
            $0.diskUsage = disk
        }
    }

    func updateADSB(total: Int, withPos: Int) {
        update {
            $0.adsbTotal = total
            $0.adsbWithPos = withPos
        }
    }

    func updateRadio(frequency: String, description: String, signal: Int) {
        update {
            $0.radioFrequency = frequency
            $0.radioDescription = description
            $0.radioSignal = signal
        }
    }

    func updateACARS(lastMessage: String, total: Int, time: String) {
        update {
            $0.acarsLastMessage = lastMessage
            $0.acarsTotalMessages = total
            $0.acarsLastTime = time
        }
    }

    func updateSatellite(name: String, nextPass: String, elevation: String) {
        update {
            $0.satName = name
            $0.satNextPass = nextPass
            $0.satElevation = elevation
        }
    }

    /// Publish the next itinerary event to the widgets / complications.
    /// Pass `nil` for every field to clear it (trip finished or no upcoming event).
    func updateTrip(title: String?, time: String?, icon: String?, date: Date?) {
        // Evento de viagem é raro e o widget deve refletir na hora.
        update(immediate: true) {
            $0.tripNextTitle = title
            $0.tripNextTime = time
            $0.tripNextIcon = icon
            $0.tripNextDate = date
        }
    }

    // MARK: - Push Widget Updates

    /// Apply a widget update coming from an APNs payload (silent or alert).
    /// Expected payload shapes:
    /// - userInfo["widget_update"] as [String: Any]
    /// - userInfo["data"]["widget_update"] as [String: Any]
    ///
    /// Supported fields (all optional):
    /// - widget_update.system.cpu_usage (Double)
    /// - widget_update.system.memory_usage (Double)
    /// - widget_update.system.disk_usage (Double)
    ///
    /// Returns true if anything changed.
    @discardableResult
    func applyWidgetUpdateFromPush(userInfo: [AnyHashable: Any]) -> Bool {
        let update =
            (userInfo["widget_update"] as? [String: Any])
            ?? ((userInfo["data"] as? [String: Any])?["widget_update"] as? [String: Any])

        guard let update, let system = update["system"] as? [String: Any] else { return false }
        let cpu = Self.double(system["cpu_usage"])
        let memory = Self.double(system["memory_usage"])
        let disk = Self.double(system["disk_usage"])

        // Síncrono e imediato: o app pode ser suspenso logo após o completionHandler.
        return queue.sync {
            updateLocked(immediate: true) {
                if let cpu { $0.cpuUsage = cpu }
                if let memory { $0.memoryUsage = memory }
                if let disk { $0.diskUsage = disk }
            }
        }
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
