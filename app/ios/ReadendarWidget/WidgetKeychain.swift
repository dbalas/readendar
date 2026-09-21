import Foundation
import Security

/// Shared Keychain for widget bearer tokens.
///
/// Access group matches the App Group so Runner and the WidgetKit extension
/// can both read/write. Accessibility is AfterFirstUnlockThisDeviceOnly:
/// readable after first unlock, never restored onto another device.
enum WidgetKeychain {
    static let service = "com.readendar.widget.secrets"
    private static let appGroup = "group.com.readendar.readendar"

    static func read(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func write(_ account: String, _ value: String) -> Bool {
        guard accessGroup != nil else { return false }
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(baseQuery(account) as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery(account)
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        return status == errSecSuccess
    }

    static func remove(_ account: String) -> Bool {
        let status = SecItemDelete(baseQuery(account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Writes both tokens, or restores the previous pair. A half-written
    /// pair is never left in Keychain: if rollback cannot restore the old
    /// access token, both entries are deleted so the Dart defaults fallback
    /// is what the widget reads.
    static func writeTokens(access: String, refresh: String) -> Bool {
        guard accessGroup != nil else { return false }
        let previousAccess = read("wdg_access")
        guard write("wdg_access", access) else { return false }
        guard write("wdg_refresh", refresh) else {
            restore("wdg_access", previousAccess)
            if read("wdg_access") != previousAccess {
                _ = remove("wdg_access")
                _ = remove("wdg_refresh")
            }
            return false
        }
        scrubDefaults("wdg_access")
        scrubDefaults("wdg_refresh")
        return true
    }

    static func clearTokens() -> Bool {
        _ = remove("wdg_access")
        _ = remove("wdg_refresh")
        // Retry once so a transient failure on the second delete cannot leave
        // a singleton Keychain entry while we report failure.
        let accessGone = remove("wdg_access")
        let refreshGone = remove("wdg_refresh")
        guard accessGone && refreshGone else { return false }
        scrubDefaults("wdg_access")
        scrubDefaults("wdg_refresh")
        return true
    }

    private static func restore(_ account: String, _ previous: String?) {
        if let previous {
            _ = write(account, previous)
        } else {
            _ = remove(account)
        }
    }

    static func scrubDefaults(_ key: String) {
        let defaults = UserDefaults(suiteName: appGroup) ?? .standard
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: "flutter.\(key)")
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    /// Runtime access group is `<TeamID>.group.com.readendar.readendar`.
    private static let accessGroup: String? = {
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "readendar.widget.teamid",
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecReturnAttributes as String: true,
        ]
        var result: AnyObject?
        var status = SecItemCopyMatching(probe as CFDictionary, &result)
        if status == errSecItemNotFound {
            SecItemAdd(probe as CFDictionary, nil)
            status = SecItemCopyMatching(probe as CFDictionary, &result)
        }
        guard status == errSecSuccess,
              let attrs = result as? [String: Any],
              let group = attrs[kSecAttrAccessGroup as String] as? String,
              let dot = group.firstIndex(of: ".")
        else { return nil }
        return String(group[..<dot]) + "." + appGroup
    }()
}
