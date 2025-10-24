//
//  Strings.swift
//  ShelfTagSnap
//
//  Created by kent.sun on 2025/10/24.
//  Centralized string constants for the app
//

import Foundation

/// Centralized string constants for UI text

enum Strings {

    // MARK: - Tab Bar

    enum TabBar {
        static let tasks = "Tasks"
        static let history = "History"
        static let settings = "Settings"
    }

    // MARK: - App

    enum App {
        static let appName = "Zoom Zone"
        static let loading = "Loading..."
        static let initializing = "Initializing"
        static let checkingAuthentication = "Checking authentication..."
    }

    // MARK: - Camera

    enum Camera {
        static let startScanning = "Start Scanning"
        static let alignBarcode = "Position barcode in frame to scan"
        static let scanSuccessful = "Scan successful"
        static let lowLight = "Low light detected - move to brighter area"
        static let tooClose = "Move camera further from barcode"
        static let tooFar = "Move camera closer to barcode"
        static let invalidBarcode = "Invalid barcode detected"
        static let capturePhoto = "Capture Photo"
        static let retake = "Retake"
        static let confirm = "Confirm"
        static let cancel = "Cancel"

        // Status messages
        static let lowLightWarning = "Low light warning"
        static let statusMessage = "Status message"
        static let distanceIndicator = "Distance indicator"
        static let moveCloser = "Move closer"
        static let moveBack = "Move back"
        static let distanceOptimal = "Distance optimal"
        static let moveCloserHint = "Move closer to the barcode for better scanning"
        static let moveBackHint = "Move back for better scanning"
        static let distanceOptimalHint = "Distance is optimal, maintain current position"
        static let scanning = "Scanning..."
        static let scanArea = "Scan area"
        static let cameraScanning = "Camera is scanning for barcodes"

        // Modal messages
        static let initializingCamera = "Initializing Camera"
        static let configuringCamera = "Configuring camera device..."
        static let cameraPermissionRequired = "Camera Permission Required"
        static let allowCameraAccess = "Please allow camera access in Settings to use scanning feature."
    }

    // MARK: - Scan Result

    enum ScanResult {
        static let barcode = "Barcode"
        static let store = "Store"
        static let merchant = "Merchant"
        static let location = "Location"
        static let timestamp = "Timestamp"
        static let photo = "Photo"
        static let save = "Save"
        static let discard = "Discard"

        static let confirmScan = "Confirm Scan"
        static let scannedPhoto = "Scanned Photo"
        static let time = "Time"
        static let storeLocation = "Store Location"
        static let storeLocationOptional = "Store Location (Optional)"
        static let storeLocationPlaceholder = "e.g., Floor 1 entrance"
        static let saveScanRecord = "Save Scan Record"
        static let scannedPhotoAlt = "Scanned photo"
        static let photoOfBarcode = "Photo of barcode"
    }

    // MARK: - History

    enum History {
        static let title = "History"
        static let noRecords = "No scan records yet"
        static let startScanningHint = "Start scanning to create records"
        static let select = "Select"
        static let selectAll = "Select All"
        static let deselectAll = "Deselect All"
        static let delete = "Delete"
        static let export = "Export"
        static let selected = "Selected"
        static let searchPlaceholder = "Search barcode, merchant or location"
        static let deleteConfirmation = "Confirm Delete"
        static let deleteMessage = "Are you sure you want to delete this record? This action cannot be undone."

        // Loading and errors
        static let loading = "Loading scan history"
        static let loadingRecords = "Loading..."
        static let failedToLoad = "Failed to Load"
        static let retry = "Retry"

        // Statistics
        static let recordsStatistics = "Records statistics"
        static let totalRecords = "records"
        static let recordsCount = "Records"

        // Search
        static let search = "Search"
        static let searchRecords = "Search scan records"
        static let searchResults = "Search Results"

        // Row accessibility
        static let scannedPhotoThumbnail = "Scan photo thumbnail"
        static let viewDetails = "Double tap to view details"

        // Empty state
        static let noScanRecordsYet = "No Scan Records Yet"
        static let startScanningToCreate = "Start scanning to create your first record"
        static let switchToScanTab = "Switch to scan tab"
    }

