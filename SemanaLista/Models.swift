import Foundation

// MARK: - Días y comidas

enum AppWeekday: Int, CaseIterable, Codable, Identifiable, Hashable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    private static let shortES = ["L", "M", "X", "J", "V", "S", "D"]
    private static let shortEN = ["M", "T", "W", "T", "F", "S", "S"]
    private static let namesES = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    private static let namesEN = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var short: String {
        (AppLanguage.isEnglish ? Self.shortEN : Self.shortES)[rawValue - 1]
    }

    var name: String {
        (AppLanguage.isEnglish ? Self.namesEN : Self.namesES)[rawValue - 1]
    }

    var lowercased: String { name.lowercased() }

    static func from(_ value: Int) -> AppWeekday {
        AppWeekday(rawValue: min(max(value, 1), 7)) ?? .monday
    }
}

enum MealSlot: String, Codable, Hashable {
    case lunch, dinner

    var label: String {
        switch self {
        case .lunch: L10n.t("Comida")
        case .dinner: L10n.t("Cena")
        }
    }

    var symbol: String { self == .lunch ? "sun.max" : "moon.stars" }
}

enum Diet: String, Codable, CaseIterable, Identifiable {
    case vegan, vegetarian, noPork, noLactose, noGluten, noFish, noSeafood

    var id: String { rawValue }

    var label: String {
        switch self {
        case .vegan: L10n.t("Vegana")
        case .vegetarian: L10n.t("Vegetariana")
        case .noPork: L10n.t("Sin cerdo")
        case .noLactose: L10n.t("Sin lactosa")
        case .noGluten: L10n.t("Sin gluten")
        case .noFish: L10n.t("Sin pescado")
        case .noSeafood: L10n.t("Sin marisco")
        }
    }

    var prompt: String {
        switch self {
        case .vegan: L10n.t("vegana estricta (sin ningún producto de origen animal)")
        case .vegetarian: L10n.t("vegetariana estricta (sin carne ni pescado)")
        case .noPork: L10n.t("sin carne de cerdo")
        case .noLactose: L10n.t("sin lactosa")
        case .noGluten: L10n.t("sin gluten")
        case .noFish: L10n.t("sin pescado")
        case .noSeafood: L10n.t("sin marisco")
        }
    }
}

// MARK: - Categorías y pasillos

enum PrepCategory: String, Codable, CaseIterable, Hashable {
    case legumbre, cereal, proteina, verdura, salsa, otro

    var label: String {
        switch self {
        case .legumbre: L10n.t("Legumbre")
        case .cereal: L10n.t("Cereal")
        case .proteina: L10n.t("Proteína")
        case .verdura: L10n.t("Verdura")
        case .salsa: L10n.t("Salsa")
        case .otro: L10n.t("Extra")
        }
    }

    var symbol: String {
        switch self {
        case .legumbre: "leaf"
        case .cereal: "circle.grid.3x3"
        case .proteina: "flame"
        case .verdura: "carrot"
        case .salsa: "drop"
        case .otro: "sparkles"
        }
    }

    var emoji: String {
        switch self {
        case .legumbre: "🫘"
        case .cereal: "🍚"
        case .proteina: "🍗"
        case .verdura: "🥦"
        case .salsa: "🍅"
        case .otro: "✨"
        }
    }

    var sortPriority: Int {
        switch self {
        case .legumbre: 0
        case .cereal: 1
        case .proteina: 2
        case .verdura: 3
        case .salsa: 4
        case .otro: 5
        }
    }

