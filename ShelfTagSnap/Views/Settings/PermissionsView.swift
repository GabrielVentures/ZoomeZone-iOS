//
//  PermissionsView.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.
//

import SwiftUI

/// Permissions management view

struct PermissionsView: View {
    // MARK: - Environment

    @EnvironmentObject private var permissionManager: PermissionManager

    // MARK: - Permission Status Helper

    private func getPermissionStatus(for permission: PermissionType) -> PermissionStatus {
        switch permission {
        case .camera:
            return permissionManager.cameraAuthorized ? .authorized : .notDetermined
        case .location:
            return permissionManager.locationAuthorized ? .authorized : .notDetermined
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            // Camera Permission
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.blue)

                        Text(Strings.Permissions.camera)
                            .font(.headline)

                        Spacer()

                        StatusBadge(status: getPermissionStatus(for: .camera))
                    }

                    Text(Strings.Permissions.cameraDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !permissionManager.cameraAuthorized {
                        Button {
                            permissionManager.openAppSettings()
                        } label: {
                            Text(Strings.Permissions.openSettings)
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(Strings.Permissions.camera)
            }

            // Location Permission
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundColor(.green)

                        Text(Strings.Permissions.location)
                            .font(.headline)

                        Spacer()

                        StatusBadge(status: getPermissionStatus(for: .location))
                    }

                    Text(Strings.Permissions.locationDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !permissionManager.locationAuthorized {
                        Button {
                            permissionManager.requestLocationPermission()
                        } label: {
                            Text(Strings.Permissions.requestPermission)
                                .font(.body)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text(Strings.Permissions.location)
            }
        }
        .navigationTitle(Strings.Permissions.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Permission Status Badge

/// Permission status badge

struct StatusBadge: View {
    let status: PermissionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.text)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(status.color)
    }
}

// MARK: - Permission Status Enum

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined

    var text: String {
        switch self {
        case .authorized:
            return Strings.Permissions.authorized
        case .denied:
            return Strings.Permissions.denied
        case .notDetermined:
            return Strings.Permissions.notDetermined
        }
    }

    var color: Color {
        switch self {
        case .authorized:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        }
    }

    var icon: String {
        switch self {
        case .authorized:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        }
    }
}

// MARK: - Permission Type Enum

enum PermissionType {
    case camera
    case location
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PermissionsView()
            .environmentObject(PermissionManager.shared)
    }
}
