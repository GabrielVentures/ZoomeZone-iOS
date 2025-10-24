//
//  AuthViewModelTests.swift
//  ShelfTagSnapTests
//
//  Created by kent.sun on 2025/10/23.
//

import Testing
import Foundation
@testable import ShelfTagSnap

/// Unit tests for AuthViewModel
@Suite("AuthViewModel Tests")
@MainActor
struct AuthViewModelTests {

    // MARK: - Validation Tests

    @Test("邮箱验证 - 有效邮箱 / Email validation - valid emails")
    func testValidEmails() async throws {
        // Given
        let validEmails = [
            "test@example.com",
            "user.name@example.com",
            "user+tag@example.co.uk",
            "test123@sub.example.com"
        ]

        // When & Then
        for email in validEmails {
            #expect(ValidationHelper.isValidEmail(email), "Email \(email) should be valid")
        }
    }

    @Test("邮箱验证 - 无效邮箱 / Email validation - invalid emails")
    func testInvalidEmails() async throws {
        // Given
        let invalidEmails = [
            "",
            "invalid",
            "@example.com",
            "user@",
            "user @example.com",
            "user@.com",
            "user@example",
            "user@@example.com"
        ]

        // When & Then
        for email in invalidEmails {
            #expect(!ValidationHelper.isValidEmail(email), "Email \(email) should be invalid")
        }
    }

    @Test("密码验证 - 有效密码 / Password validation - valid passwords")
    func testValidPasswords() async throws {
        // Given
        let validPasswords = [
            "123456",         // Minimum 6 characters
            "password",
            "MyP@ssw0rd!",
            "12345678"
        ]

        // When & Then
        for password in validPasswords {
            #expect(ValidationHelper.isValidPassword(password), "Password '\(password)' should be valid")
        }
    }

    @Test("密码验证 - 无效密码 / Password validation - invalid passwords")
    func testInvalidPasswords() async throws {
        // Given
        let invalidPasswords = [
            "",           // Empty
            "12345",      // Too short
            "abc",        // Too short
            "pass"        // Too short
        ]

        // When & Then
        for password in invalidPasswords {
            #expect(!ValidationHelper.isValidPassword(password), "Password '\(password)' should be invalid")
        }
    }

    @Test("密码强度 - 空密码 / Password strength - empty")
    func testPasswordStrengthEmpty() async throws {
        // Given
        let password = ""

        // When
        let strength = ValidationHelper.getPasswordStrength(password)

        // Then
        #expect(strength == .empty)
        #expect(strength.description.isEmpty)
    }

    @Test("密码强度 - 太短 / Password strength - too short")
    func testPasswordStrengthTooShort() async throws {
        // Given
        let password = "12345"

        // When
        let strength = ValidationHelper.getPasswordStrength(password)

        // Then
        #expect(strength == .tooShort)
        #expect(strength.description.contains("短") || strength.description.contains("short"))
    }

    @Test("密码强度 - 弱 / Password strength - weak")
    func testPasswordStrengthWeak() async throws {
        // Given
        let password = "123456" // 6-7 characters

        // When
        let strength = ValidationHelper.getPasswordStrength(password)

        // Then
        #expect(strength == .weak)
        #expect(strength.description.contains("弱") || strength.description.contains("Weak"))
    }

    @Test("密码强度 - 中等 / Password strength - medium")
    func testPasswordStrengthMedium() async throws {
        // Given
        let password = "password" // 8+ characters, no numbers

        // When
        let strength = ValidationHelper.getPasswordStrength(password)

        // Then
        #expect(strength == .medium)
    }

    @Test("密码强度 - 强 / Password strength - strong")
    func testPasswordStrengthStrong() async throws {
        // Given
        let password = "Password123" // 8+ characters with numbers and letters

        // When
        let strength = ValidationHelper.getPasswordStrength(password)

        // Then
        #expect(strength == .strong)
        #expect(strength.description.contains("强") || strength.description.contains("Strong"))
    }

    // MARK: - ViewModel State Tests

