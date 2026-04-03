import Foundation

// MARK: - Conversões de Ângulos

extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}

// MARK: - Formatação de Distância

extension Double {
    /// Formata distância em milhas náuticas
    func asNauticalMiles() -> String {
        String(format: "%.1f nm", self)
    }

    /// Formata altitude em pés
    func asAltitude() -> String {
        String(format: "%.0f ft", self)
    }

    /// Formata velocidade em nós
    func asSpeed() -> String {
        String(format: "%.0f kt", self)
    }
}
