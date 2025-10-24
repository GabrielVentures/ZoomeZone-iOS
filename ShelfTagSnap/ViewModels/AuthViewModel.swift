//
//  AuthViewModel.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation
import SwiftUI
import Combine

/// Authentication ViewModel managing user authentication flow
@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Email input
    @Published var email: String = ""

    /// Password input
    @Published var password: String = ""

    /// Confirm password input (for sign up)
    @Published var confirmPassword: String = ""

    /// Display name (optional for sign up)
    @Published var displayName: String = ""

    /// Loading state
    @Published var isLoading: Bool = false

    /// Error message
    @Published var errorMessage: String?

    /// Success message
    @Published var successMessage: String?

    /// Show password toggle
    @Published var showPassword: Bool = false

    /// Show confirm password toggle
    @Published var showConfirmPassword: Bool = false

    // MARK: - Private Properties

    private let firebaseManager = FirebaseManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// Email validation state
    var isEmailValid: Bool {
        ValidationHelper.isValidEmail(email)
    }

    /// Password validation state
    var isPasswordValid: Bool {
        ValidationHelper.isValidPassword(password)
    }

    /// Passwords match state (for sign up)
    var passwordsMatch: Bool {
        password == confirmPassword && !password.isEmpty
    }

    /// Login form is valid
    var isLoginFormValid: Bool {
        isEmailValid && !password.isEmpty
    }

    /// Sign up form is valid
    var isSignUpFormValid: Bool {
        isEmailValid && isPasswordValid && passwordsMatch
    }

    // MARK: - Initialization

    init() {
        setupBindings()
    }

    // MARK: - Setup

    /// Setup bindings
    private func setupBindings() {
        // Clear error message when input changes
        Publishers.CombineLatest3($email, $password, $confirmPassword)
            .dropFirst()
            .sink { [weak self] _, _, _ in
                self?.errorMessage = nil
                self?.successMessage = nil
            }
            .store(in: &cancellables)
    }

    // MARK: - Authentication Methods

    /// User sign in
    func signIn() async {
        guard isLoginFormValid else {
            errorMessage = "Please enter valid email and password"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await firebaseManager.signIn(email: email, password: password)
            clearForm()
        } catch let error as FirebaseManager.FirebaseError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// User sign up
    func signUp() async {
        guard isSignUpFormValid else {
            if !isEmailValid {
                errorMessage = "Please enter a valid email address"
            } else if !isPasswordValid {
                errorMessage = "Password must be at least 6 characters"
            } else if !passwordsMatch {
                errorMessage = "Passwords do not match"
            }
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 1. Register user
            _ = try await firebaseManager.signUp(email: email, password: password)
            print("✅ [AuthViewModel] User registered successfully")

            // ✅ 2. Send verification email (new)
            do {
                try await firebaseManager.sendEmailVerification()
                print("✅ [AuthViewModel] Verification email sent")

                // Update success message to prompt user to check email
                successMessage = "Registration successful! Please check your email to verify your account."

            } catch {
                print("⚠️ [AuthViewModel] Failed to send verification email: \(error.localizedDescription)")
                // Failed to send verification email doesn't affect registration, user can resend later
                successMessage = "Registration successful! But failed to send verification email. You can resend it later."
            }

            clearForm()

        } catch let error as FirebaseManager.FirebaseError {
            errorMessage = error.localizedDescription
            print("❌ Firebase Error: \(error)")
        } catch {
            let nsError = error as NSError
            let errorCode = nsError.code
            let errorDomain = nsError.domain
            let errorDetails = nsError.userInfo

            print("❌ Sign Up Error Details:")
            print("   Domain: \(errorDomain)")
            print("   Code: \(errorCode)")
            print("   UserInfo: \(errorDetails)")

            var detailedMessage = "Sign up failed\n"
            detailedMessage += "Error Code: \(errorCode)\n"

            if let description = errorDetails["NSLocalizedDescription"] as? String {
                detailedMessage += "Details: \(description)"
            } else {
                detailedMessage += "Details: \(error.localizedDescription)"
            }

            errorMessage = detailedMessage
        }

        isLoading = false
    }

    /// Send password reset email
    func sendPasswordReset() async {
        guard isEmailValid else {
            errorMessage = "Please enter a valid email address"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            try await firebaseManager.sendPasswordReset(email: email)
            successMessage = "Password reset email sent. Please check your inbox."
            email = ""
        } catch let error as FirebaseManager.FirebaseError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to send: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// User sign out
    func signOut() {
        do {
            try firebaseManager.signOut()
            clearForm()
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Helper Methods

    /// Clear form
    func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        showPassword = false
        showConfirmPassword = false
        errorMessage = nil
        successMessage = nil
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    /// Clear success message
    func clearSuccess() {
        successMessage = nil
    }

    /// Toggle password visibility
    func togglePasswordVisibility() {
        showPassword.toggle()
    }

    /// Toggle confirm password visibility
    func toggleConfirmPasswordVisibility() {
        showConfirmPassword.toggle()
    }
}

// MARK: - Validation Helper

/// Input validation helper
enum ValidationHelper {
    /// Validate email format
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    /// Validate password strength
    static func isValidPassword(_ password: String) -> Bool {
        // Firebase minimum requirement: 6 characters
        return password.count >= 6
    }

    /// Get password strength description
    static func getPasswordStrength(_ password: String) -> PasswordStrength {
        if password.isEmpty {
            return .empty
        } else if password.count < 6 {
            return .tooShort
        } else if password.count < 8 {
            return .weak
        } else if password.count >= 8 && containsNumbersAndLetters(password) {
            return .strong
        } else {
            return .medium
        }
    }

    /// Check if password contains numbers and letters
    private static func containsNumbersAndLetters(_ password: String) -> Bool {
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasLetters = password.rangeOfCharacter(from: .letters) != nil
        return hasNumbers && hasLetters
    }

    /// Password strength enumeration
    enum PasswordStrength {
        case empty
        case tooShort
        case weak
        case medium
        case strong

        var description: String {
            switch self {
            case .empty:
                return ""
            case .tooShort:
                return "Too short"
            case .weak:
                return "Weak"
            case .medium:
                return "Medium"
            case .strong:
                return "Strong"
            }
        }

        var color: Color {
            switch self {
            case .empty:
                return .gray
            case .tooShort:
                return .red
            case .weak:
                return .orange
            case .medium:
                return .yellow
            case .strong:
                return .green
            }
        }
    }
}
