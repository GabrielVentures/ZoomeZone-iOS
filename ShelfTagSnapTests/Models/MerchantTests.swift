//
//  MerchantTests.swift
//  ShelfTagSnapTests
//
//  Created by kent.sun on 2025/10/23.
//

import Testing
import Foundation
@testable import ShelfTagSnap

/// Unit tests for Merchant enumeration
struct MerchantTests {

    // MARK: - Enum Cases Tests

    @Test("所有商家 case / All merchant cases")
    func testAllCases() async throws {
        // When
        let allMerchants = Merchant.allCases

        // Then
        #expect(allMerchants.count == 4)
        #expect(allMerchants.contains(.walmart))
        #expect(allMerchants.contains(.target))
        #expect(allMerchants.contains(.costco))
        #expect(allMerchants.contains(.kroger))
    }

    @Test("rawValue 值 / rawValue values")
    func testRawValues() async throws {
        // Then
        #expect(Merchant.walmart.rawValue == "Walmart")
        #expect(Merchant.target.rawValue == "Target")
        #expect(Merchant.costco.rawValue == "Costco")
        #expect(Merchant.kroger.rawValue == "Kroger")
    }

    // MARK: - Identifiable Tests

    @Test("Identifiable ID / Identifiable conformance")
    func testIdentifiable() async throws {
        // Then - ID should equal rawValue
        #expect(Merchant.walmart.id == "Walmart")
        #expect(Merchant.target.id == "Target")
        #expect(Merchant.costco.id == "Costco")
        #expect(Merchant.kroger.id == "Kroger")
    }

    // MARK: - Display Name Tests

    @Test("显示名称 / Display names")
    func testDisplayNames() async throws {
        // Then
        #expect(Merchant.walmart.displayName == "Walmart")
        #expect(Merchant.target.displayName == "Target")
        #expect(Merchant.costco.displayName == "Costco")
        #expect(Merchant.kroger.displayName == "Kroger")
    }

    // MARK: - Icon Tests

    @Test("图标名称 / Icon names")
    func testIconNames() async throws {
        // Then - All should use "storefront" SF Symbol
        #expect(Merchant.walmart.iconName == "storefront")
        #expect(Merchant.target.iconName == "storefront")
        #expect(Merchant.costco.iconName == "storefront")
        #expect(Merchant.kroger.iconName == "storefront")
    }

    // MARK: - Color Tests

    @Test("主题颜色 / Theme colors")
    func testColorHex() async throws {
        // Then
        #expect(Merchant.walmart.colorHex == "#0071CE")  // Walmart Blue
        #expect(Merchant.target.colorHex == "#CC0000")   // Target Red
        #expect(Merchant.costco.colorHex == "#0060A9")   // Costco Blue
        #expect(Merchant.kroger.colorHex == "#004C97")   // Kroger Blue
    }

    @Test("颜色格式验证 / Color format validation")
    func testColorHexFormat() async throws {
        // Given
        let hexPattern = "^#[0-9A-F]{6}$"

        // When & Then
        for merchant in Merchant.allCases {
            let colorHex = merchant.colorHex
            let range = colorHex.range(of: hexPattern, options: .regularExpression)
            #expect(range != nil, "Color \(colorHex) for \(merchant.displayName) should match hex format")
        }
    }

    // MARK: - Factory Method Tests

    @Test("从字符串创建商家 - 成功 / Create from string - success")
    func testFromStringSuccess() async throws {
        // When & Then
        #expect(Merchant.from("Walmart") == .walmart)
        #expect(Merchant.from("Target") == .target)
        #expect(Merchant.from("Costco") == .costco)
        #expect(Merchant.from("Kroger") == .kroger)
    }

    @Test("从字符串创建商家 - 失败 / Create from string - failure")
    func testFromStringFailure() async throws {
        // When & Then - Non-existent merchant
        #expect(Merchant.from("Amazon") == nil)
        #expect(Merchant.from("Whole Foods") == nil)
        #expect(Merchant.from("") == nil)
        #expect(Merchant.from("walmart") == nil) // Case sensitive
    }

    @Test("获取所有显示名称 / Get all display names")
    func testAllDisplayNames() async throws {
        // When
        let displayNames = Merchant.allDisplayNames

        // Then
        #expect(displayNames.count == 4)
        #expect(displayNames.contains("Walmart"))
        #expect(displayNames.contains("Target"))
        #expect(displayNames.contains("Costco"))
        #expect(displayNames.contains("Kroger"))
    }

