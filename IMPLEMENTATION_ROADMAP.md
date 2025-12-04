# NMAPScanner - Complete Feature Implementation Roadmap
**Created:** November 23, 2025
**Authors:** Jordan Koch

## ✅ COMPLETED FEATURES

### Phase 1: MAC Address Collection (v2.5+)
- ✅ ARPScanner.swift - System ARP table parsing
- ✅ MAC address collection during scans
- ✅ Manufacturer detection via OUI database (800+ vendors)
- ✅ Display MAC and manufacturer in device details

### Phase 2: Device Naming & Annotations (v3.0)
- ✅ DeviceAnnotations.swift - Complete annotation system
- ✅ Custom device names
- ✅ Device tagging system
- ✅ Device grouping
- ✅ Notes/annotations per device
- ✅ DeviceAnnotationSheet UI component

### Phase 3: Scan Scheduling & Automation (v3.0)
- ✅ ScanScheduler.swift - Automated scheduling system
- ✅ Multiple schedule support
- ✅ Hourly, daily, custom intervals
- ✅ Background monitoring
- ✅ Schedule management UI

### Earlier Features
- ✅ Rogue device detection
- ✅ "Mark as Trusted" functionality
- ✅ DNS hostname resolution
- ✅ Numeric IP address sorting
- ✅ Threat analysis and scoring
- ✅ Device whitelisting
- ✅ Network history tracking

## 🚧 TO BE IMPLEMENTED

### Phase 4: Historical Tracking & Change Detection

**File:** `HistoricalTracker.swift`

```swift
@MainActor
class HistoricalTracker: ObservableObject {
    struct DeviceSnapshot: Codable {
        let timestamp: Date
        let device: EnhancedDevice
        let openPorts: [Int]
    }

    struct ChangeEvent: Codable {
        let timestamp: Date
        let ipAddress: String
        let changeType: ChangeType
        let details: String

        enum ChangeType: String, Codable {
            case newDevice = "New Device"
            case deviceLeft = "Device Left"
            case portsChanged = "Ports Changed"
            case statusChanged = "Status Changed"
        }
    }

    @Published var snapshots: [String: [DeviceSnapshot]] = [:]
    @Published var changes: [ChangeEvent] = []

    func recordSnapshot(_ device: EnhancedDevice)
    func detectChanges(current: [EnhancedDevice], previous: [Device Snapshot]) -> [ChangeEvent]
    func getDeviceHistory(for ip: String) -> [DeviceSnapshot]
    func getChanges(since date: Date) -> [ChangeEvent]
}
```

**UI Components:**
- `HistoricalView.swift` - Timeline view of changes
- `ChangeLogView.swift` - Detailed change log
- "What's New?" dashboard card showing recent changes

### Phase 5: Export & Reporting

**File:** `ExportManager.swift`

```swift
@MainActor
class ExportManager: ObservableObject {
    enum ExportFormat {
        case pdf, csv, json, html
    }

    func exportScanResults(_ devices: [EnhancedDevice], format: ExportFormat) async -> URL?
    func generatePDFReport(devices: [EnhancedDevice], threats: [ThreatFinding]) async -> URL?
    func exportToCSV(_ devices: [EnhancedDevice]) async -> URL?
    func exportThreatReport(threats: [ThreatFinding]) async -> URL?
    func scheduleEmailReport(to: String, schedule: ScanSchedule)
}
```

**Features:**
- PDF reports with charts and graphs
- CSV export for spreadsheet analysis
- JSON export for API integration
- HTML reports for web viewing
- Email delivery integration
- Automated report scheduling

### Phase 6: Search & Filter

**File:** `SearchAndFilter.swift`

```swift
@MainActor
class SearchFilterManager: ObservableObject {
    struct FilterCriteria {
        var searchText: String = ""
        var deviceTypes: Set<EnhancedDevice.DeviceType> = []
        var threatLevels: Set<ThreatLevel> = []
        var isRogue: Bool? = nil
        var manufacturers: Set<String> = []
        var tags: Set<String> = []
        var groups: Set<String> = []
        var portRange: ClosedRange<Int>? = nil
    }

    @Published var criteria = FilterCriteria()
    @Published var savedSearches: [SavedSearch] = []

    func filter(_ devices: [EnhancedDevice]) -> [EnhancedDevice]
    func saveSearch(name: String, criteria: FilterCriteria)
    func loadSearch(_ search: SavedSearch)
}
```

**UI:**
- Search bar in dashboard
- Advanced filter sheet
- Saved searches
- Quick filter chips

### Phase 7: Scan Presets

**File:** `ScanPresets.swift`

```swift
struct ScanPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var ports: [Int]
    var scanType: ScanType
    var timeout: TimeInterval
    var maxThreads: Int

    static let webServices = ScanPreset(...)
    static let iotDevices = ScanPreset(...)
    static let servers = ScanPreset(...)
}

@MainActor
class ScanPresetManager: ObservableObject {
    @Published var presets: [ScanPreset] = []

    func addPreset(_ preset: ScanPreset)
    func applyPreset(_ preset: ScanPreset, to scanner: IntegratedScannerV3)
}
```