    static func from(_ raw: String?) -> PrepCategory {
        guard let raw else { return .otro }
        let value = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if value.contains("legum") || value.contains("lentil") || value.contains("chickpea") || value.contains("bean") || value.contains("pea") { return .legumbre }
        if value.contains("cereal") || value.contains("arroz") || value.contains("pasta") || value.contains("rice") || value.contains("grain") || value.contains("noodle") || value.contains("potato") { return .cereal }
        if value.contains("protein") || value.contains("carne") || value.contains("pollo") || value.contains("pescado") || value.contains("huevo") || value.contains("chicken") || value.contains("meat") || value.contains("fish") || value.contains("egg") || value.contains("tofu") { return .proteina }
        if value.contains("verdur") || value.contains("vegetal") || value.contains("vegetable") || value.contains("veg") { return .verdura }
        if value.contains("salsa") || value.contains("tomate") || value.contains("sauce") || value.contains("tomato") { return .salsa }
        return .otro
    }
}

enum Aisle: String, Codable, CaseIterable, Identifiable, Hashable {
    case verduras, frutas, carnes, pescados, lacteos, legumbres, cereales, conservas, panaderia, despensa, otros

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verduras: L10n.t("Verduras")
        case .frutas: L10n.t("Frutas")
        case .carnes: L10n.t("Carnes")
        case .pescados: L10n.t("Pescadería")
        case .lacteos: L10n.t("Lácteos y huevos")
        case .legumbres: L10n.t("Legumbres y frutos secos")
        case .cereales: L10n.t("Cereales y pasta")
        case .conservas: L10n.t("Conservas y salsas")
        case .panaderia: L10n.t("Panadería")
        case .despensa: L10n.t("Despensa")
        case .otros: L10n.t("Otros")
        }
    }

    var symbol: String {
        switch self {
        case .verduras: "carrot"
        case .frutas: "apple.logo"
        case .carnes: "fork.knife"
        case .pescados: "fish"
        case .lacteos: "cup.and.saucer"
        case .legumbres: "leaf"
        case .cereales: "circle.grid.3x3"
        case .conservas: "shippingbox"
        case .panaderia: "birthday.cake"
        case .despensa: "cabinet"
        case .otros: "bag"
        }
    }

    var sortOrder: Int {
        switch self {
        case .verduras: 0
        case .frutas: 1
        case .carnes: 2
        case .pescados: 3
        case .lacteos: 4
        case .legumbres: 5
        case .cereales: 6
        case .conservas: 7
        case .panaderia: 8
        case .despensa: 9
        case .otros: 10
        }
    }

    static func from(_ raw: String?, name: String) -> Aisle {
        if let raw {
            let value = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            switch true {
            case value.contains("verd") || value.contains("vegetable") || value.contains("produce"): return .verduras
            case value.contains("frut") || value.contains("fruit"): return .frutas
            case value.contains("carn") || value.contains("pollo") || value.contains("cerdo") || value.contains("ternera") || value.contains("meat") || value.contains("chicken") || value.contains("beef") || value.contains("pork"): return .carnes
            case value.contains("pesc") || value.contains("marisc") || value.contains("fish") || value.contains("seafood"): return .pescados
            case value.contains("lact") || value.contains("huevo") || value.contains("queso") || value.contains("dairy") || value.contains("egg") || value.contains("cheese"): return .lacteos
            case value.contains("legum") || value.contains("fruto") || value.contains("legume") || value.contains("nut"): return .legumbres
            case value.contains("cereal") || value.contains("pasta") || value.contains("arroz") || value.contains("grain") || value.contains("rice"): return .cereales
            case value.contains("conserv") || value.contains("salsa") || value.contains("canned") || value.contains("sauce"): return .conservas
            case value.contains("pan") || value.contains("bakery") || value.contains("bread"): return .panaderia
            case value.contains("despens") || value.contains("especi") || value.contains("pantry") || value.contains("spice"): return .despensa
            case value.contains("otro") || value.contains("other"): return .otros
            default: break
            }
        }
        return inferred(from: name)
    }

    static func inferred(from name: String) -> Aisle {
        let value = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let rules: [(String, Aisle)] = [
            ("lenteja", .legumbres), ("garbanzo", .legumbres), ("alubia", .legumbres),
            ("guisante", .legumbres), ("arroz", .cereales), ("pasta", .cereales),
            ("fideo", .cereales), ("pan ", .panaderia), ("pan", .panaderia),
            ("tomate", .verduras), ("cebolla", .verduras), ("ajo", .verduras),
            ("zanahoria", .verduras), ("pimiento", .verduras), ("calabacin", .verduras),
            ("berenjena", .verduras), ("patata", .verduras), ("puerro", .verduras),
            ("calabaza", .verduras), ("lechuga", .verduras), ("ensalada", .verduras),
            ("limon", .frutas), ("manzana", .frutas), ("platano", .frutas),
            ("naranja", .frutas), ("fruta", .frutas), ("aguacate", .frutas),
            ("pollo", .carnes), ("muslo", .carnes), ("pechuga", .carnes),
            ("carne", .carnes), ("cerdo", .carnes), ("ternera", .carnes),
            ("salmon", .pescados), ("atun", .pescados), ("merluza", .pescados),
            ("pescado", .pescados), ("gamba", .pescados),
            ("huevo", .lacteos), ("leche", .lacteos), ("yogur", .lacteos),
            ("queso", .lacteos), ("mantequilla", .lacteos),
            ("aceite", .despensa), ("sal", .despensa), ("pimienta", .despensa),
            ("pimenton", .despensa), ("laurel", .despensa), ("romero", .despensa),
            ("albahaca", .despensa), ("azucar", .despensa), ("vinagre", .despensa),
            ("comino", .despensa), ("oregano", .despensa), ("curry", .despensa),
            ("conserva", .conservas), ("mayonesa", .conservas), ("aceituna", .conservas),
            ("lentil", .legumbres), ("chickpea", .legumbres), ("bean", .legumbres),
            ("pea", .legumbres), ("rice", .cereales), ("noodle", .cereales),
            ("bread", .panaderia), ("tomato", .verduras), ("onion", .verduras),
            ("garlic", .verduras), ("carrot", .verduras), ("pepper", .verduras),
            ("courgette", .verduras), ("zucchini", .verduras), ("eggplant", .verduras),
            ("aubergine", .verduras), ("potato", .verduras), ("leek", .verduras),
            ("pumpkin", .verduras), ("lettuce", .verduras), ("salad", .verduras),
            ("lemon", .frutas), ("apple", .frutas), ("banana", .frutas),
            ("orange", .frutas), ("fruit", .frutas), ("avocado", .frutas),
            ("chicken", .carnes), ("turkey", .carnes), ("beef", .carnes),
            ("pork", .carnes), ("meat", .carnes), ("salmon", .pescados),
            ("tuna", .pescados), ("cod", .pescados), ("fish", .pescados),
            ("prawn", .pescados), ("shrimp", .pescados), ("egg", .lacteos),
            ("milk", .lacteos), ("yogurt", .lacteos), ("yoghurt", .lacteos),
            ("cheese", .lacteos), ("butter", .lacteos), ("cream", .lacteos),
            ("oil", .despensa), ("salt", .despensa), ("pepper", .despensa),
            ("paprika", .despensa), ("bay", .despensa), ("rosemary", .despensa),
            ("basil", .despensa), ("sugar", .despensa), ("vinegar", .despensa),
            ("cumin", .despensa), ("oregano", .despensa), ("curry", .despensa),
            ("mayonnaise", .conservas), ("olive", .conservas), ("canned", .conservas)
        ]
        for (key, aisle) in rules where value.contains(key) {
            return aisle
        }
        return .otros
    }
}

