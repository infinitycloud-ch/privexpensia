import Foundation

// MARK: - TVA Calculator
class TVACalculator {
    static let shared = TVACalculator()
    
    private var tvaConfig: TVAConfiguration?
    
    private init() {
        loadTVAConfiguration()
    }
    
    // MARK: - Configuration Loading
    private func loadTVAConfiguration() {
        guard let url = Bundle.main.url(forResource: "TVAConfig", 
                                       withExtension: "json",
                                       subdirectory: "resources") else {
            loadDefaultConfiguration()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            tvaConfig = try JSONDecoder().decode(TVAConfiguration.self, from: data)
        } catch {
            loadDefaultConfiguration()
        }
    }
    
    private func loadDefaultConfiguration() {
        // Fallback configuration
        tvaConfig = TVAConfiguration(
            version: "1.0.0",
            lastUpdated: "2025-01-11",
            countries: [
                "CH": CountryVAT(
                    name: "Switzerland",
                    currency: "CHF",
                    vatRates: VATRates(
                        standard: 8.1,
                        reduced: 2.5,
                        accommodation: 3.7,
                        special: 2.5
                    ),
                    categories: [
                        "food": CategoryVAT(rate: 2.5, type: "reduced", description: "Basic food items"),
                        "restaurant": CategoryVAT(rate: 8.1, type: "standard", description: "Restaurant services"),
                        "hotel": CategoryVAT(rate: 3.7, type: "accommodation", description: "Hotel accommodation")
                    ],
                    registrationThreshold: 100000,
                    exceptions: []
                )
            ]
        )
    }
    
    // MARK: - VAT Calculation
    func calculateVAT(
        amount: Double,
        country: String,
        category: String,
        isInclusive: Bool = true
    ) -> VATCalculation {
        
        let countryCode = detectCountryCode(from: country)
        guard let countryVAT = tvaConfig?.countries[countryCode] else {
            return VATCalculation(
                grossAmount: amount,
                netAmount: amount,
                vatAmount: 0,
                vatRate: 0,
                country: countryCode,
                category: category
            )
        }
        
        let vatRate = getVATRate(for: category, in: countryVAT)
        
        if isInclusive {
            // Amount includes VAT
            let netAmount = amount / (1 + vatRate / 100)
            let vatAmount = amount - netAmount
            
            return VATCalculation(
                grossAmount: amount,
                netAmount: netAmount,
                vatAmount: vatAmount,
                vatRate: vatRate,
                country: countryCode,
                category: category
            )
        } else {
            // Amount excludes VAT
            let vatAmount = amount * (vatRate / 100)
            let grossAmount = amount + vatAmount
            
            return VATCalculation(
                grossAmount: grossAmount,
                netAmount: amount,
                vatAmount: vatAmount,
                vatRate: vatRate,
                country: countryCode,
                category: category
            )
        }
    }
    