**Default Presets:**
- Web Services (80, 443, 8080, 8443)
- IoT Devices (1883, 8883, 5683)
- Databases (3306, 5432, 27017, 6379)
- File Servers (445, 548, 2049)
- Security Audit (all common ports)

### Phase 8: Notification System

**File:** `NotificationManager.swift`

```swift
@MainActor
class NotificationManager: ObservableObject {
    enum NotificationType {
        case newRogueDevice
        case newDevice
        case criticalThreat
        case scanComplete
    }

    struct NotificationSettings: Codable {
        var enabled: Bool = true
        var soundEnabled: Bool = true
        var showBanner: Bool = true
        var notifyOnRogue: Bool = true
        var notifyOnNew: Bool = false
    }

    func showNotification(_ type: NotificationType, message: String)
    func playAlert()
    func showBanner(title: String, message: String)
}
```

### Phase 9: Dark/Light Mode Toggle

**File:** Update `SettingsView.swift`

```swift
@AppStorage("appearance_mode") private var appearanceMode = "auto"

enum AppearanceMode: String {
    case light, dark, auto
}

// Apply to Color extensions
extension Color {
    static var dynamicBackground: Color {
        Color(uiColor: .systemBackground)
    }
    static var dynamicText: Color {
        Color(uiColor: .label)
    }
}
```

### Phase 10: Network Topology Map

**File:** `NetworkTopologyView.swift`

```swift
struct NetworkTopologyView: View {
    let devices: [EnhancedDevice]

    struct NetworkNode: Identifiable {
        let id = UUID()
        let device: EnhancedDevice
        var position: CGPoint
        var connections: [NetworkNode]
    }

    func buildTopology() -> [NetworkNode]
    func detectRouter() -> EnhancedDevice?
    func groupBySubnet() -> [String: [EnhancedDevice]]
}
```

**Features:**
- Interactive graph visualization
- Zoom/pan controls
- Color-coded nodes by type/threat
- Connection lines
- Tap for device details

### Phase 11: Enhanced Threat Intelligence

**File:** `ThreatIntelligence.swift`

```swift
@MainActor
class ThreatIntelligenceManager: ObservableObject {
    struct ThreatFeed {
        let source: String
        let maliciousIPs: Set<String>
        let maliciousPorts: Set<Int>
        let lastUpdated: Date
    }

    func checkIP(_ ip: String) async -> ThreatLevel?
    func checkPort(_ port: Int) async -> Bool // is malicious?
    func updateFeeds() async
    func getReputationScore(for device: EnhancedDevice) -> Int
}
```

**Sources:**
- AbuseIPDB API integration
- Common backdoor port database
- CVE database integration
- Threat actor IOCs

### Phase 12: Port Service Fingerprinting

**File:** `ServiceFingerprinter.swift`

```swift
@MainActor
class ServiceFingerprinter: ObservableObject {
    struct ServiceInfo {
        let port: Int
        let service: String
        let version: String?
        let banner: String?
    }

    func grabBanner(host: String, port: Int) async -> String?
    func identifyService(port: Int, banner: String) -> ServiceInfo
    func detectOS(from banners: [String]) -> String?
}
```

### Phase 13: Network Performance Monitoring

**File:** `PerformanceMonitor.swift`

```swift
@MainActor
class PerformanceMonitor: ObservableObject {
    struct PerformanceMetrics {
        var latency: TimeInterval
        var jitter: TimeInterval
        var packetLoss: Double
        var bandwidth: Double?
    }

    func measureLatency(to host: String) async -> TimeInterval
    func measureBandwidth(to host: String) async -> Double
    func continuousMonitoring(devices: [EnhancedDevice]) async
}
```

### Phase 14: Multi-Subnet Support

**File:** Update `IntegratedDashboardViewV3.swift`

```swift
struct SubnetConfig: Codable {
    var subnet: String
    var mask: Int
    var enabled: Bool
}

@Published var subnets: [SubnetConfig] = []

func scanAllSubnets() async {
    for subnet in subnets where subnet.enabled {
        await scanSubnet(subnet.subnet)
    }
}
```

### Phase 15: Authentication & Security

**File:** `AuthenticationManager.swift`

```swift
@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var usesBiometric = true

    func authenticate() async -> Bool
    func setPIN(_ pin: String)
    func verifyPIN(_ pin: String) -> Bool
    func authenticateWithBiometric() async -> Bool
}
```

### Phase 16: Encrypted Storage

**File:** `SecureStorage.swift`

```swift
class SecureStorage {
    func encrypt(_ data: Data, with key: String) -> Data?
    func decrypt(_ data: Data, with key: String) -> Data?
    func storeSecurely(_ data: Data, for key: String) -> Bool
    func retrieveSecurely(for key: String) -> Data?
}
```