// MARK: - Unidades y cantidades

enum Unit: String, Codable, CaseIterable, Hashable {
    case gramo = "g"
    case mililitro = "ml"
    case unidad = "unidad"
    case diente = "diente"
    case rama = "rama"
    case cucharada = "cucharada"
    case pizca = "pizca"

    var plural: String {
        switch self {
        case .gramo: "g"
        case .mililitro: "ml"
        case .unidad: "uds"
        case .diente: "dientes"
        case .rama: "ramas"
        case .cucharada: "cucharadas"
        case .pizca: "pizcas"
        }
    }

    static func normalize(quantity: Double, rawUnit: String?) -> (Double, Unit) {
        let raw = (rawUnit ?? "unidad").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let value = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        switch value {
        case "kg", "kilo", "kilos", "kilogramo", "kilogramos", "kilogram", "kilograms":
            return (quantity * 1000, .gramo)
        case "l", "litro", "litros", "liter", "liters", "litre", "litres":
            return (quantity * 1000, .mililitro)
        case "g", "gr", "gramo", "gramos", "gram", "grams":
            return (quantity, .gramo)
        case "ml", "mililitro", "mililitros", "cc", "milliliter", "milliliters", "millilitre", "millilitres":
            return (quantity, .mililitro)
        case "ud", "uds", "unidad", "unidades", "pieza", "piezas", "unit", "units", "piece", "pieces":
            return (quantity, .unidad)
        case "diente", "dientes", "clove", "cloves":
            return (quantity, .diente)
        case "rama", "ramas", "sprig", "sprigs":
            return (quantity, .rama)
        case "cucharada", "cucharadas", "cda", "cdas", "tablespoon", "tablespoons", "tbsp":
            return (quantity, .cucharada)
        case "pizca", "pizcas", "pinch", "pinches":
            return (quantity, .pizca)
        default:
            return (quantity, .unidad)
        }
    }
}

