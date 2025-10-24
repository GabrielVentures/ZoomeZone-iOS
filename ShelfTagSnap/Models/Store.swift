//
//  Store.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation

/// Store model for store selection
struct Store: Identifiable, Codable, Hashable {
    // MARK: - Properties

    let id: String
    let name: String
    let category: String  // Letter category for alphabetical grouping

    // MARK: - Initialization

    init(id: String, name: String, category: String) {
        self.id = id
        self.name = name
        self.category = category
    }

    init(name: String) {
        self.id = UUID().uuidString
        self.name = name
        // Auto-determine category from first letter
        if let firstChar = name.first {
            if firstChar.isLetter {
                self.category = String(firstChar.uppercased())
            } else {
                self.category = "#"
            }
        } else {
            self.category = "#"
        }
    }
}

// MARK: - Sample Data

extension Store {

    /// All predefined stores
    static let allStores: [Store] = [
        // #
        Store(name: "7-Eleven"),
        Store(name: "99 Cents Only Stores"),
        Store(name: "99 Ranch Market"),

        // A
        Store(name: "ABC Fine Wine & Spirits"),
        Store(name: "Acme Fresh Market"),
        Store(name: "Acme Markets"),
        Store(name: "Albertsons"),
        Store(name: "ALDI"),
        Store(name: "ARCO"),
        Store(name: "Asda"),
        Store(name: "Associated Supermarkets"),

        // B
        Store(name: "Baker's Supermarkets"),
        Store(name: "Bashas' Supermarkets"),
        Store(name: "Best Buy"),
        Store(name: "BevMo!"),
        Store(name: "Big Lots"),
        Store(name: "Big Y"),
        Store(name: "Bimart"),
        Store(name: "BJ's Wholesale Club"),
        Store(name: "Brookshire Brothers"),
        Store(name: "Brookshire Grocery Company"),

        // C
        Store(name: "Cardenas Markets"),
        Store(name: "Carrefour"),
        Store(name: "Casey's General Store"),
        Store(name: "Circle K"),
        Store(name: "City Market"),
        Store(name: "Coborn's"),
        Store(name: "Coles"),
        Store(name: "Costco"),
        Store(name: "Cub Foods"),
        Store(name: "CVS Pharmacy"),

        // D
        Store(name: "Dillons"),
        Store(name: "Dollar General"),
        Store(name: "Dollar Tree"),
        Store(name: "Duane Reade"),

        // E
        Store(name: "El Super"),

        // F
        Store(name: "Family Dollar"),
        Store(name: "Family Fare"),
        Store(name: "FamilyMart"),
        Store(name: "Farm Fresh"),
        Store(name: "Festival Foods"),
        Store(name: "Food 4 Less"),
        Store(name: "Food City"),
        Store(name: "Food Lion"),
        Store(name: "FoodMaxx"),
        Store(name: "Foodtown"),
        Store(name: "Fred Meyer"),
        Store(name: "Fresh Thyme Farmers Market"),
        Store(name: "Fry's Food and Drug"),

        // G
        Store(name: "Giant Eagle"),
        Store(name: "Giant Food"),
        Store(name: "Gordon Food Service"),
        Store(name: "Grand Union"),

        // H
        Store(name: "H-E-B"),
        Store(name: "Haggen"),
        Store(name: "Hannaford"),
        Store(name: "Harris Teeter"),
        Store(name: "Hy-Vee"),

        // I
        Store(name: "Ingles Markets"),

        // J
        Store(name: "Jewel-Osco"),

        // K
        Store(name: "King Kullen"),
        Store(name: "King Soopers"),
        Store(name: "Kmart"),
        Store(name: "Kroger"),

        // L
        Store(name: "Lawson"),
        Store(name: "Lidl"),
        Store(name: "Lucky Supermarkets"),

        // M
        Store(name: "Mariano's"),
        Store(name: "Market Basket"),
        Store(name: "Marsh Supermarkets"),
        Store(name: "Meijer"),
        Store(name: "Metro Market"),

        // N
        Store(name: "Northgate González Market"),

        // P
        Store(name: "Pavilions"),
        Store(name: "Pick 'n Save"),
        Store(name: "Piggly Wiggly"),
        Store(name: "Price Chopper"),
        Store(name: "Publix"),

        // Q
        Store(name: "QFC"),

        // R
        Store(name: "Ralphs"),
        Store(name: "Raley's"),
        Store(name: "Rite Aid"),

        // S
        Store(name: "Safeway"),
        Store(name: "Sam's Club"),
        Store(name: "Save Mart"),
        Store(name: "ShopRite"),
        Store(name: "Smart & Final"),
        Store(name: "Smith's Food and Drug"),
        Store(name: "Sprouts Farmers Market"),
        Store(name: "Stater Bros."),
        Store(name: "Stop & Shop"),

        // T
        Store(name: "Target"),
        Store(name: "Tesco"),
        Store(name: "The Fresh Market"),
        Store(name: "Tops Friendly Markets"),
        Store(name: "Trader Joe's"),

        // W
        Store(name: "Walgreens"),
        Store(name: "Walmart"),
        Store(name: "Wegmans"),
        Store(name: "Weis Markets"),
        Store(name: "Whole Foods Market"),
        Store(name: "Winn-Dixie"),
        Store(name: "WinCo Foods"),
        Store(name: "Woolworths")
    ]

    /// Stores grouped by first letter
    static var groupedStores: [String: [Store]] {
        Dictionary(grouping: allStores) { $0.category }
    }

    /// All categories (sorted alphabetically)
    static var allCategories: [String] {
        let categories = Set(allStores.map { $0.category })
        return categories.sorted { category1, category2 in
            // # comes first, then alphabetical
            if category1 == "#" { return true }
            if category2 == "#" { return false }
            return category1 < category2
        }
    }

    /// Search stores by name

    static func searchStores(query: String) -> [Store] {
        if query.isEmpty {
            return allStores
        }

        let lowercasedQuery = query.lowercased()
        return allStores.filter { store in
            store.name.lowercased().contains(lowercasedQuery)
        }
    }
}

// MARK: - Conversion to Merchant

extension Store {

    /// Convert to Merchant (for backward compatibility)
    var asMerchant: Merchant? {
        return Merchant.allCases.first { merchant in
            merchant.displayName.lowercased() == name.lowercased()
        }
    }

    /// Create Store from Merchant

    static func from(merchant: Merchant) -> Store {
        return Store(name: merchant.displayName)
    }
}
