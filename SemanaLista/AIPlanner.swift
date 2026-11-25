import Foundation

// MARK: - DTO de la IA

struct AIPlanDTO: Decodable {
    var title: String?
    var subtitle: String?
    var notes: String?
    var nightBefore: String?
    var preps: [AIPrepDTO]?
    var days: [AIDayDTO]?
}

struct AIPrepDTO: Decodable {
    var id: String?
    var name: String?
    var emoji: String?
    var category: String?
    var activeMinutes: Int?
    var totalMinutes: Int?
    var storageDays: Int?
    var steps: [String]?
    var reheat: String?
    var ingredients: [AIIngredientDTO]?
}

struct AIDayDTO: Decodable {
    var weekday: Int?
    var lunch: AIMealDTO?
    var dinner: AIMealDTO?
}

struct AIMealDTO: Decodable {
    var title: String?
    var prepIDs: [String]?
    var prepIds: [String]?
    var fresh: [AIIngredientDTO]?
    var note: String?

    var allPrepIDs: [String] {
        Array(Set((prepIDs ?? []) + (prepIds ?? [])))
    }
}

struct AIIngredientDTO: Decodable {
    var name: String?
    var quantity: Double?
    var unit: String?
    var aisle: String?
    var pantry: Bool?

    enum CodingKeys: String, CodingKey {
        case name, quantity, unit, aisle, pantry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        aisle = try container.decodeIfPresent(String.self, forKey: .aisle)
        pantry = try container.decodeIfPresent(Bool.self, forKey: .pantry)

        if let value = try? container.decodeIfPresent(Double.self, forKey: .quantity) {
            quantity = value
        } else if let text = try? container.decodeIfPresent(String.self, forKey: .quantity) {
            quantity = Double(text.replacingOccurrences(of: ",", with: "."))
        } else {
            quantity = nil
        }
    }
}

// MARK: - Errores

enum AIPlanError: LocalizedError {
    case missingKey
    case http(Int, String)
    case network(String)
    case emptyResponse
    case truncated
    case decoding(String)
    case tooManyLegumes([String])
    case notEnoughPreps
    case badDays
    case mealWithoutPrep(String)
    case tooLong(Int, Int)
    case excludedIngredients([String])
    case dietConflict([String])
    case noPlan

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return L10n.t("Falta la clave de la API.")
        case .http(let code, let message):
            if code == 401 { return L10n.t("La clave de la API no es válida o ha caducado.") }
            if code == 402 {
                return L10n.t("Sin saldo en tu cuenta del proveedor. Añade créditos y vuelve a intentarlo.")
            }
            if code == 429 {
                return L10n.format("Límite de uso alcanzado en tu cuenta de IA. Esto lo marca tu proveedor: %@", message)
            }
            return L10n.format("La API respondió %lld: %@", code, message)
        case .network(let message):
            return L10n.format("No se pudo conectar: %@", message)
        case .emptyResponse:
            return L10n.t("La IA devolvió una respuesta vacía.")
        case .truncated:
            return L10n.t("El modelo agotó el límite de respuesta antes de terminar el menú. Vuelve a intentarlo o elige otro modelo.")
        case .decoding:
            return L10n.t("La IA no devolvió un menú con el formato esperado.")
        case .tooManyLegumes(let names):
            return L10n.format("La IA propuso varias legumbres (%@). Solo debe haber una por semana.", names.joined(separator: ", "))
        case .notEnoughPreps:
            return L10n.t("La IA propuso muy pocas preparaciones para cubrir la semana.")
        case .badDays:
            return L10n.t("El menú no traía los 7 días completos con comida y cena.")
        case .mealWithoutPrep(let title):
            return L10n.format("La comida «%@» no usa ninguna preparación del batch.", title)
        case .tooLong(let total, let budget):
            return L10n.format("El plan suma %lld minutos y supera tu límite de %lld minutos.", total, budget)
        case .excludedIngredients(let names):
            return L10n.format("El menú incluía alimentos que has excluido: %@.", names.joined(separator: ", "))
        case .dietConflict(let names):
            return L10n.format("La dieta elegida no permite estos alimentos: %@.", names.joined(separator: ", "))
        case .noPlan:
            return L10n.t("No se pudo crear el plan.")
        }
    }

    /// Texto que se le devuelve a la IA para que corrija su propuesta.
    var feedback: String {
        switch self {
        case .tooManyLegumes(let names):
            return L10n.format("Has incluido varias legumbres (%@). Deja SOLO UNA preparación de legumbre en toda la semana y sustitúyela por otra cosa.", names.joined(separator: ", "))
        case .notEnoughPreps:
            return L10n.t("Necesito entre 6 y 8 preparaciones. Has devuelto muy pocas.")
        case .badDays:
            return L10n.t("Devuelve exactamente 7 días (weekday 1 a 7), cada uno con lunch y dinner.")
        case .mealWithoutPrep(let title):
            return L10n.format("La comida «%@» no usa ninguna preparación. Todas las comidas deben usar al menos una preparación del batch.", title)
        case .tooLong(let total, let budget):
            return L10n.format("El plan suma %lld minutos y el límite es %lld. Reduce tiempos o elimina una preparación.", total, budget)
        case .excludedIngredients(let names):
            return L10n.format("Has usado alimentos prohibidos: %@. Elimínalos por completo de las preparaciones, de los frescos y de los títulos. No los sustituyas por una variante parecida: cambia la receta por otra con ingredientes permitidos.", names.joined(separator: ", "))
        case .dietConflict(let names):
            return L10n.format("Has usado alimentos que la dieta elegida no permite: %@. Elimínalos de las preparaciones, de los frescos y de los títulos, y cambia esas recetas por otras aptas para esa dieta.", names.joined(separator: ", "))
        case .emptyResponse:
            return L10n.t("Tu respuesta anterior llegó vacía. Devuelve SOLO el objeto JSON completo y compacto, sin explicaciones ni markdown.")
        case .truncated:
            return L10n.t("Tu respuesta anterior se cortó por el límite de salida. Devuelve el objeto JSON completo y compacto, con los 7 días y todas las preparaciones, sin explicaciones.")
        case .decoding:
            return L10n.t("Tu respuesta no era JSON válido según el esquema. Devuelve SOLO el objeto JSON, sin markdown ni comentarios.")
        default:
            return errorDescription ?? L10n.t("Corrige el plan.")
        }
    }
}

