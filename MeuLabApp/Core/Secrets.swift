import Foundation

/// 🔐 Configuration Manager for API Secrets
/// Centralizes access to configuration from Secrets.plist or environment variables
/// NEVER commit Secrets.plist to GitHub - it's in .gitignore
enum Secrets {
    private static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.meulab.app"
    
    /// API base URL
    static var apiBaseURL: String {
        loadSecret(key: "API_BASE_URL", fallback: "https://app.meulab.fun")
    }
    
    /// API authentication token
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
        // 1️⃣ Try environment variable first (useful for CI/CD)
        if let envValue = ProcessInfo.processInfo.environment[key] {
            let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        
        // 2️⃣ Try Info.plist (if populated via build phases)
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = plistValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        
        // 3️⃣ Try Secrets.plist (developer local configuration)
        if let secretsPath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let secureDictionary = NSDictionary(contentsOfFile: secretsPath) as? [String: Any],
           let secret = secureDictionary[key] as? String {
            let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        
        // 4️⃣ Return fallback (empty string for sensitive values)
        #if DEBUG
        if fallback.isEmpty {
            print("⚠️  WARNING: Secret '\(key)' not configured. Set via:")
            print("   - Environment variable: export \(key)=your_value")
            print("   - Secrets.plist (local only, not in git)")
            print("   - Info.plist with build variable $(KEY)")
        }
        #endif
        
        return fallback
    }
    
    /// Log configuration status (DEBUG only)
    static func debugPrintStatus() {
        #if DEBUG
        print("🔐 Secrets Configuration Status:")
        print("   API Base URL: \(apiBaseURL)")
        print("   API Token configured: \(isConfigured)")
        print("   Token (first 10 chars): \(String(apiToken.prefix(10)))...")
        #endif
    }
}
