//
//  UserTests.swift
//  ShelfTagSnapTests
//
//  Created by kent.sun on 2025/10/23.
//

import Testing
import Foundation
@testable import ShelfTagSnap

/// Unit tests for User model
struct UserTests {

    // MARK: - Initialization Tests

    @Test("创建用户 / Create user")
    func testUserCreation() async throws {
        // Given
        let id = "user123"
        let email = "test@example.com"
        let displayName = "Test User"

        // When
        let user = User(id: id, email: email, displayName: displayName)

        // Then
        #expect(user.id == id)
        #expect(user.email == email)
        #expect(user.displayName == displayName)
        #expect(user.createdAt <= Date()) // Should be created at or before now
    }

    @Test("创建无显示名称的用户 / Create user without display name")
    func testUserCreationWithoutDisplayName() async throws {
        // Given
        let id = "user456"
        let email = "noreply@example.com"

        // When
        let user = User(id: id, email: email, displayName: nil)

        // Then
        #expect(user.id == id)
        #expect(user.email == email)
        #expect(user.displayName == nil)
    }

    // MARK: - Computed Properties Tests

    @Test("用户名 - 使用 displayName / Username - with displayName")
    func testUsernameWithDisplayName() async throws {
        // Given
        let user = User(
            id: "user1",
            email: "john.doe@example.com",
            displayName: "John Doe"
        )

        // When
        let username = user.username

        // Then
        #expect(username == "John Doe")
    }

    @Test("用户名 - 无 displayName 使用邮箱前缀 / Username - fallback to email prefix")
    func testUsernameWithoutDisplayName() async throws {
        // Given
        let user = User(
            id: "user2",
            email: "jane.smith@example.com",
            displayName: nil
        )

        // When
        let username = user.username

        // Then
        #expect(username == "jane.smith")
    }

    @Test("用户名 - 邮箱格式异常时使用完整邮箱 / Username - fallback to full email")
    func testUsernameWithInvalidEmail() async throws {
        // Given - Email without @ symbol
        let user = User(
            id: "user3",
            email: "invalidemail",
            displayName: nil
        )

        // When
        let username = user.username

        // Then
        #expect(username == "invalidemail")
    }

    @Test("格式化创建时间 / Formatted creation time")
    func testFormattedCreatedAt() async throws {
        // Given
        let user = User(
            id: "user1",
            email: "test@example.com",
            displayName: "Test"
        )

        // When
        let formatted = user.formattedCreatedAt

        // Then
        #expect(!formatted.isEmpty)
        // Should contain date components
        #expect(formatted.contains(",") || formatted.contains("/") || formatted.contains("-"))
    }

    // MARK: - Factory Method Tests

    @Test("从 Firebase UID 创建用户 / Create from Firebase UID")
    func testFromFirebaseUser() async throws {
        // Given
        let firebaseUID = "firebase_abc123"
        let email = "firebase@example.com"
        let displayName = "Firebase User"

        // When
        let user = User.from(
            firebaseUID: firebaseUID,
            email: email,
            displayName: displayName
        )

        // Then
        #expect(user.id == firebaseUID)
        #expect(user.email == email)
        #expect(user.displayName == displayName)
    }

    @Test("从 Firebase 创建无显示名称的用户 / Create from Firebase without display name")
    func testFromFirebaseUserWithoutDisplayName() async throws {
        // Given
        let firebaseUID = "firebase_xyz789"
        let email = "anonymous@example.com"

        // When
        let user = User.from(
            firebaseUID: firebaseUID,
            email: email,
            displayName: nil
        )

        // Then
        #expect(user.id == firebaseUID)
        #expect(user.email == email)
        #expect(user.displayName == nil)
        #expect(user.username == "anonymous") // Should use email prefix
    }

    // MARK: - Codable Tests

