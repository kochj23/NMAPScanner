# Scan Performance Analysis & Optimization Recommendations
**Date:** December 3, 2025
**Authors:** Jordan Koch & Claude Code

## Current Performance Analysis

### HomeKit Device Scanning (HomeKitTabView.swift)

**Current Flow (6 Phases):**
1. **Bonjour/mDNS Discovery** (0-25%): 10 seconds fixed duration
2. **Import Bonjour Devices** (25-40%): Variable
3. **Port Scanning** (40-60%): Sequential, ~2-5 seconds per device
4. **dns-sd Direct Lookup** (60-75%): ~5 seconds
5. **Combine Results** (75-85%): ~2 seconds
6. **Final Classification** (85-100%): ~1-2 seconds

**Total Time:** 25-60 seconds depending on network size

### Dashboard Full Scan (IntegratedDashboardViewV3.swift)

**Current Flow (4 Phases):**
1. **Ping Subnet** (0-20%): ~10-30 seconds for 254 IPs
2. **MAC Address Collection** (20-30%): ~5-10 seconds
3. **Bonjour Discovery** (30-40%): 10 seconds fixed
4. **Port Scanning** (40-100%): Sequential, ~2-5 seconds per device

**Total Time:** 35-70 seconds for typical network

## Performance Bottlenecks Identified

###1 **Fixed 10-Second Bonjour Wait**
**Location:** `BonjourScanner.swift:181-186`
```swift
for i in 1...10 {
    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    // ... progress updates
}
```

**Impact:** Always waits 10 full seconds even if all devices discovered in 2 seconds
**Optimization Opportunity:** HIGH

### 2. **Sequential Port Scanning**
**Location:** `IntegratedDashboardViewV3.swift:1096-1110`
```swift
for (index, host) in sortedHosts.enumerated() {
    let openPorts = await portScanner.scanPorts(host: host, ports: portsToScan)
    // Sequential - each host must complete before next starts
}
```

**Impact:** With 20 devices × 3 seconds each = 60 seconds
**Optimization Opportunity:** CRITICAL

### 3. **Redundant Bonjour Scans**
**Impact:** Both HomeKit tab and Dashboard run full Bonjour scans separately
**Optimization Opportunity:** MEDIUM

### 4. **Large Port Lists**
**Impact:** Scanning 100+ ports per device when HomeKit only uses ~5 ports
**Optimization Opportunity:** HIGH

### 5. **Process.waitUntilExit() in Port Scanner**
**Location:** `AdvancedPortScanner.swift:129`
```swift
try process.run()
process.waitUntilExit() // Blocks until complete
```

**Impact:** Synchronous blocking prevents parallelization
**Optimization Opportunity:** HIGH

## Optimization Recommendations

### Priority 1: Parallel Port Scanning (CRITICAL)
**Time Savings:** 50-70%

**Current:**
```swift
for host in hosts {
    await portScanner.scanPorts(host, ports) // Sequential: 3s each
}
// Total for 20 hosts: 60 seconds
```

**Optimized:**
```swift
await withTaskGroup(of: (String, [Int]).self) { group in
    for host in hosts {
        group.addTask {
            let ports = await self.portScanner.scanPorts(host, self.portsToScan)
            return (host, ports)
        }
    }

    for await (host, ports) in group {
        // Process results as they complete
        updateDevice(host, ports)
    }
}
// Total for 20 hosts: ~5-8 seconds (parallel)
```

**Implementation:**
- Modify `scanPortsOnDevices()` in `IntegratedDashboardViewV3.swift` (line 1192)
- Add concurrency limit (e.g., 10 concurrent scans max to avoid overwhelming network)
- Update progress based on completed scans vs total

### Priority 2: Smart Bonjour Discovery (HIGH)
**Time Savings:** 40-60%

**Current:**
- Always waits 10 seconds
- Discovery might complete in 2-3 seconds

**Optimized:**
```swift
// Early termination when discovery stabilizes
var discoveredCount = 0
var stableCount = 0
let maxWait = 10
let earlyExitThreshold = 3 // Exit if no new devices for 3 seconds

for i in 1...maxWait {
    try? await Task.sleep(nanoseconds: 1_000_000_000)

    let currentCount = discoveredDevices.count
    if currentCount == discoveredCount {
        stableCount += 1
        if stableCount >= earlyExitThreshold {
            print("🔍 Bonjour: Early exit - no new devices for \(earlyExitThreshold)s")
            break
        }
    } else {
        discoveredCount = currentCount
        stableCount = 0
    }
}
```

**Benefits:**
- Typical completion: 3-5 seconds instead of 10
- Still captures all devices (waits for stability)
- Falls back to 10s if devices keep appearing

### Priority 3: HomeKit-Specific Port List (HIGH)
**Time Savings:** 30-50% for HomeKit scans

**Current:**
- Scans 100+ common ports per device
- Most irrelevant for HomeKit

**Optimized:**
```swift
// HomeKit-specific ports
let homeKitPorts = [
    80,    // HTTP (HAP)
    443,   // HTTPS (secure HAP)
    5353,  // mDNS
    8080,  // Alternate HTTP
    8443,  // Alternate HTTPS
    62078  // HAP (HomeKit Accessory Protocol)
]

// Use focused port list for HomeKit scans
if scanType == .homeKit {
    portsToScan = homeKitPorts
} else {
    portsToScan = commonPorts  // Full list for general scans
}
```

**Implementation:**
- Add `ScanType` enum to distinguish HomeKit vs general scans
- Use optimized port list in `HomeKitTabView.scanForHomeKitDevices()`
- Keep full port list for dashboard scans

