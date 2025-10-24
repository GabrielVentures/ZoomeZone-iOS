# iOS MVP Demo 实现计划

## 项目概述

基于《第一里程碑需求文档》，实现一个功能完整的货架标签扫描App，用于杂货店货架标签的扫描和数据采集。

**项目预算**: $450
**交付时间**: 2天内交付可测试的Demo
**测试方式**: TestFlight内部测试（2-3人使用）

---

## 技术架构

### 开发技术栈
- **开发语言**: Swift
- **UI框架**: SwiftUI
- **架构模式**: MVVM (Model-View-ViewModel)
- **相机控制**: AVFoundation
- **条形码识别**: Apple Vision Framework
- **用户认证**: Firebase Authentication (Email/Password)
- **数据存储**: 本地文件系统 (JSON + FileManager)
- **依赖管理**: Swift Package Manager (SPM)

### 架构设计

```
ShelfTagSnap/
├── Models/
│   ├── ScanRecord.swift          # 扫描记录数据模型
│   ├── User.swift                # 用户数据模型
│   └── Merchant.swift            # 商家数据模型
├── Views/
│   ├── Authentication/
│   │   ├── LoginView.swift       # 登录界面
│   │   └── SignUpView.swift      # 注册界面
│   ├── Scanner/
│   │   ├── ScannerView.swift     # 扫描主界面
│   │   ├── CameraPreview.swift   # 相机预览组件
│   │   └── MerchantSelector.swift # 商家选择器
│   └── History/
│       ├── HistoryListView.swift # 扫描历史列表
│       └── ScanDetailView.swift  # 扫描详情页
├── ViewModels/
│   ├── AuthViewModel.swift       # 认证逻辑
│   ├── ScannerViewModel.swift    # 扫描逻辑
│   └── HistoryViewModel.swift    # 历史记录逻辑
├── Services/
│   ├── CameraService.swift       # 相机服务
│   ├── BarcodeDetector.swift     # 条形码检测服务
│   ├── LocationService.swift     # 位置服务
│   ├── DataService.swift         # 数据存储服务
│   └── CSVExporter.swift         # CSV导出服务
└── Utilities/
    ├── LocalStorage.swift        # 本地存储工具
    ├── PermissionManager.swift   # 权限管理
    └── NetworkMonitor.swift      # 网络状态监控
```

---

## 核心功能模块

### 1. Firebase Authentication (Email/Password)

**功能描述**:
- 用户注册（Email + Password）
- 用户登录
- 用户登出
- 自动保持登录状态
- 用于工资结算：根据用户名统计扫描数量和工作时间

**技术实现**:
- 使用 `FirebaseAuth` SDK
- 配置 `GoogleService-Info.plist`
- 创建 `LoginView` 和 `SignUpView`
- 使用 `AuthViewModel` 管理认证状态
- 在App启动时检查登录状态

**注意事项**:
- 第一阶段仅使用Firebase做用户认证
- **不使用Firebase存储照片**（本地存储优先）

---

### 2. 条形码扫描 + 自动拍照

**功能描述**:
- 实时相机预览
- 使用Vision Framework自动识别条形码
- 识别成功后立即拍照
- 震动/声音反馈
- UI提示用户移动到下一个条形码

**技术实现**:
```swift
// 相机配置
AVCaptureSession + AVCaptureDevice (后置相机)

// 条形码识别
Vision Framework:
- VNDetectBarcodesRequest
- VNBarcodeObservation

// 自动拍照
AVCapturePhotoOutput
```

**扫描流程**:
1. 用户打开扫描界面 → 选择商家
2. 相机实时预览 + Vision实时检测
3. 识别到条形码 → 震动反馈
4. 自动拍照 → 保存照片 + 记录数据
5. UI提示"已保存，请扫描下一个"
6. 继续扫描...

---

### 3. 数据采集 & 本地存储

#### 数据字段

每次扫描记录包含以下信息：

| 字段名 | 说明 | 数据来源 |
|--------|------|----------|
| Scan_ID | 唯一标识符 | UUID自动生成 |
| Username | 用户名 | Firebase Auth |
| Timestamp | 扫描时间 | 系统时间（ISO 8601格式） |
| Merchant | 商家名称 | 用户下拉选择 |
| Barcode | 条形码内容 | Vision Framework |
| Latitude | 纬度 | CoreLocation (可选) |
| Longitude | 经度 | CoreLocation (可选) |
| Image_Filename | 照片文件名 | 本地存储路径 |
| Store_Location | 门店位置 | GPS反向地理编码 |

#### 数据格式示例

```csv
Scan_ID,Username,Timestamp,Merchant,Barcode,Latitude,Longitude,Image_Filename,Store_Location
abc123,John,2025-01-15 14:30:00,Walmart,012345678901,34.0522,-118.2437,scan_abc123.jpg,"Los Angeles, CA"
def456,John,2025-01-15 14:30:15,Walmart,987654321098,34.0522,-118.2437,scan_def456.jpg,"Los Angeles, CA"
```

#### ScanRecord数据模型

```swift
struct ScanRecord: Codable, Identifiable {
    let id: String              // Scan_ID (UUID)
    let username: String        // 用户名
    let timestamp: Date         // 扫描时间
    let merchant: String        // 商家名称
    let barcode: String         // 条形码数据
    let latitude: Double?       // 纬度（可选）
    let longitude: Double?      // 经度（可选）
    let imageFilename: String   // 照片文件名
    let storeLocation: String?  // 门店位置（可选）
    var isSynced: Bool = false  // 是否已同步
}
```

#### 本地存储方案

**照片存储**:
- 位置: `Documents/ScanImages/`
- 命名规则: `scan_{UUID}.jpg`
- 格式: JPEG（原始分辨率，无水印）

**元数据存储**:
- 位置: `Documents/ScanRecords.json`
- 格式: JSON数组
- 支持离线读写

**存储逻辑**:
```swift
// 保存流程
1. 拍照 → 保存到 Documents/ScanImages/
2. 获取GPS坐标 → 反向地理编码
3. 创建 ScanRecord 对象
4. 追加到 ScanRecords.json
5. 更新UI（扫描计数+1）
```

---

### 4. 照片处理要求

**关键原则**: 保留干净的图片用于后续机器学习(ML)任务

**实现方案**:
- ✅ 照片保持**完全原始**，无任何水印或文字覆盖
- ✅ 元数据（用户名、时间戳、商家、GPS）仅记录在CSV中
- ✅ 照片和元数据通过 `Image_Filename` 字段关联

**不需要实现**:
- ❌ 在照片上添加文字标注
- ❌ 在照片上添加水印
- ❌ 压缩或修改照片分辨率

---

### 5. 扫描历史列表

**功能描述**:
- 显示当前用户的所有扫描记录
- 按时间倒序排列（最新的在前）
- 缩略图预览 + 元数据信息
- 点击查看详情（大图 + 完整信息）

**UI设计**:
```
┌─────────────────────────────────┐
│  扫描历史 (共123条)    [导出CSV] │
├─────────────────────────────────┤
│ ┌───┐  Walmart                  │
│ │img│  012345678901              │
│ └───┘  2025-10-22 14:30  ☁️已同步│
├─────────────────────────────────┤
│ ┌───┐  Target                   │
│ │img│  987654321098              │
│ └───┘  2025-10-22 14:28  📤待上传│
└─────────────────────────────────┘
```

**功能点**:
- 显示同步状态图标（已同步☁️ / 待上传📤）
- 下拉刷新
- 搜索/筛选（按商家、日期）

---

### 6. CSV导出 & 分享

**功能描述**:
- 从历史记录生成CSV文件
- 通过邮件分享给管理员进行质量检查(QA)

**CSV格式**:
```csv
Scan_ID,Username,Timestamp,Merchant,Barcode,Latitude,Longitude,Image_Filename,Store_Location
abc123,John,2025-01-15 14:30:00,Walmart,012345678901,34.0522,-118.2437,scan_abc123.jpg,"Los Angeles, CA"
```

**实现方式**:
```swift
// CSV生成
CSVExporter.export(records: [ScanRecord]) -> URL

// 分享
UIActivityViewController
- 邮件
- AirDrop
- 保存到文件
```

**注意事项**:
- CSV文件保存到 `Documents/Exports/`
- 文件名: `scan_export_{timestamp}.csv`
- UTF-8编码（支持中文）

---

### 7. 权限管理

**需要的权限**:

