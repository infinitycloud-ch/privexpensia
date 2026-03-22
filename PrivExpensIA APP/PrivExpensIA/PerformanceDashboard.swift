import SwiftUI

// Performance monitoring dashboard for production
struct PerformanceDashboard: View {
    @StateObject private var monitor = PerformanceMonitor()
    @State private var isMonitoring = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Real-time metrics
                    metricsSection
                    
                    // Cache statistics
                    cacheSection
                    
                    // Performance graph
                    performanceGraph
                    
                    // Error log
                    errorSection
                    
                    // Controls
                    controlsSection
                }
                .padding()
            }
            .navigationTitle(LocalizationManager.shared.localized("performance.title"))
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            monitor.startMonitoring()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: monitor.isPerformant ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(monitor.isPerformant ? .green : .orange)
                    .font(.title)
                
                Text(monitor.isPerformant ? "System Performant" : "Performance Issues Detected")
                    .font(.headline)
                
                Spacer()
            }
            
            HStack {
                Label("\(monitor.memoryUsage)", systemImage: "memorychip")
                Spacer()
                Label("\(String(format: "%.0fms", monitor.avgInferenceTime * 1000))", systemImage: "timer")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Live Metrics")
                .font(.headline)
            
            MetricRow(title: "Total Inferences", value: "\(monitor.totalInferences)")
            MetricRow(title: "Success Rate", value: "\(String(format: "%.1f%%", monitor.successRate * 100))")
            MetricRow(title: "Avg Inference Time", value: "\(String(format: "%.0fms", monitor.avgInferenceTime * 1000))")
            MetricRow(title: "Peak Memory", value: "\(String(format: "%.1f MB", monitor.peakMemory))")
            
            if monitor.avgInferenceTime < 0.3 {
                Label("✅ Meeting < 300ms target", systemImage: "checkmark.circle")
                    .foregroundColor(.green)
                    .font(.caption)
            }
            
            if monitor.peakMemory < 150 {
                Label("✅ Meeting < 150MB target", systemImage: "checkmark.circle")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Cache Performance")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Cache Hits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(monitor.cacheHits)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Hit Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f%%", monitor.cacheHitRate * 100))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(monitor.cacheHitRate > 0.5 ? .green : .orange)
                }
            }
            
            ProgressView(value: monitor.cacheHitRate)
                .tint(monitor.cacheHitRate > 0.5 ? .green : .orange)
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var performanceGraph: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inference Times (last 20)")
                .font(.headline)
            
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(monitor.recentInferenceTimes.suffix(20), id: \.self) { time in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(time < 0.3 ? Color.green : Color.orange)
                        .frame(width: 12, height: CGFloat(time * 200))
                }
            }
            .frame(height: 100)
            
            HStack {
                Text("0ms")
                    .font(.caption2)
                Spacer()
                Text("300ms")
                    .font(.caption2)
                Spacer()
                Text("600ms")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Errors")
                    .font(.headline)
                Spacer()
                Text("\(monitor.failedInferences) failed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if monitor.lastError.isEmpty {
                Text("No recent errors")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.vertical, 5)
            } else {
                Text(monitor.lastError)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(5)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(10)
    }
    
    private var controlsSection: some View {
        VStack(spacing: 15) {
            Button(action: {
                monitor.clearCache()
            }) {
                Label("Clear Cache", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            Button(action: {
                monitor.resetMetrics()
            }) {
                Label("Reset Metrics", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            
            Button(action: {
                monitor.runTestInference()
            }) {
                Label("Run Test Inference", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct MetricRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// Performance Monitor ViewModel
class PerformanceMonitor: ObservableObject {
    @Published var isPerformant = true
    @Published var memoryUsage = "0 MB"
    @Published var avgInferenceTime: Double = 0
    @Published var totalInferences = 0
    @Published var successRate: Double = 0
    @Published var peakMemory: Double = 0
    @Published var cacheHits = 0
    @Published var cacheHitRate: Double = 0
    @Published var failedInferences = 0
    @Published var lastError = ""
    @Published var recentInferenceTimes: [Double] = []
    
    private let qwenManager = QwenModelManager.shared
    private var timer: Timer?
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateMetrics()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMetrics() {
        let metrics = qwenManager.getPerformanceMetrics()
        let cacheStats = qwenManager.getCacheStatistics()
        
        DispatchQueue.main.async {
            self.isPerformant = self.qwenManager.isSystemPerformant()
            self.memoryUsage = self.qwenManager.getCurrentMemoryUsage()
            self.avgInferenceTime = metrics.averageInferenceTime
            self.totalInferences = metrics.totalInferences
            self.successRate = metrics.successRate
            self.peakMemory = Double(metrics.peakMemoryUsage) / 1024 / 1024
            self.cacheHits = cacheStats.hits
            self.cacheHitRate = cacheStats.hitRate
            self.failedInferences = metrics.failedInferences
            
            if let error = metrics.lastError {
                self.lastError = error.localizedDescription
            }
            
            // Keep last 20 inference times for graph
            if self.recentInferenceTimes.count > 20 {
                self.recentInferenceTimes.removeFirst()
            }
            if metrics.averageInferenceTime > 0 {
                self.recentInferenceTimes.append(metrics.averageInferenceTime)
            }
        }
    }
    
    func clearCache() {
        qwenManager.resetPerformance()
        updateMetrics()
    }
    
    func resetMetrics() {
        qwenManager.resetPerformance()
        recentInferenceTimes.removeAll()
        updateMetrics()
    }
    
    func runTestInference() {
        let testText = """
        TEST STORE
        Date: \(Date())
        Item 1: 10.00
        Item 2: 15.00
        Total: 25.00
        """
        
        qwenManager.runInference(prompt: testText) { _ in
            self.updateMetrics()
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

// Preview
struct PerformanceDashboard_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDashboard()
    }
}