enum QuantityFormat {
    private static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = AppLanguage.locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static func number(_ value: Double, maxFraction: Int = 1) -> String {
        decimal.locale = AppLanguage.locale
        decimal.maximumFractionDigits = maxFraction
        return decimal.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func format(_ quantity: Double, unit: Unit, shopping: Bool = false) -> String {
        let value = quantity.isFinite ? max(0, quantity) : 0
        let english = AppLanguage.isEnglish
        switch unit {
        case .gramo:
            if value >= 1000 {
                return "\(number(value / 1000, maxFraction: 2)) kg"
            }
            if value >= 20 {
                return "\(number(value.rounded(), maxFraction: 0)) g"
            }
            return "\(number(value, maxFraction: 1)) g"
        case .mililitro:
            if value >= 1000 {
                return "\(number(value / 1000, maxFraction: 2)) l"
            }
            if value >= 20 {
                return "\(number(value.rounded(), maxFraction: 0)) ml"
            }
            return "\(number(value, maxFraction: 1)) ml"
        case .unidad:
            let display = shopping ? ceil(value) : value
            if display == 1 { return english ? "1 unit" : "1 ud" }
            if display < 1 { return "\(number(display, maxFraction: 2)) \(english ? "unit" : "ud")" }
            return english
                ? "\(number(display, maxFraction: shopping ? 0 : 1)) units"
                : "\(number(display, maxFraction: shopping ? 0 : 1)) uds"
        case .diente:
            let display = shopping ? ceil(value) : value
            if english { return display == 1 ? "1 clove" : "\(number(display, maxFraction: shopping ? 0 : 1)) cloves" }
            return display == 1 ? "1 diente" : "\(number(display, maxFraction: shopping ? 0 : 1)) dientes"
        case .rama:
            let display = shopping ? ceil(value) : value
            if english { return display == 1 ? "1 sprig" : "\(number(display, maxFraction: shopping ? 0 : 1)) sprigs" }
            return display == 1 ? "1 rama" : "\(number(display, maxFraction: shopping ? 0 : 1)) ramas"
        case .cucharada:
            if english { return value == 1 ? "1 tbsp" : "\(number(value)) tbsp" }
            return value == 1 ? "1 cucharada" : "\(number(value)) cucharadas"
        case .pizca:
            if english { return value == 1 ? "1 pinch" : "\(number(value)) pinches" }
            return value == 1 ? "1 pizca" : "\(number(value)) pizcas"
        }
    }

    static func roundedForShopping(_ quantity: Double, unit: Unit) -> Double {
        switch unit {
        case .gramo:
            if quantity >= 100 { return (quantity / 5).rounded() * 5 }
            if quantity >= 20 { return quantity.rounded() }
            return (quantity * 2).rounded() / 2
        case .mililitro:
            if quantity >= 100 { return (quantity / 5).rounded() * 5 }
            if quantity >= 20 { return quantity.rounded() }
            return (quantity * 2).rounded() / 2
        case .unidad, .diente, .rama:
            return ceil(quantity)
        case .cucharada, .pizca:
            return (quantity * 2).rounded() / 2
        }
    }
}

// MARK: - Ingredientes y preparaciones

struct Ingredient: Codable, Identifiable, Hashable {
    var name: String
    var quantity: Double
    var unit: Unit
    var aisle: Aisle
    var pantry: Bool