#### 1. 相机权限（必需）
```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相机扫描货架标签条形码</string>
```

#### 2. 位置权限（可选，使用时请求）
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>记录扫描位置信息，帮助管理门店数据</string>
```

**权限请求流程**:
1. App首次启动 → 请求相机权限
2. 开始扫描时 → 请求位置权限（可选）
3. 权限被拒绝 → 显示引导界面，提示用户前往设置开启

---

### 8. 网络同步机制（预留接口）

**离线优先策略**:
- 所有数据首先保存到本地
- 支持完全离线工作（地下室、无网络环境）
- 有网络时自动/手动同步

**同步逻辑**:
```swift
// 1. 检测网络状态
NetworkMonitor (Combine + NWPathMonitor)

// 2. 自动同步触发条件
- 检测到WiFi连接
- App进入前台且有待同步数据

// 3. 手动同步
- 用户点击"立即同步"按钮
- 上传所有 isSynced = false 的记录

// 4. 同步状态
- 待上传 (Pending)
- 同步中 (Syncing)
- 已同步 (Synced)
- 失败 (Failed)
```

**后端API接口（预留）**:
```
POST /api/scans
Body: {
  "scan_id": "abc123",
  "username": "John",
  "timestamp": "2025-01-15T14:30:00Z",
  "merchant": "Walmart",
  "barcode": "012345678901",
  "latitude": 34.0522,
  "longitude": -118.2437,
  "store_location": "Los Angeles, CA",
  "image_base64": "..."  // 或者先上传图片获取URL
}
```

**注意**: 第一阶段仅实现本地存储和CSV导出，云端同步功能保留架构但暂不实现。

---

### 9. 商家下拉列表

**商家选项（示例，可后续修改）**:
```swift
let merchants = [
    "Walmart",
    "Target",
    "Costco",
    "Kroger"
]
```

**UI实现**:
- 使用 `Picker` 或 `Menu` 组件
- 扫描前必须选择商家
- 选择后缓存，下次扫描自动使用上次选择

**扩展性**:
- 商家列表可通过配置文件修改
- 未来可支持从服务器动态获取

---

## 边界情况和异常处理

### 概述

为确保App在各种真实场景下稳定运行，需要处理以下边界情况和异常。优先级标注：
- ⭐⭐⭐ **高优先级**（MVP必须实现）
- ⭐⭐ **中优先级**（增强用户体验）
- ⭐ **低优先级**（未来优化）

---

### 1. 扫描流程中的边界情况

#### 1.1 距离检测 ⭐⭐⭐

**问题**: 用户距离条形码过远或过近，导致识别失败或图片模糊

**实现方案**:
```swift
// 检测条形码在画面中的大小
let barcodeSize = barcode.boundingBox.size

// 距离过远：条形码太小
if barcodeSize.width < 0.15 || barcodeSize.height < 0.08 {
    showHint("靠近条形码 / Move closer to barcode")
    highlightColor = .yellow
}

// 距离过近：条形码超出对焦范围
else if barcodeSize.width > 0.9 || barcodeSize.height > 0.7 {
    showHint("稍微远离 / Move back a bit")
    highlightColor = .orange
}

// 距离合适
else {
    showHint("按住拍摄 / Hold to scan")
    highlightColor = .green
}
```

**UI设计**:
- 显示虚线参考框，引导用户将条形码放入框内
- 条形码边框颜色实时变化：
  - 🟢 绿色 = 距离合适
  - 🟡 黄色 = 太远
  - 🟠 橙色 = 太近
  - 🔴 红色 = 无法识别

---

#### 1.2 光线检测 ⭐⭐⭐

**问题**: 光线不足导致条形码无法识别或图片过暗

**实现方案**:
```swift
// 使用 AVCaptureDevice 获取环境光线
let device = AVCaptureDevice.default(for: .video)

// 光线检测（通过图像亮度分析）
func detectLowLight(from image: CIImage) -> Bool {
    let extent = image.extent
    let averageBrightness = image.applyingFilter("CIAreaAverage",
                                                  parameters: [kCIInputExtentKey: extent])
    return averageBrightness < threshold
}

// 提示用户
if isLowLight {
    showAlert("光线不足，建议打开闪光灯")
    showFlashlightButton = true
}
```

**UI元素**:
- 手电筒快捷按钮（右上角）
- 图标：💡 关闭 / 🔦 开启
- 自动建议：光线不足时自动提示

---

#### 1.3 重复扫描防抖 ⭐⭐⭐

**问题**: 同一条形码在短时间内被重复扫描，产生冗余数据

**实现方案**:
```swift
// 防抖机制
var lastScannedBarcode: String?
var lastScanTime: Date?

func shouldAllowScan(barcode: String) -> Bool {
    guard let lastBarcode = lastScannedBarcode,
          let lastTime = lastScanTime else {
        return true  // 首次扫描
    }

    // 相同条形码且在5秒内
    if barcode == lastBarcode && Date().timeIntervalSince(lastTime) < 5.0 {
        showWarning("刚刚已扫描此条形码")
        vibrateError()
        return false
    }

    return true
}

// 智能重复检测
func checkDuplicate(barcode: String, merchant: String, location: CLLocation?) -> Bool {
    let recentScans = dataService.getScans(within: 24.hours)

    return recentScans.contains { scan in
        scan.barcode == barcode &&
        scan.merchant == merchant &&
        scan.location?.distance(from: location) ?? 1000 < 50  // 50米内
    }
}

// 提示用户
if isDuplicate {
    showAlert("可能重复：该条形码今天已在此位置扫描过") {
        Button("确认重新扫描") { forceScan() }
        Button("取消") { dismissAlert() }
    }
}
```

**防抖策略**:
- **短期防抖**: 5秒内同一条形码不重复扫描
- **智能去重**: 24小时内相同条形码+相同商家+相同位置（50米内）→ 提示确认
- **视觉反馈**: 重复扫描时显示红色边框 + 震动提示

---

#### 1.4 识别质量检测 ⭐⭐

**问题**: 条形码损坏、污损、遮挡或反光导致识别不准确

**实现方案**:
```swift
// Vision Framework 置信度检测
func validateBarcodeQuality(_ observation: VNBarcodeObservation) -> Bool {
    // 置信度检查
    guard observation.confidence > 0.7 else {
        showHint("条形码不清晰，请调整角度")
        return false
    }

    // 检测反光（高光区域占比）
    if hasHighlight(in: capturedImage, region: observation.boundingBox) {
        showHint("避免反光，请调整角度")
        return false
    }

    return true
}

// 高光检测
func hasHighlight(in image: CIImage, region: CGRect) -> Bool {
    let croppedImage = image.cropped(to: region)
    let histogram = croppedImage.applyingFilter("CIAreaHistogram")

    // 检测过曝像素比例
    let overexposedRatio = calculateOverexposedRatio(histogram)
    return overexposedRatio > 0.3  // 超过30%认为有反光
}
```

**用户提示**:
- 置信度低 < 0.5: "条形码不清晰"
- 置信度中 0.5-0.7: "请保持稳定"
- 置信度高 > 0.7: 自动拍照
- 反光检测: "避免反光，请调整角度"

---

#### 1.5 多条形码场景 ⭐⭐

**问题**: 画面中同时出现多个条形码，用户不知道扫描的是哪一个

**实现方案**:
```swift
// 多条形码处理
func handleMultipleBarcodes(_ observations: [VNBarcodeObservation]) {
    guard observations.count > 1 else {
        return handleSingleBarcode(observations.first!)
    }

    // 策略1: 选择最接近画面中心的条形码
    let centerBarcode = observations.min(by: { obs1, obs2 in
        let center = CGPoint(x: 0.5, y: 0.5)
        let dist1 = distance(from: obs1.boundingBox.center, to: center)
        let dist2 = distance(from: obs2.boundingBox.center, to: center)
        return dist1 < dist2
    })

    // 高亮显示选中的条形码
    highlightBarcode(centerBarcode)

    // 提示用户
    showHint("检测到 \(observations.count) 个条形码，已选择中心的")
}