### Priority 4: Cached Bonjour Results (MEDIUM)
**Time Savings:** 10-15 seconds on repeat scans

**Strategy:**
```swift
class BonjourCache {
    static let shared = BonjourCache()
    private var cache: [String: BonjourDeviceMetadata] = [:]
    private var cacheTime: Date?
    private let cacheValidDuration: TimeInterval = 300 // 5 minutes

    func getCachedResults() -> [String: BonjourDeviceMetadata]? {
        guard let time = cacheTime,
              Date().timeIntervalSince(time) < cacheValidDuration else {
            return nil
        }
        return cache
    }

    func updateCache(_ results: [String: BonjourDeviceMetadata]) {
        cache = results
        cacheTime = Date()
    }
}
```

**Benefits:**
- Repeated scans within 5 minutes use cached data
- Refresh button forces new scan
- Automatic expiration ensures freshness

### Priority 5: Concurrent Ping Scanning (MEDIUM)
**Time Savings:** 20-40% for large subnets

**Current:**
- `pingSubnet()` likely sequential or limited parallelism

**Optimized:**
```swift
func pingSubnet(_ subnet: String) async -> Set<String> {
    return await withTaskGroup(of: String?.self) { group in
        var aliveHosts: Set<String> = []

        // Ping in batches of 50 to avoid overwhelming
        for i in 1...254 {
            group.addTask {
                let host = "\(subnet).\(i)"
                return await self.ping(host) ? host : nil
            }

            // Process results as they complete
            if i % 50 == 0 || i == 254 {
                for await result in group {
                    if let host = result {
                        aliveHosts.insert(host)
                    }
                }
            }
        }

        return aliveHosts
    }
}
```

## Implementation Priority

### Immediate (Today):
1. ✅ Parallel port scanning with concurrency limit
2. ✅ Smart Bonjour early termination
3. ✅ HomeKit-specific port list

### Short-term (This Week):
4. Bonjour result caching
5. Concurrent ping scanning

### Long-term (Future):
6. Progressive result display (show devices as discovered)
7. Background refresh (update without full re-scan)
8. Incremental scanning (only scan new IPs)

## Expected Performance Improvements

### HomeKit Scan:
- **Before:** 25-60 seconds
- **After:** 8-15 seconds
- **Improvement:** 70-80% faster

### Dashboard Full Scan:
- **Before:** 35-70 seconds
- **After:** 12-20 seconds
- **Improvement:** 65-75% faster

## Testing Requirements

### Accuracy Testing:
- ✅ Verify all devices still discovered (no false negatives)
- ✅ Test on networks with 5, 10, 20, 50 devices
- ✅ Test with various HomeKit device types
- ✅ Verify timeout handling still works

### Performance Testing:
- ✅ Measure actual scan times before/after
- ✅ Monitor CPU and network usage
- ✅ Test with slow-responding devices
- ✅ Verify UI remains responsive

### Edge Cases:
- ✅ Empty network (no devices)
- ✅ Large network (100+ devices)
- ✅ Mixed device types (HomeKit, non-HomeKit)
- ✅ Devices joining/leaving during scan

## Trade-offs & Considerations

### Parallel Scanning:
**Pros:**
- Dramatically faster
- Better resource utilization

**Cons:**
- Higher network load during scan
- May trigger IDS/IPS on enterprise networks
- Need concurrency limits

**Mitigation:**
- Limit to 10-15 concurrent scans
- Add option for "gentle mode" (sequential) for sensitive networks
- Respect rate limiting

### Early Termination:
**Pros:**
- Faster when few devices
- Still accurate

**Cons:**
- Might miss slow-responding devices
- Need tuning of stability threshold

**Mitigation:**
- Configurable threshold (2-5 seconds)
- Always respect minimum wait time (e.g., 3 seconds)
- Log early exits for debugging

### Focused Port Lists:
**Pros:**
- Much faster for HomeKit scans
- Less network noise

**Cons:**
- Might miss non-standard ports
- Need different lists for different scan types

**Mitigation:**
- Keep full port list option
- Document port choices
- Allow custom port lists in settings

## Code Locations to Modify

### High Priority:
1. **BonjourScanner.swift:181-186** - Add early termination
2. **IntegratedDashboardViewV3.swift:1096-1163** - Parallel port scanning
3. **HomeKitTabView.swift:180** - Add HomeKit-specific ports
4. **IntegratedDashboardViewV3.swift:1192-1310** - Parallel port scanning

### Medium Priority:
5. **PingScanner.swift** - Add concurrent ping scanning
6. Create **BonjourCache.swift** - New file for caching

## Security Considerations

### Network Scanning Ethics:
- Parallel scanning is more "noisy" - may be detected as attack
- Add user-configurable "scan intensity" settings:
  - **Gentle:** Sequential, slower (current behavior)
  - **Normal:** Moderate parallelism (5 concurrent)
  - **Aggressive:** High parallelism (15 concurrent)

### Rate Limiting:
- Implement exponential backoff for failed connections
- Respect network congestion signals
- Add delays between scan phases if network errors detected

### Permission Model:
- Document that aggressive scanning may trigger security alerts
- Add disclaimer about network scanning policies
- Respect Do Not Scan lists if implemented

## Documentation Updates Needed

1. Update user guide with performance expectations
2. Document scan intensity settings
3. Add troubleshooting for slow scans
4. Explain early termination logic
5. Document HomeKit port list rationale

---

**Next Steps:**
1. Implement Priority 1-3 optimizations
2. Test thoroughly on various network sizes
3. Measure and document performance improvements
4. Deploy optimized version as v8.4.0

**Authors:** Jordan Koch & Claude Code