    var id: String {
        "\(name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current))|\(unit.rawValue)"
    }

    var formattedQuantity: String {
        QuantityFormat.format(quantity, unit: unit)
    }

    var shoppingQuantity: String {
        QuantityFormat.format(QuantityFormat.roundedForShopping(quantity, unit: unit), unit: unit, shopping: true)
    }
}

struct Prep: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var emoji: String
    var category: PrepCategory
    var servings: Int
    var ingredients: [Ingredient]
    var activeMinutes: Int
    var totalMinutes: Int
    var storageDays: Int
    var steps: [String]
    var reheat: String

    var tupperCount: Int {
        max(1, Int(ceil(Double(servings) / 2.0)))
    }
}

struct Meal: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var slot: MealSlot
    var title: String
    var prepIDs: [String]
    var fresh: [Ingredient]
    var note: String = ""

    var hasContent: Bool {
        !prepIDs.isEmpty || !fresh.isEmpty
    }
}

struct DayPlan: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var weekday: AppWeekday
    var lunch: Meal
    var dinner: Meal

    var meals: [Meal] { [lunch, dinner] }

    func meal(for slot: MealSlot) -> Meal {
        slot == .lunch ? lunch : dinner
    }
}

enum PlanSource: Codable, Equatable {
    case ai(model: String)
    case local

    var isAI: Bool {
        if case .ai = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .ai(let model): return "\(L10n.t("IA")) · \(model)"
        case .local: return L10n.t("Plan base")
        }
    }
}

struct WeekPlan: Codable {
    var title: String
    var subtitle: String
    var source: PlanSource
    var createdAt: Date
    var startDate: Date
    var people: Int
    var startHour: Int
    var startMinute: Int
    var timeBudget: Int
    var preps: [Prep]
    var days: [DayPlan]
    var notes: String
    var nightBefore: String
    /// Idioma en el que se generó el contenido ("es" o "en"). Los planes
    /// antiguos no lo tienen y se consideran en español.
    var language: String? = nil

    var mealCount: Int { days.count * 2 }

    var totalPrepMinutes: Int {
        preps.reduce(0) { $0 + $1.totalMinutes }
    }

    var totalMinutes: Int {
        totalPrepMinutes + 20
    }

    var totalServings: Int {
        preps.reduce(0) { $0 + $1.servings }
    }

