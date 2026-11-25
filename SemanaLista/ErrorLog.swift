import Foundation
import Observation

// MARK: - Modelo

enum AppErrorCategory: String, Codable, CaseIterable, Identifiable {
    case app
    case ai
    case network
    case storage
    case export
    case photos
    case crash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: L10n.t("General")
        case .ai: L10n.t("Inteligencia artificial")
        case .network: L10n.t("Red")
        case .storage: L10n.t("Almacenamiento")
        case .export: L10n.t("Exportar menú")
        case .photos: L10n.t("Fotos")
        case .crash: L10n.t("Cierre inesperado")
        }
    }

    var symbol: String {
        switch self {
        case .app: "exclamationmark.circle.fill"
        case .ai: "sparkles"
        case .network: "wifi.exclamationmark"
        case .storage: "internaldrive"
        case .export: "doc.badge.ellipsis"
        case .photos: "photo.badge.exclamationmark"
        case .crash: "xmark.octagon.fill"
        }
    }
}

struct LoggedError: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var category: AppErrorCategory
    var summary: String
    var context: String
    var details: String

    var formattedDate: String {
        LoggedError.dateFormatter.string(from: date)
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Registro

@MainActor
@Observable
final class ErrorLog {
    static let shared = ErrorLog()

    private(set) var entries: [LoggedError] = []

    private static let maxEntries = 200
    private static let storeKey = "semanalista.errorlog.v1"
    private static let sessionKey = "semanalista.session.active"

    private init() {
        load()
        importCrashReports()
        checkPreviousSession()
        UserDefaults.standard.set(true, forKey: Self.sessionKey)
    }

    // MARK: API pública

    func log(_ error: Error, context: String, category: AppErrorCategory? = nil) {
        // Una cancelación no es un fallo: no ensucia el registro.
        if error is CancellationError { return }
        if let urlError = error as? URLError, urlError.code == .cancelled { return }

        let resolved = category ?? Self.category(for: error)
        let nsError = error as NSError

        var details = String(reflecting: error)
        details += "\nDominio: \(nsError.domain) · Código: \(nsError.code)"
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            details += "\nCausa: \(String(reflecting: underlying))"
        }
        let stack = Thread.callStackSymbols.dropFirst().prefix(12).joined(separator: "\n")
        if !stack.isEmpty {
            details += "\nPila:\n\(stack)"
        }

        append(
            LoggedError(
                category: resolved,
                summary: error.localizedDescription,
                context: context,
                details: details
            )
        )
    }

    func log(
        message: String,
        context: String,
        category: AppErrorCategory = .app,
        details: String = ""
    ) {
        append(
            LoggedError(
                category: category,
                summary: message,
                context: context,
                details: details
            )
        )
    }

    func clear() {
        entries = []
        persist()
    }

    func exportText() -> String {
        var lines: [String] = []
        lines.append(L10n.t("Semana Lista · Registro de errores"))
        lines.append(L10n.format("Generado: %@", Date().description(with: AppLanguage.locale)))
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        lines.append(L10n.format("Versión: %@ (%@)", version, build))
        lines.append(L10n.format("Dispositivo: %@ · iOS %@", Self.deviceModel, Self.systemVersion))
        lines.append(L10n.format("Errores guardados: %lld", entries.count))
        lines.append("")

        if entries.isEmpty {
            lines.append(L10n.t("No hay errores registrados."))
        } else {
            for (index, entry) in entries.enumerated() {
                lines.append("────────────────────────────")
                lines.append("#\(index + 1) · \(entry.formattedDate)")
                lines.append(L10n.format("Categoría: %@", entry.category.title))
                lines.append(L10n.format("Contexto: %@", entry.context))
                lines.append(L10n.format("Error: %@", entry.summary))
                if !entry.details.isEmpty {
                    lines.append(L10n.t("Detalles:"))
                    lines.append(entry.details)
                }
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: Sesión y cierres inesperados

    /// Marca la sesión como activa. Se llama al volver al primer plano.
    func markSessionActive() {
        UserDefaults.standard.set(true, forKey: Self.sessionKey)
    }

    /// Marca la sesión como cerrada correctamente. Se llama al pasar a segundo plano.
    func markSessionFinished() {
        UserDefaults.standard.set(false, forKey: Self.sessionKey)
    }

    private func checkPreviousSession() {
        guard UserDefaults.standard.bool(forKey: Self.sessionKey) else { return }
        append(
            LoggedError(
                category: .crash,
                summary: L10n.t("La app se cerró de forma inesperada en la sesión anterior."),
                context: L10n.t("Sesión anterior"),
                details: L10n.t("No se registró un cierre limpio. Puede deberse a un fallo de la app, a un cierre forzado o a una terminación del sistema.")
            )
        )
    }

    // MARK: Persistencia

    private func append(_ entry: LoggedError) {
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storeKey) else { return }
        do {
            entries = try JSONDecoder().decode([LoggedError].self, from: data)
        } catch {
            entries = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        } catch {
            // Si el propio registro no se puede guardar, no hay nada más que hacer.
        }
    }

    // MARK: Clasificación

    static func category(for error: Error) -> AppErrorCategory {
        if let aiError = error as? AIPlanError {
            switch aiError {
            case .network, .http: return .network
            default: return .ai
            }
        }
        if error is URLError { return .network }
        if error is DecodingError { return .storage }
        if let exportError = error as? MenuExportError {
            switch exportError {
            case .galleryPermission, .gallerySave: return .photos
            case .pdfGeneration, .imageGeneration: return .export
            }
        }
        if error is CocoaError { return .storage }
        return .app
    }

    // MARK: Informes de cierre (seguros desde el handler)

    nonisolated static func installGlobalHandlers() {
        NSSetUncaughtExceptionHandler(semanaListaUncaughtExceptionHandler)
    }

    private func importCrashReports() {
        guard let text = CrashReportStore.consume() else { return }

        for chunk in text.components(separatedBy: "\n=== SEMANA LISTA ===\n") {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            entries.append(
                LoggedError(
                    category: .crash,
                    summary: L10n.t("La app se cerró por un error grave."),
                    context: L10n.t("Informe de cierre"),
                    details: trimmed
                )
            )
        }
        entries.sort { $0.date > $1.date }
        if entries.count > Self.maxEntries {
            entries.removeLast(entries.count - Self.maxEntries)
        }
        persist()
    }

    // MARK: Entorno

    static var deviceModel: String {
        #if targetEnvironment(simulator)
        return "Simulador"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return identifier
        #endif
    }

    static var systemVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        if version.patchVersion > 0 {
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }
        return "\(version.majorVersion).\(version.minorVersion)"
    }
}

// MARK: - Ayuda global

/// Registra un error desde cualquier parte de la app, aunque no sea un contexto
/// de UI. El registro siempre se escribe en el hilo principal.
func logAppError(
    _ error: Error,
    context: String,
    category: AppErrorCategory? = nil
) {
    Task { @MainActor in
        ErrorLog.shared.log(error, context: context, category: category)
    }
}

// MARK: - Cierres inesperados

/// Handler de excepciones de Objective-C. No puede capturar contexto, por eso
/// es una función global y escribe directamente a disco.
private nonisolated func semanaListaUncaughtExceptionHandler(_ exception: NSException) {
    let details = """
    Tipo: Excepción no controlada
    Nombre: \(exception.name.rawValue)
    Motivo: \(exception.reason ?? "—")
    Fecha: \(Date().description)
    Pila:
    \(exception.callStackSymbols.joined(separator: "\n"))
    """
    CrashReportStore.write(details)
}

/// Archivo donde se dejan los informes de cierre para importarlos en el
/// siguiente arranque. Se mantiene fuera de `ErrorLog` para poder escribir
/// desde el handler de excepciones sin depender del actor principal.
enum CrashReportStore {
    nonisolated private static let fileName = "SemanaLista-crash.log"
    nonisolated private static let separator = "\n=== SEMANA LISTA ===\n"

    nonisolated private static var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("SemanaLista", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    nonisolated static func write(_ text: String) {
        let url = fileURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload = Data((separator + text).utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(payload)
            try? handle.close()
        } else {
            try? payload.write(to: url, options: .atomic)
        }
    }

    nonisolated static func consume() -> String? {
        let url = fileURL
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        try? FileManager.default.removeItem(at: url)
        return text
    }
}