// MARK: - Constructor del plan

enum PlanBuilder {
    private static let legumeWords = ["lenteja", "garbanzo", "alubia", "judion", "guisante", "legumbre", "lentil", "chickpea", "bean", "pea", "legume"]

    static func build(_ dto: AIPlanDTO, settings: UserSettings) throws -> WeekPlan {
        let rawPreps = (dto.preps ?? []).filter { !(($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        guard rawPreps.count >= 4 else { throw AIPlanError.notEnoughPreps }

        var usedIDs = Set<String>()
        var idMap: [String: String] = [:]
        var nameToID: [String: String] = [:]
        var preps: [Prep] = []
        var rawByNewID: [String: AIPrepDTO] = [:]

        for raw in rawPreps {
            let name = clean(raw.name, fallback: L10n.t("Preparación"))
            let baseID = slug(raw.id ?? name)
            var newID = baseID.isEmpty ? "prep" : baseID
            var counter = 2
            while usedIDs.contains(newID) {
                newID = "\(baseID)-\(counter)"
                counter += 1
            }
            usedIDs.insert(newID)

            let rawKeys = [raw.id, name].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            for key in rawKeys {
                idMap[key] = newID
                idMap[slug(key)] = newID
            }
            nameToID[slug(name)] = newID

            var category = PrepCategory.from(raw.category)
            if isLegume(name) { category = .legumbre }
            if isLegume(raw.category ?? "") { category = .legumbre }

            let total = min(max(raw.totalMinutes ?? 25, 5), 180)
            let active = min(max(raw.activeMinutes ?? min(total, 15), 1), total)
            let ingredients = (raw.ingredients ?? []).compactMap { makeIngredient($0) }
            let steps = (raw.steps ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let reheat = clean(raw.reheat, fallback: L10n.t("Calienta suavemente y ajusta de sal."))
            let storage = min(max(raw.storageDays ?? 4, 1), 6)

            let prep = Prep(
                id: newID,
                name: name,
                emoji: emoji(raw.emoji, fallback: category.emoji),
                category: category,
                servings: 0,
                ingredients: ingredients,
                activeMinutes: active,
                totalMinutes: total,
                storageDays: storage,
                steps: steps.isEmpty ? [L10n.t("Cocina la preparación y déjala enfriar antes de guardarla.")] : steps,
                reheat: reheat
            )
            preps.append(prep)
            rawByNewID[newID] = raw
        }

        preps = preps.filter { !$0.ingredients.isEmpty }
        guard preps.count >= 4 else { throw AIPlanError.notEnoughPreps }

        let legumes = preps.filter { $0.category == .legumbre }
        guard legumes.count <= 1 else {
            throw AIPlanError.tooManyLegumes(legumes.map(\.name))
        }

        let rawDays = dto.days ?? []
        guard rawDays.count == 7 else { throw AIPlanError.badDays }

        var days: [DayPlan] = []
        var usage: [String: Int] = [:]

        for (index, rawDay) in rawDays.enumerated() {
            let weekday = AppWeekday.from(rawDay.weekday ?? (index + 1))
            guard let lunchDTO = rawDay.lunch, let dinnerDTO = rawDay.dinner else {
                throw AIPlanError.badDays
            }
            let lunch = try makeMeal(lunchDTO, slot: .lunch, settings: settings, idMap: idMap, nameToID: nameToID, validIDs: usedIDs)
            let dinner = try makeMeal(dinnerDTO, slot: .dinner, settings: settings, idMap: idMap, nameToID: nameToID, validIDs: usedIDs)
            for meal in [lunch, dinner] {
                for id in meal.prepIDs {
                    usage[id, default: 0] += 1
                }
            }
            days.append(DayPlan(weekday: weekday, lunch: lunch, dinner: dinner))
        }

        let uniqueWeekdays = Set(days.map(\.weekday))
        guard uniqueWeekdays.count == 7 else { throw AIPlanError.badDays }
        days.sort { $0.weekday.rawValue < $1.weekday.rawValue }

        // El menú empieza el día de cocina. Reetiquetamos los días con la fecha real
        // para que "lunes" en la respuesta de la IA no acabe mostrado un domingo.
        var start = WeekDates.nextDate(for: settings.batchWeekday)
        let calendar = Calendar.current
        if calendar.isDateInToday(start), calendar.component(.hour, from: .now) >= settings.startHour + 1 {
            start = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        }
        for index in days.indices {
            if let date = calendar.date(byAdding: .day, value: index, to: start) {
                days[index].weekday = WeekDates.appWeekday(of: date, calendar: calendar)
            }
        }

        // Una preparación que la IA dejó sin usar no se compra ni se cocina.
        preps = preps.filter { (usage[$0.id] ?? 0) > 0 }
        guard preps.count >= 4 else { throw AIPlanError.notEnoughPreps }

        // Porciones reales: cada comida gasta `people` raciones de cada preparación.
        let people = max(1, settings.people)
        preps = preps.map { prep in
            let servings = people * max(1, usage[prep.id] ?? 1)
            var copy = prep
            copy.servings = servings
            copy.ingredients = prep.ingredients.map { ingredient in
                var scaled = ingredient
                scaled.quantity = ingredient.quantity * Double(servings)
                return scaled
            }
            return copy
        }

        let total = 20 + preps.reduce(0) { $0 + $1.totalMinutes }
        if total > settings.timeBudget {
            throw AIPlanError.tooLong(total, settings.timeBudget)
        }

        let validIDs = Set(preps.map(\.id))
        days = days.map { day in
            var copy = day
            copy.lunch.prepIDs = copy.lunch.prepIDs.filter { validIDs.contains($0) }
            copy.dinner.prepIDs = copy.dinner.prepIDs.filter { validIDs.contains($0) }
            return copy
        }
        for day in days {
            for meal in day.meals where meal.prepIDs.isEmpty {
                throw AIPlanError.mealWithoutPrep(meal.title)
            }
        }

        try validateExclusions(preps: preps, days: days, settings: settings)
        try validateDiets(preps: preps, days: days, settings: settings)

        let title = clean(dto.title, fallback: L10n.t("Tu semana cocinada"))
        let subtitle = clean(dto.subtitle, fallback: L10n.t("Cocina una vez, come toda la semana."))
        let notes = clean(dto.notes, fallback: L10n.t("Guarda cada preparación por separado y monta el plato al calentar. Etiqueta los táperes con la fecha."))
        let nightBefore = clean(dto.nightBefore, fallback: L10n.t("Revisa la compra y deja en remojo o descongela lo que lo necesite."))

        return WeekPlan(
            title: title,
            subtitle: subtitle,
            source: .ai(model: settings.model.isEmpty ? "IA" : settings.model),
            createdAt: .now,
            startDate: start,
            people: people,
            startHour: settings.startHour,
            startMinute: settings.startMinute,
            timeBudget: settings.timeBudget,
            preps: preps,
            days: days,
            notes: notes,
            nightBefore: nightBefore,
            language: AppLanguage.code
        )
    }

    /// Rechaza el plan si la IA ha colado algún alimento vetado por el usuario.
    private static func validateExclusions(preps: [Prep], days: [DayPlan], settings: UserSettings) throws {
        let exclusions = settings.exclusions
        guard !exclusions.isEmpty else { return }

        var found: [String] = []
        for prep in preps {
            if exclusions.excludes(prep.name) { found.append(prep.name) }
            for ingredient in prep.ingredients where exclusions.excludes(ingredient.name) {
                found.append(ingredient.name)
            }
        }
        for day in days {
            for meal in day.meals {
                if exclusions.excludes(meal.title) { found.append(meal.title) }
                for ingredient in meal.fresh where exclusions.excludes(ingredient.name) {
                    found.append(ingredient.name)
                }
            }
        }

        guard !found.isEmpty else { return }
        let unique = Array(Set(found)).sorted()
        throw AIPlanError.excludedIngredients(unique)
    }

    /// Rechaza planes de IA que cuelen productos de origen animal en dietas
    /// vegetarianas o veganas. Compara palabras completas (con singular/plural)
    /// para no confundir "leche" con "lechuga" ni "nata" con "natillas", y deja
    /// pasar sustitutos vegetales como "leche de coco", "queso vegano" o
    /// "mantequilla de cacahuete".
    private static func validateDiets(preps: [Prep], days: [DayPlan], settings: UserSettings) throws {
        let vegan = settings.isVegan
        let vegetarian = settings.isVegetarian
        guard vegetarian else { return }

        let animalProducts = vegan
            ? "carne, pollo, pavo, ternera, cerdo, cordero, conejo, jamon, chorizo, bacon, panceta, pescado, atun, salmon, merluza, bacalao, sardina, gamba, langostino, mejillon, almeja, calamar, pulpo, huevo, leche, queso, yogur, mantequilla, nata, miel, mayonesa, gelatina, chicken, turkey, beef, pork, lamb, rabbit, ham, chorizo, bacon, pancetta, fish, tuna, salmon, cod, sardine, prawn, shrimp, mussel, clam, squid, octopus, egg, milk, cheese, yogurt, yoghurt, butter, cream, honey, mayonnaise, gelatin"
            : "carne, pollo, pavo, ternera, cerdo, cordero, conejo, jamon, chorizo, bacon, panceta, pescado, atun, salmon, merluza, bacalao, sardina, gamba, langostino, mejillon, almeja, calamar, pulpo, chicken, turkey, beef, pork, lamb, rabbit, ham, chorizo, bacon, pancetta, fish, tuna, salmon, cod, sardine, prawn, shrimp, mussel, clam, squid, octopus"
        let forbidden = IngredientExclusions(rawText: animalProducts)

        func isPlantBased(_ name: String) -> Bool {
            plantBasedQualifiers.contains { qualifier in
                IngredientExclusions.normalize(name).contains(qualifier)
            }
        }

        var found: [String] = []
        for prep in preps {
            if forbidden.excludes(prep.name), !isPlantBased(prep.name) { found.append(prep.name) }
            for ingredient in prep.ingredients where forbidden.excludes(ingredient.name) && !isPlantBased(ingredient.name) {
                found.append(ingredient.name)
            }
        }
        for day in days {
            for meal in day.meals {
                if forbidden.excludes(meal.title), !isPlantBased(meal.title) { found.append(meal.title) }
                for ingredient in meal.fresh where forbidden.excludes(ingredient.name) && !isPlantBased(ingredient.name) {
                    found.append(ingredient.name)
                }
            }
        }

        guard !found.isEmpty else { return }
        throw AIPlanError.dietConflict(Array(Set(found)).sorted())
    }

    private static let plantBasedQualifiers = [
        "coco", "almendra", "soja", "avena", "anacardo", "cacahuete", "vegetal", "vegano", "vegana",
        "berenjena", "eggplant", "coconut", "almond", "soy", "oat", "cashew", "peanut", "plant", "vegan"
    ]

    private static func makeMeal(
        _ dto: AIMealDTO,
        slot: MealSlot,
        settings: UserSettings,
        idMap: [String: String],
        nameToID: [String: String],
        validIDs: Set<String>
    ) throws -> Meal {
        var ids: [String] = []
        for raw in dto.allPrepIDs {
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let id = idMap[key] ?? idMap[slug(key)] ?? nameToID[slug(key)] ?? (validIDs.contains(slug(key)) ? slug(key) : nil) {
                if !ids.contains(id) { ids.append(id) }
            }
        }

        let fresh = (dto.fresh ?? []).compactMap { ingredient -> Ingredient? in
            guard var made = makeIngredient(ingredient) else { return nil }
            made.quantity = made.quantity * Double(max(1, settings.people))
            return made
        }

        let title = clean(dto.title, fallback: L10n.t("Comida de batch"))
        if ids.isEmpty {
            throw AIPlanError.mealWithoutPrep(title)
        }

        return Meal(
            slot: slot,
            title: title,
            prepIDs: ids,
            fresh: fresh,
            note: clean(dto.note, fallback: "")
        )
    }

    private static func makeIngredient(_ dto: AIIngredientDTO) -> Ingredient? {
        let name = clean(dto.name, fallback: "")
        guard !name.isEmpty else { return nil }
        let rawQuantity = dto.quantity ?? 0
        guard rawQuantity.isFinite, rawQuantity > 0 else { return nil }
        let (quantity, unit) = Unit.normalize(quantity: rawQuantity, rawUnit: dto.unit)
        guard quantity.isFinite, quantity > 0 else { return nil }
        let lower = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        guard !lower.contains("agua") else { return nil }
        return Ingredient(
            name: name,
            quantity: quantity,
            unit: unit,
            aisle: Aisle.from(dto.aisle, name: name),
            pantry: dto.pantry ?? isPantry(name)
        )
    }

    private static func isPantry(_ name: String) -> Bool {
        let value = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return ["aceite", "sal", "pimienta", "pimenton", "laurel", "romero", "albahaca", "azucar", "vinagre", "comino", "oregano", "curry", "canela", "agua", "oil", "salt", "pepper", "paprika", "bay", "rosemary", "basil", "sugar", "vinegar", "cumin", "oregano", "curry", "cinnamon", "water"].contains { value.contains($0) }
    }

    private static func isLegume(_ text: String) -> Bool {
        let value = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return legumeWords.contains { value.contains($0) }
    }

    private static func slug(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES")).lowercased()
        let allowed = folded.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        return String(allowed).split(separator: "-").joined(separator: "-")
    }

    private static func clean(_ text: String?, fallback: String) -> String {
        let value = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }

    private static func emoji(_ text: String?, fallback: String) -> String {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return fallback }
        let first = text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2)
        return String(first).isEmpty ? fallback : String(first)
    }
}

// MARK: - Cliente HTTP compatible con OpenAI

struct AIClient {
    let apiKey: String
    let baseURL: String
    let model: String
    let sessionID: String

    func generatePlan(settings: UserSettings, previous: WeekPlan? = nil, variation: Int = 0) async throws -> WeekPlan {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIPlanError.missingKey
        }
        guard !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIPlanError.network(L10n.t("La URL base está vacía."))
        }

        var feedback: String?
        var lastError: Error = AIPlanError.noPlan
        let initialBudget = maxOutputTokens

        for attempt in 1...3 {
            // Los modelos con razonamiento gastan parte del presupuesto pensando.
            // Damos margen de sobra y, si se queda corto, lo duplicamos.
            let budget = attempt == 1 ? initialBudget : min(initialBudget * (1 << (attempt - 1)), 64_000)
            do {
                let prompt = PromptBuilder.userPrompt(
                    settings: settings,
                    feedback: feedback,
                    previous: previous,
                    variation: variation
                )
                let content = try await send(system: PromptBuilder.systemPrompt, user: prompt, maxTokens: budget)
                let dto = try decode(content)
                return try PlanBuilder.build(dto, settings: settings)
            } catch {
                logAppError(
                    error,
                    context: L10n.format("Intento %lld de 3 al generar el menú", attempt)
                )
                lastError = error
                if attempt < 3 {
                    feedback = (error as? AIPlanError)?.feedback ?? L10n.t("La respuesta no era un JSON válido. Devuelve solo el objeto JSON del esquema.")
                }
            }
        }
        throw lastError
    }