    var endDate: Date {
        let calendar = Calendar.current
        let start = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: startDate) ?? startDate
        return start.addingTimeInterval(TimeInterval(totalMinutes * 60))
    }

    var startDateForCooking: Date {
        Calendar.current.date(bySettingHour: startHour, minute: startMinute, second: 0, of: startDate) ?? startDate
    }

    var rangeLabel: String {
        let calendar = Calendar.current
        guard let end = calendar.date(byAdding: .day, value: days.count - 1, to: startDate) else {
            return startDate.formattedSpanish()
        }
        return "\(startDate.formattedSpanish(short: true)) – \(end.formattedSpanish(short: true))"
    }

    func prep(id: String) -> Prep? {
        preps.first { $0.id == id }
    }

    func prep(for meal: Meal) -> [Prep] {
        meal.prepIDs.compactMap { prep(id: $0) }
    }

    func mealDate(_ index: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: index, to: startDate) ?? startDate
    }

    /// Secuencia realista: primero lo largo (legumbre, arroz, proteína, verdura, salsa)
    /// y al final las preparaciones rápidas. Una cosa detrás de otra.
    var orderedPreps: [Prep] {
        preps.enumerated().sorted { lhs, rhs in
            let a = lhs.element
            let b = rhs.element
            let phaseA = cookPhase(a)
            let phaseB = cookPhase(b)
            if phaseA != phaseB { return phaseA < phaseB }
            if a.totalMinutes != b.totalMinutes { return a.totalMinutes > b.totalMinutes }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private func cookPhase(_ prep: Prep) -> Int {
        let name = prep.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Date.spanishLocale)
        if prep.category == .legumbre { return 0 }
        if prep.category == .cereal, name.contains("arroz") || prep.totalMinutes >= 18 { return 1 }
        if prep.category == .proteina, prep.totalMinutes >= 20 { return 2 }
        if prep.category == .verdura { return 3 }
        if prep.category == .salsa { return 4 }
        return 5
    }

    var timeline: [TimelineBlock] {
        var blocks: [TimelineBlock] = []
        let calendar = Calendar.current
        let base = startDateForCooking
        var cursor = base
        let setupStart = cursor
        cursor = cursor.addingTimeInterval(10 * 60)
        blocks.append(TimelineBlock(
            kind: .setup,
            title: L10n.t("Preparar la cocina"),
            subtitle: L10n.t("Saca táperes, deja la encimera libre y pon agua a calentar."),
            start: setupStart,
            end: cursor,
            emoji: "🧺"
        ))

        for (index, prep) in orderedPreps.enumerated() {
            let start = cursor
            cursor = cursor.addingTimeInterval(TimeInterval(prep.totalMinutes * 60))
            blocks.append(TimelineBlock(
                kind: .prep(prep, index),
                title: prep.name,
                subtitle: L10n.format("%lld raciones · %lld táperes", prep.servings, prep.tupperCount),
                start: start,
                end: cursor,
                emoji: prep.emoji
            ))
        }

        let cleanupStart = cursor
        cursor = cursor.addingTimeInterval(10 * 60)
        blocks.append(TimelineBlock(
            kind: .cleanup,
            title: L10n.t("Enfriar y guardar"),
            subtitle: L10n.t("Etiqueta los táperes con el nombre y la fecha. A la nevera."),
            start: cleanupStart,
            end: cursor,
            emoji: "🏷️"
        ))
        _ = calendar
        return blocks
    }

    func shoppingItems(checked: Set<String>) -> [ShoppingItem] {
        var merged: [String: ShoppingItem] = [:]

        func add(_ ingredient: Ingredient, pantryOverride: Bool? = nil) {
            let key = ingredient.id
            let pantry = pantryOverride ?? ingredient.pantry
            if var existing = merged[key] {
                existing.quantity += ingredient.quantity
                existing.pantry = existing.pantry && pantry
                merged[key] = existing
            } else {
                merged[key] = ShoppingItem(
                    name: ingredient.name,
                    quantity: ingredient.quantity,
                    unit: ingredient.unit,
                    aisle: ingredient.aisle,
                    pantry: pantry,
                    checked: checked.contains(key)
                )
            }
        }

        for prep in preps {
            for ingredient in prep.ingredients where !ingredient.name.lowercased().contains("agua") {
                add(ingredient)
            }
        }
        for day in days {
            for meal in day.meals {
                for ingredient in meal.fresh {
                    add(ingredient)
                }
            }
        }

        return merged.values.sorted {
            if $0.pantry != $1.pantry { return !$0.pantry }
            if $0.aisle.sortOrder != $1.aisle.sortOrder { return $0.aisle.sortOrder < $1.aisle.sortOrder }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    var shoppingPreviewCount: Int {
        shoppingItems(checked: []).count
    }
}

enum TimelineKind: Equatable {
    case setup
    case prep(Prep, Int)
    case cleanup
}

struct TimelineBlock: Identifiable, Equatable {
    let kind: TimelineKind
    let title: String
    let subtitle: String
    let start: Date
    let end: Date
    let emoji: String

    var id: String {
        switch kind {
        case .setup: "setup"
        case .cleanup: "cleanup"
        case .prep(let prep, _): "prep-\(prep.id)"
        }
    }

    var minutes: Int {
        max(1, Int(end.timeIntervalSince(start) / 60))
    }

    var isPrep: Bool {
        if case .prep = kind { return true }
        return false
    }

    var prep: Prep? {
        if case .prep(let prep, _) = kind { return prep }
        return nil
    }
}

// MARK: - Lista de la compra

struct ShoppingItem: Identifiable, Hashable {
    var name: String
    var quantity: Double
    var unit: Unit
    var aisle: Aisle
    var pantry: Bool
    var checked: Bool

    var id: String {
        "\(name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current))|\(unit.rawValue)"
    }

    var quantityLabel: String {
        QuantityFormat.format(QuantityFormat.roundedForShopping(quantity, unit: unit), unit: unit, shopping: true)
    }
}

// MARK: - Ajustes

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: L10n.t("Automático")
        case .light: L10n.t("Día")
        case .dark: L10n.t("Noche")
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }
}