    @Test("JSON 编码和解码 / JSON encoding and decoding")
    func testCodable() async throws {
        // Given
        let originalUser = User(
            id: "encode_test_123",
            email: "encode@example.com",
            displayName: "Encode Test"
        )

        // When - Encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(originalUser)

        // When - Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedUser = try decoder.decode(User.self, from: jsonData)

        // Then
        #expect(decodedUser.id == originalUser.id)
        #expect(decodedUser.email == originalUser.email)
        #expect(decodedUser.displayName == originalUser.displayName)
        // Allow small time difference due to encoding/decoding
        let timeDifference = abs(decodedUser.createdAt.timeIntervalSince(originalUser.createdAt))
        #expect(timeDifference < 1.0)
    }

    @Test("编码后的 JSON 结构 / Encoded JSON structure")
    func testEncodedJSONStructure() async throws {
        // Given
        let user = User(
            id: "struct_test",
            email: "struct@example.com",
            displayName: "Struct Test"
        )

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(user)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Then
        #expect(jsonString.contains("\"id\""))
        #expect(jsonString.contains("\"email\""))
        #expect(jsonString.contains("\"displayName\""))
        #expect(jsonString.contains("\"createdAt\""))
        #expect(jsonString.contains("struct_test"))
        #expect(jsonString.contains("struct@example.com"))
    }

    // MARK: - Hashable Tests

    @Test("Hashable 一致性 / Hashable conformance")
    func testHashable() async throws {
        // Given
        let user1 = User(
            id: "hash1",
            email: "hash1@example.com",
            displayName: "Hash Test 1"
        )

        let user2 = user1 // Same instance

        // Then
        #expect(user1.hashValue == user2.hashValue)

        // When - Create set
        let userSet: Set = [user1, user2]

        // Then - Should only contain 1 unique user
        #expect(userSet.count == 1)
    }

    @Test("不同用户有不同 hash / Different users have different hashes")
    func testDifferentUsersHaveDifferentHashes() async throws {
        // Given
        let user1 = User(
            id: "user1",
            email: "user1@example.com",
            displayName: "User 1"
        )

        let user2 = User(
            id: "user2",
            email: "user2@example.com",
            displayName: "User 2"
        )

        // When
        let userSet: Set = [user1, user2]

        // Then - Should contain 2 unique users
        #expect(userSet.count == 2)
    }

    // MARK: - Identifiable Tests

    @Test("Identifiable 协议 / Identifiable conformance")
    func testIdentifiable() async throws {
        // Given
        let userId = "identifiable_test"
        let user = User(
            id: userId,
            email: "id@example.com",
            displayName: "ID Test"
        )

        // Then - id property should match
        #expect(user.id == userId)
    }

    // MARK: - Edge Cases

    @Test("空显示名称字符串 / Empty display name string")
    func testEmptyDisplayNameString() async throws {
        // Given - Empty string vs nil
        let user = User(
            id: "empty_test",
            email: "test@example.com",
            displayName: ""
        )

        // Then - Empty string should be used as is
        #expect(user.displayName == "")
        #expect(user.username == "") // Should use empty displayName
    }

    @Test("特殊字符邮箱 / Special characters in email")
    func testSpecialCharactersInEmail() async throws {
        // Given
        let specialEmail = "user+tag@sub.example.com"
        let user = User(
            id: "special_test",
            email: specialEmail,
            displayName: nil
        )

        // When
        let username = user.username

        // Then - Should extract "user+tag" before @
        #expect(username == "user+tag")
    }

    @Test("Unicode 显示名称 / Unicode display name")
    func testUnicodeDisplayName() async throws {
        // Given
        let unicodeName = "张三 🎉"
        let user = User(
            id: "unicode_test",
            email: "test@example.com",
            displayName: unicodeName
        )

        // When
        let username = user.username

        // Then
        #expect(username == unicodeName)
    }

    @Test("超长邮箱地址 / Very long email address")
    func testVeryLongEmail() async throws {
        // Given
        let longEmail = "very.long.email.address.with.many.dots.and.characters@subdomain.example.com"
        let user = User(
            id: "long_test",
            email: longEmail,
            displayName: nil
        )

        // When
        let username = user.username

        // Then - Should extract prefix correctly
        #expect(username == "very.long.email.address.with.many.dots.and.characters")
    }
}
