import Foundation

/// Plan de respaldo, sin red. Cocina realista en secuencia:
/// legumbre → cereal → proteína → verduras → salsa → rápidos.
/// Respeta la lista de alimentos excluidos y rota los ingredientes principales
/// en cada regeneración (pollo → pavo, arroz → pasta, lentejas → garbanzos…).
enum LocalPlanner {
    private struct PrepSeed {
        let id: String
        let name: String
        let keyword: String
        let emoji: String
        let category: PrepCategory
        let active: Int
        let total: Int
        let storage: Int
        let ingredients: [Ingredient]
        let steps: [String]
        let reheat: String
    }

    private struct MealSeed {
        let title: String
        let prepIDs: [String]
        let fresh: [Ingredient]
        let note: String
    }

    private struct VegOption {
        let name: String
        let quantity: Double
    }

    private struct SauceOption {
        let id: String
        let name: String
        let keyword: String
        let emoji: String
        let ingredient: Ingredient
    }

    static func make(settings: UserSettings, variation: Int = 0) -> WeekPlan {
        if AppLanguage.isEnglish {
            return EnglishPlanner.make(settings: settings, variation: variation)
        }
        let people = max(1, settings.people)
        let exclusions = settings.exclusions
        let rotation = abs(variation)

        let vegan = settings.isVegan
        let vegetarian = settings.isVegetarian
        let noPork = settings.diets.contains(.noPork)
        let noFish = settings.diets.contains(.noFish) || settings.diets.contains(.noSeafood) || vegetarian
        let noLactose = settings.diets.contains(.noLactose) || vegan
        let noGluten = settings.diets.contains(.noGluten)

        // MARK: Componentes del menú

        let legume = pick(legumeSeeds().filter { isAllowed($0, exclusions: exclusions) }, rotation: rotation)

        var cerealOptions = cerealSeeds().filter { isAllowed($0, exclusions: exclusions) }
        if noGluten {
            cerealOptions.removeAll { $0.id == "pasta" || $0.id == "cuscus" }
        }
        let cerealIndex = cerealOptions.isEmpty ? 0 : rotation % cerealOptions.count
        let cerealA = cerealOptions.isEmpty ? nil : cerealOptions[cerealIndex]
        let cerealB = cerealOptions.count > 1 ? cerealOptions[(cerealIndex + 1) % cerealOptions.count] : cerealA

        var proteinOptions = proteinSeeds().filter { isAllowed($0, exclusions: exclusions) }
        if vegetarian {
            proteinOptions.removeAll { $0.id != "tofu" }
        }
        if vegan, !noGluten, isAllowed(seitanSeed(), exclusions: exclusions) {
            proteinOptions.append(seitanSeed())
        }
        if noPork {
            proteinOptions.removeAll { $0.id == "cerdo" }
        }
        if noFish {
            proteinOptions.removeAll { $0.id == "salmon" || $0.id == "merluza" }
        }
        let protein = pick(proteinOptions, rotation: rotation)

        let eggs = (vegan || exclusions.excludes("Huevos")) ? nil : eggSeed()
        let vegetables = vegetableSeed(exclusions: exclusions, rotation: rotation)
        let sauce = sauceSeed(exclusions: exclusions, rotation: rotation)

        func freshIngredient(_ name: String, _ quantity: Double, _ unit: Unit, _ aisle: Aisle, pantry: Bool = false) -> Ingredient? {
            guard !exclusions.excludes(name) else { return nil }
            return Ingredient(name: name, quantity: quantity, unit: unit, aisle: aisle, pantry: pantry)
        }

        let pan = noGluten ? nil : freshIngredient("Pan integral", 60, .gramo, .panaderia)
        let tomato = freshIngredient("Tomate", 80, .gramo, .verduras)
        let lettuce = freshIngredient("Lechuga", 40, .gramo, .verduras)
        let saladMix = freshIngredient("Ensalada mixta", 100, .gramo, .verduras)
        let springOnion = freshIngredient("Cebolleta", 30, .gramo, .verduras)
        let olives = freshIngredient("Aceitunas", 25, .gramo, .conservas)
        let vinegar = freshIngredient("Vinagre", 5, .mililitro, .despensa, pantry: true)
        let tuna = noFish ? nil : freshIngredient("Atún al natural", 60, .gramo, .pescados)
        let cheese = noLactose ? nil : freshIngredient("Queso fresco", 40, .gramo, .lacteos)
        let mayo = vegan ? nil : freshIngredient("Mayonesa", 15, .gramo, .conservas)

        // MARK: Composición de títulos

        func compose(_ pieces: [String?]) -> String {
            let words = pieces
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard let first = words.first else { return "Comida de batch" }
            if words.count == 1 { return capitalizeFirst(first) }
            if words.count == 2 { return "\(capitalizeFirst(first)) con \(words[1])" }
            let middle = words[1..<(words.count - 1)]
            return "\(capitalizeFirst(first)) con \(middle.joined(separator: ", ")) y \(words[words.count - 1])"
        }

        func ids(_ seeds: [PrepSeed?]) -> [String] {
            var result: [String] = []
            for seed in seeds.compactMap({ $0 }) where !result.contains(seed.id) {
                result.append(seed.id)
            }
            return result
        }

        let fallbackSeed = protein ?? legume ?? cerealA ?? vegetables ?? sauce

        func meal(_ title: String, _ seeds: [PrepSeed?], fresh: [Ingredient?] = [], note: String = "Monta el plato al calentar y ajusta de sal.") -> MealSeed {
            var prepIDs = ids(seeds)
            if prepIDs.isEmpty {
                prepIDs = [fallbackSeed.id]
            }
            return MealSeed(title: title, prepIDs: prepIDs, fresh: fresh.compactMap { $0 }, note: note)
        }

        let lunL: MealSeed
        if let legume {
            let title = pan == nil
                ? capitalizeFirst(legume.keyword)
                : "\(capitalizeFirst(legume.keyword)) con pan integral"
            lunL = meal(title, [legume], fresh: [pan])
        } else {
            lunL = meal(
                compose([protein?.keyword, vegetables != nil ? "verduras" : nil]),
                [protein, vegetables],
                fresh: [pan]
            )
        }

        let lunD = meal(
            compose([cerealA?.keyword, eggs != nil ? "huevo" : nil, vegetables != nil ? "verduras asadas" : nil]),
            [cerealA, eggs, vegetables]
        )

        let marL = meal(
            compose([protein?.keyword, cerealA?.keyword, sauce.keyword]),
            [protein, cerealA, sauce]
        )

        let marD: MealSeed
        if let legume {
            marD = meal(
                "Ensalada templada de \(legume.keyword)",
                [legume, vegetables],
                fresh: [tomato, springOnion, lettuce, olives, vinegar]
            )
        } else {
            marD = meal(
                "Ensalada templada de verduras",
                [vegetables, protein],
                fresh: [tomato, springOnion, lettuce, olives, vinegar]
            )
        }

        let mieL = meal(
            compose([cerealB?.keyword, sauce.keyword, vegetables != nil ? "verduras" : nil]),
            [cerealB, sauce, vegetables]
        )

        let mieD: MealSeed
        if protein != nil || cheese != nil {
            var title = "Tostadas"
            if let protein { title += " de \(protein.keyword)" }
            if tomato != nil { title += " con tomate" }
            if cheese != nil { title += " y queso fresco" }
            mieD = meal(title, [protein, sauce], fresh: [pan, tomato, cheese])
        } else {
            mieD = meal("Tostadas con tomate", [sauce, vegetables], fresh: [pan, tomato])
        }

        let jueL = meal(
            compose([legume?.keyword, vegetables != nil ? "verduras asadas" : nil]),
            [legume, vegetables]
        )

        let jueD = meal(
            compose([cerealA?.keyword, protein?.keyword, vegetables != nil ? "verduras" : nil]),
            [cerealA, protein, vegetables]
        )

        let vieL = meal(
            compose([protein?.keyword, saladMix != nil ? "ensalada" : nil, sauce.keyword]),
            [protein, sauce],
            fresh: [saladMix, pan]
        )

        let vieD: MealSeed
        if eggs != nil {
            vieD = meal(
                tuna == nil ? "Huevos rellenos" : "Huevos rellenos con atún",
                [eggs],
                fresh: [tuna, mayo, lettuce, tomato]
            )
        } else if tuna != nil {
            vieD = meal(
                "Ensalada de atún",
                [vegetables, protein],
                fresh: [tuna, lettuce, tomato, mayo]
            )
        } else {
            vieD = meal(
                "Ensalada de verduras",
                [vegetables, protein],
                fresh: [lettuce, tomato, mayo]
            )
        }

        let sabL = meal(
            compose([cerealA?.keyword, vegetables != nil ? "verduras" : nil, eggs != nil ? "huevo" : nil]),
            [cerealA, vegetables, eggs]
        )

        let sabD = meal(
            compose([cerealB?.keyword, tuna != nil ? "atún" : nil, tomato != nil ? "tomate" : nil]),
            [cerealB, sauce],
            fresh: [tuna, tomato]
        )

        let domL = meal(
            compose([cerealA?.keyword, protein?.keyword, sauce.keyword]),
            [cerealA, protein, sauce]
        )

        let domD = meal(
            compose([cerealB?.keyword, vegetables != nil ? "verduras" : nil, tuna != nil ? "atún" : nil]),
            [cerealB, vegetables],
            fresh: [tuna, tomato, lettuce]
        )

        let meals: [MealSeed] = [
            lunL, lunD, marL, marD,
            mieL, mieD, jueL, jueD,
            vieL, vieD, sabL, sabD,
            domL, domD
        ]

        // MARK: Preparaciones usadas

        var seedByID: [String: PrepSeed] = [:]
        for seed in [legume, cerealA, cerealB, protein, eggs, vegetables, sauce].compactMap({ $0 }) {
            seedByID[seed.id] = seed
        }

        var uses: [String: Int] = [:]
        for seed in meals {
            for id in Set(seed.prepIDs) {
                uses[id, default: 0] += 1
            }
        }

        let preps: [Prep] = seedByID.values
            .filter { (uses[$0.id] ?? 0) > 0 }
            .sorted {
                if $0.category.sortPriority != $1.category.sortPriority {
                    return $0.category.sortPriority < $1.category.sortPriority
                }
                return $0.id < $1.id
            }
            .map { seed in
                let servings = people * max(1, uses[seed.id] ?? 1)
                let ingredients = seed.ingredients
                    .filter { !exclusions.excludes($0.name) }
                    .map { ingredient -> Ingredient in
                        var copy = ingredient
                        copy.quantity *= Double(servings)
                        return copy
                    }
                return Prep(
                    id: seed.id,
                    name: seed.name,
                    emoji: seed.emoji,
                    category: seed.category,
                    servings: servings,
                    ingredients: ingredients,
                    activeMinutes: seed.active,
                    totalMinutes: seed.total,
                    storageDays: seed.storage,
                    steps: seed.steps,
                    reheat: seed.reheat
                )
            }

        // MARK: Días y fechas

        var days: [DayPlan] = []
        let startWeekday = settings.batchWeekday
        for index in 0..<7 {
            let weekday = AppWeekday.from(((startWeekday.rawValue - 1 + index) % 7) + 1)
            let lunch = makeMeal(meals[index * 2], slot: .lunch, people: people)
            let dinner = makeMeal(meals[index * 2 + 1], slot: .dinner, people: people)
            days.append(DayPlan(weekday: weekday, lunch: lunch, dinner: dinner))
        }

        var start = WeekDates.nextDate(for: settings.batchWeekday)
        let calendar = Calendar.current
        if calendar.isDateInToday(start), calendar.component(.hour, from: .now) >= settings.startHour + 1 {
            start = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        }

        // MARK: Textos

        var title = "Semana mediterránea"
        if vegan { title = "Semana vegana" }
        else if vegetarian { title = "Semana vegetariana" }
        else if noGluten { title = "Semana sin gluten" }
        else if noFish { title = "Semana sin pescado" }
        else if noLactose { title = "Semana sin lactosa" }

        let subtitleParts = ["Una legumbre", cerealA?.keyword, protein?.keyword, "verduras"].compactMap { $0 }
        let subtitle = "\(subtitleParts.joined(separator: ", ")). Todo cocinado en una tarde."

        var nightBefore = ""
        if let protein {
            switch protein.id {
            case "tofu":
                nightBefore = "Deja el tofu escurriendo en la nevera. "
            case "seitan":
                nightBefore = ""
            default:
                nightBefore = "Pasa el \(protein.keyword) del congelador a la nevera. "
            }
        }
        if let legume {
            nightBefore += "Si tus \(legume.keyword) son de piel dura, déjalos en remojo la noche anterior."
        }
        if nightBefore.isEmpty {
            nightBefore = "Revisa la compra y deja en remojo o descongela lo que lo necesite."
        }

        return WeekPlan(
            title: title,
            subtitle: subtitle,
            source: .local,
            createdAt: .now,
            startDate: start,
            people: people,
            startHour: settings.startHour,
            startMinute: settings.startMinute,
            timeBudget: settings.timeBudget,
            preps: preps,
            days: days,
            notes: "Guarda cada preparación por separado y monta el plato al calentar. Así las 14 comidas saben distinto aunque cocines una sola vez. La salsa y las verduras aguantan mejor que el cereal: deja el cereal para las comidas más cercanas al día de cocina.",
            nightBefore: nightBefore,
            language: "es"
        )
    }