    @Test("初始状态 / Initial state")
    func testInitialState() async throws {
        // Given
        let viewModel = AuthViewModel()

        // Then
        #expect(viewModel.email.isEmpty)
        #expect(viewModel.password.isEmpty)
        #expect(viewModel.confirmPassword.isEmpty)
        #expect(viewModel.displayName.isEmpty)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.successMessage == nil)
        #expect(viewModel.showPassword == false)
        #expect(viewModel.showConfirmPassword == false)
    }

    @Test("邮箱验证状态 / Email validation state")
    func testEmailValidationState() async throws {
        // Given
        let viewModel = AuthViewModel()

        // When - Invalid email
        viewModel.email = "invalid-email"

        // Then
        #expect(!viewModel.isEmailValid)

        // When - Valid email
        viewModel.email = "test@example.com"

        // Then
        #expect(viewModel.isEmailValid)
    }

    @Test("密码验证状态 / Password validation state")
    func testPasswordValidationState() async throws {
        // Given
        let viewModel = AuthViewModel()

        // When - Invalid password
        viewModel.password = "12345"

        // Then
        #expect(!viewModel.isPasswordValid)

        // When - Valid password
        viewModel.password = "123456"

        // Then
        #expect(viewModel.isPasswordValid)
    }

    @Test("密码匹配状态 / Passwords match state")
    func testPasswordsMatchState() async throws {
        // Given
        let viewModel = AuthViewModel()

        // When - Passwords don't match
        viewModel.password = "password123"
        viewModel.confirmPassword = "password456"

        // Then
        #expect(!viewModel.passwordsMatch)

        // When - Passwords match
        viewModel.confirmPassword = "password123"

        // Then
        #expect(viewModel.passwordsMatch)

        // When - Empty passwords
        viewModel.password = ""
        viewModel.confirmPassword = ""

        // Then - Should not match when empty
        #expect(!viewModel.passwordsMatch)
    }

    @Test("登录表单验证 / Login form validation")
    func testLoginFormValidation() async throws {
        // Given
        let viewModel = AuthViewModel()

        // When - Empty fields
        viewModel.email = ""
        viewModel.password = ""

        // Then
        #expect(!viewModel.isLoginFormValid)

        // When - Invalid email
        viewModel.email = "invalid"
        viewModel.password = "password"

        // Then
        #expect(!viewModel.isLoginFormValid)

        // When - Valid credentials
        viewModel.email = "test@example.com"
        viewModel.password = "password123"

        // Then
        #expect(viewModel.isLoginFormValid)
    }

    @Test("注册表单验证 / Sign up form validation")
    func testSignUpFormValidation() async throws {
        // Given
        let viewModel = AuthViewModel()

        // When - Empty fields
        // Then
        #expect(!viewModel.isSignUpFormValid)

        // When - Valid email, invalid password
        viewModel.email = "test@example.com"
        viewModel.password = "12345" // Too short

        // Then
        #expect(!viewModel.isSignUpFormValid)

        // When - Valid email and password, but not matching
        viewModel.password = "123456"
        viewModel.confirmPassword = "654321"

        // Then
        #expect(!viewModel.isSignUpFormValid)

        // When - All valid
        viewModel.email = "test@example.com"
        viewModel.password = "password123"
        viewModel.confirmPassword = "password123"

        // Then
        #expect(viewModel.isSignUpFormValid)
    }

    // MARK: - Helper Methods Tests

    @Test("清空表单 / Clear form")
    func testClearForm() async throws {
        // Given
        let viewModel = AuthViewModel()
        viewModel.email = "test@example.com"
        viewModel.password = "password"
        viewModel.confirmPassword = "password"
        viewModel.displayName = "Test User"
        viewModel.showPassword = true
        viewModel.showConfirmPassword = true
        viewModel.errorMessage = "Some error"
        viewModel.successMessage = "Some success"

        // When
        viewModel.clearForm()

        // Then
        #expect(viewModel.email.isEmpty)
        #expect(viewModel.password.isEmpty)
        #expect(viewModel.confirmPassword.isEmpty)
        #expect(viewModel.displayName.isEmpty)
        #expect(viewModel.showPassword == false)
        #expect(viewModel.showConfirmPassword == false)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.successMessage == nil)
    }

