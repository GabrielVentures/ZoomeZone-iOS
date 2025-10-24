//
//  FirebaseManager.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI
import Combine
/// Firebase service manager for authentication and data sync
@MainActor
class FirebaseManager: ObservableObject {
    // MARK: - Singleton

    static let shared = FirebaseManager()

    // MARK: - Published Properties

    /// Current authenticated user
    @Published var currentUser: User?

    /// Whether user is authenticated
    @Published var isAuthenticated = false

    /// Whether email is verified
    @Published var isEmailVerified: Bool = false

    /// Whether Firebase initialization is complete
    @Published var isInitialized: Bool = false

    /// Authentication state
    @Published var authState: AuthState = .unauthenticated

    // MARK: - Private Properties

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private var authStateListener: AuthStateDidChangeListenerHandle?

    /// Last verification check timestamp
    private var lastVerificationCheck: Date = Date.distantPast

    /// Debounce interval for verification checks
    private let verificationDebounceInterval: TimeInterval = 3.0

    // MARK: - Authentication State

    enum AuthState {
        case unauthenticated
        case authenticating
        case authenticated
        case error(String)
    }

    enum EmailVerificationStatus {
        case notAuthenticated
        case pending
        case verified

        var displayText: String {
            switch self {
            case .notAuthenticated: return "Not signed in"
            case .pending: return "Verification pending"
            case .verified: return "Verified"
            }
        }

        var color: Color {
            switch self {
            case .notAuthenticated: return .gray
            case .pending: return .orange
            case .verified: return .green
            }
        }
    }

    // MARK: - Errors

    enum FirebaseError: LocalizedError {
        case authenticationFailed(String)
        case userNotFound
        case networkError
        case invalidCredentials
        case emailAlreadyInUse
        case weakPassword
        case rateLimited
        case emailAlreadyVerified
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .authenticationFailed(let message):
                return "Authentication failed: \(message)"
            case .userNotFound:
                return "User not found"
            case .networkError:
                return "Network error"
            case .invalidCredentials:
                return "Invalid credentials"
            case .emailAlreadyInUse:
                return "Email already in use"
            case .weakPassword:
                return "Password is too weak"
            case .rateLimited:
                return "Too many verification emails sent. Please wait before requesting another."
            case .emailAlreadyVerified:
                return "Email is already verified."
            case .unknown(let error):
                return "Unknown error: \(error.localizedDescription)"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .rateLimited:
                return "You can request a new verification email in an hour."
            case .emailAlreadyVerified:
                return "You can start using all features immediately."
            default:
                return nil
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Synchronously read locally cached user state (instant, non-blocking)
        if let currentFirebaseUser = auth.currentUser {
            // User is logged in (from local cache)
            print("✅ [FirebaseManager] init - Detected cached user")
            print("   Email: \(currentFirebaseUser.email ?? "N/A")")
            print("   EmailVerified: \(currentFirebaseUser.isEmailVerified)")

            // Immediately set user state (synchronous)
            self.currentUser = User.from(
                firebaseUID: currentFirebaseUser.uid,
                email: currentFirebaseUser.email ?? "",
                displayName: currentFirebaseUser.displayName
            )
            self.isAuthenticated = true
            self.isEmailVerified = currentFirebaseUser.isEmailVerified
            self.authState = .authenticated
        } else {
            // User is not logged in
            print("ℹ️ [FirebaseManager] init - No cached user")
            self.isAuthenticated = false
            self.isEmailVerified = false
            self.authState = .unauthenticated
        }

        // Mark initialization complete (synchronous read completed)
        self.isInitialized = true
        print("✅ [FirebaseManager] init - Initialization complete (sync)")

        // Setup listener for background async refresh (doesn't block startup)
        setupAuthStateListener()
    }

    /// Configure Firebase
    static func configure() {
        FirebaseApp.configure()
    }

    // MARK: - Auth State Listener

    /// Setup authentication state listener (background async refresh)
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                guard let self = self else { return }