    @Test("显示名称顺序 / Display names order")
    func testAllDisplayNamesOrder() async throws {
        // When
        let displayNames = Merchant.allDisplayNames

        // Then - Should match allCases order
        #expect(displayNames[0] == "Walmart")
        #expect(displayNames[1] == "Target")
        #expect(displayNames[2] == "Costco")
        #expect(displayNames[3] == "Kroger")
    }

    // MARK: - Codable Tests

    @Test("JSON 编码 / JSON encoding")
    func testEncoding() async throws {
        // Given
        let merchant = Merchant.walmart

        // When
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(merchant)
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Then
        #expect(jsonString == "\"Walmart\"")
    }

    @Test("JSON 解码 / JSON decoding")
    func testDecoding() async throws {
        // Given
        let jsonString = "\"Target\""
        let jsonData = jsonString.data(using: .utf8)!

        // When
        let decoder = JSONDecoder()
        let merchant = try decoder.decode(Merchant.self, from: jsonData)

        // Then
        #expect(merchant == .target)
    }

    @Test("编码所有商家 / Encode all merchants")
    func testEncodeAllMerchants() async throws {
        // Given
        let merchants = Merchant.allCases

        // When
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(merchants)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Then
        #expect(jsonString.contains("Walmart"))
        #expect(jsonString.contains("Target"))
        #expect(jsonString.contains("Costco"))
        #expect(jsonString.contains("Kroger"))
    }

    @Test("解码无效商家名称 / Decode invalid merchant")
    func testDecodeInvalid() async throws {
        // Given
        let invalidJSON = "\"InvalidMerchant\""
        let jsonData = invalidJSON.data(using: .utf8)!

        // When & Then
        let decoder = JSONDecoder()
        #expect(throws: Error.self) {
            _ = try decoder.decode(Merchant.self, from: jsonData)
        }
    }

    // MARK: - Comparison Tests

    @Test("枚举相等性 / Enum equality")
    func testEquality() async throws {
        // Given
        let merchant1 = Merchant.walmart
        let merchant2 = Merchant.walmart
        let merchant3 = Merchant.target

        // Then
        #expect(merchant1 == merchant2)
        #expect(merchant1 != merchant3)
    }

    // MARK: - Integration Tests

    @Test("在数组中使用 / Use in array")
    func testInArray() async throws {
        // Given
        let merchants: [Merchant] = [.walmart, .target, .costco]

        // Then
        #expect(merchants.count == 3)
        #expect(merchants.contains(.walmart))
        #expect(!merchants.contains(.kroger))
    }

    @Test("在字典中使用 / Use in dictionary")
    func testInDictionary() async throws {
        // Given
        let storeLocations: [Merchant: String] = [
            .walmart: "123 Main St",
            .target: "456 Oak Ave",
            .costco: "789 Pine Rd"
        ]

        // Then
        #expect(storeLocations[.walmart] == "123 Main St")
        #expect(storeLocations[.target] == "456 Oak Ave")
        #expect(storeLocations[.kroger] == nil)
    }

    @Test("在 Set 中使用 / Use in set")
    func testInSet() async throws {
        // Given
        let merchantSet: Set<Merchant> = [.walmart, .target, .walmart, .target]

        // Then - Duplicates should be removed
        #expect(merchantSet.count == 2)
        #expect(merchantSet.contains(.walmart))
        #expect(merchantSet.contains(.target))
    }

    // MARK: - Edge Cases

    @Test("大小写敏感性 / Case sensitivity")
    func testCaseSensitivity() async throws {
        // When & Then - from() method is case-sensitive
        #expect(Merchant.from("walmart") == nil)
        #expect(Merchant.from("WALMART") == nil)
        #expect(Merchant.from("Walmart") == .walmart)
        #expect(Merchant.from("WalMart") == nil)
    }

    @Test("空字符串和空白字符 / Empty and whitespace strings")
    func testEmptyAndWhitespace() async throws {
        // When & Then
        #expect(Merchant.from("") == nil)
        #expect(Merchant.from(" ") == nil)
        #expect(Merchant.from("  Walmart  ") == nil) // No trimming
    }

    @Test("Switch 语句完整性 / Switch statement exhaustiveness")
    func testSwitchExhaustiveness() async throws {
        // Given
        var results: [String] = []

        // When - Switch over all cases
        for merchant in Merchant.allCases {
            let description: String
            switch merchant {
            case .walmart:
                description = "Walmart"
            case .target:
                description = "Target"
            case .costco:
                description = "Costco"
            case .kroger:
                description = "Kroger"
            }
            results.append(description)
        }

        // Then
        #expect(results.count == 4)
        #expect(results == ["Walmart", "Target", "Costco", "Kroger"])
    }
}