// 策略2: 让用户选择（可选）
func showBarcodeSelector(_ barcodes: [VNBarcodeObservation]) {
    // 在画面上标注每个条形码编号
    for (index, barcode) in barcodes.enumerated() {
        drawLabel("\(index + 1)", at: barcode.boundingBox)
    }
    showHint("点击要扫描的条形码")
}
```

**UI反馈**:
- 所有检测到的条形码显示灰色边框
- 当前选中的条形码显示绿色边框
- 顶部提示："检测到3个条形码"

---

#### 1.6 无条形码超时 ⭐⭐

**问题**: 用户对着空白区域扫描很久，没有引导提示

**实现方案**:
```swift
// 扫描超时检测
var scanningStartTime: Date?
var noBarcodeDetectionCount = 0

func checkScanTimeout() {
    guard let startTime = scanningStartTime else { return }

    let duration = Date().timeIntervalSince(startTime)

    // 10秒未检测到条形码
    if duration > 10.0 && noBarcodeDetectionCount > 30 {
        showHelpDialog()
    }
}

func showHelpDialog() {
    Alert(title: "未检测到条形码") {
        Button("手动输入条形码") { showManualInputView() }
        Button("继续扫描") { resetScanTimer() }
        Button("跳过") { dismissScanner() }
    }
}

// 手动输入功能
struct ManualBarcodeInputView: View {
    @State private var barcodeInput = ""

    var body: some View {
        VStack {
            Text("手动输入条形码")
            TextField("请输入条形码数字", text: $barcodeInput)
                .keyboardType(.numberPad)
            Button("确认") {
                if validateBarcode(barcodeInput) {
                    manualCapture(barcode: barcodeInput)
                }
            }
        }
    }
}
```

**触发条件**:
- 扫描时间 > 10秒
- 检测帧数 > 30 帧（假设每秒3帧）
- 未识别到任何条形码

---

### 2. 相机和硬件相关边界情况

#### 2.1 相机会话中断 ⭐⭐⭐

**问题**: 相机被其他App占用、来电、视频通话、系统限制等

**实现方案**:
```swift
// 监听会话中断
NotificationCenter.default.addObserver(
    forName: .AVCaptureSessionWasInterrupted,
    object: captureSession,
    queue: .main
) { notification in
    guard let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey]
                       as? AVCaptureSession.InterruptionReason else { return }

    switch reason {
    case .videoDeviceNotAvailableWithMultipleForegroundApps:
        showToast("相机被其他应用占用")
    case .videoDeviceInUseByAnotherClient:
        showToast("相机正在使用中")
    case .audioDeviceInUseByAnotherClient:
        // 音频冲突不影响扫描
        break
    @unknown default:
        showToast("相机暂时不可用")
    }

    pauseScanning()
}

// 监听会话恢复
NotificationCenter.default.addObserver(
    forName: .AVCaptureSessionInterruptionEnded,
    object: captureSession,
    queue: .main
) { _ in
    showToast("相机已恢复，可以继续扫描")
    resumeScanning()
}

// 运行时错误
NotificationCenter.default.addObserver(
    forName: .AVCaptureSessionRuntimeError,
    object: captureSession,
    queue: .main
) { notification in
    guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }

    if error.code == .mediaServicesWereReset {
        // 重新初始化会话
        restartCaptureSession()
    } else {
        showError("相机出现错误: \(error.localizedDescription)")
    }
}
```

**用户提示**:
- 中断时: "扫描已暂停（来电/其他应用）"
- 恢复时: "可以继续扫描"
- 错误时: "相机出现错误，请重启应用"

---

#### 2.2 对焦失败 ⭐⭐

**问题**: 自动对焦失败（距离不合适、环境太暗、物体移动）

**实现方案**:
```swift
// 对焦监控
var focusStartTime: Date?

func configureFocus() {
    guard let device = AVCaptureDevice.default(for: .video) else { return }

    do {
        try device.lockForConfiguration()

        // 设置自动对焦
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }

        // 监听对焦状态
        device.addObserver(self, forKeyPath: "adjustingFocus", options: .new, context: nil)

        device.unlockForConfiguration()
    } catch {
        showError("对焦配置失败")
    }
}

// 对焦状态监听
override func observeValue(forKeyPath keyPath: String?,
                          of object: Any?,
                          change: [NSKeyValueChangeKey : Any]?,
                          context: UnsafeMutableRawPointer?) {
    if keyPath == "adjustingFocus" {
        let device = object as! AVCaptureDevice

        if device.isAdjustingFocus {
            focusStartTime = Date()
            showHint("对焦中...")
        } else {
            // 对焦完成
            if let startTime = focusStartTime,
               Date().timeIntervalSince(startTime) > 3.0 {
                showHint("对焦困难，请调整距离或光线")
            }
            focusStartTime = nil
        }
    }
}

// 手动对焦（点击屏幕）
func focusAtPoint(_ point: CGPoint) {
    guard let device = AVCaptureDevice.default(for: .video) else { return }

    do {
        try device.lockForConfiguration()

        if device.isFocusModeSupported(.autoFocus) {
            device.focusMode = .autoFocus
            device.focusPointOfInterest = point
        }

        device.unlockForConfiguration()

        showFocusIndicator(at: point)
    } catch {
        showError("手动对焦失败")
    }
}
```

**用户交互**:
- 对焦时间 > 3秒 → 提示"对焦困难，请调整距离"
- 提供手动对焦：点击屏幕对焦
- 显示对焦指示器（方框动画）

---

#### 2.3 设备兼容性 ⭐

**问题**: 旧设备性能不足、没有后置相机（极少见）

**实现方案**:
```swift
// 启动时设备检测
func checkDeviceCapability() {
    // 检查后置相机
    guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
        showError("该设备不支持扫描功能（无后置相机）")
        disableScannerFeature()
        return
    }

    // 检查设备性能
    let device = UIDevice.current

    // iOS 版本检查
    if #available(iOS 14.0, *) {
        // 正常使用
    } else {
        showWarning("系统版本过低，可能存在兼容性问题")
    }

    // 设备型号检测（可选）
    if isOldDevice() {
        enablePerformanceMode()
    }
}

func isOldDevice() -> Bool {
    // 检测处理器或设备型号
    var systemInfo = utsname()
    uname(&systemInfo)
    let modelCode = String(cString: withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) { $0 }
    })

    // iPhone 6s 及更早型号
    let oldDevices = ["iPhone8,1", "iPhone8,2", "iPhone7,1", "iPhone7,2"]
    return oldDevices.contains(modelCode)
}

func enablePerformanceMode() {
    // 降级策略
    barcodeDetectionFrequency = 1  // 每秒1次（默认3次）
    photoQuality = 0.7  // 降低照片质量
    showToast("已启用性能优化模式")
}
```

**降级策略**:
- 扫描频率: 3次/秒 → 1次/秒
- 照片质量: 0.9 → 0.7
- 禁用部分动画效果

---

#### 2.4 内存和性能管理 ⭐⭐

**问题**: 长时间扫描导致内存泄漏、UI卡顿

**实现方案**:
```swift
// 内存监控
var scanCount = 0

func monitorMemoryUsage() {
    let memoryUsage = getMemoryUsage()

    if memoryUsage > 500_000_000 { // 500MB
        showWarning("内存使用较高，建议重启应用")
        clearCache()
    }
}

func getMemoryUsage() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    return kerr == KERN_SUCCESS ? info.resident_size : 0
}

// 定期清理
func clearCache() {
    // 清理临时文件
    let tempDir = FileManager.default.temporaryDirectory
    try? FileManager.default.removeItem(at: tempDir)

    // 释放图片缓存
    imageCache.removeAllObjects()

    scanCount = 0
}

// 每50次扫描自动清理
func afterScanComplete() {
    scanCount += 1

    if scanCount % 50 == 0 {
        DispatchQueue.global(qos: .background).async {
            self.clearCache()
        }
    }
}

// 拍照优化：后台处理
func capturePhoto() {
    photoOutput.capturePhoto(with: settings, delegate: self)

    // 拍照时暂停条形码检测，避免卡顿
    pauseBarcodeDetection()
}

