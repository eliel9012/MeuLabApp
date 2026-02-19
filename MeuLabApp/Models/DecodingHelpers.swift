import Foundation

struct LossyDecodableArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []

        while !container.isAtEnd {
            if let value = try? container.decode(Element.self) {
                elements.append(value)
            } else {
                _ = try? container.decode(EmptyDecodable.self)
            }
        }

        self.elements = elements
    }
}

private struct EmptyDecodable: Decodable {}

extension KeyedDecodingContainer {
    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key, default defaultValue: T) -> T {
        (try? decodeIfPresent(type, forKey: key)) ?? defaultValue
    }

    func decodeLossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
        (try? decode(LossyDecodableArray<T>.self, forKey: key).elements) ?? []
    }
}
