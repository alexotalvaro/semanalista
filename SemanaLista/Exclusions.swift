import Foundation

/// Lista de ingredientes que el usuario no quiere ver en el menú.
/// Acepta texto libre separado por comas, punto y coma, barras o saltos de línea
/// ("lentejas, arroz, pollo"), prefijos tipo "sin " y familias completas
/// ("carne", "pescado", "lácteos", "gluten", "frutos secos").
struct IngredientExclusions: Equatable {
    /// Términos tal y como los escribió el usuario (limpios y sin duplicados).
    let terms: [String]

    private let matchers: [[String]]

    init(allergies: String, dislikes: String) {
        self.init(rawText: [allergies, dislikes].joined(separator: ","))
    }

    init(rawText: String) {
        let parsed = Self.parse(rawText)
        terms = parsed

        var seen = Set<String>()
        var matchers: [[String]] = []
        for term in parsed {
            for expanded in Self.expand(term) {
                let words = Self.words(expanded)
                guard !words.isEmpty else { continue }
                let key = words.joined(separator: " ")
                if seen.insert(key).inserted {
                    matchers.append(words)
                }
            }
        }
        self.matchers = matchers
    }

    var isEmpty: Bool { matchers.isEmpty }

    /// Texto listo para mostrar en ajustes o meter en el prompt de la IA.
    var promptList: String {
        terms.joined(separator: ", ")
    }

    /// ¿Este nombre de ingrediente o de preparación está excluido?
    func excludes(_ name: String) -> Bool {
        let nameWords = Self.words(name)
        guard !nameWords.isEmpty else { return false }

        for matcher in matchers {
            if matcher.allSatisfy({ term in nameWords.contains { Self.wordMatches($0, term) } }) {
                return true
            }
        }
        return false
    }

    /// Nombres encontrados en una lista de ingredientes.
    func conflicts(in ingredients: [Ingredient]) -> [String] {
        ingredients.filter { excludes($0.name) }.map(\.name)
    }

    // MARK: - Interpretación del texto

    private static let stopWords: Set<String> = [
        "nada", "ninguno", "ninguna", "ningun", "todo", "todos", "sin", "no", "evitar", "quitar",
        "nothing", "none", "no", "all", "everything", "avoid", "remove", "without"
    ]

    private static let prefixes = [
        "no me gustan ", "no me gusta ", "me disgustan ", "me disgusta ",
        "intolerancia a ", "intolerante a ", "alergia a ", "alergia al ",
        "alergico a ", "alergica a ",
        "nada de ", "nada en ",
        "intolerancia ", "alergico ", "alergica ", "alergia ",
        "evitar ", "quitar ", "sin ", "no ",
        "unos ", "unas ", "los ", "las ", "el ", "la ", "un ", "una ", "al ",
        "i don't like ", "i dont like ", "i dislike ", "allergic to ",
        "intolerance to ", "intolerant to ", "no ", "without ", "avoid ", "remove "
    ]

