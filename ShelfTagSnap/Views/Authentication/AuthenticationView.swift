//
//  AuthenticationView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/23.
//

import SwiftUI

/// Main authentication view
struct AuthenticationView: View {
    // MARK: - State Objects

    @StateObject private var authViewModel = AuthViewModel()

    // MARK: - State

    @State private var showSignUp: Bool = false
    @State private var showForgotPassword: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            LoginView(
                showSignUp: $showSignUp,
                showForgotPassword: $showForgotPassword
            )
            .environmentObject(authViewModel)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
                    .environmentObject(authViewModel)
                    .onDisappear {

                        // Clear form when returning to login
                        authViewModel.clearForm()
                    }
            }
            .navigationDestination(isPresented: $showForgotPassword) {
                ForgotPasswordView()
                    .environmentObject(authViewModel)
                    .onDisappear {

                        // Clear form when returning to login
                        authViewModel.clearForm()
                    }
            }
        }
        .tint(.blue)
    }
}

// MARK: - Preview

#Preview {
    AuthenticationView()
}
