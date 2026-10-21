import SwiftUI

struct SettingsView: View {
    @Environment(FlightStore.self) private var store

    var body: some View {
        Form {
            Section("Visualização espacial") {
                Picker("Raio horizontal", selection: Binding(
                    get: { store.settings.radiusKilometers },
                    set: { store.settings.radiusKilometers = $0 }
                )) {
                    Text("50 km").tag(50.0)
                    Text("100 km").tag(100.0)
                    Text("200 km").tag(200.0)
                }
                Picker("Exagero vertical", selection: Binding(
                    get: { store.settings.verticalExaggeration },
                    set: { store.settings.verticalExaggeration = $0 }
                )) {
                    Text("1×").tag(1.0)
                    Text("1,5×").tag(1.5)
                    Text("2×").tag(2.0)
                }
                Picker("Altitude mínima", selection: Binding(
                    get: { store.settings.minimumAltitudeFeet },
                    set: { store.settings.minimumAltitudeFeet = $0 }
                )) {
                    Text("Solo").tag(0.0)
                    Text("10.000 ft").tag(10_000.0)
                    Text("20.000 ft").tag(20_000.0)
                    Text("30.000 ft").tag(30_000.0)
                }
                Text("A altura dos marcadores é exagerada para legibilidade; não está na mesma escala que a distância horizontal.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Dados") {
                LabeledContent("Endpoint", value: "radar.meulab.fun")
                LabeledContent("Frescor da posição", value: "30 segundos")
                LabeledContent("Atualização", value: "3 s; backoff em falhas")
                Text("Origem geográfica aproximada: 20,54° S · 47,40° O. Não corresponde à posição validada da antena.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Configurações")
    }
}
