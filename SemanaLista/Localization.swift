import Foundation

enum AppLanguage {
    /// Idioma resuelto por iOS para la app (según el idioma del teléfono y las
    /// localizaciones declaradas). De momento la app soporta español e inglés.
    static var code: String {
        if let preferred = Bundle.main.preferredLocalizations.first, preferred.hasPrefix("en") {
            return "en"
        }
        return "es"
    }

    static var isEnglish: Bool { code == "en" }

    static var locale: Locale {
        Locale(identifier: isEnglish ? "en_GB" : "es_ES")
    }
}

enum L10n {
    /// Traduce una clave. Las claves son los textos en español del código y
    /// `en.lproj/Localizable.strings` contiene su versión inglesa.
    static func t(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: NSLocalizedString(key, comment: ""), arguments: args)
    }
}