    /// Presupuesto de salida. OpenCode Go sirve modelos de razonamiento con límites
    /// de salida muy altos; el resto de proveedores se quedan en 16k para no romper
    /// modelos pequeños (gpt-4o-mini admite 16k como máximo).
    private var maxOutputTokens: Int {
        let base = baseURL.lowercased()
        if base.contains("opencode.ai/inference") { return 32_000 }
        return 16_000
    }

    private func decode(_ content: String) throws -> AIPlanDTO {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIPlanError.emptyResponse }
        let json: String
        if let object = Self.lastJSONObject(in: trimmed) {
            json = object
        } else if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            json = String(trimmed[start...end])
        } else {
            throw AIPlanError.decoding(L10n.t("No hay un objeto JSON en la respuesta."))
        }
        var cleaned = json.replacingOccurrences(of: ",\\s*([}\\]])", with: "$1", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else {
            throw AIPlanError.decoding(L10n.t("Codificación inválida."))
        }
        do {
            return try JSONDecoder().decode(AIPlanDTO.self, from: data)
        } catch {
            throw AIPlanError.decoding(error.localizedDescription)
        }
    }

    private func send(system: String, user: String, maxTokens: Int) async throws -> String {
        let messages = [
            ChatRequest.Message(role: "system", content: system),
            ChatRequest.Message(role: "user", content: user)
        ]

        let full = ChatRequest(
            model: model,
            messages: messages,
            temperature: 0.65,
            maxTokens: maxTokens,
            responseFormat: .init(type: "json_object"),
            reasoningEffort: supportsReasoningEffort ? "none" : nil,
            stream: false
        )

        do {
            return try await perform(full)
        } catch let error as AIPlanError {
            // Algunos proveedores compatibles con OpenAI rechazan parámetros concretos.
            // Si el fallo apunta a uno de ellos, reintentamos con el cuerpo mínimo.
            guard case .http(let code, let message) = error,
                  (code == 400 || code == 422),
                  isUnsupportedParameterError(message) else {
                throw error
            }
            let minimal = ChatRequest(
                model: model,
                messages: messages,
                temperature: nil,
                maxTokens: nil,
                responseFormat: nil,
                reasoningEffort: nil,
                stream: false
            )
            return try await perform(minimal)
        }
    }

    /// OpenCode Go acepta `reasoning_effort: "none"`. Sin esto, DeepSeek V4.1 Flash
    /// puede pasar minutos razonando un menú y agotar el tiempo de espera.
    private var supportsReasoningEffort: Bool {
        baseURL.lowercased().contains("opencode.ai/inference")
    }

    private func isUnsupportedParameterError(_ message: String) -> Bool {
        let value = message.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return ["response_format", "max_tokens", "temperature", "reasoning_effort", "unsupported", "unknown parameter", "not supported", "invalid parameter"].contains { value.contains($0) }
    }

    private func perform(_ body: ChatRequest) async throws -> String {
        let endpoint = makeEndpoint()
        guard let url = URL(string: endpoint) else {
            throw AIPlanError.network(L10n.t("La URL de la API no es válida."))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if baseURL.contains("openrouter.ai") {
            request.setValue("Semana Lista", forHTTPHeaderField: "X-Title")
        }
        if baseURL.contains("opencode.ai/inference") {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            request.setValue("SemanaLista/\(version)", forHTTPHeaderField: "User-Agent")
            let session = sessionID.hasPrefix("ses_") ? sessionID : "ses_\(sessionID)"
            request.setValue(session, forHTTPHeaderField: "x-opencode-session")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIPlanError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIPlanError.network(L10n.t("Respuesta no válida."))
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = parseErrorMessage(data) ?? L10n.t("Error desconocido")
            throw AIPlanError.http(http.statusCode, message)
        }

        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw AIPlanError.decoding(L10n.t("No se pudo leer la respuesta del servidor."))
        }
        guard let choice = decoded.choices.first else { throw AIPlanError.emptyResponse }

        let content = choice.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let reasoning = [choice.message.reasoningContent, choice.message.reasoning]
            .compactMap { $0 }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let reason = choice.finishReason ?? "desconocido"

        #if DEBUG
        let reasoningTokens = decoded.usage?.completionTokensDetails?.reasoningTokens ?? 0
        print("[AIPlanner] finish_reason=\(reason) content=\(content.count) reasoning=\(reasoning.count) reasoning_tokens=\(reasoningTokens)")
        #endif

        // Algunos modelos de razonamiento devuelven el texto en `reasoning_content`
        // y dejan `content` vacío. Si ahí hay un JSON completo, lo aprovechamos.
        if !content.isEmpty { return content }
        if let salvaged = Self.lastJSONObject(in: reasoning) {
            #if DEBUG
            print("[AIPlanner] JSON recuperado de reasoning_content (\(salvaged.count) caracteres)")
            #endif
            return salvaged
        }
        if reason == "length" { throw AIPlanError.truncated }
        throw AIPlanError.emptyResponse
    }

    /// Devuelve el último objeto JSON completo dentro de un texto.
    /// Se usa como red de seguridad con `reasoning_content`, donde el modelo
    /// puede ir escribiendo borradores del JSON antes de la respuesta final.
    static func lastJSONObject(in text: String) -> String? {
        guard !text.isEmpty else { return nil }
        var depth = 0
        var start: String.Index?
        var last: String?
        var inString = false
        var escaped = false

        for index in text.indices {
            let character = text[index]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }
            if character == "\"" {
                inString = true
            } else if character == "{" {
                if depth == 0 { start = index }
                depth += 1
            } else if character == "}", depth > 0 {
                depth -= 1
                if depth == 0, let objectStart = start {
                    last = String(text[objectStart...index])
                    start = nil
                }
            }
        }
        return last
    }

    private func makeEndpoint() -> String {
        let base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.contains("/chat/completions") { return base }
        return base.hasSuffix("/") ? "\(base)chat/completions" : "\(base)/chat/completions"
    }

    private func parseErrorMessage(_ data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
                return message
            }
            if let message = object["message"] as? String {
                return message
            }
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.isEmpty ? nil : String(text.prefix(220))
    }
}