                if let firebaseUser = firebaseUser {
                    // User logged in (listener triggered, async refresh)
                    print("🔄 [FirebaseManager] Listener detected user, refreshing...")

                    do {
                        // Async refresh user data to get latest verification status
                        try await firebaseUser.reload()

                        // Update user info
                        self.currentUser = User.from(
                            firebaseUID: firebaseUser.uid,
                            email: firebaseUser.email ?? "",
                            displayName: firebaseUser.displayName
                        )
                        self.isAuthenticated = true

                        // Sync email verification status
                        let wasVerified = self.isEmailVerified
                        self.isEmailVerified = firebaseUser.isEmailVerified

                        // Log status changes
                        if !wasVerified && firebaseUser.isEmailVerified {
                            print("🎉 [FirebaseManager] Email verified!")
                            // Trigger celebration animation
                            NotificationCenter.default.post(
                                name: .emailVerificationCompleted,
                                object: nil
                            )
                        }

                        self.authState = .authenticated

                        print("✅ [FirebaseManager] Listener update complete:")
                        print("   Email: \(firebaseUser.email ?? "N/A")")
                        print("   EmailVerified: \(firebaseUser.isEmailVerified)")

                    } catch {
                        print("⚠️ [FirebaseManager] Failed to refresh user data: \(error.localizedDescription)")
                        // Even if refresh fails, update basic info
                        self.currentUser = User.from(
                            firebaseUID: firebaseUser.uid,
                            email: firebaseUser.email ?? "",
                            displayName: firebaseUser.displayName
                        )
                        self.isAuthenticated = true
                        self.isEmailVerified = firebaseUser.isEmailVerified
                        self.authState = .authenticated
                    }

                } else {
                    // User not logged in (listener triggered logout)
                    print("ℹ️ [FirebaseManager] Listener detected logout")
                    self.currentUser = nil
                    self.isAuthenticated = false
                    self.isEmailVerified = false
                    self.authState = .unauthenticated

                    // Reset verification check time
                    self.lastVerificationCheck = Date.distantPast
                }
            }
        }
    }

    // MARK: - Authentication Methods

    /// User registration
    /// - Parameters:
    ///   - email: Email address
    ///   - password: Password
    /// - Returns: User object
    /// - Throws: FirebaseError
    func signUp(email: String, password: String) async throws -> User {
        authState = .authenticating

        do {
            let result = try await auth.createUser(withEmail: email, password: password)

            let user = User.from(
                firebaseUID: result.user.uid,
                email: result.user.email ?? email,
                displayName: result.user.displayName
            )

            self.currentUser = user
            self.isAuthenticated = true
            self.authState = .authenticated

            return user

        } catch let error as NSError {
            let firebaseError = mapAuthError(error)
            self.authState = .error(firebaseError.localizedDescription ?? "Unknown error")
            throw firebaseError
        }
    }

    /// User sign in
    /// - Parameters:
    ///   - email: Email address
    ///   - password: Password
    /// - Returns: User object
    /// - Throws: FirebaseError
    func signIn(email: String, password: String) async throws -> User {
        authState = .authenticating

        do {
            let result = try await auth.signIn(withEmail: email, password: password)

            let user = User.from(
                firebaseUID: result.user.uid,
                email: result.user.email ?? email,
                displayName: result.user.displayName
            )

            self.currentUser = user
            self.isAuthenticated = true
            self.authState = .authenticated

            return user

        } catch let error as NSError {
            let firebaseError = mapAuthError(error)
            self.authState = .error(firebaseError.localizedDescription ?? "Unknown error")
            throw firebaseError
        }
    }

    /// User sign out
    /// - Throws: FirebaseError
    func signOut() throws {
        do {
            try auth.signOut()
            self.currentUser = nil
            self.isAuthenticated = false
            self.authState = .unauthenticated
        } catch {
            throw FirebaseError.unknown(error)
        }
    }

    /// Send password reset email
    /// - Parameter email: Email address
    /// - Throws: FirebaseError
    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw mapAuthError(error)
        }
    }

    // MARK: - Email Verification Methods

    /// Send email verification with enhanced error handling
    func sendEmailVerification() async throws {
        guard let user = auth.currentUser else {
            print("❌ [FirebaseManager] sendEmailVerification: No current user")
            throw FirebaseError.userNotFound
        }

        // Already verified check
        if user.isEmailVerified {
            print("✅ [FirebaseManager] Email already verified, no need to resend")
            await MainActor.run {
                self.isEmailVerified = true
            }
            return
        }

        do {
            try await user.sendEmailVerification()
            print("📧 [FirebaseManager] Verification email sent successfully: \(user.email ?? "N/A")")

            // Record send time (for analysis)
            UserDefaults.standard.set(Date(), forKey: "lastVerificationEmailSent")

        } catch let error as NSError {
            print("❌ [FirebaseManager] Failed to send verification email: \(error.localizedDescription)")

            // Special error handling
            if error.code == AuthErrorCode.tooManyRequests.rawValue {
                // Rate limit error, provide friendly message
                throw FirebaseError.rateLimited
            }

            throw mapAuthError(error)
        }
    }

    /// Smart email verification check with debouncing
    func checkEmailVerified() async -> Bool {
        guard let user = auth.currentUser else {
            print("❌ [FirebaseManager] checkEmailVerified: No current user")
            await MainActor.run {
                self.isEmailVerified = false
            }
            return false
        }

        // Debounce check: avoid frequent requests
        let now = Date()
        if now.timeIntervalSince(lastVerificationCheck) < verificationDebounceInterval {
            print("⏸️ [FirebaseManager] Verification check debounced, using cached result")
            return isEmailVerified
        }

        do {
            // Refresh user data
            try await user.reload()
            lastVerificationCheck = now

            let verified = user.isEmailVerified
            let wasVerified = isEmailVerified

            await MainActor.run {
                self.isEmailVerified = verified
            }

            // Status change detection
            if !wasVerified && verified {
                print("🎉 [FirebaseManager] Email verification status updated to verified!")
                // Trigger verification completed notification
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .emailVerificationCompleted,
                        object: nil
                    )
                }
            }

            print("🔍 [FirebaseManager] Verification status check result: \(verified)")
            return verified

        } catch {
            print("❌ [FirebaseManager] Verification status check failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Get email verification status synchronously
    var emailVerificationStatus: EmailVerificationStatus {
        guard isAuthenticated else { return .notAuthenticated }
        return isEmailVerified ? .verified : .pending
    }

    /// Delete user account
    /// - Throws: FirebaseError
    func deleteAccount() async throws {
        guard let firebaseUser = auth.currentUser else {
            throw FirebaseError.userNotFound
        }

        do {
            try await firebaseUser.delete()
            self.currentUser = nil
            self.isAuthenticated = false
            self.authState = .unauthenticated
        } catch {
            throw FirebaseError.unknown(error)
        }
    }

    // MARK: - Error Mapping

    /// Map Firebase Auth errors to custom errors
    /// - Parameter error: NSError from Firebase
    /// - Returns: FirebaseError
    private func mapAuthError(_ error: NSError) -> FirebaseError {
        // Print detailed error info for debugging
        print("🔥 Firebase Auth Error:")
        print("   Code: \(error.code)")
        print("   Domain: \(error.domain)")
        print("   Description: \(error.localizedDescription)")
        print("   UserInfo: \(error.userInfo)")

        guard let errorCode = AuthErrorCode(rawValue: error.code) else {
            print("   ⚠️ Unknown error code, returning .unknown")
            return .unknown(error)
        }

        print("   ErrorCode: \(errorCode)")

        switch errorCode {
        case .networkError:
            return .networkError
        case .userNotFound:
            return .userNotFound
        case .invalidEmail, .invalidCredential, .wrongPassword:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .internalError:
            // Internal error - usually configuration issue
            let detailedMessage = "Internal Error\n" +
                                 "Possible causes:\n" +
                                 "1. Email/Password authentication not enabled in Firebase Console\n" +
                                 "2. GoogleService-Info.plist configuration error\n" +
                                 "3. Network connection issue\n" +
                                 "Details: \(error.localizedDescription)"
            return .authenticationFailed(detailedMessage)
        default:
            return .authenticationFailed(error.localizedDescription)
        }
    }

    // MARK: - Data Sync Methods (Firestore)

    /// Upload scan record to Firestore
    /// - Parameter record: Scan record
    /// - Throws: Error
    func uploadScanRecord(_ record: ScanRecord) async throws {
        guard let user = currentUser else {
            throw FirebaseError.userNotFound
        }

        let recordData: [String: Any] = [
            "Scan_ID": record.id,
            "Username": record.username,
            "Timestamp": Timestamp(date: record.timestamp),
            "Merchant": record.merchant,
            "Barcode": record.barcode,
            "Latitude": record.latitude ?? NSNull(),
            "Longitude": record.longitude ?? NSNull(),
            "Image_Filename": record.imageFilename,
            "Store_Location": record.storeLocation ?? NSNull(),
            "User_ID": user.id
        ]

        try await db.collection("scan_records").document(record.id).setData(recordData)
    }

    /// Batch upload scan records
    /// - Parameter records: Array of scan records
    /// - Returns: Number of successfully uploaded records
    func batchUploadRecords(_ records: [ScanRecord]) async throws -> Int {
        var successCount = 0

        for record in records {
            do {
                try await uploadScanRecord(record)
                successCount += 1
            } catch {
                print("Failed to upload record \(record.id): \(error.localizedDescription)")
                // Continue uploading other records
                continue
            }
        }

        return successCount
    }

    // MARK: - Storage Methods (Firebase Storage)

    /// Upload image to Firebase Storage
    /// - Parameters:
    ///   - imageData: Image data
    ///   - filename: Filename
    /// - Returns: Download URL
    /// - Throws: Error
    func uploadImage(imageData: Data, filename: String) async throws -> URL {
        guard let user = currentUser else {
            throw FirebaseError.userNotFound
        }

        let storageRef = storage.reference()
        let imageRef = storageRef.child("users/\(user.id)/images/\(filename)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await imageRef.downloadURL()

        return downloadURL
    }

    // MARK: - Cleanup

    deinit {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let emailVerificationCompleted = Notification.Name("emailVerificationCompleted")
}
