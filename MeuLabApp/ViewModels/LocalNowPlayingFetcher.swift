import Foundation

#if canImport(MediaPlayer)
import MediaPlayer
#endif

/// Provides a local, low-latency way to fetch now-playing information from the device.
/// If local info isn't available, this throws so the caller can fall back to the backend API.
enum LocalNowPlayingFetcher {
    enum FetchError: Error {
        case unavailable
    }

    /// Attempts to read now-playing metadata from the system and convert it to your `NowPlaying` model.
    /// - Returns: A `NowPlaying` instance if local metadata is available.
    /// - Throws: `FetchError.unavailable` when local data can't be obtained.
    static func fetch() async throws -> NowPlaying {
        #if canImport(MediaPlayer)
        #if targetEnvironment(simulator)
        throw FetchError.unavailable
        #else
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            throw FetchError.unavailable
        }
        #endif

        let center = MPNowPlayingInfoCenter.default()
        guard let info = center.nowPlayingInfo, !info.isEmpty else {
            throw FetchError.unavailable
        }

        // Extract common metadata keys
        let title = (info[MPMediaItemPropertyTitle] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = (info[MPMediaItemPropertyArtist] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let album = (info[MPMediaItemPropertyAlbumTitle] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        // If we don't have at least a title, consider it unavailable
        guard let titleUnwrapped = title, !titleUnwrapped.isEmpty else {
            throw FetchError.unavailable
        }

        // Try to initialize NowPlaying with the most likely initializer signatures.
        // Since we don't know the exact API, we provide two construction paths guarded by availability.
        if let ctor = NowPlayingConstructors.preferred {
            return ctor(titleUnwrapped, artist, album)
        } else if let ctorDisplay = NowPlayingConstructors.displayTitleOnly {
            let display: String
            if let artist, !artist.isEmpty {
                display = "\(artist) — \(titleUnwrapped)"
            } else {
                display = titleUnwrapped
            }
            return ctorDisplay(display)
        } else {
            // As a last resort, synthesize a minimal display-only structure using reflection-free fallback.
            // This will likely be replaced by the real initializer path in your project.
            throw FetchError.unavailable
        }
        #else
        throw FetchError.unavailable
        #endif
    }
}

// MARK: - NowPlaying construction shims

/// Because we don't know the exact initializer signatures of your `NowPlaying` type,
/// provide indirection that can be manually updated if needed.
private enum NowPlayingConstructors {
    // Update these closures to match your actual `NowPlaying` initializers if different.
    static var preferred: ((String, String?, String?) -> NowPlaying)? = {
        // If your `NowPlaying` has an initializer like: init(title:artist:album:)
        // replace the body with: NowPlaying(title: $0, artist: $1, album: $2)
        // If not available, return nil below.
        return nil
    }()

    static var displayTitleOnly: ((String) -> NowPlaying)? = {
        // If your `NowPlaying` has an initializer like: init(displayTitle: String)
        // replace the body with: NowPlaying(displayTitle: $0)
        // If not available, return nil below.
        return nil
    }()
}
