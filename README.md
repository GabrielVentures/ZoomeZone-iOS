# ShelfTagSnap iOS

Native iOS application for scanning and managing shelf tag images with AI-powered product recognition.

## 📋 Overview

ShelfTagSnap is a professional iOS application that enables users to capture shelf tag images, automatically extract product information using AI, and sync data to the cloud for centralized management.

## 🏗️ Architecture

### Tech Stack
- **Platform**: iOS 17.0+
- **Language**: Swift 5.9
- **UI Framework**: SwiftUI
- **Architecture**: MVVM (Model-View-ViewModel)
- **Data Persistence**: SwiftData + CoreData
- **Backend**: Firebase (Firestore, Storage, Auth, Functions)
- **Camera**: AVFoundation
- **Barcode Scanning**: Vision Framework

### Core Modules

**Views**
- `Authentication/` - Login and user management
- `Camera/` - Camera capture interface
- `Scanner/` - Barcode scanning
- `History/` - Record browsing and management
- `Cloud/` - Cloud sync status and management
- `Export/` - CSV export functionality
- `Tasks/` - Background task management
- `Settings/` - App configuration

**Services**
- `FirebaseManager` - Firebase integration and authentication
- `CloudSyncService` - Cloud synchronization engine
- `CameraManager` - Camera capture and image processing
- `BarcodeDetector` - Barcode detection using Vision
- `RecordStorageService` - Local data persistence
- `UploadCoordinator` - Intelligent upload management
- `ExportManager` - CSV export operations
- `SwiftDataService` - SwiftData database operations

**ViewModels**
- `CameraViewModel` - Camera logic and state
- `HistoryViewModel` - Record list management
- `CloudViewModel` - Cloud sync state
- `ExportViewModel` - Export operations

**Models**
- `ScanRecord` - Local scan record model
- `CloudScanRecord` - Cloud-synced record model
- `UserSettings` - App preferences

## 🚀 Features

### 1. Camera & Scanning
- **Professional Camera Interface** - Full-screen capture with preview
- **Real-time Barcode Detection** - Automatic barcode scanning
- **Manual Input** - Manual barcode entry option
- **Image Quality Control** - Automatic image optimization
- **GPS Location Tracking** - Automatic location capture

### 2. Local Storage
- **SwiftData Integration** - Modern data persistence
- **Offline Support** - Full offline functionality
- **Search & Filter** - Quick record lookup
- **Pagination** - Efficient large dataset handling
- **Image Caching** - Optimized image storage

### 3. Cloud Synchronization
- **Automatic Upload** - Background upload when online
- **Retry Mechanism** - Automatic retry for failed uploads
- **Batch Upload** - Efficient batch processing
- **Upload Queue** - Prioritized upload queue
- **Sync Status** - Real-time sync status tracking
- **Network Detection** - Automatic network state handling

### 4. AI Processing
- **Cloud AI Integration** - OpenAI Vision API via Cloud Functions
- **Automatic Processing** - AI processing triggered on upload
- **Processing Status** - Real-time status updates (Pending/Processing/Completed/Failed)
- **Cost Tracking** - AI processing cost monitoring

### 5. Data Export
- **CSV Export** - Export records to CSV format
- **Flexible Options** - Export all or filtered records
- **Share Integration** - System share sheet integration
- **Email Support** - Direct email export

### 6. User Management
- **Firebase Authentication** - Secure user authentication
- **Anonymous Auth** - Optional anonymous mode
- **Multi-device Sync** - Cross-device data synchronization
- **User Preferences** - Customizable settings

## 📱 App Flow

```
Launch
  ↓
Authentication (Firebase Auth)
  ↓
Main Tab View
  ├── Camera Tab
  │     ├── Capture Image
  │     ├── Detect Barcode
  │     └── Save to Local DB
  ├── History Tab
  │     ├── View All Records
  │     ├── Search & Filter
  │     └── View Details
  ├── Cloud Tab
  │     ├── Upload Status
  │     ├── Sync Management
  │     └── Retry Failed
  └── Settings Tab
        ├── User Profile
        ├── Export Settings
        └── App Preferences
```

## 🔄 Sync Architecture

### Upload Flow
1. **Capture** - User captures image
2. **Local Save** - Save to SwiftData with pending status
3. **Queue** - Add to upload queue
4. **Upload** - Background upload to Firebase Storage
5. **Firestore** - Create scan_records document
6. **AI Trigger** - Cloud Function processes image
7. **Status Update** - Update local record with AI results

### Retry Logic
- **Exponential Backoff** - Intelligent retry timing
- **Max Attempts** - Up to 3 automatic retries
- **Manual Retry** - User-triggered retry option
- **Batch Retry** - Retry all failed uploads

## 🗄️ Data Models