// MARK: - Prompt

enum PromptBuilder {
    static var systemPrompt: String {
        AppLanguage.isEnglish ? englishSystemPrompt : spanishSystemPrompt
    }

    static let spanishSystemPrompt = """
    Eres Mise, cocinero español experto en batch cooking, nutrición cotidiana y conservación de alimentos. Diseñas semanas realistas para gente que cocina una sola vez y come de táper el resto de la semana.

    Devuelves SIEMPRE un único objeto JSON válido, sin markdown, sin comentarios y sin texto fuera del JSON. El JSON debe cumplir exactamente el esquema pedido.
    """

    static let englishSystemPrompt = """
    You are Mise, a Spanish cook specialising in batch cooking, everyday nutrition and food storage. You design realistic weeks for people who cook once and eat from containers for the rest of the week.

    Always return a single valid JSON object, with no markdown, no comments and no text outside the JSON. The JSON must match the requested schema exactly. Write every human-readable text in natural English: title, subtitle, notes, nightBefore, preparation names, steps, reheat, ingredient names, meal titles and meal notes. Keep the internal values of "unit", "aisle" and "category" exactly as listed in the schema; those are internal codes, not user-facing text.
    """

    static func userPrompt(settings: UserSettings, feedback: String?, previous: WeekPlan? = nil, variation: Int = 0) -> String {
        if AppLanguage.isEnglish {
            return englishUserPrompt(settings: settings, feedback: feedback, previous: previous, variation: variation)
        }
        return spanishUserPrompt(settings: settings, feedback: feedback, previous: previous, variation: variation)
    }