enum APIProvider: String, Codable, CaseIterable, Identifiable {
    case groq, openai, openrouter, opencodeGo = "opencode-go", custom

    var id: String { rawValue }

    var name: String {
        switch self {
        case .openai: "OpenAI"
        case .openrouter: "OpenRouter"
        case .groq: "Groq"
        case .opencodeGo: "OpenCode Go"
        case .custom: "Personalizado"
        }
    }

    var baseURL: String {
        switch self {
        case .openai: "https://api.openai.com/v1"
        case .openrouter: "https://openrouter.ai/api/v1"
        case .groq: "https://api.groq.com/openai/v1"
        case .opencodeGo: "https://opencode.ai/inference/go/openai/v1"
        case .custom: ""
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: "gpt-4.1-mini"
        case .openrouter: "openai/gpt-4.1-mini"
        case .groq: "llama-3.3-70b-versatile"
        case .opencodeGo: "deepseek-v4.1-flash"
        case .custom: ""
        }
    }

    /// Modelos sugeridos para el selector. Los de OpenRouter con ":free" son gratuitos
    /// (con límite diario por clave). En OpenCode Go solo incluimos modelos servidos
    /// por Chat Completions, que es la API que usa la app.
    var presetModels: [String] {
        switch self {
        case .groq:
            return [
                "llama-3.3-70b-versatile",
                "llama-3.1-8b-instant",
                "mixtral-8x7b-32768"
            ]
        case .openai:
            return [
                "gpt-4.1-mini",
                "gpt-4o-mini",
                "gpt-4.1"
            ]
        case .openrouter:
            return [
                "deepseek/deepseek-chat:free",
                "meta-llama/llama-3.3-70b-instruct:free",
                "qwen/qwen-2.5-72b-instruct:free",
                "openai/gpt-4.1-mini"
            ]
        case .opencodeGo:
            return [
                "deepseek-v4.1-flash",
                "glm-5.3-flash",
                "mimo-v2.6-flash",
                "deepseek-v4-pro"
            ]
        case .custom:
            return []
        }
    }

