import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pushManager: PushNotificationManager
    @State private var selectedTab: Tab = .adsb

    enum Tab: String, CaseIterable {
        case adsb = "airplane"
        case map = "map"
        case acars = "envelope.badge"
        case satellite = "antenna.radiowaves.left.and.right"
        case system = "cpu"
        case radio = "radio"
        case weather = "cloud.sun"

        var title: String {
            switch self {
            case .adsb: return "ADS-B"
            case .map: return "Radar"
            case .acars: return "ACARS"
            case .satellite: return "Satélite"
            case .system: return "Sistema"
            case .radio: return "Rádio"
            case .weather: return "Clima"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ADSBView()
                .tabItem {
                    Label(Tab.adsb.title, systemImage: Tab.adsb.rawValue)
                }
                .tag(Tab.adsb)

            MapView()
                .tabItem {
                    Label(Tab.map.title, systemImage: Tab.map.rawValue)
                }
                .tag(Tab.map)

            ACARSView()
                .tabItem {
                    Label(Tab.acars.title, systemImage: Tab.acars.rawValue)
                }
                .tag(Tab.acars)

            SatelliteView()
                .tabItem {
                    Label(Tab.satellite.title, systemImage: Tab.satellite.rawValue)
                }
                .tag(Tab.satellite)

            SystemView()
                .tabItem {
                    Label(Tab.system.title, systemImage: Tab.system.rawValue)
                }
                .tag(Tab.system)

            RadioView()
                .tabItem {
                    Label(Tab.radio.title, systemImage: Tab.radio.rawValue)
                }
                .tag(Tab.radio)

            WeatherView()
                .tabItem {
                    Label(Tab.weather.title, systemImage: Tab.weather.rawValue)
                }
                .tag(Tab.weather)
        }
        .tint(.blue)
        .onReceive(NotificationCenter.default.publisher(for: .navigateToTab)) { notification in
            if let userInfo = notification.userInfo,
               let tabName = userInfo["tab"] as? String {
                switch tabName {
                case "adsb": selectedTab = .adsb
                case "radar", "map": selectedTab = .map
                case "acars": selectedTab = .acars
                case "satellite": selectedTab = .satellite
                case "system": selectedTab = .system
                case "radio": selectedTab = .radio
                case "weather": selectedTab = .weather
                default: break
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(PushNotificationManager.shared)
}
