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
    
    var lastUpdate: Date
}

class WidgetDataManager {
    static let shared = WidgetDataManager()
    private let appGroup = "group.com.meulab"
    private let dataKey = "widget_shared_data"
    
    // MARK: - Private Helpers
    private func loadCurrentData() -> WidgetSharedData {
        if let defaults = UserDefaults(suiteName: appGroup),
           let data = defaults.data(forKey: dataKey),
           let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data) {
            return decoded
        }
        return WidgetSharedData(lastUpdate: Date())
    }
    
    private func saveData(_ data: WidgetSharedData) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        
        var updatedData = data
        updatedData.lastUpdate = Date()
        
        if let encoded = try? JSONEncoder().encode(updatedData) {
            defaults.set(encoded, forKey: dataKey)
            
            // Legacy/Backup keys if needed (keeping for backwards compatibility if any)
            if let cpu = data.cpuUsage { defaults.set(cpu, forKey: "widget_cpu_usage") }
            if let adsb = data.adsbTotal { defaults.set(adsb, forKey: "widget_adsb_total") }
            
            defaults.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // MARK: - Public Updaters
    
    func updateSystem(cpu: Double, memory: Double, disk: Double) {
        var data = loadCurrentData()
        data.cpuUsage = cpu
        data.memoryUsage = memory
        data.diskUsage = disk
        saveData(data)
    }
    
    func updateADSB(total: Int, withPos: Int) {
        var data = loadCurrentData()
        data.adsbTotal = total
        data.adsbWithPos = withPos
        saveData(data)
    }
    
    func updateRadio(frequency: String, description: String, signal: Int) {
        var data = loadCurrentData()
        data.radioFrequency = frequency
        data.radioDescription = description
        data.radioSignal = signal
        saveData(data)
    }
    
    func updateACARS(lastMessage: String, total: Int, time: String) {
        var data = loadCurrentData()
        data.acarsLastMessage = lastMessage
        data.acarsTotalMessages = total
        data.acarsLastTime = time
        saveData(data)
    }
    
    func updateSatellite(name: String, nextPass: String, elevation: String) {
        var data = loadCurrentData()
        data.satName = name
        data.satNextPass = nextPass
        data.satElevation = elevation
        saveData(data)
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

        guard let update else { return false }

        var changed = false
        var data = loadCurrentData()

        if let system = update["system"] as? [String: Any] {
            if let v = Self.double(system["cpu_usage"]), data.cpuUsage != v {
                data.cpuUsage = v
                changed = true
            }
            if let v = Self.double(system["memory_usage"]), data.memoryUsage != v {
                data.memoryUsage = v
                changed = true
            }
            if let v = Self.double(system["disk_usage"]), data.diskUsage != v {
                data.diskUsage = v
                changed = true
            }
        }

        if changed {
            saveData(data)
        }
        return changed
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
