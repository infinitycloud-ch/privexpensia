import SwiftUI
import VisionKit
import UIKit

// MARK: - One-Click Scanner View - Jony Ive Style
// Direct camera access with automatic receipt detection and processing

struct OneClickScannerView: View {
    @Binding var isProcessing: Bool
    @Binding var extractedData: ExtractedExpenseData?
    @Binding var showingResult: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var scannedImage: UIImage?
    @State private var scanProgress: Double = 0
    @State private var statusMessage = ""

    var body: some View {
        ZStack {
            // Full screen camera
            if isProcessing {
                processingView
            } else {
                DocumentScannerView { image in
                    processScannedImage(image)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Processing View

    private var processingView: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Jony Ive inspired processing animation
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 120, height: 120)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: scanProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: scanProgress)

                    // Center icon
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(.white)
                }

                VStack(spacing: 8) {
                    Text("Processing Receipt")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.white)

                    Text(statusMessage)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: statusMessage)
                }
            }
        }
    }

    // MARK: - Processing Logic

    private func processScannedImage(_ image: UIImage) {
        scannedImage = image
        isProcessing = true

        // Simulate progressive processing steps
        simulateProcessing()
    }

    private func simulateProcessing() {
        // Step 1: Image Analysis
        withAnimation(.easeInOut(duration: 0.5)) {
            scanProgress = 0.3
            statusMessage = "Analyzing image..."
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Step 2: Text Recognition
            withAnimation(.easeInOut(duration: 0.5)) {
                scanProgress = 0.6
                statusMessage = "Extracting text..."
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Step 3: AI Processing
                withAnimation(.easeInOut(duration: 0.5)) {
                    scanProgress = 0.9
                    statusMessage = "AI analysis..."
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Step 4: Complete
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scanProgress = 1.0
                        statusMessage = "Complete!"
                    }

                    // Generate mock data for now (replace with real OCR/AI processing)
                    generateMockExpenseData()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isProcessing = false
                        dismiss()
                        showingResult = true
                    }
                }
            }
        }
    }

    private func generateMockExpenseData() {
        // Mock data - replace with real OCR/AI processing
        extractedData = ExtractedExpenseData(
            merchant: "Coop",
            totalAmount: 45.50,
            taxAmount: 3.45,
            date: Date(),
            category: "Alimentation",
            items: "Pain, Lait, Fromage",
            paymentMethod: "Card",
            confidence: 0.92,
            rawOCRText: nil  // Mock data - no OCR text
        )
    }
}

// MARK: - Document Scanner View (VisionKit Wrapper)

struct DocumentScannerView: UIViewControllerRepresentable {
    let completion: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView

        init(_ parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Get first scanned page
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                parent.completion(image)
            }
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
    }
}