    // MARK: - Settings

    enum Settings {
        static let title = "Settings"
        static let account = "Account"
        static let storage = "Storage"
        static let appSettings = "Settings"
        static let about = "About"

        static let permissions = "Permissions"
        static let dataSync = "Data Sync"
        static let version = "Version"
        static let signOut = "Sign Out"
        static let changePassword = "Change Password"

        static let storageUsed = "Storage Used"
        static let clearData = "Clear Data"
        static let clearDataConfirmation = "Confirm Clear Data"
        static let clearDataMessage = "This will delete all scan records and photos. This action cannot be undone."

        static let confirmSignOut = "Confirm Sign Out"
        static let signOutMessage = "Are you sure you want to sign out?"

        static let storageManagement = "Storage Management"
        static let recordsCount = "Scan Records"
        static let photosSize = "Photos"
        static let loadingStorage = "Loading..."

        // Storage Details
        static let storageDetails = "Storage Details"
        static let availableSpace = "Available Space"
        static let total = "Total"
        static let used = "Used"
        static let available = "Available"
        static let usage = "Usage"
        static let deviceStorage = "Device Storage"
        static let appTotal = "App Total"
        static let photos = "Photos"
        static let records = "Records"
        static let appStorage = "App Storage"
        static let cleanupSuggestions = "Cleanup Suggestions"
        static let saveSpace = "Save"
    }

    // MARK: - Authentication

    enum Auth {
        static let signIn = "Sign In"
        static let signUp = "Sign Up"
        static let email = "Email"
        static let password = "Password"
        static let confirmPassword = "Confirm Password"
        static let forgotPassword = "Forgot Password"
        static let createAccount = "Create Account"
        static let alreadyHaveAccount = "Already have an account?"
        static let dontHaveAccount = "Don't have an account?"
        static let resetPassword = "Reset Password"
        static let backToSignIn = "Back to Sign In"

        // Headers and titles
        static let welcomeBack = "Welcome Back"
        static let forgotPasswordTitle = "Forgot Password?"
        static let enterEmailForReset = "Enter your email address and we'll send you a password reset link"
        static let joinShelfTagSnap = "Join ShelfTagSnap and start scanning efficiently"
        static let emailSent = "Email Sent!"
        static let pageWillClose = "This page will close automatically in a few seconds..."

        // Placeholders
        static let emailPlaceholder = "example@email.com"
        static let passwordPlaceholder = "••••••"
        static let atLeast6Characters = "At least 6 characters"
        static let reEnterPassword = "Re-enter password"

        // Validation
        static let pleaseEnterValidEmail = "Please enter a valid email"
        static let passwordMustBeAtLeast6 = "Password must be at least 6 characters"
        static let passwordsMatch = "Passwords match"
        static let passwordsDoNotMatch = "Passwords do not match"

        // Password strength
        static let passwordStrength = "Password Strength:"

        // Actions
        static let sendResetLink = "Send Reset Link"
        static let hidePassword = "Hide password"
        static let showPassword = "Show password"

        // Info messages
        static let checkSpamFolder = "Check your spam folder"
        static let resetLinkValid24Hours = "Reset link valid for 24 hours"
        static let accountSecurityPriority = "Your account security is our priority"
        static let bySigningUpYouAgree = "By signing up, you agree to our "
        static let termsOfService = "Terms of Service"
        static let and = " and "
        static let privacyPolicy = "Privacy Policy"

        // Success messages
        static let signInSuccessful = "Sign in successful"
        static let signUpSuccessful = "Sign up successful"
        static let passwordResetSent = "Password reset email sent"
        static let passwordResetEmailSentTo = "Password reset email sent to"
        static let pleaseCheckInbox = "Please check your inbox."

        // Error messages
        static let invalidEmail = "Invalid email address"
        static let passwordTooShort = "Password must be at least 6 characters"
        static let emailAlreadyInUse = "Email already in use"
        static let wrongPassword = "Wrong password"
        static let userNotFound = "User not found"
        static let networkError = "Network error. Please try again."
    }

    // MARK: - Permissions