func photoOutput(_ output: AVCapturePhotoOutput,
                didFinishProcessingPhoto photo: AVCapturePhoto,
                error: Error?) {
    // 后台处理图片
    DispatchQueue.global(qos: .userInitiated).async {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }

        // 压缩图片
        let compressedData = image.jpegData(compressionQuality: 0.85)

        // 保存到磁盘
        self.savePhoto(compressedData)

        DispatchQueue.main.async {
            // 恢复条形码检测
            self.resumeBarcodeDetection()
        }
    }
}
```

**优化策略**:
- 每50次扫描清理缓存
- 拍照时暂停检测，避免UI卡顿
- 图片处理使用后台队列
- 内存超过500MB时提示用户

---

### 3. 数据存储和网络相关边界情况

#### 3.1 存储空间不足 ⭐⭐⭐

**问题**: 照片占用大量存储空间，导致无法继续扫描

**实现方案**:
```swift
// 存储空间检测
func checkStorageSpace() -> StorageStatus {
    let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)

    do {
        let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])

        if let capacity = values.volumeAvailableCapacityForImportantUsage {
            let capacityMB = capacity / 1_048_576  // 转换为MB

            if capacityMB < 500 {
                return .critical  // 禁止扫描
            } else if capacityMB < 1000 {
                return .warning  // 警告
            } else {
                return .normal
            }
        }
    } catch {
        return .unknown
    }

    return .unknown
}

enum StorageStatus {
    case normal, warning, critical, unknown
}

// 扫描前检查
func beforeScan() {
    let status = checkStorageSpace()

    switch status {
    case .critical:
        showAlert("存储空间不足") {
            Text("剩余空间低于500MB，无法继续扫描")
            Button("清理空间") { showStorageManager() }
            Button("取消") { dismissScanner() }
        }
        disableScanning = true

    case .warning:
        showToast("存储空间不足1GB，建议清理")
        showStorageIndicator = true

    case .normal:
        break

    case .unknown:
        showToast("无法检测存储空间")
    }
}

// 存储管理界面
struct StorageManagerView: View {
    @State private var totalScans = 0
    @State private var syncedScans = 0
    @State private var usedSpace: Int64 = 0

    var body: some View {
        List {
            Section("存储使用情况") {
                HStack {
                    Text("总扫描记录")
                    Spacer()
                    Text("\(totalScans) 条")
                }
                HStack {
                    Text("已同步记录")
                    Spacer()
                    Text("\(syncedScans) 条")
                }
                HStack {
                    Text("占用空间")
                    Spacer()
                    Text("\(usedSpace / 1_048_576) MB")
                }
            }

            Section("清理选项") {
                Button("删除已同步的照片") {
                    deleteSyncedPhotos()
                }
                Button("压缩未同步的照片") {
                    compressPhotos()
                }
                Button("导出并清空数据") {
                    exportAndClear()
                }
            }
        }
    }
}
```

**阈值策略**:
- **< 500MB** (🔴 Critical): 禁止扫描，强制清理
- **500MB - 1GB** (🟡 Warning): 警告提示，允许继续
- **> 1GB** (🟢 Normal): 正常使用

**清理选项**:
1. 删除已同步的照片（释放空间）
2. 压缩未同步的照片（质量0.85 → 0.7）
3. 导出CSV + 照片压缩包后清空
4. 查看存储详情

---

#### 3.2 数据损坏和恢复 ⭐⭐⭐

**问题**: JSON文件损坏、App崩溃导致数据丢失

**实现方案**:
```swift
// 原子写入（防止写入中断导致损坏）
func saveScanRecords(_ records: [ScanRecord]) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    let data = try encoder.encode(records)

    // 先写入临时文件
    let tempURL = recordsURL.appendingPathExtension("tmp")
    try data.write(to: tempURL, options: .atomic)

    // 原子替换
    _ = try FileManager.default.replaceItemAt(recordsURL,
                                               withItemAt: tempURL,
                                               backupItemName: "backup")
}

// 启动时数据验证
func validateDataIntegrity() {
    do {
        // 尝试读取主文件
        let records = try loadScanRecords()

        // 验证数据完整性
        for record in records {
            // 检查照片是否存在
            let imageURL = imageDirectory.appendingPathComponent(record.imageFilename)
            if !FileManager.default.fileExists(atPath: imageURL.path) {
                missingImages.append(record.id)
            }
        }

        if !missingImages.isEmpty {
            showWarning("发现\(missingImages.count)条记录的照片丢失")
        }

    } catch {
        // 主文件损坏，尝试恢复备份
        recoverFromBackup()
    }
}

// 从备份恢复
func recoverFromBackup() {
    let backupURL = recordsURL.appendingPathExtension("backup")

    if FileManager.default.fileExists(atPath: backupURL.path) {
        do {
            try FileManager.default.copyItem(at: backupURL, to: recordsURL)
            showAlert("数据已从备份恢复")
        } catch {
            showError("数据恢复失败，请联系支持")
        }
    } else {
        // 无备份，创建新文件
        try? saveScanRecords([])
        showAlert("无法恢复数据，已重新初始化")
    }
}

// 增量备份（每10条记录）
var recordsSinceLastBackup = 0

func afterRecordSaved() {
    recordsSinceLastBackup += 1

    if recordsSinceLastBackup >= 10 {
        createIncrementalBackup()
        recordsSinceLastBackup = 0
    }
}

func createIncrementalBackup() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
    let timestamp = dateFormatter.string(from: Date())

    let backupURL = backupDirectory.appendingPathComponent("backup_\(timestamp).json")

    try? FileManager.default.copyItem(at: recordsURL, to: backupURL)

    // 保留最近3天的备份
    cleanOldBackups(keepDays: 3)
}