    @Test("清除错误消息 / Clear error message")
    func testClearError() async throws {
        // Given
        let viewModel = AuthViewModel()
        viewModel.errorMessage = "Some error"

        // When
        viewModel.clearError()

        // Then
        #expect(viewModel.errorMessage == nil)
    }

    @Test("清除成功消息 / Clear success message")
    func testClearSuccess() async throws {
        // Given
        let viewModel = AuthViewModel()
        viewModel.successMessage = "Some success"

        // When
        viewModel.clearSuccess()

        // Then
        #expect(viewModel.successMessage == nil)
    }

    @Test("切换密码可见性 / Toggle password visibility")
    func testTogglePasswordVisibility() async throws {
        // Given
        let viewModel = AuthViewModel()
        #expect(viewModel.showPassword == false)

        // When
        viewModel.togglePasswordVisibility()

        // Then
        #expect(viewModel.showPassword == true)

        // When
        viewModel.togglePasswordVisibility()

        // Then
        #expect(viewModel.showPassword == false)
    }

    @Test("切换确认密码可见性 / Toggle confirm password visibility")
    func testToggleConfirmPasswordVisibility() async throws {
        // Given
        let viewModel = AuthViewModel()
        #expect(viewModel.showConfirmPassword == false)

        // When
        viewModel.toggleConfirmPasswordVisibility()

        // Then
        #expect(viewModel.showConfirmPassword == true)

        // When
        viewModel.toggleConfirmPasswordVisibility()

        // Then
        #expect(viewModel.showConfirmPassword == false)
    }

    // MARK: - Edge Cases

    @Test("特殊字符邮箱验证 / Special characters in email")
    func testSpecialCharactersInEmail() async throws {
        // Given
        let viewModel = AuthViewModel()

        // When - Valid special characters
        viewModel.email = "user+tag123@sub.example.co.uk"

        // Then
        #expect(viewModel.isEmailValid)

        // When - Invalid special characters
        viewModel.email = "user#tag@example.com"

        // Then
        #expect(!viewModel.isEmailValid)
    }

    @Test("超长密码 / Very long password")
    func testVeryLongPassword() async throws {
        // Given
        let longPassword = String(repeating: "a", count: 100)

        // When
        let isValid = ValidationHelper.isValidPassword(longPassword)
        let strength = ValidationHelper.getPasswordStrength(longPassword)

        // Then
        #expect(isValid) // Should be valid (>= 6 characters)
        #expect(strength == .medium) // Medium (no numbers)
    }

    @Test("Unicode 密码 / Unicode password")
    func testUnicodePassword() async throws {
        // Given
        let unicodePassword = "密码123456"

        // When
        let isValid = ValidationHelper.isValidPassword(unicodePassword)
        let strength = ValidationHelper.getPasswordStrength(unicodePassword)

        // Then
        #expect(isValid) // Should be valid (>= 6 characters)
        #expect(strength == .strong) // Strong (numbers + letters)
    }

    @Test("空白字符密码 / Whitespace in password")
    func testWhitespaceInPassword() async throws {
        // Given
        let passwordWithSpace = "pass word"

        // When
        let isValid = ValidationHelper.isValidPassword(passwordWithSpace)

        // Then
        #expect(isValid) // Should be valid (>= 6 characters, whitespace allowed)
    }

    @Test("密码强度颜色 / Password strength colors")
    func testPasswordStrengthColors() async throws {
        // Given & When & Then
        #expect(ValidationHelper.PasswordStrength.empty.color == .gray)
        #expect(ValidationHelper.PasswordStrength.tooShort.color == .red)
        #expect(ValidationHelper.PasswordStrength.weak.color == .orange)
        #expect(ValidationHelper.PasswordStrength.medium.color == .yellow)
        #expect(ValidationHelper.PasswordStrength.strong.color == .green)
    }
}
