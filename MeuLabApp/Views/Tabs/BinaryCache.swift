import Foundation

#if canImport(CryptoKit)
import CryptoKit
#endif

/// Disk-backed cache for binary payloads (SatDump FFTs, pass imagery).
///
/// Every entry point is reached from an `async` function, so nothing here may
/// block a cooperative-pool thread. The serial queue still provides mutual
/// exclusion over the cache directory, but callers reach it through a
/// continuation rather than `dispatch_sync`.
final class BinaryCache: @unchecked Sendable {
    static let shared = BinaryCache()

    private let memoryCache = NSCache<NSString, NSData>()
    private let ioQueue = DispatchQueue(label: "BinaryCache.ioQueue")

    private let cacheDirectoryURL: URL

    private init() {
        let cachesDirectories = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let baseURL = cachesDirectories.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        cacheDirectoryURL = baseURL.appendingPathComponent("BinaryCache", isDirectory: true)

        // Enqueued rather than awaited: the queue is serial, so every later
        // read or write is ordered behind this and finds the directory in place.
        let directoryURL = cacheDirectoryURL
        ioQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // If directory creation fails, there's not much we can do here
            }
        }
    }

    func cachedData(forPath path: String) async -> Data? {
        // NSCache is thread-safe, so a hit costs nothing and never suspends.
        if let cached = memoryCache.object(forKey: path as NSString) {
            return cached as Data
        }

        let fileURL = fileURLForPath(path)

        return await withCheckedContinuation { continuation in
            ioQueue.async { [weak self] in
                guard FileManager.default.fileExists(atPath: fileURL.path),
                    let fileData = try? Data(contentsOf: fileURL)
                else {
                    // Missing or unreadable file, treat as a cache miss
                    continuation.resume(returning: nil)
                    return
                }
                self?.memoryCache.setObject(fileData as NSData, forKey: path as NSString)
                continuation.resume(returning: fileData)
            }
        }
    }

    func store(_ data: Data, forPath path: String) {
        memoryCache.setObject(data as NSData, forKey: path as NSString)
        let fileURL = fileURLForPath(path)

        ioQueue.async {
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Failed to write to disk, nothing else to do
            }
        }
    }

    func clear() {
        memoryCache.removeAllObjects()
        ioQueue.async {
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: self.cacheDirectoryURL, includingPropertiesForKeys: nil, options: [])
                for file in contents {
                    try FileManager.default.removeItem(at: file)
                }
            } catch {
                // Failed to clear disk cache, ignore
            }
        }
    }

    private func fileURLForPath(_ path: String) -> URL {
        let filename = BinaryCache.hashString(path) + ".bin"
        return cacheDirectoryURL.appendingPathComponent(filename)
    }

    static func hashString(_ string: String) -> String {
        #if canImport(CryptoKit)
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *) {
            let inputData = Data(string.utf8)
            let hashed = SHA256.hash(data: inputData)
            return hashed.compactMap { String(format: "%02x", $0) }.joined()
        } else {
            return fallbackHash(string)
        }
        #else
        return fallbackHash(string)
        #endif
    }

    private static func fallbackHash(_ string: String) -> String {
        let base64 = Data(string.utf8).base64EncodedString()
        // sanitize base64 to filesystem-safe: remove "/" and "+" and "=" replace with "-"
        let sanitized = base64
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "+", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return sanitized
    }
}
