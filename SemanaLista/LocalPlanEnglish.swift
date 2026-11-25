import Foundation

/// Plan base íntegramente en inglés para cuando el iPhone está en inglés.
/// Mantiene la misma estructura que el plan español: una legumbre, dos bases,
/// una proteína, verdura, salsa y huevos, con 14 comidas montadas.
enum EnglishPlanner {
    private struct Seed {
        let id: String
        let name: String
        let keyword: String
        let singular: String
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

    static func make(settings: UserSettings, variation: Int = 0) -> WeekPlan {
        let people = max(1, settings.people)
        let exclusions = settings.exclusions
        let rotation = abs(variation)
        let vegan = settings.isVegan
        let vegetarian = settings.isVegetarian
        let noFish = settings.diets.contains(.noFish) || settings.diets.contains(.noSeafood) || vegetarian
        let noGluten = settings.diets.contains(.noGluten)
        let noLactose = settings.diets.contains(.noLactose) || vegan
        let budget = settings.timeBudget

        func allowed(_ seed: Seed) -> Bool {
            guard !exclusions.excludes(seed.name), !exclusions.excludes(seed.keyword) else { return false }
            return seed.ingredients.contains { !exclusions.excludes($0.name) }
        }

        var legumeOptions = legumeSeeds().filter(allowed)
        if budget <= 180 {
            let quick = legumeOptions.filter { $0.total <= 36 }
            if !quick.isEmpty { legumeOptions = quick }
        }
        let legume = pick(legumeOptions, rotation: rotation)

        var cerealOptions = cerealSeeds().filter { seed in
            guard allowed(seed) else { return false }
            if noGluten && (seed.id == "pasta" || seed.id == "couscous") { return false }
            return true
        }
        if cerealOptions.isEmpty { cerealOptions = [riceSeed()] }
        let cerealA = pick(cerealOptions, rotation: rotation) ?? cerealOptions[0]
        let cerealB = pick(cerealOptions.filter { $0.id != cerealA.id }, rotation: rotation) ?? cerealA

        let proteinOptions = proteinSeeds().filter { seed in
            if seed.id == "seitan" && !vegan { return false }
            if vegetarian {
                let plantProtein = seed.id == "tofu" || seed.id == "seitan"
                if !plantProtein { return false }
            }
            if noGluten && seed.id == "seitan" { return false }
            if noFish && seed.id == "salmon" { return false }
            if budget < 220 && seed.id == "beef" { return false }
            return allowed(seed)
        }
        let pickedProtein = pick(proteinOptions, rotation: rotation)
        var eggs: Seed? = (vegan || exclusions.excludes("Eggs") || exclusions.excludes("egg")) ? nil : eggSeed()
        let mainProtein: Seed
        if let pickedProtein {
            mainProtein = pickedProtein
        } else if let egg = eggs {
            mainProtein = egg
            eggs = nil
        } else {
            mainProtein = legume ?? cerealA
        }

        let vegetables = pick(vegetableSeeds().filter(allowed), rotation: rotation)
        let sauce = pick(sauceSeeds().filter(allowed), rotation: rotation) ?? tomatoSauceSeed()

        func fresh(_ name: String, _ quantity: Double, _ unit: Unit, _ aisle: Aisle, pantry: Bool = false) -> Ingredient? {
            guard !exclusions.excludes(name) else { return nil }
            return Ingredient(name: name, quantity: quantity, unit: unit, aisle: aisle, pantry: pantry)
        }

        let bread = noGluten ? nil : fresh("Wholegrain bread", 60, .gramo, .panaderia)
        let tomato = fresh("Tomato", 80, .gramo, .verduras)
        let lettuce = fresh("Lettuce", 40, .gramo, .verduras)
        let saladMix = fresh("Mixed salad", 100, .gramo, .verduras)
        let springOnion = fresh("Spring onion", 30, .gramo, .verduras)
        let olives = fresh("Olives", 25, .gramo, .conservas)
        let vinegar = fresh("Vinegar", 5, .mililitro, .despensa, pantry: true)
        let tuna = noFish ? nil : fresh("Tuna in water", 60, .gramo, .pescados)
        let cheese = noLactose ? nil : fresh("Fresh cheese", 40, .gramo, .lacteos)
        let mayo = vegan ? nil : fresh("Mayonnaise", 15, .gramo, .conservas)

        func cap(_ text: String) -> String {
            guard let first = text.first else { return text }
            return String(first).uppercased() + text.dropFirst()
        }

        func compose(_ pieces: [String?], fallback: String) -> String {
            let words = pieces
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard let first = words.first else { return fallback }
            if words.count == 1 { return cap(first) }
            if words.count == 2 { return "\(cap(first)) with \(words[1])" }
            let middle = words[1..<(words.count - 1)]
            return "\(cap(first)) with \(middle.joined(separator: ", ")) and \(words[words.count - 1])"
        }

        func ids(_ seeds: [Seed?]) -> [String] {
            var result: [String] = []
            for seed in seeds.compactMap({ $0 }) where !result.contains(seed.id) {
                result.append(seed.id)
            }
            return result
        }

        let fallbackSeed = mainProtein

        func meal(_ title: String, _ seeds: [Seed?], fresh: [Ingredient?] = [], note: String = "Assemble the plate when reheating and season to taste.") -> MealSeed {
            var prepIDs = ids(seeds)
            if prepIDs.isEmpty {
                prepIDs = [fallbackSeed.id]
            }
            return MealSeed(title: title, prepIDs: prepIDs, fresh: fresh.compactMap { $0 }, note: note)
        }

        let legumeSingular = legume?.singular ?? "vegetable"

        let lunL: MealSeed
        if let legume {
            lunL = meal(
                bread == nil
                    ? "\(cap(legume.keyword)) with vegetables"
                    : "\(cap(legume.keyword)) with wholegrain bread",
                [legume],
                fresh: [bread]
            )
        } else {
            lunL = meal(
                compose([mainProtein.keyword, vegetables?.keyword], fallback: "Batch lunch"),
                [mainProtein, vegetables],
                fresh: [bread]
            )
        }

        let lunD = meal(
            compose([cerealA.keyword, eggs?.keyword, vegetables?.keyword], fallback: "Rice bowl"),
            [cerealA, eggs, vegetables]
        )

        let marL = meal(
            compose([mainProtein.keyword, cerealA.keyword, sauce.keyword], fallback: "Batch lunch"),
            [mainProtein, cerealA, sauce]
        )

        let marD: MealSeed
        if legume != nil {
            marD = meal(
                "Warm \(legumeSingular) salad",
                [legume, vegetables],
                fresh: [tomato, springOnion, lettuce, olives, vinegar]
            )
        } else {
            marD = meal(
                "Warm vegetable salad",
                [vegetables, mainProtein],
                fresh: [tomato, springOnion, lettuce, olives, vinegar]
            )
        }

        let mieL = meal(
            compose([cerealB.keyword, sauce.keyword, vegetables?.keyword], fallback: "Batch lunch"),
            [cerealB, sauce, vegetables]
        )

        let mieD: MealSeed
        if bread != nil {
            var title = "Toast with \(mainProtein.keyword)"
            if tomato != nil { title += ", tomato" }
            if cheese != nil { title += " and fresh cheese" }
            mieD = meal(title, [mainProtein, sauce], fresh: [bread, tomato, cheese])
        } else {
            mieD = meal(
                compose([cerealB.keyword, mainProtein.keyword, tomato != nil ? "tomato" : nil], fallback: "Batch dinner"),
                [cerealB, mainProtein, sauce],
                fresh: [tomato, cheese]
            )
        }

        let jueL = meal(
            compose([legume?.keyword, vegetables != nil ? "roasted vegetables" : nil], fallback: "Roasted vegetables"),
            [legume, vegetables]
        )

        let jueD = meal(
            compose([cerealA.keyword, mainProtein.keyword, vegetables?.keyword], fallback: "Batch dinner"),
            [cerealA, mainProtein, vegetables]
        )

        let vieL = meal(
            compose([mainProtein.keyword, saladMix != nil ? "salad" : nil, sauce.keyword], fallback: "Batch lunch"),
            [mainProtein, sauce],
            fresh: [saladMix, bread]
        )

        let vieD: MealSeed
        if eggs != nil {
            vieD = meal(
                tuna == nil ? "Stuffed eggs" : "Stuffed eggs with tuna",
                [eggs],
                fresh: [tuna, mayo, lettuce, tomato]
            )
        } else if tuna != nil {
            vieD = meal(
                "Tuna salad",
                [vegetables, mainProtein],
                fresh: [tuna, lettuce, tomato, mayo]
            )
        } else {
            vieD = meal(
                "Vegetable salad",
                [vegetables, mainProtein],
                fresh: [lettuce, tomato, mayo]
            )
        }

        let sabL = meal(
            compose([cerealA.keyword, vegetables?.keyword, eggs?.keyword], fallback: "Batch lunch"),
            [cerealA, vegetables, eggs]
        )

        let sabD = meal(
            compose([cerealB.keyword, tuna != nil ? "tuna" : nil, tomato != nil ? "tomato" : nil], fallback: "Batch dinner"),
            [cerealB, sauce],
            fresh: [tuna, tomato]
        )

        let domL = meal(
            compose([cerealA.keyword, mainProtein.keyword, sauce.keyword], fallback: "Batch lunch"),
            [cerealA, mainProtein, sauce]
        )

        let domD = meal(
            compose([cerealB.keyword, vegetables?.keyword, tuna != nil ? "tuna" : nil], fallback: "Batch dinner"),
            [cerealB, vegetables],
            fresh: [tuna, tomato, lettuce]
        )

        let meals = [lunL, lunD, marL, marD, mieL, mieD, jueL, jueD, vieL, vieD, sabL, sabD, domL, domD]

        var seedByID: [String: Seed] = [:]
        for seed in [legume, cerealA, cerealB, mainProtein, eggs, vegetables, sauce].compactMap({ $0 }) {
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

        var title = "Mediterranean week"
        if vegan { title = "Vegan week" }
        else if vegetarian { title = "Vegetarian week" }
        else if noGluten { title = "Gluten-free week" }
        else if noFish { title = "Fish-free week" }
        else if noLactose { title = "Lactose-free week" }

        let subtitleParts = ["One legume", cerealA.keyword, mainProtein.keyword, "vegetables"].compactMap { $0 }
        let subtitle = "\(subtitleParts.joined(separator: ", ")). All cooked in one afternoon."

        var nightBefore: String
        switch mainProtein.id {
        case "tofu":
            nightBefore = "Leave the tofu draining in the fridge. "
        case "seitan":
            nightBefore = ""
        default:
            nightBefore = "Move the \(mainProtein.keyword) from the freezer to the fridge. "
        }
        if let legume {
            nightBefore += "If your \(legume.keyword) are old, soak them the night before."
        }
        if nightBefore.isEmpty {
            nightBefore = "Check your shopping and soak or defrost anything that needs it."
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
            notes: "Store each preparation separately and assemble the plate when reheating. The 14 meals will taste different even though you cook once. Sauces and vegetables keep better than rice or pasta: leave the cereal for the meals closest to cooking day.",
            nightBefore: nightBefore,
            language: "en"
        )
    }

    // MARK: - Utilidades

    private static func pick(_ seeds: [Seed], rotation: Int) -> Seed? {
        guard !seeds.isEmpty else { return nil }
        return seeds[rotation % seeds.count]
    }

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

    // MARK: - Catálogo

    private static func legumeSeeds() -> [Seed] {
        [
            Seed(
                id: "lentils",
                name: "Lentil stew",
                keyword: "lentils",
                singular: "lentil",
                emoji: "🫘",
                category: .legumbre,
                active: 15,
                total: 35,
                storage: 4,
                ingredients: [
                    ing("Pardina lentils", 70, .gramo, .legumbres),
                    ing("Carrot", 40, .gramo, .verduras),
                    ing("Onion", 30, .gramo, .verduras),
                    ing("Green pepper", 30, .gramo, .verduras),
                    ing("Chopped tomatoes", 60, .gramo, .conservas),
                    ing("Potato", 50, .gramo, .verduras),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Sweet paprika", 0.5, .gramo, .despensa, pantry: true),
                    ing("Bay leaf", 0.2, .gramo, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Sauté the chopped vegetables in the oil for 6 minutes.",
                    "Add the lentils, potato, tomato and spices; cover with water.",
                    "Simmer for 25-30 minutes until the lentils are tender. Season to taste."
                ],
                reheat: "Reheat with a splash of water or stock so it doesn't dry out."
            ),
            Seed(
                id: "chickpeas",
                name: "Chickpea stew",
                keyword: "chickpeas",
                singular: "chickpea",
                emoji: "🫘",
                category: .legumbre,
                active: 15,
                total: 40,
                storage: 4,
                ingredients: [
                    ing("Dried chickpeas", 70, .gramo, .legumbres),
                    ing("Carrot", 40, .gramo, .verduras),
                    ing("Onion", 30, .gramo, .verduras),
                    ing("Green pepper", 30, .gramo, .verduras),
                    ing("Chopped tomatoes", 60, .gramo, .conservas),
                    ing("Potato", 50, .gramo, .verduras),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Sweet paprika", 0.5, .gramo, .despensa, pantry: true),
                    ing("Bay leaf", 0.2, .gramo, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Soak the chickpeas overnight if they are dried.",
                    "Sauté the chopped vegetables in the oil for 6 minutes and add the tomato and spices.",
                    "Add the chickpeas and potato, cover with water and simmer for 30-35 minutes."
                ],
                reheat: "Add a little water when reheating: it thickens a lot in the fridge."
            ),
            Seed(
                id: "white-beans",
                name: "White bean stew",
                keyword: "white beans",
                singular: "white bean",
                emoji: "🫘",
                category: .legumbre,
                active: 12,
                total: 40,
                storage: 4,
                ingredients: [
                    ing("Dried white beans", 70, .gramo, .legumbres),
                    ing("Leek", 40, .gramo, .verduras),
                    ing("Carrot", 40, .gramo, .verduras),
                    ing("Chopped tomatoes", 50, .gramo, .conservas),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Sweet paprika", 0.5, .gramo, .despensa, pantry: true),
                    ing("Bay leaf", 0.2, .gramo, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Soak the beans overnight if they are dried.",
                    "Soften the leek and carrot in the oil for 6 minutes.",
                    "Add the beans, tomato and spices, cover with water and simmer for 30-35 minutes."
                ],
                reheat: "Reheat gently and add water if it has thickened too much."
            )
        ]
    }

    private static func cerealSeeds() -> [Seed] {
        [
            riceSeed(),
            Seed(
                id: "pasta",
                name: "Wholewheat pasta",
                keyword: "pasta",
                singular: "pasta",
                emoji: "🍝",
                category: .cereal,
                active: 2,
                total: 12,
                storage: 4,
                ingredients: [
                    ing("Wholewheat pasta", 75, .gramo, .cereales),
                    ing("Olive oil", 2, .mililitro, .despensa, pantry: true),
                    ing("Salt", 0.5, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Cook the pasta in salted water according to the packet (8-10 minutes).",
                    "Drain, cool slightly and toss with oil so it doesn't stick."
                ],
                reheat: "Sprinkle with water and reheat for 1 minute in the microwave."
            ),
            Seed(
                id: "couscous",
                name: "Couscous",
                keyword: "couscous",
                singular: "couscous",
                emoji: "🍚",
                category: .cereal,
                active: 5,
                total: 10,
                storage: 4,
                ingredients: [
                    ing("Wholewheat couscous", 70, .gramo, .cereales),
                    ing("Olive oil", 3, .mililitro, .despensa, pantry: true),
                    ing("Salt", 0.5, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Boil the same volume of water as couscous with a pinch of salt.",
                    "Pour over the couscous, cover and rest for 5 minutes.",
                    "Fluff with a fork and mix with the oil."
                ],
                reheat: "Steam or microwave with a splash of water to loosen it."
            ),
            Seed(
                id: "potatoes",
                name: "Boiled potatoes",
                keyword: "potatoes",
                singular: "potato",
                emoji: "🥔",
                category: .cereal,
                active: 10,
                total: 25,
                storage: 4,
                ingredients: [
                    ing("Potatoes", 200, .gramo, .verduras),
                    ing("Olive oil", 3, .mililitro, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Peel and cut the potatoes into chunks.",
                    "Boil in salted water for 15-18 minutes until tender.",
                    "Drain and drizzle with oil."
                ],
                reheat: "Reheat in the microwave or pan-fry for a couple of minutes."
            )
        ]
    }

    private static func riceSeed() -> Seed {
        Seed(
            id: "rice",
            name: "Basmati rice",
            keyword: "rice",
            singular: "rice",
            emoji: "🍚",
            category: .cereal,
            active: 5,
            total: 20,
            storage: 4,
            ingredients: [
                ing("Basmati rice", 70, .gramo, .cereales),
                ing("Olive oil", 2, .mililitro, .despensa, pantry: true),
                ing("Salt", 0.5, .gramo, .despensa, pantry: true)
            ],
            steps: [
                "Rinse the rice until the water runs clear.",
                "Toast for 1 minute in the oil, then add double the volume of water and salt.",
                "Cover and cook for 10 minutes, turn off and rest for 5 minutes. Fluff with a fork."
            ],
            reheat: "A splash of water and 1 minute in the microwave. Steam if you can."
        )
    }

    private static func proteinSeeds() -> [Seed] {
        [
            Seed(
                id: "chicken",
                name: "Roast chicken",
                keyword: "chicken",
                singular: "chicken",
                emoji: "🍗",
                category: .proteina,
                active: 10,
                total: 35,
                storage: 4,
                ingredients: [
                    ing("Chicken breast", 170, .gramo, .carnes),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Sweet paprika", 1, .gramo, .despensa, pantry: true),
                    ing("Rosemary", 0.5, .gramo, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Season the chicken with oil, paprika, rosemary and salt.",
                    "Roast at 200 °C for 25-30 minutes until cooked through.",
                    "Rest for 5 minutes and slice."
                ],
                reheat: "Reheat covered with a splash of water so it stays juicy."
            ),
            Seed(
                id: "turkey",
                name: "Turkey meatballs",
                keyword: "turkey",
                singular: "turkey",
                emoji: "🍗",
                category: .proteina,
                active: 15,
                total: 30,
                storage: 4,
                ingredients: [
                    ing("Minced turkey", 170, .gramo, .carnes),
                    ing("Egg", 0.5, .unidad, .lacteos),
                    ing("Breadcrumbs", 10, .gramo, .panaderia),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Mix the turkey with egg, breadcrumbs and salt.",
                    "Shape into small meatballs.",
                    "Brown in the oil for 10-12 minutes, turning often."
                ],
                reheat: "Reheat in a pan with a spoonful of tomato sauce."
            ),
            Seed(
                id: "salmon",
                name: "Baked salmon",
                keyword: "salmon",
                singular: "salmon",
                emoji: "🐟",
                category: .proteina,
                active: 5,
                total: 20,
                storage: 3,
                ingredients: [
                    ing("Salmon fillet", 170, .gramo, .pescados),
                    ing("Olive oil", 3, .mililitro, .despensa, pantry: true),
                    ing("Lemon", 0.25, .unidad, .frutas),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Place the salmon on baking paper and drizzle with oil and lemon.",
                    "Bake at 190 °C for 12-15 minutes.",
                    "Season with salt and rest."
                ],
                reheat: "Reheat gently, covered, so it doesn't dry out."
            ),
            Seed(
                id: "tofu",
                name: "Marinated tofu",
                keyword: "tofu",
                singular: "tofu",
                emoji: "🧈",
                category: .proteina,
                active: 10,
                total: 20,
                storage: 3,
                ingredients: [
                    ing("Firm tofu", 170, .gramo, .legumbres),
                    ing("Soy sauce", 10, .mililitro, .conservas, pantry: true),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Sweet paprika", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Press the tofu and cut it into cubes.",
                    "Marinate with soy sauce, oil and paprika for 10 minutes.",
                    "Pan-fry until golden on all sides."
                ],
                reheat: "Reheat in a pan for a couple of minutes."
            ),
            Seed(
                id: "seitan",
                name: "Roast seitan",
                keyword: "seitan",
                singular: "seitan",
                emoji: "🌾",
                category: .proteina,
                active: 10,
                total: 30,
                storage: 4,
                ingredients: [
                    ing("Seitan", 160, .gramo, .otros),
                    ing("Lemon", 0.25, .unidad, .frutas),
                    ing("Garlic", 0.5, .diente, .verduras),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Sweet paprika", 1, .gramo, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Cut the seitan into thick strips and pat dry.",
                    "Marinate with lemon, garlic, paprika, oil and salt.",
                    "Roast at 200 °C for 20-25 minutes, turning halfway."
                ],
                reheat: "Reheat covered for 2 minutes so it stays juicy."
            ),
            Seed(
                id: "beef",
                name: "Beef stew",
                keyword: "beef",
                singular: "beef",
                emoji: "🥩",
                category: .proteina,
                active: 15,
                total: 45,
                storage: 4,
                ingredients: [
                    ing("Stewing beef", 170, .gramo, .carnes),
                    ing("Onion", 40, .gramo, .verduras),
                    ing("Carrot", 40, .gramo, .verduras),
                    ing("Chopped tomatoes", 60, .gramo, .conservas),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Brown the beef in the oil.",
                    "Add the chopped onion, carrot and tomato.",
                    "Cover with water and simmer for 35-40 minutes until tender."
                ],
                reheat: "Reheat slowly with a little water or stock."
            )
        ]
    }

    private static func eggSeed() -> Seed {
        Seed(
            id: "eggs",
            name: "Boiled eggs",
            keyword: "eggs",
            singular: "egg",
            emoji: "🥚",
            category: .proteina,
            active: 2,
            total: 10,
            storage: 4,
            ingredients: [
                ing("Eggs", 2, .unidad, .lacteos),
                ing("Salt", 0.5, .gramo, .despensa, pantry: true)
            ],
            steps: [
                "Put the eggs in a pan of cold water.",
                "Boil for 9 minutes, then cool in iced water.",
                "Peel and store in the fridge."
            ],
            reheat: "No need to reheat; add to the plate at room temperature."
        )
    }

    private static func vegetableSeeds() -> [Seed] {
        [
            Seed(
                id: "roasted-vegetables",
                name: "Roasted vegetables",
                keyword: "roasted vegetables",
                singular: "roasted vegetables",
                emoji: "🥦",
                category: .verdura,
                active: 10,
                total: 30,
                storage: 4,
                ingredients: [
                    ing("Courgette", 100, .gramo, .verduras),
                    ing("Red pepper", 100, .gramo, .verduras),
                    ing("Onion", 60, .gramo, .verduras),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Cut the vegetables into similar pieces.",
                    "Toss with oil and salt and spread on a tray.",
                    "Roast at 200 °C for 20-25 minutes."
                ],
                reheat: "Reheat in the oven or a hot pan for a few minutes."
            ),
            Seed(
                id: "sauteed-vegetables",
                name: "Sautéed vegetables",
                keyword: "sautéed vegetables",
                singular: "sautéed vegetables",
                emoji: "🥕",
                category: .verdura,
                active: 12,
                total: 20,
                storage: 4,
                ingredients: [
                    ing("Green beans", 100, .gramo, .verduras),
                    ing("Carrot", 80, .gramo, .verduras),
                    ing("Garlic", 1, .diente, .verduras),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Cut the vegetables into small pieces.",
                    "Sauté the garlic in the oil, then add the vegetables.",
                    "Cook for 10-12 minutes, adding a splash of water."
                ],
                reheat: "Reheat in a pan for 2 minutes."
            )
        ]
    }

    private static func sauceSeeds() -> [Seed] {
        [
            tomatoSauceSeed(),
            Seed(
                id: "pepper-sauce",
                name: "Pepper sauce",
                keyword: "pepper sauce",
                singular: "pepper sauce",
                emoji: "🍅",
                category: .salsa,
                active: 8,
                total: 20,
                storage: 5,
                ingredients: [
                    ing("Roasted red peppers", 100, .gramo, .conservas),
                    ing("Garlic", 1, .diente, .verduras),
                    ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                    ing("Vinegar", 3, .mililitro, .despensa, pantry: true),
                    ing("Salt", 1, .gramo, .despensa, pantry: true)
                ],
                steps: [
                    "Drain the roasted peppers.",
                    "Blend with garlic, oil, vinegar and salt.",
                    "Cook gently for 8-10 minutes."
                ],
                reheat: "Warm gently or serve at room temperature."
            )
        ]
    }

    private static func tomatoSauceSeed() -> Seed {
        Seed(
            id: "tomato-sauce",
            name: "Tomato sauce",
            keyword: "tomato sauce",
            singular: "tomato sauce",
            emoji: "🍅",
            category: .salsa,
            active: 5,
            total: 15,
            storage: 5,
            ingredients: [
                ing("Chopped tomatoes", 100, .gramo, .conservas),
                ing("Onion", 30, .gramo, .verduras),
                ing("Garlic", 1, .diente, .verduras),
                ing("Olive oil", 5, .mililitro, .despensa, pantry: true),
                ing("Salt", 1, .gramo, .despensa, pantry: true)
            ],
            steps: [
                "Soften the chopped onion and garlic in the oil.",
                "Add the tomatoes and a pinch of salt.",
                "Simmer for 10 minutes until slightly reduced."
            ],
            reheat: "Warm gently; add a splash of water if it is too thick."
        )
    }
}
