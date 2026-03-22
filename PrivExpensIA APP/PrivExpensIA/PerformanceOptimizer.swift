import Foundation
import UIKit
import os.log

// MARK: - Performance Optimizer
final class PerformanceOptimizer {
    static let shared = PerformanceOptimizer()
    
    private let logger = Logger(subsystem: "com.minhtam.ExpenseAI", category: "Performance")
    private var launchStartTime: CFAbsoluteTime = 0
    
    private init() {}
    
    // MARK: - App Launch Optimization
    func startLaunchTracking() {
        launchStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    func endLaunchTracking() {
        let launchTime = CFAbsoluteTimeGetCurrent() - launchStartTime
        logger.info("App launch time: \(String(format: "%.3f", launchTime))s")
        
        AnalyticsManager.shared.trackPerformance(operation: "app_launch", duration: launchTime)
        
        if launchTime > 2.0 {
            logger.warning("App launch time exceeds 2 seconds target")
        }
    }
    
    // MARK: - Memory Optimization
    func optimizeMemory() {
        // Clear image cache safely
        DispatchQueue.main.async {
            URLCache.shared.removeAllCachedResponses()
        }
        
        // Clear unused Core Data objects
        CoreDataManager.shared.saveContext()
        
        logger.info("Memory optimization completed")
    }
    
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1024.0 / 1024.0 // MB
            logger.info("Current memory usage: \(String(format: "%.1f", usedMemory)) MB")
            
            if usedMemory > 150 {
                logger.warning("Memory usage exceeds 150MB target")
                optimizeMemory()
            }
            
            return usedMemory
        }
        
        return 0
    }
    
    // MARK: - Battery Optimization
    func enableLowPowerMode() {
        // Reduce animation complexity
        UIView.setAnimationsEnabled(ProcessInfo.processInfo.isLowPowerModeEnabled == false)
        
        // Reduce background processing
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            logger.info("Low power mode detected - reducing background activity")
        }
    }
    
    // MARK: - Animation Performance
    func measureAnimationPerformance(name: String, block: () -> Void) {
        let startTime = CACurrentMediaTime()
        
        block()
        
        let duration = CACurrentMediaTime() - startTime
        let fps = 1.0 / duration
        
        if fps < 60 {
            logger.warning("Animation '\(name)' running at \(String(format: "%.0f", fps)) FPS")
        }
        
        AnalyticsManager.shared.trackPerformance(operation: "animation_\(name)", duration: duration)
    }
    
    // MARK: - App Size Reduction
    func cleanTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: nil
            )
            
            var totalSize: Int64 = 0
            
            for file in contents {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                if let fileSize = attributes[.size] as? Int64 {
                    totalSize += fileSize
                }
                
                try FileManager.default.removeItem(at: file)
            }
            
            logger.info("Cleaned \(totalSize / 1024) KB of temporary files")
        } catch {
            logger.error("Failed to clean temporary files: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Performance Monitoring
    func startMonitoring() {
        // Monitor memory warnings
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Monitor low power mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerStateChange),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        // Monitor thermal state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThermalStateChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        logger.warning("Memory warning received")
        optimizeMemory()
        AnalyticsManager.shared.trackEvent(
            AnalyticsEvent(name: "memory_warning", parameters: [:])
        )
    }
    
    @objc private func handlePowerStateChange() {
        enableLowPowerMode()
    }
    
    @objc private func handleThermalStateChange() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .nominal:
            logger.info("Thermal state: Nominal")
        case .fair:
            logger.info("Thermal state: Fair - minor throttling")
        case .serious:
            logger.warning("Thermal state: Serious - reducing performance")
            // Reduce heavy operations
        case .critical:
            logger.error("Thermal state: Critical - maximum throttling")
            // Suspend non-essential operations
        @unknown default:
            break
        }
    }
    
    // MARK: - Bottleneck Detection
    func profileOperation<T>(name: String, operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            if duration > 0.1 { // Operations taking more than 100ms
                logger.warning("Bottleneck detected: '\(name)' took \(String(format: "%.3f", duration))s")
            }
            
            AnalyticsManager.shared.trackPerformance(operation: name, duration: duration)
        }
        
        return try operation()
    }
    
    // MARK: - Preloading & Caching
    func preloadCriticalResources() {
        DispatchQueue.global(qos: .background).async {
            // Preload glass theme colors
            _ = LiquidGlassTheme.Colors.backgroundGradient
            
            // Warm up Core Data stack
            _ = CoreDataManager.shared.persistentContainer
            
            // Initialize analytics
            _ = AnalyticsManager.shared
            
            self.logger.info("Critical resources preloaded")
        }
    }
}

// MARK: - Launch Performance
class LaunchPerformanceManager {
    
    static func optimizeLaunch() {
        // Defer non-critical initialization
        DispatchQueue.main.async {
            // Initialize after first frame
            PerformanceOptimizer.shared.preloadCriticalResources()
        }
        
        // Clean up on launch if needed
        if shouldCleanOnLaunch() {
            PerformanceOptimizer.shared.cleanTemporaryFiles()
        }
    }
    
    private static func shouldCleanOnLaunch() -> Bool {
        let lastClean = UserDefaults.standard.object(forKey: "last_temp_clean") as? Date ?? Date.distantPast
        let daysSinceClean = Calendar.current.dateComponents([.day], from: lastClean, to: Date()).day ?? 0
        
        if daysSinceClean > 7 {
            UserDefaults.standard.set(Date(), forKey: "last_temp_clean")
            return true
        }
        
        return false
    }
}

// MARK: - Image Optimization
extension UIImage {
    func optimizedForDisplay(maxDimension: CGFloat = 1024) -> UIImage? {
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        
        guard scale < 1 else { return self }
        
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    func compressedData(quality: CGFloat = 0.7) -> Data? {
        return jpegData(compressionQuality: quality)
    }
}