### Phase 17: Network Health Score

**File:** `NetworkHealthScorer.swift`

```swift
@MainActor
class NetworkHealthScorer: ObservableObject {
    struct HealthScore {
        var overall: Int // 0-100
        var securityScore: Int
        var performanceScore: Int
        var complianceScore: Int
        var recommendations: [String]
    }

    func calculateScore(devices: [EnhancedDevice], threats: [ThreatFinding]) -> HealthScore
    func generateRecommendations(_ score: HealthScore) -> [String]
    func trendAnalysis(scores: [HealthScore]) -> Trend
}
```

### Phase 18: Compliance Checking

**File:** `ComplianceChecker.swift`

```swift
enum ComplianceStandard {
    case pciDss, hipaa, cisBenchmark, custom
}

struct ComplianceRule {
    let standard: ComplianceStandard
    let rule: String
    let check: (EnhancedDevice) -> Bool
    let severity: ThreatLevel
}

@MainActor
class ComplianceChecker: ObservableObject {
    func checkCompliance(devices: [EnhancedDevice], standard: ComplianceStandard) -> [ComplianceViolation]
    func generateComplianceReport() async -> URL?
}
```

### Phase 19: Integration APIs

**File:** `IntegrationManager.swift`

```swift
@MainActor
class IntegrationManager: ObservableObject {
    // Webhook support
    func sendWebhook(url: URL, event: Event) async
    func configureWebhooks(_ webhooks: [WebhookConfig])

    // REST API
    func exposeRESTAPI(port: Int)
    func handleAPIRequest(_ request: APIRequest) -> APIResponse

    // SIEM Integration
    func sendToSplunk(event: SecurityEvent) async
    func sendToElasticsearch(event: SecurityEvent) async
}
```

### Phase 20: Mobile Companion App

**Separate iOS/iPadOS Project:**
- Shared data models via iCloud
- Push notification support
- Remote scan triggering
- Real-time sync
- Mobile-optimized UI

## IMPLEMENTATION PRIORITY

### Must Have (v3.0)
1. ✅ MAC Address Collection
2. ✅ Device Naming & Annotations
3. ✅ Scan Scheduling
4. Historical Tracking
5. Export & Reporting
6. Search & Filter

### Should Have (v3.1)
7. Scan Presets
8. Notifications
9. Dark Mode
10. Network Topology

### Nice to Have (v3.2+)
11-20. All remaining features

## TESTING CHECKLIST

### Unit Tests Needed
- [ ] ARPScanner MAC parsing
- [ ] Device annotation persistence
- [ ] Schedule timing logic
- [ ] Export format generation
- [ ] Search/filter algorithms

### Integration Tests
- [ ] End-to-end scan with MAC collection
- [ ] Scheduled scan execution
- [ ] Annotation save/load
- [ ] Export all formats
- [ ] Search across large datasets

### Performance Tests
- [ ] 1000+ device scan
- [ ] Historical data with 10k+ records
- [ ] Search performance
- [ ] Export large datasets

## DEPLOYMENT NOTES

### Version Numbering
- v3.0: Core features (MAC, annotations, scheduling, history, export, search)
- v3.1: UI enhancements (presets, notifications, dark mode, topology)
- v3.2: Advanced features (threat intel, fingerprinting, performance)
- v3.3: Security & compliance (auth, encryption, compliance checking)
- v4.0: Integrations & mobile (APIs, webhooks, iOS app)

### Database Migration
When implementing historical tracking, migrate existing device data to new schema.

### Backwards Compatibility
Maintain support for existing whitelists and device persistence data.

## DOCUMENTATION NEEDED

- [ ] User Guide for all new features
- [ ] API Documentation (if exposing REST API)
- [ ] Integration Guide for SIEM
- [ ] Compliance Mapping Documentation
- [ ] Mobile App User Guide

## KNOWN LIMITATIONS

1. **ARP Scanning**: Requires devices to be in ARP cache (ping first)
2. **MAC Addresses**: May not work across VLANs/routers
3. **Background Scanning**: tvOS limitations on background tasks
4. **Export Size**: Large datasets may cause memory issues
5. **Real-time Monitoring**: Poll-based, not truly real-time

## FUTURE ENHANCEMENTS

- IPv6 support
- Wireless network analysis
- VPN tunnel scanning
- Docker container detection
- Kubernetes cluster discovery
- Cloud infrastructure scanning (AWS/Azure/GCP)
- AI-powered anomaly detection
- Blockchain-based device registry
- Zero-trust network assessment

---

**Next Steps:**
1. Complete MAC address integration
2. Build and test v3.0 features
3. Deploy to production
4. Gather user feedback
5. Prioritize v3.1 features based on usage

**For questions or contributions:** kochj@digitalnoise.net
