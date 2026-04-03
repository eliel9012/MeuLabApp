import Foundation

/// 🔐 Configuration Manager for watchOS
/// Centralizes access to API Token from Secrets.plist or environment variables
/// NEVER commit Secrets.plist to GitHub - it's in .gitignore
enum WatchSecrets {
    /// API authentication token for watchOS
    static var apiToken: String {
        loadSecret(key: "MEULAB_API_TOKEN", fallback: "")
    }
    
    /// Alternative token key for backward compatibility
    static var apiTokenAlternative: String {
        loadSecret(key: "API_TOKEN", fallback: "")
    }
    
    /// Check if API token is configured
    static var isConfigured: Bool {
        !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !apiTokenAlternative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Load a secret from Secrets.plist or environment variable
    /// - Parameters:
    ///   - key: The key to load
    ///   - fallback: Default value if not found
    /// - Returns: Secret value or fallback
    private static func loadSecret(key: String, fallback: String) -> String {
        // 1️⃣ Try environment variable first
        if let envValue = ProcessInfo.processInfo.environment[key] {
            let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        
        // 2️⃣ Try Info.plist
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        
        // 3️⃣ Try Secrets.plist
        if let secretsPath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let secureDictionary = NSDictionary(contentsOfFile: secretsPath) as? [String: Any],
           let secret = secureDictionary[key] as? String {
            let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        
        // 4️⃣ Return fallback
        #if DEBUG
        if fallback.isEmpty {
            print("⚠️  WARNING (watchOS): Secret '\(key)' not configured")
        }
        #endif
        
        return fallback
    }
}