    private static func spanishUserPrompt(settings: UserSettings, feedback: String?, previous: WeekPlan?, variation: Int) -> String {
        let notes = settings.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let dislikes = settings.dislikes.trimmingCharacters(in: .whitespacesAndNewlines)
        let allergies = settings.allergies.trimmingCharacters(in: .whitespacesAndNewlines)
        let diet = settings.dietPrompt
        let budget = settings.timeBudget
        let people = settings.people
        let exclusions = settings.exclusions
        let excludedList = exclusions.isEmpty ? "ninguno" : exclusions.promptList
        let previousNames = previous?.preps.map(\.name).joined(separator: ", ") ?? ""

        var text = """
        DISEÑA UNA SEMANA DE BATCH COOKING.

        DATOS
        - Comensales: \(people) personas adultas. Cada comida es de \(people) raciones.
        - 7 días consecutivos, con comida y cena (14 comidas). Sin desayunos.
        - Se cocina TODO en una sola sesión de \(budget) minutos como máximo. La app añade 20 minutos fijos de organización, enfriado y guardado; la suma de "totalMinutes" de las preparaciones debe ser ≤ \(max(60, budget - 20)).
        - El orden de cocinado real será el orden del array "preps": primero legumbre, después cereal, después proteína, después verdura, después salsa y al final lo rápido. Cocina secuencial, sin dos guisos largos a la vez.
        - Día de batch: \(settings.batchWeekday.name.lowercased()) a las \(settings.startTimeLabel). La app pone las fechas.
        - Preferencias: \(diet).
        - Alergias o intolerancias: \(allergies.isEmpty ? "ninguna" : allergies).
        - No le gusta: \(dislikes.isEmpty ? "nada" : dislikes).
        - PROHIBIDOS (exclusión estricta): \(excludedList).
        - Generación nº \(variation + 1). \(previousNames.isEmpty ? "Es la primera semana." : "La semana anterior usaba: \(previousNames). NO repitas esas preparaciones ni sus ingredientes principales.")
        - Notas: \(notes.isEmpty ? "ninguna" : notes).

        REGLAS OBLIGATORIAS
        1. UNA SOLA LEGUMBRE en toda la semana: lentejas, garbanzos, alubias, guisantes o judiones. Está terminantemente prohibido proponer lentejas y alubias/garbanzos en el mismo plan. Si hay legumbre, va la primera. Si la legumbre está en PROHIBIDOS, no incluyas ninguna.
        2. Entre 6 y 8 preparaciones distintas. Todas se cocinan ese día. Cada preparación se usa en 2-5 comidas (las bases como arroz, pasta, patata, cuscús o quinoa pueden llegar a 5). Nada de preparaciones que no se usen.
        3. Cada una de las 14 comidas debe incluir al menos UNA preparación del batch. Los frescos (pan, ensalada, fruta, yogur, atún, queso) son solo acompañamiento, nunca la comida entera.
        4. El menú debe ser realista y saciante: comida principal + cena. Varía títulos, salsas y acompañamientos; no repitas el mismo plato exacto ni pongas la misma preparación en comida y cena del mismo día.
        5. Ingredientes de supermercado español, cocina sencilla con olla, sartén, horno y vitro. Nada de robot de cocina, airfryer, ingredientes exóticos ni técnicas complicadas.
        6. Conservación: máximo 4 días en nevera (5 para salsas). Ordena las comidas para gastar antes lo más perecedero (carne, pescado y verduras) y deja los cereales para el final.
        7. Cantidades POR RACIÓN (1 persona) y en crudo. La app multiplica por las raciones que correspondan. Sé preciso: legumbre seca 70-80 g, arroz o pasta 70-90 g, carne o pescado 150-180 g, verdura 200-250 g por ración. Los frescos también son por ración.
        8. Incluye aceite, sal y especias con "pantry": true. No incluyas agua.
        9. "unit" solo puede ser: "g", "ml", "unidad", "diente", "rama", "cucharada", "pizca".
        10. "aisle" solo puede ser: verduras, frutas, carnes, pescados, lacteos, legumbres, cereales, conservas, panaderia, despensa.
        11. "category" solo puede ser: legumbre, cereal, proteina, verdura, salsa, otro.
        12. Respeta alergias y preferencias. Si es vegetariana, no uses carne ni pescado: usa huevos, lácteos, tofu o legumbres (solo una legumbre). Si es vegana, no uses carne, pescado, marisco, huevos, lácteos, miel ni ningún otro producto de origen animal: usa tofu, seitán, legumbres (solo una), frutos secos y semillas.
        13. "totalMinutes" es el tiempo completo de esa preparación; "activeMinutes" el tiempo con las manos. No infles los tiempos.
        14. El resultado debe caber en \(budget) minutos. Si no cabe, reduce preparaciones o elige recetas más rápidas.
        15. VARIACIÓN: al regenerar, cambia los ingredientes principales. Si antes había pollo, usa otra proteína permitida (pavo, ternera, cerdo, pescado, huevo o tofu). Si antes había arroz, usa pasta, patata, cuscús o quinoa. No te limites a reordenar las mismas preparaciones.
        16. EXCLUSIONES: los alimentos de PROHIBIDOS no pueden aparecer en ninguna preparación, en ningún fresco, ni en los títulos. Tampoco variantes directas del mismo alimento. Sustituye la receta completa por otra que no los use.

        ESQUEMA EXACTO (devuelve este objeto; mismos nombres de campos)
        {
          "title": "Nombre corto de la semana",
          "subtitle": "Una frase que resuma el enfoque",
          "notes": "2-3 consejos de conservación y montaje",
          "nightBefore": "Qué dejar en remojo o descongelar la noche anterior (o \"\")",
          "preps": [
            {
              "id": "lentejas",
              "name": "Lentejas estofadas",
              "emoji": "🫘",
              "category": "legumbre",
              "activeMinutes": 15,
              "totalMinutes": 35,
              "storageDays": 4,
              "steps": ["Paso 1", "Paso 2", "Paso 3"],
              "reheat": "Cómo recalentar esta preparación",
              "ingredients": [
                {"name": "Lentejas pardinas", "quantity": 70, "unit": "g", "aisle": "legumbres", "pantry": false},
                {"name": "Aceite de oliva", "quantity": 5, "unit": "ml", "aisle": "despensa", "pantry": true}
              ]
            }
          ],
          "days": [
            {
              "weekday": 1,
              "lunch": {
                "title": "Lentejas estofadas con pan",
                "prepIDs": ["lentejas"],
                "fresh": [{"name": "Pan integral", "quantity": 60, "unit": "g", "aisle": "panaderia", "pantry": false}],
                "note": "Consejo breve para montar o recalentar"
              },
              "dinner": {
                "title": "Cena completa",
                "prepIDs": ["arroz", "pollo"],
                "fresh": [],
                "note": ""
              }
            }
          ]
        }

        "weekday" va de 1 (lunes) a 7 (domingo). Devuelve los 7 días y 14 comidas. Los "prepIDs" deben coincidir exactamente con los "id" de "preps". Incluye 3-5 pasos por preparación, claros y breves. No devuelvas markdown.
        """

        if let feedback, !feedback.isEmpty {
            text += "\n\nCORRECCIÓN OBLIGATORIA DE TU INTENTO ANTERIOR:\n\(feedback)\nDevuelve el plan completo corregido."
        }
        return text
    }

