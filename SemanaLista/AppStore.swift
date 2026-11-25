import Foundation
import Observation

struct ShoppingSection: Identifiable {
    let aisle: Aisle
    let items: [ShoppingItem]
    var id: String { aisle.rawValue }
}

@MainActor
@Observable
final class AppStore {
    var settings: UserSettings {
        didSet { Storage.saveSettings(settings) }
    }

    var plan: WeekPlan {
        didSet { Storage.savePlan(plan) }
    }

    var checked: Set<String> {
        didSet { Storage.saveChecked(checked) }
    }

    var cookChecked: Set<String> {
        didSet { Storage.saveCookChecked(cookChecked) }
    }

    var apiKey: String {
        didSet { Keychain.save(apiKey) }
    }

    var appearance: AppAppearance {
        didSet { Storage.saveAppearance(appearance) }
    }

    var isGenerating = false
    var pendingLanguageRefresh = false
    var generationStatus = L10n.t("Preparando la cocina…")
    var notice: StoreNotice?

    init() {
        let loadedSettings = Storage.loadSettings() ?? UserSettings()
        let loadedKey = Keychain.read() ?? ""
        let loadedPlan = Storage.loadPlan() ?? LocalPlanner.make(settings: loadedSettings)
        settings = loadedSettings
        apiKey = loadedKey
        plan = loadedPlan
        checked = Storage.loadChecked()
        cookChecked = Storage.loadCookChecked()
        appearance = Storage.loadAppearance() ?? .system

        if ProcessInfo.processInfo.arguments.contains("-demo") {
            settings.onboarded = true
            plan = LocalPlanner.make(settings: settings)
            checked = []
            cookChecked = []
            notice = nil
        }

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-onboarding") {
            settings.onboarded = false
            apiKey = ""
        }
        if let index = arguments.firstIndex(of: "-diet"), arguments.indices.contains(index + 1),
           let diet = Diet(rawValue: arguments[index + 1]) {
            settings.onboarded = true
            settings.diets = [diet]
            plan = LocalPlanner.make(settings: settings)
            checked = []
            cookChecked = []
        }
        if let index = arguments.firstIndex(of: "-mock-ai"), arguments.indices.contains(index + 1) {
            settings.onboarded = true
            settings.provider = .custom
            settings.apiBaseURL = arguments[index + 1]
            settings.model = "mock-model"
            apiKey = "test-key"
        }
        if let index = arguments.firstIndex(of: "-appearance"), arguments.indices.contains(index + 1),
           let value = AppAppearance(rawValue: arguments[index + 1]) {
            appearance = value
        }
        #endif

