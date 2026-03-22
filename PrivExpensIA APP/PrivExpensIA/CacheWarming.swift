import Foundation
import UIKit

// MARK: - Cache Warming Service
// Preloads common receipt patterns for instant first inference

class CacheWarmingService {
    static let shared = CacheWarmingService()
    private let qwenManager = QwenModelManager.shared
    
    private init() {}
    
    // Common receipt patterns to preload
    private let warmupSamples = [
        // French restaurant
        """
        RESTAURANT LE BISTRO
        Date: 12/09/2025
        Plat du jour: 15.00€
        Dessert: 6.00€
        Total: 21.00€
        """,
        
        // Supermarket
        """
        CARREFOUR
        12/09/2025
        Articles: 5
        Total: 45.50€
        CB ****1234
        """,
        
        // Coffee shop
        """
        STARBUCKS
        Cappuccino 4.50
        Croissant 2.50
        Total $7.00
        """,
        
        // Transport
        """
        UBER
        Ride fare: $25.00
        Tip: $5.00
        Total: $30.00
        """,
        
        // Gas station
        """
        SHELL
        Unleaded 95
        50 Litres
        Total: 85.00€
        """
    ]
    
    // MARK: - Public Methods
    
    /// Warms up the cache at app startup
    func warmCache(completion: @escaping (Bool) -> Void) {
        let startTime = Date()
        
        // Load model first if needed
        qwenManager.downloadModel(progress: { _ in }) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success:
                self.preloadSamples { success in
                    let warmupTime = Date().timeIntervalSince(startTime)
                    completion(success)
                }
                
            case .failure(let error):
                completion(false)
            }
        }
    }
    
    /// Preloads sample receipts into cache
    private func preloadSamples(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var successCount = 0
        
        for sample in warmupSamples.prefix(Constants.Cache.warmupItemCount) {
            group.enter()
            
            // Run inference to populate cache
            qwenManager.runInference(prompt: sample) { result in
                if case .success = result {
                    successCount += 1
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let success = successCount > 0
            if success {
            }
            completion(success)
        }
    }
    
    /// Intelligent preloading based on usage patterns
    func preloadBasedOnHistory() {
        // Future: Analyze Core Data for common merchants
        // and preload those patterns
    }
    
    /// Clears old cache entries
    func cleanupCache() {
        qwenManager.resetPerformance()
    }
}

// MARK: - App Startup Extension
extension UIResponder {
    
    /// Call this in applicationDidFinishLaunching
    func initializeCacheWarming() {
        // Run cache warming in background
        DispatchQueue.global(qos: .background).async {
            CacheWarmingService.shared.warmCache { success in
                DispatchQueue.main.async {
                    if success {
                        // Post notification for UI
                        NotificationCenter.default.post(
                            name: .cacheWarmingComplete,
                            object: nil
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let cacheWarmingComplete = Notification.Name("CacheWarmingComplete")
    static let modelLoadingStarted = Notification.Name("ModelLoadingStarted")
    static let modelLoadingComplete = Notification.Name("ModelLoadingComplete")
}