func cleanOldBackups(keepDays: Int) {
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -keepDays, to: Date())!

    let backups = try? FileManager.default.contentsOfDirectory(at: backupDirectory,
                                                                includingPropertiesForKeys: [.creationDateKey])

    backups?.forEach { url in
        if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
           creationDate < cutoffDate {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
```

**数据保护策略**:
1. **原子写入**: 使用临时文件 + 原子替换
2. **自动备份**: 每10条记录创建增量备份
3. **备份保留**: 保留最近3天的备份
4. **启动验证**: App启动时检查数据完整性
5. **崩溃恢复**: 自动从最近备份恢复

---

#### 3.3 CSV导出异常 ⭐⭐

**问题**: 特殊字符、大数据量、编码问题

**实现方案**:
```swift
// CSV导出增强
func exportToCSV(records: [ScanRecord]) throws -> URL {
    // 大数据量检测
    if records.count > 10000 {
        return try exportLargeDataset(records)
    }

    var csvString = "Scan_ID,Username,Timestamp,Merchant,Barcode,Latitude,Longitude,Image_Filename,Store_Location\n"

    for record in records {
        let row = [
            record.id,
            record.username,
            formatTimestamp(record.timestamp),
            escapeCSVField(record.merchant),
            record.barcode,
            String(format: "%.6f", record.latitude ?? 0),
            String(format: "%.6f", record.longitude ?? 0),
            record.imageFilename,
            escapeCSVField(record.storeLocation ?? "")
        ].joined(separator: ",")

        csvString += row + "\n"
    }

    // UTF-8编码（支持中文）
    guard let data = csvString.data(using: .utf8) else {
        throw CSVError.encodingFailed
    }

    let filename = "scan_export_\(Date().timeIntervalSince1970).csv"
    let fileURL = exportDirectory.appendingPathComponent(filename)

    try data.write(to: fileURL, options: .atomic)

    return fileURL
}

// CSV字段转义
func escapeCSVField(_ field: String) -> String {
    // 包含逗号、换行符或引号时需要转义
    if field.contains(",") || field.contains("\n") || field.contains("\"") {
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    return field
}

// 大数据集导出（分批）
func exportLargeDataset(_ records: [ScanRecord]) throws -> URL {
    showProgress("正在导出大量数据...")

    let batchSize = 1000
    var allCSVData = Data()

    // 添加CSV头
    let header = "Scan_ID,Username,Timestamp,Merchant,Barcode,Latitude,Longitude,Image_Filename,Store_Location\n"
    allCSVData.append(header.data(using: .utf8)!)

    // 分批处理
    for i in stride(from: 0, to: records.count, by: batchSize) {
        let batch = Array(records[i..<min(i + batchSize, records.count)])
        let batchCSV = generateCSVRows(batch)
        allCSVData.append(batchCSV)

        updateProgress(Float(i) / Float(records.count))
    }

    let filename = "scan_export_large_\(Date().timeIntervalSince1970).csv"
    let fileURL = exportDirectory.appendingPathComponent(filename)
    try allCSVData.write(to: fileURL)

    hideProgress()
    return fileURL
}

// 导出前预览
struct ExportPreviewView: View {
    let records: [ScanRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导出确认")
                .font(.title2)

            Group {
                HStack {
                    Text("总记录数:")
                    Spacer()
                    Text("\(records.count) 条")
                }

                HStack {
                    Text("日期范围:")
                    Spacer()
                    Text("\(dateRange)")
                }

                HStack {
                    Text("文件大小:")
                    Spacer()
                    Text("\(estimatedSize) MB")
                }
            }

            Spacer()

            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("确认导出") { performExport() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

**导出增强**:
- **特殊字符处理**: 转义逗号、换行符、引号
- **大数据分批**: 超过10000条记录分批处理
- **UTF-8编码**: 支持中文等多语言
- **导出预览**: 显示记录数、日期范围、文件大小
- **进度显示**: 大数据导出显示进度条

---

#### 3.4 GPS定位异常 ⭐⭐⭐

**问题**: 室内信号弱、定位超时、精度差

**实现方案**:
```swift
// GPS定位增强
class LocationService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationTimeout: Timer?
    private var completion: ((CLLocation?) -> Void)?

    func requestLocation(timeout: TimeInterval = 5.0,
                        completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion

        // 配置定位精度
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.delegate = self

        // 开始定位
        locationManager.requestLocation()

        // 设置超时
        locationTimeout = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.handleLocationTimeout()
        }
    }

    func locationManager(_ manager: CLLocationManager,
                        didUpdateLocations locations: [CLLocation]) {
        locationTimeout?.invalidate()

        guard let location = locations.last else {
            completion?(nil)
            return
        }

        // 检查定位精度
        if location.horizontalAccuracy > 100 {
            showWarning("定位精度较低（误差\(Int(location.horizontalAccuracy))米）")
        }

        completion?(location)
    }

    func locationManager(_ manager: CLLocationManager,
                        didFailWithError error: Error) {
        locationTimeout?.invalidate()

        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                showAlert("定位权限被拒绝，GPS数据将为空")
            case .locationUnknown:
                // 使用上次位置
                completion?(getLastKnownLocation())
            case .network:
                showToast("网络定位失败，使用近似位置")
                completion?(getLastKnownLocation())
            default:
                completion?(nil)
            }
        }
    }

    private func handleLocationTimeout() {
        showToast("定位超时，使用上次位置")
        completion?(getLastKnownLocation())
    }

    private func getLastKnownLocation() -> CLLocation? {
        // 从UserDefaults读取上次位置
        guard let data = UserDefaults.standard.data(forKey: "lastKnownLocation"),
              let location = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CLLocation.self,
                from: data) else {
            return nil
        }
        return location
    }

    private func saveLastKnownLocation(_ location: CLLocation) {
        if let data = try? NSKeyedArchiver.archivedData(
            withRootObject: location,
            requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: "lastKnownLocation")
        }
    }
}

// 定位场景处理
func handleLocationScenarios(_ location: CLLocation?) {
    if let loc = location {
        // 场景1: 成功定位
        if loc.horizontalAccuracy <= 50 {
            statusIcon = "📍"  // 精确定位
        } else if loc.horizontalAccuracy <= 100 {
            statusIcon = "📌"  // 一般精度
        } else {
            statusIcon = "📍?"  // 低精度
            showToast("定位精度较低")
        }

        // 反向地理编码
        reverseGeocode(location: loc) { placemark in
            storeLocation = formatPlacemark(placemark)
        }

    } else {
        // 场景2: 定位失败
        statusIcon = "❓"
        latitude = nil
        longitude = nil
        storeLocation = "Unknown"

        // 不阻塞扫描
        allowScanWithoutLocation = true
    }
}
```

**定位场景细化**:

| 场景 | 处理策略 | 用户提示 |
|------|---------|---------|
| 室内/地下室 | 5秒超时 → 使用上次位置 | "定位超时，使用近似位置" |
| 精度差 (>100m) | 标记低精度 + 继续扫描 | "定位精度较低（误差150米）" |
| 权限禁用 | GPS字段留空 + 不阻塞 | 图标显示 "❓" |
| 系统定位关闭 | 引导用户设置 + 不阻塞 | "定位服务已关闭" |
| 首次定位 | 显示加载动画 | "正在获取位置..." |

---

#### 3.5 网络状态切换 ⭐⭐

**问题**: WiFi切换到蜂窝、网络中断

**实现方案**:
```swift
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected = false
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false

    enum ConnectionType {
        case wifi, cellular, ethernet, unknown
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.updateConnectionType(path)
                self?.handleConnectionChange(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }

    private func handleConnectionChange(_ path: NWPath) {
        if path.status == .satisfied {
            // 有网络
            if connectionType == .wifi {
                showToast("已连接WiFi，可自动同步")
                autoSyncIfNeeded()
            } else if connectionType == .cellular {
                // WiFi → 蜂窝
                if shouldPromptForCellularSync {
                    askUserAboutCellularSync()
                }
            }
        } else {
            // 无网络
            showToast("已切换到离线模式")
            updateUIForOfflineMode()
        }
    }

    func askUserAboutCellularSync() {
        Alert(title: "使用移动数据同步？") {
            Text("当前使用移动数据网络，同步可能产生流量费用")
            Button("仅WiFi同步") {
                UserDefaults.standard.set(true, forKey: "wifiOnlySync")
            }
            Button("使用流量") {
                startSync()
            }
            Button("暂停同步") {
                pauseSync()
            }
        }
    }
}

// 网络状态图标
func getNetworkStatusIcon() -> String {
    if !networkMonitor.isConnected {
        return "📵"  // 离线
    } else if networkMonitor.connectionType == .wifi {
        return "📶"  // WiFi
    } else {
        return "📡"  // 蜂窝
    }
}
```

**网络切换场景**:
- **WiFi → 蜂窝**: 询问是否继续同步
- **有网 → 无网**: 提示"离线模式" + 图标变化
- **无网 → 有网**: 提示"已恢复网络" + 询问是否同步
- **流量控制**: 仅WiFi同步选项

---

### 4. 用户体验和权限相关边界情况

#### 4.1 权限撤销处理 ⭐⭐⭐

**问题**: 用户在使用过程中撤销权限

**实现方案**:
```swift
// 权限状态监控
class PermissionManager: ObservableObject {
    @Published var cameraAuthorized = false
    @Published var locationAuthorized = false

    func startMonitoring() {
        // 监听应用进入前台
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAllPermissions()
        }

        // 初始检查
        checkAllPermissions()
    }

    func checkAllPermissions() {
        checkCameraPermission()
        checkLocationPermission()
    }

    func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            cameraAuthorized = true

        case .denied, .restricted:
            cameraAuthorized = false
            showCameraPermissionGuide()

        case .notDetermined:
            requestCameraPermission()

        @unknown default:
            break
        }
    }

    func checkLocationPermission() {
        let manager = CLLocationManager()
        let status = manager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationAuthorized = true

        case .denied, .restricted:
            locationAuthorized = false
            // 不阻塞扫描，仅显示提示
            showLocationPermissionHint()

        case .notDetermined:
            requestLocationPermission()

        @unknown default:
            break
        }
    }

    func showCameraPermissionGuide() {
        Alert(title: "需要相机权限") {
            Text("扫描功能需要使用相机，请在设置中开启权限")
            Button("前往设置") {
                openAppSettings()
            }
            Button("取消") {
                dismiss()
            }
        }
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// 运行时权限变化检测
func handlePermissionChange() {
    // 相机权限被撤销
    if !permissionManager.cameraAuthorized && isScanning {
        pauseScanning()
        showAlert("相机权限已被撤销，扫描已暂停")
    }

    // 相机权限被重新授予
    if permissionManager.cameraAuthorized && wasPausedDueToPermission {
        resumeScanning()
        showToast("权限已恢复，可以继续扫描")
    }

    // 位置权限变化（不阻塞扫描）
    if !permissionManager.locationAuthorized {
        showLocationDisabledIcon()
    }
}
```

**权限引导界面**:
```swift
struct PermissionGuideView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("需要相机权限")
                .font(.title2)
                .bold()

            Text("扫描货架标签需要使用相机功能")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("1.")
                    Text("点击下方"前往设置"按钮")
                }
                HStack {
                    Text("2.")
                    Text("找到"相机"选项")
                }
                HStack {
                    Text("3.")
                    Text("开启相机权限")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            Button("前往设置") {
                openAppSettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

---

#### 4.2 账户管理 ⭐⭐

**问题**: 登出、切换账户时的数据处理

**实现方案**:
```swift
// 登出处理
func handleLogout() {
    // 检查未同步数据
    let unsyncedCount = dataService.getUnsyncedRecordsCount()

    if unsyncedCount > 0 {
        showAlert("有未同步的数据") {
            Text("您有 \(unsyncedCount) 条未同步的扫描记录")

            Button("保留数据，稍后同步") {
                // 数据保留在本地，下次登录可继续同步
                performLogout(clearData: false)
            }

            Button("导出后登出") {
                exportDataThenLogout()
            }

            Button("清除数据并登出", role: .destructive) {
                confirmClearAndLogout()
            }

            Button("取消", role: .cancel) {}
        }
    } else {
        // 无未同步数据，直接登出
        performLogout(clearData: false)
    }
}

func confirmClearAndLogout() {
    Alert(title: "确认清除数据？") {
        Text("所有扫描记录和照片将被永久删除，此操作不可恢复")

        Button("确认删除", role: .destructive) {
            performLogout(clearData: true)
        }

        Button("取消", role: .cancel) {}
    }
}

func performLogout(clearData: Bool) {
    // 停止所有服务
    cameraService.stop()
    locationService.stop()
    syncService.cancelAllTasks()

    if clearData {
        // 清除用户数据
        dataService.deleteAllRecords()
        try? FileManager.default.removeItem(at: imageDirectory)
    } else {
        // 保留数据，标记用户ID
        // 下次登录时可恢复
    }

    // Firebase登出
    try? Auth.auth().signOut()

    // 返回登录页
    navigateToLogin()
}

// 多用户数据隔离
func getUserDataDirectory(userID: String) -> URL {
    let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let userDir = baseURL.appendingPathComponent("Users/\(userID)")

    // 创建用户目录
    try? FileManager.default.createDirectory(at: userDir,
                                             withIntermediateDirectories: true)

    return userDir
}

// 切换账户
func switchAccount(to userID: String) {
    // 保存当前用户状态
    saveCurrentUserState()

    // 切换数据目录
    let newUserDir = getUserDataDirectory(userID: userID)
    dataService.switchDataDirectory(to: newUserDir)

    // 加载新用户数据
    loadUserData()

    showToast("已切换到账户: \(userID)")
}
```

**数据隔离方案**:
```
Documents/
├── Users/
│   ├── user123/
│   │   ├── ScanRecords.json
│   │   └── ScanImages/
│   │       ├── scan_001.jpg
│   │       └── scan_002.jpg
│   └── user456/
│       ├── ScanRecords.json
│       └── ScanImages/
└── Shared/
    └── Config.json
```

---

#### 4.3 App生命周期管理 ⭐⭐⭐

**问题**: App进入后台、被杀死、崩溃

**实现方案**:
```swift
// AppDelegate / SceneDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {

    func applicationWillResignActive(_ application: UIApplication) {
        // App即将进入非活跃状态（来电、控制中心等）
        NotificationCenter.default.post(name: .appWillResignActive, object: nil)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // App进入后台
        handleEnterBackground()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // App即将返回前台
        handleEnterForeground()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // App已激活
        NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // App即将终止（极少触发）
        saveAllData()
    }
}

// 进入后台处理
func handleEnterBackground() {
    // 1. 暂停相机会话
    cameraService.stop()

    // 2. 保存当前状态
    saveAppState()

    // 3. 取消所有网络请求
    syncService.pauseAllTasks()

    // 4. 保存正在进行的扫描
    if let currentScan = scannerViewModel.currentScan {
        saveDraft(currentScan)
    }

    // 5. 释放资源
    imageCache.removeAllObjects()
}

func saveAppState() {
    let state = AppState(
        selectedMerchant: currentMerchant,
        scanCount: totalScans,
        lastActiveTime: Date(),
        isScanning: isScanning
    )

    if let data = try? JSONEncoder().encode(state) {
        UserDefaults.standard.set(data, forKey: "appState")
    }
}

// 返回前台处理
func handleEnterForeground() {
    // 1. 恢复App状态
    restoreAppState()

    // 2. 检查权限变化
    permissionManager.checkAllPermissions()

    // 3. 恢复相机会话
    if permissionManager.cameraAuthorized && wasScanning {
        cameraService.start()
    }

    // 4. 检查网络状态
    networkMonitor.checkConnection()

    // 5. 提示用户
    let inactiveTime = Date().timeIntervalSince(lastActiveTime)
    if inactiveTime > 300 {  // 超过5分钟
        showToast("欢迎回来！已扫描 \(totalScans) 条")
    }
}

// 崩溃恢复
func recoverFromCrash() {
    // 检测上次是否异常退出
    let didCrash = !UserDefaults.standard.bool(forKey: "cleanExit")

    if didCrash {
        showAlert("上次未正常退出") {
            Text("检测到异常退出，是否恢复上次的扫描会话？")

            Button("恢复") {
                recoverLastSession()
            }

            Button("重新开始") {
                startNewSession()
            }
        }
    }

    // 标记正常启动
    UserDefaults.standard.set(false, forKey: "cleanExit")
}

func applicationWillTerminate() {
    // 标记正常退出
    UserDefaults.standard.set(true, forKey: "cleanExit")
    saveAllData()
}
```

**状态保存内容**:
- 当前选择的商家
- 已扫描数量
- 最后活跃时间
- 是否正在扫描
- 草稿扫描记录

---

#### 4.4 用户误操作保护 ⭐⭐

**问题**: 误删除、误清空数据

**实现方案**:
```swift
// 删除单条记录（支持撤销）
func deleteScanRecord(_ record: ScanRecord) {
    // 软删除：移到回收站
    deletedRecords.append(record)
    records.removeAll { $0.id == record.id }

    // 显示Toast + 撤销按钮
    showToast("已删除") {
        Button("撤销") {
            undoDelete(record)
        }
    }

    // 5秒后永久删除
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        permanentlyDelete(record)
    }
}

func undoDelete(_ record: ScanRecord) {
    records.append(record)
    deletedRecords.removeAll { $0.id == record.id }
    showToast("已恢复")
}

// 批量删除（强确认）
func batchDelete(_ records: [ScanRecord]) {
    let unsyncedCount = records.filter { !$0.isSynced }.count

    Alert(title: "确认删除 \(records.count) 条记录？") {
        if unsyncedCount > 0 {
            Text("包含 \(unsyncedCount) 条未同步记录")
                .foregroundColor(.red)
        }

        TextField("输入 DELETE 确认", text: $confirmText)

        Button("删除", role: .destructive) {
            if confirmText == "DELETE" {
                performBatchDelete(records)
            } else {
                showError("确认文本不正确")
            }
        }

        Button("取消", role: .cancel) {}
    }
}

// 清空所有数据（超强确认）
func clearAllData() {
    Alert(title: "⚠️ 危险操作") {
        Text("此操作将删除所有扫描记录和照片，不可恢复！")
            .foregroundColor(.red)

        Text("未同步记录: \(unsyncedCount) 条")
        Text("总照片数: \(totalPhotos) 张")
        Text("占用空间: \(usedSpace) MB")

        Button("导出后清空") {
            exportThenClear()
        }

        Button("直接清空", role: .destructive) {
            requireSecondConfirmation {
                performClearAll()
            }
        }

        Button("取消", role: .cancel) {}
    }
}

// 二次确认
func requireSecondConfirmation(action: @escaping () -> Void) {
    Alert(title: "最后确认") {
        Text("确定要删除所有数据吗？此操作不可撤销！")

        Button("确定删除", role: .destructive) {
            action()
        }

        Button("我再想想", role: .cancel) {}
    }
}

// 导出预览
struct ExportConfirmationView: View {
    let records: [ScanRecord]

    var dateRange: String {
        guard let first = records.first?.timestamp,
              let last = records.last?.timestamp else {
            return "无数据"
        }
        return "\(format(first)) - \(format(last))"
    }

    var estimatedSize: String {
        let photosSize = records.count * 2 * 1024 * 1024  // 假设每张2MB
        let csvSize = records.count * 200  // 假设每条200字节
        let totalMB = (photosSize + csvSize) / 1_048_576
        return "\(totalMB) MB"
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("导出确认")
                .font(.title2)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(label: "总记录数", value: "\(records.count) 条")
                    InfoRow(label: "日期范围", value: dateRange)
                    InfoRow(label: "预计文件大小", value: estimatedSize)
                    InfoRow(label: "包含照片", value: "是")
                }
            }

            Text("导出内容将包含CSV文件和所有照片的压缩包")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("确认导出") {
                    performExport()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}
```

**误操作保护策略**:
1. **删除单条**: Toast + 5秒撤销
2. **批量删除**: 显示未同步数量 + 输入"DELETE"确认
3. **清空数据**: 两次确认 + 显示详细信息
4. **导出预览**: 显示记录数、日期范围、文件大小

---

#### 4.5 商家选择强制 ⭐⭐⭐

**问题**: 用户忘记选择商家就开始扫描

**实现方案**:
```swift
// 商家选择器
struct MerchantSelectorView: View {
    @State private var selectedMerchant: String?
    @AppStorage("lastSelectedMerchant") private var lastMerchant: String?

    let merchants = ["Walmart", "Target", "Costco", "Kroger"]

    var body: some View {
        VStack(spacing: 16) {
            Text("选择商家")
                .font(.headline)

            Picker("商家", selection: $selectedMerchant) {
                Text("请选择商家").tag(nil as String?)
                ForEach(merchants, id: \.self) { merchant in
                    Text(merchant).tag(merchant as String?)
                }
            }
            .pickerStyle(.menu)

            // 记忆上次选择
            if let last = lastMerchant {
                Button("继续扫描 \(last)") {
                    selectedMerchant = last
                    startScanning()
                }
                .buttonStyle(.borderedProminent)
            }

            Button("开始扫描") {
                startScanning()
            }
            .disabled(selectedMerchant == nil)
        }
        .onAppear {
            // 自动选择上次的商家
            if let last = lastMerchant {
                selectedMerchant = last
            }
        }
    }

    func startScanning() {
        guard let merchant = selectedMerchant else {
            showError("请先选择商家")
            return
        }

        // 保存选择
        lastMerchant = merchant

        // 开始扫描
        navigateToScanner(merchant: merchant)
    }
}

// 扫描界面顶部显示
struct ScannerHeaderView: View {
    let currentMerchant: String
    let scanCount: Int
    let onChangeMerchant: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("当前商家")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(currentMerchant)
                    .font(.headline)
            }

            Spacer()

            Button("更改") {
                onChangeMerchant()
            }
            .font(.caption)

            Text("已扫描: \(scanCount)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(12)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}

// 强制选择逻辑
@Published var canScan: Bool = false

func validateScanPreconditions() -> Bool {
    // 检查商家是否选择
    guard currentMerchant != nil else {
        showAlert("请先选择商家")
        return false
    }

    // 检查相机权限
    guard permissionManager.cameraAuthorized else {
        showAlert("请授予相机权限")
        return false
    }

    // 检查存储空间
    guard storageStatus != .critical else {
        showAlert("存储空间不足，无法扫描")
        return false
    }

    return true
}
```

**商家选择流程**:
1. App启动 → 登录成功 → 商家选择页
2. 自动选择上次的商家（快捷操作）
3. 未选择商家 → 禁用"开始扫描"按钮
4. 扫描界面顶部显示当前商家 + "更改"按钮
5. 更改商家 → 确认对话框（避免误操作）

---

### 5. 其他错误处理

#### 5.1 Firebase认证异常 ⭐⭐

**实现方案**:
```swift
func handleFirebaseError(_ error: Error) {
    guard let authError = error as? AuthErrorCode else {
        showError("未知错误: \(error.localizedDescription)")
        return
    }

    switch authError.code {
    case .networkError:
        showError("网络连接失败，请检查网络后重试")
    case .userNotFound:
        showError("用户不存在，请检查邮箱")
    case .wrongPassword:
        passwordErrorCount += 1
        if passwordErrorCount >= 3 {
            showError("密码错误次数过多，请稍后再试")
            lockLoginFor(minutes: 5)
        } else {
            showError("密码错误")
        }
    case .invalidEmail:
        showError("邮箱格式不正确")
    case .emailAlreadyInUse:
        showError("该邮箱已被注册")
    case .weakPassword:
        showError("密码强度不足（至少8位，包含字母和数字）")
    case .tooManyRequests:
        showError("请求过于频繁，请稍后再试")
    case .userDisabled:
        showError("该账户已被禁用，请联系管理员")
    default:
        showError("登录失败: \(authError.localizedDescription)")
    }
}
```

#### 5.2 Vision Framework异常 ⭐

**实现方案**:
```swift
func handleVisionError(_ error: Error) {
    if let vnError = error as? VNError {
        switch vnError.code {
        case .requestCancelled:
            // 正常取消，不提示
            break
        case .invalidModel:
            showError("条形码识别模型加载失败")
            fallbackToManualInput()
        case .outOfMemory:
            showError("内存不足，请关闭其他应用")
            enablePerformanceMode()
        default:
            showError("识别失败: \(vnError.localizedDescription)")
        }
    }
}
```

---

### 优先级总结

#### ⭐⭐⭐ 高优先级（MVP必须实现）

1. **距离检测与提示** - 条形码太远/太近实时提示
2. **光线检测** - 光线不足提示 + 手电筒按钮
3. **重复扫描防抖** - 5秒内同一条形码不重复
4. **商家强制选择** - 未选择商家禁用扫描
5. **存储空间检测** - < 500MB禁止扫描 + 清理选项
6. **相机会话中断** - 电话、后台处理
7. **权限撤销处理** - 运行时权限变化检测
8. **数据原子写入** - 防止崩溃导致数据损坏
9. **GPS定位超时** - 5秒超时使用上次位置
10. **基本错误提示** - 网络、权限、相机错误

#### ⭐⭐ 中优先级（增强体验）

11. 多条形码选择
12. 对焦失败处理
13. 识别质量检测
14. 无条形码超时提示
15. 设备性能降级
16. 内存管理
17. CSV导出增强
18. 网络状态切换提示
19. 账户切换数据隔离
20. 删除操作撤销

#### ⭐ 低优先级（未来优化）

21. 手动输入条形码
22. 设备兼容性检测
23. 时间异常检测
24. 高级数据恢复
25. 性能监控

---

## 交付清单

### 代码交付物
- [x] 完整的Xcode项目源代码
- [x] 清晰的代码注释（中英文）
- [x] MVVM架构，模块化设计
- [x] 可扩展的代码结构

### 功能交付物
- [x] Firebase Authentication (Email/Password)
- [x] 条形码扫描 + 自动拍照
- [x] 本地数据存储（完全离线可用）
- [x] 扫描历史列表
- [x] CSV导出和分享功能
- [x] GPS位置采集
- [x] 权限管理（相机、位置）
- [x] 同步状态指示（预留接口）

### 文档交付物
- [x] Firebase配置指南
- [x] TestFlight部署步骤
- [x] 功能使用说明
- [x] 代码结构说明

---

## 实施步骤

### Phase 1: 基础配置 (0.5天)
1. ✅ 配置Firebase项目
2. ✅ 添加Firebase SDK依赖 (SPM)
3. ✅ 配置 `GoogleService-Info.plist`
4. ✅ 创建数据模型 (ScanRecord, User, Merchant)
5. ✅ 配置Info.plist权限

### Phase 2: 用户认证 (0.5天)
6. ✅ 实现 `AuthViewModel`
7. ✅ 创建 `LoginView` 和 `SignUpView`
8. ✅ 实现登录/注册/登出逻辑
9. ✅ 添加登录状态持久化

### Phase 3: 核心扫描功能 (1天)
10. ✅ 实现 `CameraService` (AVFoundation)
11. ✅ 实现 `BarcodeDetector` (Vision Framework)
12. ✅ 创建 `CameraPreview` 组件 (UIViewRepresentable)
13. ✅ 实现自动拍照逻辑
14. ✅ 实现 `LocationService` (CoreLocation)
15. ✅ 创建 `ScannerView` 主界面
16. ✅ 添加商家选择器 `MerchantSelector`
17. ✅ 实现震动/声音反馈

### Phase 4: 数据存储与历史 (0.5天)
18. ✅ 实现 `DataService` (本地存储)
19. ✅ 实现照片保存逻辑
20. ✅ 创建 `HistoryListView`
21. ✅ 创建 `ScanDetailView`
22. ✅ 实现同步状态显示

### Phase 5: 导出与完善 (0.5天)
23. ✅ 实现 `CSVExporter`
24. ✅ 实现分享功能 (UIActivityViewController)
25. ✅ 添加权限请求引导
26. ✅ 实现网络状态监控（预留）
27. ✅ 错误处理和用户提示
28. ✅ **实现边界情况处理（高优先级）**:
    - 距离检测与实时提示
    - 光线检测 + 手电筒按钮
    - 重复扫描防抖机制
    - 商家强制选择验证
    - 存储空间检测与清理
    - 相机会话中断恢复
    - 权限撤销运行时处理
    - 数据原子写入保护
    - GPS定位超时处理
    - App生命周期管理

### Phase 6: 测试与部署 (0.5天)
29. ✅ 完整流程测试
30. ✅ 边界情况测试（距离、光线、重复扫描等）
31. ✅ 修复Bug
32. ✅ 准备TestFlight部署
33. ✅ 编写部署文档

**预计总时间**: 2天内完成

---

## Firebase 配置要求

### Firebase项目设置
1. 创建Firebase项目: https://console.firebase.google.com
2. 添加iOS应用
   - Bundle ID: `com.yourdomain.ShelfTagSnap` (需与Xcode一致)
   - 下载 `GoogleService-Info.plist`
3. 启用 **Authentication**
   - 登录方式: Email/Password
4. 添加项目成员（Owner权限）
   - Email: sunkaifeng05@gmail.com

### 注意事项
- **不使用Firebase Storage**（第一阶段）
- **不使用Firestore Database**（第一阶段）
- 仅使用Firebase Authentication

---

## TestFlight 部署要求

### 开发者账户配置
1. 添加开发者到Apple Developer账户
   - Apple ID: sunkaifeng05@gmail.com
   - 角色: Developer / Admin
2. 配置App ID和证书
3. 创建Provisioning Profile

### TestFlight上传步骤
1. Archive项目 (Xcode: Product → Archive)
2. 上传到App Store Connect
3. 添加测试用户（2-3人）
4. 发送TestFlight邀请链接

---

## 技术难点与解决方案

### 1. 条形码实时识别性能
**问题**: Vision Framework实时处理可能导致性能问题
**解决方案**:
- 控制识别频率（每秒3-5次）
- 识别成功后暂停检测，拍照完成后恢复

### 2. 离线数据可靠性
**问题**: App强制退出或崩溃可能丢失数据
**解决方案**:
- 每次扫描立即写入文件
- 使用原子写入（atomic write）
- 定期备份数据

### 3. GPS精度和速度
**问题**: 室内GPS信号弱，定位慢
**解决方案**:
- 使用 `kCLLocationAccuracyBest`
- 设置超时机制（5秒未获取则使用上次位置）
- GPS为可选字段，不阻塞扫描

### 4. 照片存储空间
**问题**: 大量照片占用存储空间
**解决方案**:
- 使用JPEG压缩（质量0.8-0.9）
- 监控存储空间，低于1GB时提示用户
- 已同步的照片可选择删除

---

## 用户反馈设计

### 扫描成功反馈
1. **震动**: `UIImpactFeedbackGenerator` (medium impact)
2. **声音**: 系统"拍照"声音
3. **视觉**:
   - 绿色边框闪烁
   - Toast提示"已保存 #123"
   - 扫描计数+1

### 边界情况提示

#### 距离相关
- 🟡 **条形码太远**: "靠近条形码 / Move closer"
- 🟠 **条形码太近**: "稍微远离 / Move back"
- 🟢 **距离合适**: "按住拍摄 / Hold to scan"
- 边框颜色实时反馈：绿色（合适）、黄色（太远）、橙色（太近）、红色（无法识别）

#### 光线相关
- 💡 **光线不足**: "光线不足，建议打开闪光灯"
- 🔦 手电筒快捷按钮（右上角）
- 自动提示 + 一键开启

#### 重复扫描
- ⚠️ **短期重复**: "刚刚已扫描此条形码"（5秒内）
- 🔄 **智能去重**: "可能重复：该条形码今天已在此位置扫描过"
- 选项：[确认重新扫描] [取消]

#### 识别质量
- 📷 **置信度低**: "条形码不清晰，请调整角度"
- 🌟 **置信度中**: "请保持稳定"
- ⚡ **置信度高**: 自动拍照
- 💿 **反光检测**: "避免反光，请调整角度"

#### 多条形码
- 🔢 **多目标**: "检测到3个条形码"
- 高亮显示当前选中的条形码（绿色边框）
- 其他条形码显示灰色边框

#### 无条形码超时
- ⏱️ **10秒无识别**: "未检测到条形码"
- 选项：[手动输入] [继续扫描] [跳过]

#### 相机和硬件
- 📵 **相机中断**: "扫描已暂停（来电/其他应用）"
- ✅ **相机恢复**: "可以继续扫描"
- 🎯 **对焦困难**: "对焦困难，请调整距离或光线"
- 👆 **手动对焦**: "点击屏幕对焦"

#### 存储空间
- 🔴 **Critical (<500MB)**: "存储空间不足，无法继续扫描"
  - 选项：[清理空间] [取消]
- 🟡 **Warning (500MB-1GB)**: "存储空间不足1GB，建议清理"
- 🟢 **Normal (>1GB)**: 正常使用

#### GPS定位
- 📍 **精确定位**: (<50m误差)
- 📌 **一般精度**: (50-100m误差)
- 📍? **低精度**: (>100m误差) + "定位精度较低（误差150米）"
- ❓ **定位失败**: "定位超时，使用近似位置"
- ⏳ **首次定位**: "正在获取位置..."

#### 网络状态
- 📶 **WiFi连接**: "已连接WiFi，可自动同步"
- 📡 **蜂窝网络**: 询问"使用移动数据同步？"
- 📵 **离线模式**: "已切换到离线模式"
- 🔄 **网络恢复**: "检测到网络，是否立即同步？"

#### 权限相关
- 🚫 **相机权限被撤销**: "相机权限已被撤销，扫描已暂停"
  - 引导：[前往设置] [取消]
- ✅ **权限恢复**: "权限已恢复，可以继续扫描"
- ℹ️ **位置权限禁用**: 不阻塞扫描，图标显示"❓"

#### App生命周期
- 👋 **返回前台**: "欢迎回来！已扫描123条"（超过5分钟显示）
- 💥 **崩溃恢复**: "上次未正常退出，是否恢复上次的扫描会话？"
  - 选项：[恢复] [重新开始]

#### 误操作保护
- 🗑️ **删除单条**: Toast "已删除" + [撤销]按钮（5秒）
- ⚠️ **批量删除**: "确认删除X条记录？包含Y条未同步记录"
  - 输入"DELETE"确认
- 🚨 **清空数据**: "此操作将删除所有扫描记录和照片，不可恢复！"
  - 显示：未同步数量、总照片数、占用空间
  - 二次确认

#### 商家选择
- 🏪 **未选择商家**: "开始扫描"按钮禁用
- 📝 **智能记忆**: 自动选择上次的商家
- 🔄 **更改商家**: 顶部显示当前商家 + [更改]按钮

### 错误提示
- 相机权限被拒绝 → 显示引导页
- 网络同步失败 → 红色提示 + 重试按钮
- 存储空间不足 → 警告弹窗
- Firebase认证失败 → 具体错误信息（邮箱格式、密码强度等）
- Vision识别失败 → 降级策略或手动输入选项

---

## 未来扩展方向（超出第一里程碑）

### 可能的功能扩展
1. **云端存储**:
   - 照片上传到Firebase Storage / AWS S3
   - 元数据存储到Firestore / PostgreSQL
2. **管理员后台**:
   - Web端管理界面
   - 查看所有用户扫描数据
   - 工资结算报表
3. **数据分析**:
   - 扫描热力图
   - 效率统计
   - 重复扫描检测
4. **离线地图**:
   - 预下载门店地图
   - 离线导航

---

## 参考资料

### 官方文档
- [Firebase iOS SDK](https://firebase.google.com/docs/ios/setup)
- [AVFoundation Programming Guide](https://developer.apple.com/documentation/avfoundation)
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [Core Location](https://developer.apple.com/documentation/corelocation)

### 参考App
- **Shelf Snap**: https://apps.apple.com/app/id1591199171
- **演示视频**: https://www.loom.com/share/7d3500746ba4401cbec6a47ee4bd48a0

---

## 项目时间线

- **2025-10-22**: 合同确认，需求分析完成
- **2025-10-23**: 核心功能开发（认证 + 扫描）
- **2025-10-24**: 数据存储 + 历史列表 + CSV导出
- **2025-10-24 晚**: 首个可测试Demo交付

---

**文档创建日期**: 2025年10月22日
**最后更新**: 2025年10月22日
