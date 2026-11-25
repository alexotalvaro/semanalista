import Foundation
import Security

enum Keychain {
    private static let service = "com.alejandro.semanalista2026"
    private static let account = "ai-api-key"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess && status != errSecItemNotFound {
            logAppError(Self.error(status), context: L10n.t("Leer la clave del Keychain"))
        }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            delete()
            return
        }
        let data = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            if addStatus != errSecSuccess {
                logAppError(Self.error(addStatus), context: L10n.t("Guardar la clave en el Keychain"))
            }
        } else if status != errSecSuccess {
            logAppError(Self.error(status), context: L10n.t("Actualizar la clave en el Keychain"))
        }
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logAppError(Self.error(status), context: L10n.t("Borrar la clave del Keychain"))
        }
    }

    private static func error(_ status: OSStatus) -> NSError {
        NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}

enum Storage {
    private static let settingsKey = "semanalista.settings.v1"
    private static let planKey = "semanalista.plan.v1"
    private static let checkedKey = "semanalista.checked.v1"
    private static let cookKey = "semanalista.cook.v1"
    private static let appearanceKey = "semanalista.appearance.v1"

    static func loadSettings() -> UserSettings? {
        load(UserSettings.self, key: settingsKey)
    }

    static func saveSettings(_ settings: UserSettings) {
        save(settings, key: settingsKey)
    }

    static func loadPlan() -> WeekPlan? {
        load(WeekPlan.self, key: planKey)
    }

    static func savePlan(_ plan: WeekPlan) {
        save(plan, key: planKey)
    }

    static func loadChecked() -> Set<String> {
        load(Set<String>.self, key: checkedKey) ?? []
    }

    static func saveChecked(_ checked: Set<String>) {
        save(checked, key: checkedKey)
    }

    static func loadCookChecked() -> Set<String> {
        load(Set<String>.self, key: cookKey) ?? []
    }

    static func saveCookChecked(_ checked: Set<String>) {
        save(checked, key: cookKey)
    }

    static func loadAppearance() -> AppAppearance? {
        guard let raw = UserDefaults.standard.string(forKey: appearanceKey) else { return nil }
        return AppAppearance(rawValue: raw)
    }

    static func saveAppearance(_ appearance: AppAppearance) {
        UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logAppError(
                error,
                context: L10n.format("Leer datos guardados (%@)", key),
                category: .storage
            )
            return nil
        }
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            logAppError(
                error,
                context: L10n.format("Guardar datos (%@)", key),
                category: .storage
            )
        }
    }
}