    // MARK: - Country Detection
    func detectCountryFromText(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        // Check for currency symbols
        if text.contains("CHF") || text.contains("Fr.") {
            return "CH"
        } else if text.contains("€") || text.contains("EUR") {
            if lowercased.contains("deutschland") || lowercased.contains("germany") {
                return "DE"
            } else if lowercased.contains("france") || lowercased.contains("paris") {
                return "FR"
            }
            return "FR" // Default EUR country
        } else if text.contains("$") || text.contains("USD") {
            return "US"
        } else if text.contains("¥") || text.contains("JPY") {
            return "JP"
        }
        
        // Check for country-specific keywords
        let countryKeywords = [
            "CH": ["suisse", "switzerland", "schweiz", "svizzera", "genève", "zurich", "basel"],
            "DE": ["deutschland", "germany", "berlin", "münchen", "hamburg"],
            "FR": ["france", "paris", "lyon", "marseille"],
            "JP": ["japan", "tokyo", "osaka", "kyoto"],
            "US": ["usa", "united states", "america", "new york", "california"]
        ]
        
        for (country, keywords) in countryKeywords {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    return country
                }
            }
        }
        
        // Default to Switzerland (app's primary market)
        return "CH"
    }
    
    private func detectCountryCode(from country: String) -> String {
        // If already a code
        if country.count == 2 && country == country.uppercased() {
            return country
        }
        
        // Map country names to codes
        let countryMap = [
            "switzerland": "CH",
            "suisse": "CH",
            "schweiz": "CH",
            "germany": "DE",
            "deutschland": "DE",
            "france": "FR",
            "japan": "JP",
            "united states": "US",
            "usa": "US"
        ]
        
        return countryMap[country.lowercased()] ?? "CH"
    }
    
    // MARK: - Category Detection (Swiss-optimized)
    // Returns categories matching Constants.Categories.all
    func detectCategoryFromText(_ text: String) -> String {
        let lowercased = text.lowercased()

        // Categories aligned with Constants.Categories.all - order matters (first match wins)
        // More specific patterns checked first to avoid false positives
        let categoryKeywords: [(category: String, keywords: [String])] = [
            // RESTAURANT - specific restaurant keywords first (before Coffee/Groceries)
            ("Restaurant", [
                "restaurant", "bistro", "brasserie", "pizzeria", "trattoria",
                "mcdonald", "burger king", "subway", "five guys", "holy cow", "kfc",
                "beiz", "wirtschaft", "gasthof", "stübli", "fondue", "raclette",
                "bar", "pub", "taverne", "buvette", "grill"
            ]),

            // COFFEE - specific coffee shops (before generic cafe)
            ("Coffee", [
                "starbucks", "espresso bar", "tea room", "salon de thé"
            ]),

            // GROCERIES - supermarkets and food stores
            ("Groceries", [
                "migros", "coop", "denner", "aldi", "lidl", "spar", "volg",
                "migrolino", "coop pronto", "avec", "k kiosk",
                "boulangerie", "bäckerei", "panetteria", "back-factory", "brezelkönig",
                "boucherie", "metzgerei", "primeur",
                "supermarché", "supermarkt", "grocery", "épicerie", "lebensmittel"
            ]),

            // GAS - fuel stations
            ("Gas", [
                "essence", "benzin", "diesel", "shell", "bp", "avia", "migrol", "agrola",
                "coop mineralöl", "esso", "total"
            ]),

            // TRANSPORT - public transport, taxis, parking
            ("Transport", [
                "sbb", "cff", "ffs", "tpg", "tl", "bls", "vbz", "bernmobil",
                "uber", "taxi", "bolt", "lyft",
                "parking", "parkhaus", "parkplatz",
                "bus", "train", "metro", "tram"
            ]),

            // SHOPPING - retail stores
            ("Shopping", [
                "manor", "globus", "jelmoli", "loeb", "pfister",
                "digitec", "galaxus", "mediamarkt", "fust", "interdiscount",
                "h&m", "zara", "c&a", "ikea", "decathlon",
                "jumbo", "hornbach", "obi",
                "boutique", "magasin", "geschäft", "laden"
            ]),

            // BILLS - utilities and telecom
            ("Bills", [
                "swisscom", "sunrise", "salt", "wingo", "yallo",
                "electric", "water", "internet", "téléphone", "telefon"
            ]),

            // ENTERTAINMENT - leisure activities
            ("Entertainment", [
                "cinema", "cinéma", "kino", "pathé",
                "theater", "théâtre", "opéra", "concert",
                "museum", "musée", "exposition",
                "fitness", "gym", "piscine", "wellness", "spa",
                "zoo", "parc"
            ]),

            // COFFEE - generic cafe keywords (could be coffee or restaurant)
            ("Coffee", [
                "café", "cafe", "coffee", "kaffee", "espresso"
            ]),

            // ⚠️ HEALTH - EN DERNIER (catégorie rare, ne doit jamais prendre le dessus)
            // Seulement si c'est VRAIMENT une pharmacie/hôpital
            ("Health", [
                "amavita", "sunstore", "coop vitality", "dropa", "toppharm", "benu",
                "pharmacy", "pharmacie", "apotheke", "farmacia",
                "doctor", "médecin", "arzt", "praxis",
                "hospital", "hôpital", "spital", "clinique", "klinik",
                "dentiste", "zahnarzt", "optique", "optiker"
            ])
        ]

        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    return category
                }
            }
        }

        return "Other"
    }
    
    // MARK: - Helper Methods
    private func getVATRate(for category: String, in countryVAT: CountryVAT) -> Double {
        if let categoryVAT = countryVAT.categories[category] {
            return categoryVAT.rate
        }
        
        // Default to standard rate
        return countryVAT.vatRates.standard
    }
    
    func getAvailableCountries() -> [String] {
        guard let countries = tvaConfig?.countries else { return [] }
        return Array(countries.keys).sorted()
    }
    
    func getCountryName(_ code: String) -> String {
        return tvaConfig?.countries[code]?.name ?? code
    }
    
    func getCategoriesForCountry(_ countryCode: String) -> [String] {
        guard let country = tvaConfig?.countries[countryCode] else {
            return []
        }
        return Array(country.categories.keys).sorted()
    }
}

// MARK: - Data Models
struct TVAConfiguration: Codable {
    let version: String
    let lastUpdated: String
    let countries: [String: CountryVAT]
}

struct CountryVAT: Codable {
    let name: String
    let currency: String
    let vatRates: VATRates
    let categories: [String: CategoryVAT]
    let registrationThreshold: Double?
    let exceptions: [String]?
}

struct VATRates: Codable {
    let standard: Double
    let reduced: Double?
    let accommodation: Double?
    let special: Double?
}

struct CategoryVAT: Codable {
    let rate: Double
    let type: String
    let description: String
}

struct VATCalculation {
    let grossAmount: Double
    let netAmount: Double
    let vatAmount: Double
    let vatRate: Double
    let country: String
    let category: String
    
    var formattedVATRate: String {
        return String(format: "%.1f%%", vatRate)
    }
    
    var formattedVATAmount: String {
        return String(format: "%.2f", vatAmount)
    }
    
    var formattedNetAmount: String {
        return String(format: "%.2f", netAmount)
    }
    
    var formattedGrossAmount: String {
        return String(format: "%.2f", grossAmount)
    }
}