    enum Permissions {
        static let title = "Permissions"
        static let camera = "Camera"
        static let cameraDescription = "Required for barcode scanning"
        static let location = "Location"
        static let locationDescription = "Optional for recording store location"

        static let authorized = "Authorized"
        static let denied = "Denied"
        static let notDetermined = "Not Set"

        static let openSettings = "Open Settings"
        static let requestPermission = "Request Permission"

        static let cameraAccessDenied = "Camera access denied. Please enable in Settings."
    }

    // MARK: - Duplicate Alert

    enum Duplicate {
        static let title = "Already Captured"
        static let message = "This barcode was already scanned"
        static let scannedAt = "Scanned at"
        static let scannedOn = "Scanned on"
        static let scanAgain = "Scan Again"
        static let cancel = "Cancel"
    }

    // MARK: - Export

    enum Export {
        static let preparing = "Preparing Export..."
        static let generatingZip = "Generating ZIP file"
        static let exportingFiles = "Exporting files..."
        static let success = "Export successful"
        static let failed = "Export failed"
        static let noRecordsSelected = "No records selected"

        // Export Preview
        static let exportConfirmation = "Export Confirmation"
        static let exportStatistics = "Export Statistics"
        static let totalRecordsLabel = "Total Records"
        static let dateRange = "Date Range"
        static let estimatedSize = "Est. Size"
        static let exportButton = "Export"
        static let exportWithImages = "Export with Images"
        static let exportCSVFile = "Export CSV file"
        static let cancelExport = "Cancel export"
        static let csvFileWillContain = "CSV file will contain all scan records"
        static let zipFileWillContain = "ZIP file will contain CSV and all photos"
        static let chineseEncodingSupport = "• Chinese encoding support"
        static let canBeOpenedInExcel = "• Can be opened in Excel"
        static let exportError = "Export Error"

        // Multi-select
        static let deleteSelected = "Delete Selected"
        static let deleteSelectedConfirmation = "Delete Selected Records?"
        static let deleteSelectedMessage = "Are you sure you want to delete %d selected records? This action cannot be undone."
    }

    // MARK: - Common

    enum Common {
        static let ok = "OK"
        static let cancel = "Cancel"
        static let delete = "Delete"
        static let clear = "Clear"
        static let save = "Save"
        static let done = "Done"
        static let close = "Close"
        static let retry = "Retry"
        static let loading = "Loading..."
        static let error = "Error"
        static let success = "Success"
        static let warning = "Warning"
        static let dismiss = "Dismiss"
        static let share = "Share"
        static let moreOptions = "More options"

        // Accessibility
        static let inputValid = "Input valid"
        static let inputInvalid = "Input invalid"
        static let validationMessage = "Validation message"
        static let loadingPleaseWait = "Loading, please wait"
        static let buttonIsDisabled = "Button is disabled"
        static let doubleTapToPerformAction = "Double tap to perform action"
    }

    // MARK: - Detail View

    enum Detail {
        static let title = "Detail"
        static let scannedPhoto = "Scanned Photo"
        static let scanInformation = "Scan Information"
        static let barcode = "Barcode"
        static let merchant = "Merchant"
        static let time = "Time"
        static let storeLocation = "Store Location"
        static let gpsCoordinates = "GPS Coordinates"
        static let locationMap = "Location Map"
        static let scanLocation = "Scan Location"
        static let mapShowingScanLocation = "Map showing scan location"
        static let scanRecord = "Scan Record"
        static let photoSupportsZoom = "Scan photo, pinch to zoom"
        static let doubleTapToResetZoom = "Double tap to reset zoom"
    }

    // MARK: - Store Selection

    enum StoreSelection {
        static let title = "Select Store"
        static let searchPlaceholder = "Search stores..."
        static let noStoresFound = "No stores found"
        static let addStore = "Add Store"
    }

    // MARK: - Merchant Picker

    enum MerchantPicker {
        static let title = "Select Merchant"
        static let searchPlaceholder = "Search merchants..."
        static let noMerchantsFound = "No merchants found"
        static let selected = "Selected"
        static let notSelected = "Not selected"
        static let selectHint = "Double tap to select this merchant"
    }
}