    var keyHint: String {
        switch self {
        case .openai: "sk-…"
        case .openrouter: "sk-or-v1-…"
        case .groq: "gsk_…"
        case .opencodeGo: "oc_sk_…"
        case .custom: "Tu clave"
        }
    }
}

struct UserSettings: Codable, Equatable {
    var onboarded: Bool = false
    var people: Int = 2
    var diets: Set<Diet> = []
    var dislikes: String = ""
    var allergies: String = ""
    var notes: String = ""
    var batchWeekday: AppWeekday = .sunday
    var startHour: Int = 10
    var startMinute: Int = 0
    var timeBudget: Int = 240
    var provider: APIProvider = .groq
    var apiBaseURL: String = APIProvider.groq.baseURL
    var model: String = APIProvider.groq.defaultModel
    /// Contador de generaciones. Sirve para rotar el plan local y para pedir
    /// a la IA ingredientes distintos en cada regeneración.
    var variationSeed: Int? = nil

    /// Ingredientes vetados a partir de alergias e intolerancias + "no me gusta".
    var exclusions: IngredientExclusions {
        IngredientExclusions(allergies: allergies, dislikes: dislikes)
    }

    /// La dieta vegana incluye la vegetariana y añade la exclusión de huevos,
    /// lácteos, miel y cualquier otro producto de origen animal.
    var isVegan: Bool { diets.contains(.vegan) }

    var isVegetarian: Bool { diets.contains(.vegetarian) || isVegan }

    /// Marca o desmarca una dieta manteniendo la coherencia entre vegana y
    /// vegetariana: la vegana ya cubre todo lo que excluye la vegetariana.
    mutating func toggleDiet(_ diet: Diet) {
        if diets.contains(diet) {
            diets.remove(diet)
            return
        }
        diets.insert(diet)
        if diet == .vegan {
            diets.remove(.vegetarian)
        } else if diet == .vegetarian {
            diets.remove(.vegan)
        }
    }

    var timeBudgetLabel: String {
        let hours = timeBudget / 60
        let minutes = timeBudget % 60
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
    }

    var startTimeLabel: String {
        String(format: "%02d:%02d", startHour, startMinute)
    }

    var dietPrompt: String {
        let values = Diet.allCases.filter { diets.contains($0) }.map(\.prompt)
        return values.isEmpty ? "sin restricciones" : values.joined(separator: ", ")
    }
}

// MARK: - Fechas

extension Date {
    static let spanishLocale = Locale(identifier: "es_ES")

    static var appLocale: Locale { AppLanguage.locale }

    func formattedSpanish(short: Bool = false) -> String {
        if short {
            return formatted(.dateTime.locale(Date.appLocale).day().month(.abbreviated))
        }
        return formatted(.dateTime.locale(Date.appLocale).weekday(.wide).day().month(.wide))
    }

    func capitalizedSpanish(short: Bool = false) -> String {
        let text = formattedSpanish(short: short)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    var timeLabel: String {
        formatted(.dateTime.locale(Date.appLocale).hour().minute())
    }
}

enum WeekDates {
    static func nextDate(for weekday: AppWeekday, from date: Date = .now, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        let current = appWeekday(of: start, calendar: calendar)
        let delta = (weekday.rawValue - current.rawValue + 7) % 7
        return calendar.date(byAdding: .day, value: delta, to: start) ?? start
    }

    static func appWeekday(of date: Date, calendar: Calendar = .current) -> AppWeekday {
        let value = calendar.component(.weekday, from: date)
        return AppWeekday.from((value + 5) % 7 + 1)
    }

    static func date(for day: DayPlan, in plan: WeekPlan, calendar: Calendar = .current) -> Date {
        guard let index = plan.days.firstIndex(where: { $0.id == day.id }) else { return plan.startDate }
        return calendar.date(byAdding: .day, value: index, to: plan.startDate) ?? plan.startDate
    }
}