### Local Record (SwiftData)
```swift
@Model
class ScanRecord {
    var recordID: String
    var barcode: String
    var merchant: String
    var storeLocation: String
    var deviceTimestamp: Date
    var imageData: Data?
    var latitude: Double?
    var longitude: Double?
    var uploadStatus: UploadStatus
    var cloudRecordID: String?
    var aiStatus: AIStatus?
}
```

### Cloud Record (Firestore)
```swift
struct CloudScanRecord {
    var User_ID: String
    var Username: String
    var Timestamp: Date
    var Barcode: String
    var Merchant: String
    var Store_Location: String
    var Device_Timestamp: Date
    var Image_URL: String
    var GPS_Latitude: Double?
    var GPS_Longitude: Double?
    var ai_processed: Bool
    var ai_status: String
    var ai_result: AIResult?
}
```

## 🚢 Build & Deployment

### Prerequisites
- Xcode 15.0+
- iOS 17.0+ deployment target
- Apple Developer Account
- Firebase project configured

### Setup
1. Open `ShelfTagSnap.xcodeproj` in Xcode
2. Configure Firebase:
   - Add `GoogleService-Info.plist` to project
   - Ensure Bundle ID matches Firebase project
3. Update code signing settings
4. Build and run

### Build Configurations
- **Debug** - Development with verbose logging
- **Release** - Production-ready optimized build

### Firebase Configuration
The app requires a Firebase project with:
- **Authentication** - Email/password and anonymous auth enabled
- **Firestore** - Database for scan records
- **Storage** - Image storage
- **Functions** - AI processing backend

## 📊 Project Structure

```
ShelfTagSnap/
├── ShelfTagSnap/
│   ├── Views/
│   │   ├── Authentication/      # Login screens
│   │   ├── Camera/              # Camera interface
│   │   ├── Scanner/             # Barcode scanner
│   │   ├── History/             # Record list
│   │   ├── Cloud/               # Sync management
│   │   ├── Export/              # CSV export
│   │   ├── Tasks/               # Background tasks
│   │   ├── Settings/            # Settings
│   │   └── Components/          # Reusable UI components
│   ├── ViewModels/
│   │   ├── CameraViewModel.swift
│   │   ├── HistoryViewModel.swift
│   │   └── CloudViewModel.swift
│   ├── Models/
│   │   ├── ScanRecord.swift
│   │   ├── CloudScanRecord.swift
│   │   └── UserSettings.swift
│   ├── Services/
│   │   ├── FirebaseManager.swift
│   │   ├── CloudSyncService.swift
│   │   ├── CameraManager.swift
│   │   ├── BarcodeDetector.swift
│   │   ├── RecordStorageService.swift
│   │   ├── UploadCoordinator.swift
│   │   └── ExportManager.swift
│   ├── Utilities/
│   │   └── Extensions/          # Swift extensions
│   └── Resources/
│       └── GoogleService-Info.plist
└── ShelfTagSnap.xcodeproj
```

## 🔧 Development

### Run in Simulator
```bash
# Open in Xcode
open ShelfTagSnap.xcodeproj

# Or use xcodebuild
xcodebuild -project ShelfTagSnap.xcodeproj \
           -scheme ShelfTagSnap \
           -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
           build
```

### Testing
- **Unit Tests** - Test business logic
- **UI Tests** - Test user flows
- **Integration Tests** - Test Firebase integration

### Debugging
- Enable verbose logging in Debug configuration
- Use Firebase Debug View for analytics
- Monitor network requests with Charles Proxy

## 📱 Device Requirements

### Minimum Requirements
- **iOS Version**: 17.0+
- **Camera**: Required for image capture
- **Network**: WiFi or Cellular for cloud sync
- **Storage**: 100MB+ recommended

### Recommended
- **Device**: iPhone 12 or newer
- **iOS Version**: Latest iOS version
- **Network**: WiFi for batch uploads

## 🔐 Permissions

Required permissions in `Info.plist`:
- **Camera** - `NSCameraUsageDescription`
- **Photo Library** - `NSPhotoLibraryUsageDescription`
- **Location** - `NSLocationWhenInUseUsageDescription`

## 🎨 Design System

### Colors
- Primary: Blue (#007AFF)
- Success: Green (#34C759)
- Warning: Orange (#FF9500)
- Error: Red (#FF3B30)

### Typography
- System Font (San Francisco)
- Dynamic Type support
- Accessibility font scaling

## 📚 Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Firebase iOS SDK](https://firebase.google.com/docs/ios/setup)
- [AVFoundation](https://developer.apple.com/documentation/avfoundation)

---

**Version**: 2.1.0
**Last Updated**: 2025-11-14
**Platform**: iOS 17.0+
**Language**: Swift 5.9