    private static func parse(_ text: String) -> [String] {
        var cleaned = text
        cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
        cleaned = cleaned.replacingOccurrences(
            of: "\\s+y\\s+",
            with: ",",
            options: [.regularExpression, .caseInsensitive]
        )

        let separators = CharacterSet(charactersIn: ",;\n/|·•*")
        var result: [String] = []
        var seen = Set<String>()

        for piece in cleaned.components(separatedBy: separators) {
            var term = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            term = term.trimmingCharacters(in: CharacterSet(charactersIn: "-–—+ "))
            term = term.replacingOccurrences(of: "\\([^)]*\\)", with: " ", options: .regularExpression)
            term = term.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            term = term.trimmingCharacters(in: .whitespacesAndNewlines)

            var keepStripping = true
            while keepStripping {
                keepStripping = false
                let folded = normalize(term)
                for prefix in prefixes where folded.hasPrefix(prefix) {
                    term = String(term.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    keepStripping = true
                    break
                }
            }

            let folded = normalize(term)
            guard term.count >= 2, !stopWords.contains(folded) else { continue }
            guard seen.insert(folded).inserted else { continue }
            result.append(term)
        }
        return result
    }

    // MARK: - Familias de ingredientes

    /// Al escribir una familia ("carne") se excluyen también sus variantes habituales.
    /// Cada clave debe aparecer UNA sola vez: un literal de diccionario con claves
    /// duplicadas provoca un trap en tiempo de ejecución en Swift (Debug).
    private static let aliases: [String: [String]] = [
        "carne": ["pollo", "pavo", "ternera", "cerdo", "cordero", "conejo", "jamon", "chorizo", "bacon", "panceta", "carne picada"],
        "pescado": ["atun", "salmon", "merluza", "bacalao", "sardina", "lubina", "dorada", "trucha", "boqueron", "pescado"],
        "marisco": ["gamba", "langostino", "mejillon", "almeja", "calamar", "pulpo", "berberecho", "marisco"],
        "fruto seco": ["nuez", "almendra", "cacahuete", "avellana", "pistacho", "anacardo", "pinon", "fruto seco"],
        "lacteo": ["leche", "queso", "yogur", "mantequilla", "nata", "crema", "lacteo"],
        "lactosa": ["leche", "queso", "yogur", "mantequilla", "nata", "crema", "lacteo"],
        "gluten": ["pan", "pasta", "harina", "trigo", "cebada", "centeno", "cuscus", "gluten", "bread", "flour", "wheat", "barley", "rye", "couscous"],
        "huevo": ["huevo"],
        "legumbre": ["lenteja", "garbanzo", "alubia", "guisante", "judion", "legumbre"],
        "cereal": ["arroz", "pasta", "pan", "harina", "cuscus", "quinoa", "avena", "cereal", "rice", "bread", "flour", "couscous", "oats", "grain"],
        "verdura": ["calabacin", "berenjena", "pimiento", "cebolla", "zanahoria", "judia", "brocoli", "champinon", "tomate", "lechuga", "verdura", "courgette", "zucchini", "eggplant", "aubergine", "pepper", "onion", "carrot", "green bean", "broccoli", "mushroom", "tomato", "lettuce", "vegetable"],
        "fruta": ["limon", "manzana", "platano", "naranja", "aguacate", "fresa", "fruta", "lemon", "apple", "banana", "orange", "avocado", "strawberry", "fruit"],
        "meat": ["chicken", "turkey", "beef", "pork", "lamb", "rabbit", "ham", "chorizo", "bacon", "pancetta", "minced meat"],
        "pork": ["pork", "ham", "chorizo", "bacon", "pancetta"],
        "fish": ["tuna", "salmon", "cod", "sardine", "sea bass", "sea bream", "trout", "anchovy", "fish"],
        "seafood": ["prawn", "shrimp", "mussel", "clam", "squid", "octopus", "seafood"],
        "nut": ["walnut", "almond", "peanut", "hazelnut", "pistachio", "cashew", "pine nut", "nut"],
        "dairy": ["milk", "cheese", "yogurt", "yoghurt", "butter", "cream", "dairy"],
        "lactose": ["milk", "cheese", "yogurt", "yoghurt", "butter", "cream", "dairy"],
        "egg": ["egg"],
        "legume": ["lentil", "chickpea", "bean", "pea", "legume"]
    ]

    private static func expand(_ term: String) -> [String] {
        var values = [term]
        for key in aliasKeys(term) {
            values.append(contentsOf: aliases[key] ?? [])
        }
        return values
    }

    /// Prueba las dos formas habituales de singular ("legumbres" → "legumbre",
    /// "cereales" → "cereal") porque el castellano no es regular.
    private static func aliasKeys(_ term: String) -> [String] {
        let original = words(term)
        guard !original.isEmpty else { return [] }

        var variants: [String] = [original.joined(separator: " ")]

        let dropS = original.map { word -> String in
            word.hasSuffix("s") && word.count > 3 ? String(word.dropLast()) : word
        }
        let dropES = original.map { word -> String in
            word.hasSuffix("es") && word.count > 4 ? String(word.dropLast(2)) : word
        }

        for variant in [dropS.joined(separator: " "), dropES.joined(separator: " ")] where !variants.contains(variant) {
            variants.append(variant)
        }
        return variants
    }

    // MARK: - Normalización y comparación

    static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
            .lowercased()
    }

    private static func words(_ text: String) -> [String] {
        normalize(text)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func singular(_ word: String) -> String {
        if word.count > 4, word.hasSuffix("es") { return String(word.dropLast(2)) }
        if word.count > 3, word.hasSuffix("s") { return String(word.dropLast()) }
        return word
    }

    private static func wordMatches(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        if singular(lhs) == singular(rhs) { return true }
        // "nuez"/"nueces", "pez"/"peces": la z pasa a c en plural.
        let lhsFolded = lhs.replacingOccurrences(of: "z", with: "c")
        let rhsFolded = rhs.replacingOccurrences(of: "z", with: "c")
        if lhsFolded != lhs || rhsFolded != rhs {
            if lhsFolded == rhsFolded || singular(lhsFolded) == singular(rhsFolded) { return true }
        }
        guard min(lhs.count, rhs.count) >= 4 else { return false }
        return lhs.hasPrefix(rhs) || rhs.hasPrefix(lhs)
    }
}
