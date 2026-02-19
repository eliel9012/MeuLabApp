import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                // Resumo (Home)
                NavigationLink {
                    HomeView()
                } label: {
                    Label("Resumo", systemImage: "rectangle.3.group.bubble.left.fill")
                }
                
                // Alertas
                NavigationLink {
                    AlertsView()
                } label: {
                    Label("Alertas", systemImage: "bell.badge.fill")
                }
                
                Section("Categorias") {
                    NavigationLink {
                        WatchADSBView()
                    } label: {
                        Label("ADS-B", systemImage: "airplane.radar")
                    }
                    
                    NavigationLink {
                        WatchACARSView()
                    } label: {
                        Label("ACARS", systemImage: "envelope.badge.fill")
                    }
                    
                    NavigationLink {
                        WatchSystemView()
                    } label: {
                        Label("Sistema", systemImage: "cpu.fill")
                    }
                    
                    NavigationLink {
                        WatchInfraView()
                    } label: {
                        Label("Infra", systemImage: "server.rack")
                    }
                    
                    NavigationLink {
                        WatchWeatherView()
                    } label: {
                        Label("Clima", systemImage: "cloud.sun.fill")
                    }
                    
                    NavigationLink {
                        WatchSatDumpView()
                    } label: {
                        Label("SatDump", systemImage: "satellite.fill")
                    }
                }
            }
            .navigationTitle("MeuLab")
        }
    }
}

#Preview {
    ContentView()
}