        // Si el menú guardado está en otro idioma, se regenera al arrancar
        // para que interfaz, contenido y PDF hablen el mismo idioma.
        pendingLanguageRefresh = settings.onboarded && (plan.language ?? "es") != AppLanguage.code
    }

    // MARK: - Derivados

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var shoppingItems: [ShoppingItem] {
        plan.shoppingItems(checked: checked)
    }

    var shoppingSections: [ShoppingSection] {
        Aisle.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { aisle in
                let items = shoppingItems.filter { !$0.pantry && $0.aisle == aisle }
                return items.isEmpty ? nil : ShoppingSection(aisle: aisle, items: items)
            }
    }

    var pantryItems: [ShoppingItem] {
        shoppingItems.filter(\.pantry)
    }

    var checkedCount: Int {
        shoppingItems.filter(\.checked).count
    }

    var shoppingProgress: Double {
        guard !shoppingItems.isEmpty else { return 0 }
        return Double(checkedCount) / Double(shoppingItems.count)
    }

    var timeline: [TimelineBlock] {
        plan.timeline
    }

    var cookProgress: Double {
        let ids = Set(timeline.map(\.id))
        let done = cookChecked.intersection(ids).count
        guard !ids.isEmpty else { return 0 }
        return Double(done) / Double(ids.count)
    }

    var cookDoneCount: Int {
        cookChecked.intersection(Set(timeline.map(\.id))).count
    }

    // MARK: - Acciones

    func toggleShopping(_ item: ShoppingItem) {
        if checked.contains(item.id) {
            checked.remove(item.id)
        } else {
            checked.insert(item.id)
        }
    }

    func toggleCook(_ block: TimelineBlock) {
        if cookChecked.contains(block.id) {
            cookChecked.remove(block.id)
        } else {
            cookChecked.insert(block.id)
        }
    }

    func resetShopping() {
        checked = []
    }

    func resetCooking() {
        cookChecked = []
    }

    func finishOnboarding() {
        settings.onboarded = true
    }

    func startWithLocalPlan() {
        finishOnboarding()
        plan = LocalPlanner.make(settings: settings)
        checked = []
        cookChecked = []
        let hasRestrictions = !settings.diets.isEmpty || !settings.allergies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        notice = StoreNotice(
            kind: .info,
            text: hasRestrictions
                ? L10n.t("Plan base listo con tus restricciones. Revisa igualmente alérgenos y cantidades.")
                : L10n.t("Plan base listo. Añade tu clave de IA en Ajustes para generar menús a medida.")
        )
    }

    func selectProvider(_ provider: APIProvider) {
        settings.provider = provider
        settings.apiBaseURL = provider.baseURL
        if provider != .custom {
            settings.model = provider.defaultModel
        }
    }

    func regenerate() async {
        guard !isGenerating else { return }
        isGenerating = true
        notice = nil
        defer { isGenerating = false }

        let variation = nextVariation()
        var snapshot = settings
        if snapshot.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            snapshot.model = snapshot.provider.defaultModel
        }
        if snapshot.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            snapshot.apiBaseURL = snapshot.provider.baseURL
        }

        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            generationStatus = L10n.t("Montando un plan base…")
            try? await Task.sleep(for: .milliseconds(650))
            apply(LocalPlanner.make(settings: snapshot, variation: variation))
            notice = StoreNotice(
                kind: .info,
                text: L10n.t("Este es el plan base. Añade una clave de IA en Ajustes para que el menú lo diseñe la IA.")
            )
            return
        }

        generationStatus = L10n.t("Diseñando el menú de la semana…")
        let client = AIClient(
            apiKey: key,
            baseURL: snapshot.apiBaseURL,
            model: snapshot.model,
            sessionID: UUID().uuidString
        )

        do {
            let generated = try await client.generatePlan(settings: snapshot, previous: plan, variation: variation)
            generationStatus = L10n.t("Cuadrando cantidades y tiempos…")
            try? await Task.sleep(for: .milliseconds(550))
            apply(generated)
            notice = StoreNotice(
                kind: .success,
                text: L10n.format("Semana generada con %@. Revisa alérgenos y ajusta lo que quieras.", snapshot.model)
            )
        } catch {
            ErrorLog.shared.log(
                error,
                context: L10n.format(
                    "Generar la semana con %@ · %@",
                    snapshot.provider.name,
                    snapshot.model
                ),
                category: .ai
            )
            let fallback = LocalPlanner.make(settings: snapshot, variation: variation)
            apply(fallback)
            notice = StoreNotice(
                kind: .warning,
                text: L10n.format("No se pudo usar la IA: %@ Te dejo un plan base para que no te quedes sin semana.", error.localizedDescription)
            )
        }
    }

    func regenerateLocal() {
        let variation = nextVariation()
        apply(LocalPlanner.make(settings: settings, variation: variation))
        notice = StoreNotice(kind: .info, text: L10n.t("Plan base regenerado. No se ha usado la API."))
    }

    /// Avanza el contador de generaciones para que cada regeneración cambie
    /// los ingredientes principales en lugar de reordenar los mismos.
    private func nextVariation() -> Int {
        let next = (settings.variationSeed ?? 0) + 1
        settings.variationSeed = next
        return next
    }

    private func apply(_ newPlan: WeekPlan) {
        plan = newPlan
        checked = []
        cookChecked = []
    }

    var shareText: String {
        var lines: [String] = []
        lines.append(L10n.format("LISTA DE LA COMPRA · %@", plan.title))
        lines.append("\(plan.rangeLabel) · " + L10n.format("%lld personas", plan.people))
        lines.append("")
        for section in shoppingSections {
            lines.append(section.aisle.title.uppercased())
            for item in section.items {
                lines.append("\(item.checked ? "✓" : "□") \(item.name) — \(item.quantityLabel)")
            }
            lines.append("")
        }
        if !pantryItems.isEmpty {
            lines.append(L10n.t("DESPENSA"))
            for item in pantryItems {
                lines.append("\(item.checked ? "✓" : "□") \(item.name) — \(item.quantityLabel)")
            }
        }
        lines.append("")
        lines.append(L10n.t("Generado con Semana Lista"))
        return lines.joined(separator: "\n")
    }
}