    private static func englishUserPrompt(settings: UserSettings, feedback: String?, previous: WeekPlan?, variation: Int) -> String {
        let notes = settings.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let dislikes = settings.dislikes.trimmingCharacters(in: .whitespacesAndNewlines)
        let allergies = settings.allergies.trimmingCharacters(in: .whitespacesAndNewlines)
        let diet = settings.dietPrompt
        let budget = settings.timeBudget
        let people = settings.people
        let exclusions = settings.exclusions
        let excludedList = exclusions.isEmpty ? "none" : exclusions.promptList
        let previousNames = previous?.preps.map(\.name).joined(separator: ", ") ?? ""

        var text = """
        DESIGN A BATCH-COOKING WEEK.

        DATA
        - Diners: \(people) adults. Each meal is \(people) servings.
        - 7 consecutive days with lunch and dinner (14 meals). No breakfasts.
        - Everything is cooked in a single session of at most \(budget) minutes. The app adds 20 fixed minutes for organising, cooling and storing; the sum of "totalMinutes" across preparations must be ≤ \(max(60, budget - 20)).
        - The real cooking order will be the order of the "preps" array: legume first, then cereal, then protein, then vegetables, then sauce, and quick items last. Cook sequentially, never two long dishes at once.
        - Batch day: \(settings.batchWeekday.name.lowercased()) at \(settings.startTimeLabel). The app sets the dates.
        - Preferences: \(diet).
        - Allergies or intolerances: \(allergies.isEmpty ? "none" : allergies).
        - Dislikes: \(dislikes.isEmpty ? "none" : dislikes).
        - FORBIDDEN (strict exclusion): \(excludedList).
        - Generation no. \(variation + 1). \(previousNames.isEmpty ? "This is the first week." : "The previous week used: \(previousNames). Do NOT repeat those preparations or their main ingredients.")
        - Notes: \(notes.isEmpty ? "none" : notes).

        MANDATORY RULES
        1. ONLY ONE LEGUME in the whole week: lentils, chickpeas, white beans, peas or broad beans. Never propose lentils and beans/chickpeas in the same plan. If there is a legume, it goes first. If legumes are FORBIDDEN, include none.
        2. Between 6 and 8 different preparations. All are cooked that day. Each preparation is used in 2-5 meals (staple bases such as rice, pasta, potato, couscous or quinoa may reach 5). Never include a preparation that is not used.
        3. Each of the 14 meals must include at least ONE batch preparation. Fresh items (bread, salad, fruit, yogurt, tuna, cheese) are accompaniments only, never the whole meal.
        4. The menu must be realistic and filling: main dish + dinner. Vary titles, sauces and sides; do not repeat the exact same dish or use the same preparation for lunch and dinner on the same day.
        5. Use supermarket ingredients and simple cooking with a pot, pan, oven and hob. No food processor, air fryer, exotic ingredients or complicated techniques.
        6. Storage: maximum 4 days in the fridge (5 for sauces). Order meals to use the most perishable food first (meat, fish and vegetables) and leave cereals for the end.
        7. Quantities are PER SERVING (1 person) and raw. The app multiplies by the corresponding servings. Be precise: 70-80 g dry legumes, 70-90 g rice or pasta, 150-180 g meat or fish, 200-250 g vegetables per serving. Fresh items are also per serving.
        8. Include oil, salt and spices with "pantry": true. Do not include water.
        9. "unit" must be exactly one of: "g", "ml", "unidad", "diente", "rama", "cucharada", "pizca".
        10. "aisle" must be exactly one of: verduras, frutas, carnes, pescados, lacteos, legumbres, cereales, conservas, panaderia, despensa.
        11. "category" must be exactly one of: legumbre, cereal, proteina, verdura, salsa, otro.
        12. Respect allergies and preferences. If vegetarian, do not use meat or fish: use eggs, dairy, tofu or legumes (only one legume). If vegan, do not use meat, fish, seafood, eggs, dairy, honey or any other animal-derived product: use tofu, seitan, legumes (only one), nuts and seeds.
        13. "totalMinutes" is the full time for that preparation; "activeMinutes" is hands-on time. Do not inflate times.
        14. The result must fit within \(budget) minutes. If it does not fit, reduce preparations or choose quicker recipes.
        15. VARIATION: when regenerating, change the main ingredients. If the previous plan used chicken, use another allowed protein (turkey, beef, pork, fish, egg or tofu). If it used rice, use pasta, potato, couscous or quinoa. Do not simply reorder the same preparations.
        16. EXCLUSIONS: foods in FORBIDDEN cannot appear in any preparation, any fresh item or any title. Do not use direct variants of the same food either. Replace the whole recipe with one that does not use them.

        EXACT SCHEMA (return this object; same field names)
        {
          "title": "Short name for the week",
          "subtitle": "One sentence summarising the approach",
          "notes": "2-3 storage and assembly tips",
          "nightBefore": "What to soak or defrost the night before (or \"\")",
          "preps": [
            {
              "id": "lentils",
              "name": "Lentil stew",
              "emoji": "🫘",
              "category": "legumbre",
              "activeMinutes": 15,
              "totalMinutes": 35,
              "storageDays": 4,
              "steps": ["Step 1", "Step 2", "Step 3"],
              "reheat": "How to reheat this preparation",
              "ingredients": [
                {"name": "Pardina lentils", "quantity": 70, "unit": "g", "aisle": "legumbres", "pantry": false},
                {"name": "Olive oil", "quantity": 5, "unit": "ml", "aisle": "despensa", "pantry": true}
              ]
            }
          ],
          "days": [
            {
              "weekday": 1,
              "lunch": {
                "title": "Lentil stew with bread",
                "prepIDs": ["lentils"],
                "fresh": [{"name": "Wholegrain bread", "quantity": 60, "unit": "g", "aisle": "panaderia", "pantry": false}],
                "note": "Short tip for assembling or reheating"
              },
              "dinner": {
                "title": "Complete dinner",
                "prepIDs": ["rice", "chicken"],
                "fresh": [],
                "note": ""
              }
            }
          ]
        }

        "weekday" goes from 1 (Monday) to 7 (Sunday). Return the 7 days and 14 meals. The "prepIDs" must match the "id" values of "preps" exactly. Include 3-5 clear, short steps per preparation. Do not return markdown. All human-readable text must be in English; keep unit, aisle and category values exactly as the internal codes above.
        """

        if let feedback, !feedback.isEmpty {
            text += "\n\nMANDATORY CORRECTION TO YOUR PREVIOUS ATTEMPT:\n\(feedback)\nReturn the complete corrected plan."
        }
        return text
    }
}

// MARK: - Tipos de red

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double?
    let maxTokens: Int?
    let responseFormat: ResponseFormat?
    let reasoningEffort: String?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
        case responseFormat = "response_format"
        case reasoningEffort = "reasoning_effort"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
            let reasoningContent: String?
            let reasoning: String?
            let refusal: String?

            enum CodingKeys: String, CodingKey {
                case content, reasoning, refusal
                case reasoningContent = "reasoning_content"
            }
        }

        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Usage: Decodable {
        struct CompletionDetails: Decodable {
            let reasoningTokens: Int?

            enum CodingKeys: String, CodingKey {
                case reasoningTokens = "reasoning_tokens"
            }
        }

        let promptTokens: Int?
        let completionTokens: Int?
        let completionTokensDetails: CompletionDetails?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case completionTokensDetails = "completion_tokens_details"
        }
    }

    let choices: [Choice]
    let usage: Usage?
}