    // MARK: - Utilidades

    private static func makeMeal(_ seed: MealSeed, slot: MealSlot, people: Int) -> Meal {
        Meal(
            slot: slot,
            title: seed.title,
            prepIDs: seed.prepIDs,
            fresh: seed.fresh.map { ingredient in
                var copy = ingredient
                copy.quantity = ingredient.quantity * Double(people)
                return copy
            },
            note: seed.note
        )
    }

    private static func ing(_ name: String, _ quantity: Double, _ unit: Unit, _ aisle: Aisle, pantry: Bool = false) -> Ingredient {
        Ingredient(name: name, quantity: quantity, unit: unit, aisle: aisle, pantry: pantry)
    }

    private static func capitalizeFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    private static func pick(_ seeds: [PrepSeed], rotation: Int) -> PrepSeed? {
        guard !seeds.isEmpty else { return nil }
        return seeds[rotation % seeds.count]
    }

    private static func isAllowed(_ seed: PrepSeed, exclusions: IngredientExclusions) -> Bool {
        guard !exclusions.excludes(seed.name) else { return false }
        return seed.ingredients.contains { ingredient in
            !ingredient.pantry && !exclusions.excludes(ingredient.name)
        }
    }

    // MARK: - Catálogo de legumbres

    private static func legumeSeeds() -> [PrepSeed] {
        [
            PrepSeed(
                id: "lentejas",
                name: "Lentejas estofadas",
                keyword: "lentejas",
                emoji: "🫘",
                category: .legumbre,
                active: 15,
                total: 35,
                storage: 4,
                ingredients: [
                    ing("Lentejas pardinas", 70, .gramo, .legumbres),
                    ing("Zanahoria", 40, .gramo, .verduras),
                    ing("Cebolla", 30, .gramo, .verduras),
                    ing("Pimiento verde", 30, .gramo, .verduras),
                    ing("Tomate triturado", 60, .gramo, .conservas),
                    ing("Patata", 50, .gramo, .verduras),
                    ing("Aceite de oliva", 5, .mililitro, .despensa, pantry: true),
                    ing("Pimentón dulce", 0.5, .gramo, .despensa, pantry: true),
                    ing("Laurel", 0.2, .gramo, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Sofríe la verdura picada con el aceite 6 minutos.",
                    "Añade la legumbre, la patata, el tomate y las especias; cubre con agua.",
                    "Cuece 25-30 minutos a fuego medio hasta que la legumbre esté tierna. Ajusta de sal."
                ],
                reheat: "Calienta con un chorrito de agua o caldo para que no se reseque."
            ),
            PrepSeed(
                id: "garbanzos",
                name: "Garbanzos estofados",
                keyword: "garbanzos",
                emoji: "🫘",
                category: .legumbre,
                active: 15,
                total: 40,
                storage: 4,
                ingredients: [
                    ing("Garbanzos secos", 70, .gramo, .legumbres),
                    ing("Zanahoria", 40, .gramo, .verduras),
                    ing("Cebolla", 30, .gramo, .verduras),
                    ing("Pimiento verde", 30, .gramo, .verduras),
                    ing("Tomate triturado", 60, .gramo, .conservas),
                    ing("Patata", 50, .gramo, .verduras),
                    ing("Aceite de oliva", 5, .mililitro, .despensa, pantry: true),
                    ing("Pimentón dulce", 0.5, .gramo, .despensa, pantry: true),
                    ing("Laurel", 0.2, .gramo, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Deja los garbanzos en remojo la noche anterior si son secos.",
                    "Sofríe la verdura picada con el aceite 6 minutos y añade el tomate y las especias.",
                    "Incorpora los garbanzos y la patata, cubre con agua y cuece 30-35 minutos."
                ],
                reheat: "Añade un poco de agua al calentar: espesa bastante en la nevera."
            ),
            PrepSeed(
                id: "alubias",
                name: "Alubias blancas estofadas",
                keyword: "alubias",
                emoji: "🫘",
                category: .legumbre,
                active: 12,
                total: 40,
                storage: 4,
                ingredients: [
                    ing("Alubias blancas secas", 70, .gramo, .legumbres),
                    ing("Puerro", 40, .gramo, .verduras),
                    ing("Zanahoria", 40, .gramo, .verduras),
                    ing("Tomate triturado", 50, .gramo, .conservas),
                    ing("Aceite de oliva", 5, .mililitro, .despensa, pantry: true),
                    ing("Pimentón dulce", 0.5, .gramo, .despensa, pantry: true),
                    ing("Laurel", 0.2, .gramo, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Deja las alubias en remojo la noche anterior si son secas.",
                    "Pocha el puerro y la zanahoria con el aceite 6 minutos.",
                    "Añade las alubias, el tomate y las especias, cubre con agua y cuece 30-35 minutos."
                ],
                reheat: "Calienta despacio y añade agua si ha espesado demasiado."
            )
        ]
    }

    // MARK: - Catálogo de cereales y bases

    private static func cerealSeeds() -> [PrepSeed] {
        [
            PrepSeed(
                id: "arroz",
                name: "Arroz basmati",
                keyword: "arroz",
                emoji: "🍚",
                category: .cereal,
                active: 5,
                total: 20,
                storage: 4,
                ingredients: [
                    ing("Arroz basmati", 70, .gramo, .cereales),
                    ing("Aceite de oliva", 2, .mililitro, .despensa, pantry: true),
                    ing("Sal", 0.5, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Lava el arroz hasta que el agua salga clara.",
                    "Sofríe 1 minuto con el aceite, añade el doble de agua y sal.",
                    "Cuece tapado 10 minutos, apaga y deja reposar 5 minutos. Suelta con un tenedor."
                ],
                reheat: "Un chorrito de agua y 1 minuto de microondas. Mejor al vapor si puedes."
            ),
            PrepSeed(
                id: "pasta",
                name: "Pasta integral",
                keyword: "pasta",
                emoji: "🍝",
                category: .cereal,
                active: 2,
                total: 12,
                storage: 4,
                ingredients: [
                    ing("Pasta integral", 75, .gramo, .cereales),
                    ing("Aceite de oliva", 2, .mililitro, .despensa, pantry: true),
                    ing("Sal", 0.5, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Cuece la pasta en agua con sal según el paquete (8-10 minutos).",
                    "Escurre, enfría un poco y mezcla con aceite para que no se pegue."
                ],
                reheat: "Añade una cucharada de agua al calentarla para que vuelva a soltarse."
            ),
            PrepSeed(
                id: "patata",
                name: "Patatas panadera",
                keyword: "patatas",
                emoji: "🥔",
                category: .cereal,
                active: 10,
                total: 35,
                storage: 4,
                ingredients: [
                    ing("Patata", 200, .gramo, .verduras),
                    ing("Cebolla", 40, .gramo, .verduras),
                    ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Corta la patata en láminas finas y la cebolla en juliana.",
                    "Mezcla con aceite y sal y extiende en una bandeja.",
                    "Hornea 25-30 minutos a 200 °C hasta que estén doradas."
                ],
                reheat: "Recalienta en sartén o airfryer para recuperar la textura; en microondas quedan blandas."
            ),
            PrepSeed(
                id: "cuscus",
                name: "Cuscús integral",
                keyword: "cuscús",
                emoji: "🥣",
                category: .cereal,
                active: 3,
                total: 10,
                storage: 4,
                ingredients: [
                    ing("Cuscús integral", 70, .gramo, .cereales),
                    ing("Aceite de oliva", 3, .mililitro, .despensa, pantry: true),
                    ing("Sal", 0.5, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Cubre el cuscús con el mismo volumen de agua hirviendo y sal.",
                    "Tapa 5 minutos y suelta con un tenedor.",
                    "Añade el aceite y mezcla para que quede suelto."
                ],
                reheat: "Un chorrito de agua y 1 minuto de microondas."
            ),
            PrepSeed(
                id: "quinoa",
                name: "Quinoa",
                keyword: "quinoa",
                emoji: "🌾",
                category: .cereal,
                active: 3,
                total: 18,
                storage: 4,
                ingredients: [
                    ing("Quinoa", 70, .gramo, .cereales),
                    ing("Aceite de oliva", 2, .mililitro, .despensa, pantry: true),
                    ing("Sal", 0.5, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Lava la quinoa bajo el grifo hasta que no haga espuma.",
                    "Cuece 15 minutos con el doble de agua y sal.",
                    "Escurre el sobrante y mezcla con el aceite."
                ],
                reheat: "Se suelta bien con un tenedor y un chorrito de agua al calentar."
            )
        ]
    }

    // MARK: - Catálogo de proteínas

    private static func proteinSeeds() -> [PrepSeed] {
        [
            PrepSeed(
                id: "pollo",
                name: "Pollo al horno",
                keyword: "pollo",
                emoji: "🍗",
                category: .proteina,
                active: 12,
                total: 38,
                storage: 4,
                ingredients: [
                    ing("Muslos de pollo sin piel", 180, .gramo, .carnes),
                    ing("Limón", 0.25, .unidad, .frutas),
                    ing("Ajo", 0.5, .diente, .verduras),
                    ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true),
                    ing("Pimentón dulce", 1, .gramo, .despensa, pantry: true),
                    ing("Romero", 0.3, .gramo, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Marina el pollo con limón, ajo picado, pimentón, romero, aceite y sal.",
                    "Coloca en una bandeja y hornea 30-35 minutos a 200 °C.",
                    "Deja reposar 5 minutos antes de deshuesar y guardar con sus jugos."
                ],
                reheat: "Recalienta tapado para que no se seque. También queda bien templado en ensalada."
            ),
            PrepSeed(
                id: "pavo",
                name: "Pavo al horno",
                keyword: "pavo",
                emoji: "🦃",
                category: .proteina,
                active: 10,
                total: 30,
                storage: 4,
                ingredients: [
                    ing("Pechuga de pavo", 170, .gramo, .carnes),
                    ing("Limón", 0.25, .unidad, .frutas),
                    ing("Ajo", 0.5, .diente, .verduras),
                    ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true),
                    ing("Pimentón dulce", 1, .gramo, .despensa, pantry: true),
                    ing("Romero", 0.3, .gramo, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Marina la pechuga con limón, ajo, pimentón, romero, aceite y sal.",
                    "Hornea 22-25 minutos a 200 °C sin pasarla.",
                    "Reposa 5 minutos y córtala en filetes gruesos."
                ],
                reheat: "Mojada en su jugo aguanta muy bien. No la recalientes demasiado."
            ),
            PrepSeed(
                id: "ternera",
                name: "Ternera guisada",
                keyword: "ternera",
                emoji: "🥩",
                category: .proteina,
                active: 15,
                total: 45,
                storage: 4,
                ingredients: [
                    ing("Ternera para guisar", 160, .gramo, .carnes),
                    ing("Cebolla", 40, .gramo, .verduras),
                    ing("Zanahoria", 40, .gramo, .verduras),
                    ing("Tomate triturado", 60, .gramo, .conservas),
                    ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true),
                    ing("Pimentón dulce", 1, .gramo, .despensa, pantry: true),
                    ing("Laurel", 0.2, .gramo, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Dora la ternera en el aceite y retírala.",
                    "Pocha la cebolla y la zanahoria, añade el tomate y el pimentón.",
                    "Vuelve a poner la carne, cubre con agua y guisa 35-40 minutos."
                ],
                reheat: "Está mejor de un día para otro. Calienta despacio con su salsa."
            ),
            PrepSeed(
                id: "cerdo",
                name: "Cerdo al horno",
                keyword: "cerdo",
                emoji: "🥩",
                category: .proteina,
                active: 10,
                total: 35,
                storage: 4,
                ingredients: [
                    ing("Lomo de cerdo", 170, .gramo, .carnes),
                    ing("Limón", 0.25, .unidad, .frutas),
                    ing("Ajo", 0.5, .diente, .verduras),
                    ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true),
                    ing("Pimentón dulce", 1, .gramo, .despensa, pantry: true),
                    ing("Romero", 0.3, .gramo, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Marina el lomo con limón, ajo, pimentón, romero, aceite y sal.",
                    "Hornea 25-30 minutos a 200 °C.",
                    "Reposa 5 minutos antes de cortarlo en medallones."
                ],
                reheat: "Con un poco de su jugo se mantiene tierno."
            ),
            PrepSeed(
                id: "salmon",
                name: "Salmón al horno",
                keyword: "salmón",
                emoji: "🐟",
                category: .proteina,
                active: 6,
                total: 25,
                storage: 3,
                ingredients: [
                    ing("Salmón", 150, .gramo, .pescados),
                    ing("Limón", 0.25, .unidad, .frutas),
                    ing("Ajo", 0.5, .diente, .verduras),
                    ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Coloca el salmón en una bandeja con limón, ajo y aceite.",
                    "Hornea 12-15 minutos a 200 °C, justo hasta que se separe en lascas.",
                    "Guarda sin hueso ni piel y con su jugo."
                ],
                reheat: "Mejor templado que muy caliente: se seca enseguida."
            ),
            PrepSeed(
                id: "merluza",
                name: "Merluza al horno",
                keyword: "merluza",
                emoji: "🐟",
                category: .proteina,
                active: 6,
                total: 25,
                storage: 3,
                ingredients: [
                    ing("Merluza", 180, .gramo, .pescados),
                    ing("Limón", 0.25, .unidad, .frutas),
                    ing("Ajo", 0.5, .diente, .verduras),
                    ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Coloca la merluza en una bandeja con limón, ajo y aceite.",
                    "Hornea 12-15 minutos a 200 °C.",
                    "Guarda en táper plano para que no se rompa."
                ],
                reheat: "Calienta tapada y con cuidado de no romperla."
            ),
            PrepSeed(
                id: "tofu",
                name: "Tofu al horno",
                keyword: "tofu",
                emoji: "🧈",
                category: .proteina,
                active: 15,
                total: 35,
                storage: 4,
                ingredients: [
                    ing("Tofu firme", 150, .gramo, .otros),
                    ing("Limón", 0.25, .unidad, .frutas),
                    ing("Ajo", 0.5, .diente, .verduras),
                    ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true),
                    ing("Pimentón dulce", 1, .gramo, .despensa, pantry: true),
                    ing("Sal", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Prensa el tofu 10 minutos para que suelte el agua y córtalo en dados.",
                    "Marina con limón, ajo picado, pimentón, aceite y sal.",
                    "Hornea 20-25 minutos a 200 °C, dándole la vuelta a mitad."
                ],
                reheat: "Calienta tapado 2 minutos. También queda bien templado en ensalada."
            )
        ]
    }

    /// Proteína vegetal de apoyo para la semana vegana cuando el gluten está permitido.
    private static func seitanSeed() -> PrepSeed {
        PrepSeed(
            id: "seitan",
            name: "Seitán al horno",
            keyword: "seitán",
            emoji: "🌾",
            category: .proteina,
            active: 10,
            total: 30,
            storage: 4,
            ingredients: [
                ing("Seitán", 160, .gramo, .otros),
                ing("Limón", 0.25, .unidad, .frutas),
                ing("Ajo", 0.5, .diente, .verduras),
                ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true),
                ing("Pimentón dulce", 1, .gramo, .despensa, pantry: true),
                ing("Sal", 1, .gramo, .despensa, pantry: true)
            ],
            steps: [
                "Corta el seitán en tiras gruesas y sécalo con papel de cocina.",
                "Marina con limón, ajo picado, pimentón, aceite y sal.",
                "Hornea 20-25 minutos a 200 °C, dándole la vuelta a mitad."
            ],
            reheat: "Calienta tapado 2 minutos para que no se seque. También queda bien templado."
        )
    }

    private static func eggSeed() -> PrepSeed {
        PrepSeed(
            id: "huevos",
            name: "Huevos cocidos",
            keyword: "huevo",
            emoji: "🥚",
            category: .proteina,
            active: 2,
            total: 10,
            storage: 4,
            ingredients: [
                ing("Huevos", 1, .unidad, .lacteos)
            ],
            steps: [
                "Cuece los huevos 9 minutos desde que empieza a hervir.",
                "Pásalos a agua con hielo, pélalos y guárdalos enteros."
            ],
            reheat: "No necesitan calentarse. Pélalos justo antes de comer si los guardas con cáscara."
        )
    }

    // MARK: - Verduras y salsa

    private static let vegetableOptions: [VegOption] = [
        VegOption(name: "Calabacín", quantity: 100),
        VegOption(name: "Pimiento rojo", quantity: 80),
        VegOption(name: "Berenjena", quantity: 80),
        VegOption(name: "Cebolla", quantity: 50),
        VegOption(name: "Zanahoria", quantity: 80),
        VegOption(name: "Judía verde", quantity: 80),
        VegOption(name: "Brócoli", quantity: 80),
        VegOption(name: "Champiñón", quantity: 80)
    ]

    private static func vegetableSeed(exclusions: IngredientExclusions, rotation: Int) -> PrepSeed? {
        let allowed = vegetableOptions.filter { !exclusions.excludes($0.name) }
        guard !allowed.isEmpty else { return nil }

        let count = min(4, allowed.count)
        let start = rotation % allowed.count
        let chosen = (0..<count).map { allowed[(start + $0) % allowed.count] }

        var ingredients = chosen.map { ing($0.name, $0.quantity, .gramo, .verduras) }
        ingredients.append(ing("Aceite de oliva", 8, .mililitro, .despensa, pantry: true))
        ingredients.append(ing("Sal", 1, .gramo, .despensa, pantry: true))

        return PrepSeed(
            id: "verduras",
            name: "Verduras asadas",
            keyword: "verduras",
            emoji: "🥦",
            category: .verdura,
            active: 10,
            total: 30,
            storage: 4,
            ingredients: ingredients,
            steps: [
                "Corta las verduras en trozos regulares.",
                "Mezcla con aceite y sal y extiende en una bandeja.",
                "Hornea 25 minutos a 200 °C removiendo a mitad."
            ],
            reheat: "Mejor templadas o a temperatura ambiente; en microondas pierden textura."
        )
    }

    private static let sauceOptions: [SauceOption] = [
        SauceOption(id: "salsa", name: "Salsa de tomate casera", keyword: "salsa de tomate", emoji: "🍅", ingredient: ing("Tomate triturado", 150, .gramo, .conservas)),
        SauceOption(id: "salsa-pimiento", name: "Salsa de pimiento asado", keyword: "salsa de pimiento", emoji: "🫑", ingredient: ing("Pimiento rojo", 150, .gramo, .verduras)),
        SauceOption(id: "salsa-calabacin", name: "Salsa de calabacín", keyword: "salsa de calabacín", emoji: "🥒", ingredient: ing("Calabacín", 150, .gramo, .verduras)),
        SauceOption(id: "salsa-berenjena", name: "Salsa de berenjena", keyword: "salsa de berenjena", emoji: "🍆", ingredient: ing("Berenjena", 150, .gramo, .verduras))
    ]

    private static func sauceSeed(exclusions: IngredientExclusions, rotation: Int) -> PrepSeed {
        let allowed = sauceOptions.filter { !exclusions.excludes($0.ingredient.name) }

        if !allowed.isEmpty {
            let option = allowed[rotation % allowed.count]
            var ingredients = [option.ingredient]
            if !exclusions.excludes("Cebolla") {
                ingredients.append(ing("Cebolla", 30, .gramo, .verduras))
            }
            if !exclusions.excludes("Ajo") {
                ingredients.append(ing("Ajo", 0.5, .diente, .verduras))
            }
            ingredients.append(ing("Aceite de oliva", 10, .mililitro, .despensa, pantry: true))
            if !exclusions.excludes("Albahaca") {
                ingredients.append(ing("Albahaca", 0.5, .gramo, .despensa, pantry: true))
            }
            ingredients.append(ing("Sal", 0.5, .gramo, .despensa, pantry: true))

            return PrepSeed(
                id: option.id,
                name: option.name,
                keyword: option.keyword,
                emoji: option.emoji,
                category: .salsa,
                active: 10,
                total: 15,
                storage: 5,
                ingredients: ingredients,
                steps: [
                    "Pocha la cebolla y el ajo picados 6 minutos.",
                    "Añade la verdura de base y las especias.",
                    "Cuece 8-10 minutos hasta que espese. Reparte en dos táperes pequeños."
                ],
                reheat: "Se calienta en 30 segundos. Úsala para dar jugo a cereales y verduras."
            )
        }

        var ingredients: [Ingredient] = []
        let lemon = !exclusions.excludes("Limón")
        if lemon { ingredients.append(ing("Limón", 0.5, .unidad, .frutas)) }
        ingredients.append(ing("Aceite de oliva", 15, .mililitro, .despensa, pantry: true))
        if !exclusions.excludes("Ajo") {
            ingredients.append(ing("Ajo", 0.5, .diente, .verduras))
        }
        ingredients.append(ing("Sal", 1, .gramo, .despensa, pantry: true))

        return PrepSeed(
            id: "alino",
            name: lemon ? "Aliño de limón y aceite" : "Aliño de aceite de oliva",
            keyword: "aliño",
            emoji: "🍋",
            category: .salsa,
            active: 2,
            total: 5,
            storage: 5,
            ingredients: ingredients,
            steps: [
                "Mezcla el aceite con el limón, el ajo picado y la sal.",
                "Guarda en un tarro pequeño y aliña al servir."
            ],
            reheat: "No necesita calentarse."
        )
    }
}
