import Vision
import VisionKit
import UIKit
import SwiftUI

class OCRService: NSObject {
    static let shared = OCRService()
    
    private override init() {
        super.init()
    }
    
    private var performanceTimer: Date?
    private var resultsCache = [String: ExtractedData]()
    
    // MARK: - Simple OCR (Vision only)
    func processImageSimple(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {

        guard let preprocessedImage = preprocessImage(image) else {
            completion(.failure(OCRError.poorImageQuality))
            return
        }

        guard let cgImage = preprocessedImage.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage,
                                                  orientation: detectImageOrientation(image),
                                                  options: [:])

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextFound))
                return
            }

            let extractedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            completion(.success(extractedText))
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        do {
            try requestHandler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }

    func processImage(_ image: UIImage, completion: @escaping (Result<ExtractedData, Error>) -> Void) {
        performanceTimer = Date()

        // Vérifier qualité image
        guard let preprocessedImage = preprocessImage(image) else {
            completion(.failure(OCRError.poorImageQuality))
            return
        }

        // Check cache
        let imageKey = "\(image.hashValue)"
        if let cachedResult = resultsCache[imageKey] {
            completion(.success(cachedResult))
            return
        }
        
        guard let cgImage = preprocessedImage.cgImage else {
            completion(.failure(OCRError.invalidImage))
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, 
                                                  orientation: detectImageOrientation(image),
                                                  options: [:])
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextFound))
                return
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            let processingTime = Date().timeIntervalSince(self?.performanceTimer ?? Date())
            
            let extractedData = ExtractedData(
                text: recognizedText,
                language: "multi",
                processingTime: processingTime,
                confidence: observations.first?.confidence ?? 0
            )
            
            // Cache result
            self?.resultsCache[imageKey] = extractedData
            completion(.success(extractedData))
        }
        
        request.recognitionLanguages = ["fr", "de", "it", "en", "ja", "ko", "sk", "es"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01
        request.automaticallyDetectsLanguage = true
        
        do {
            try requestHandler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }
    
    private func preprocessImage(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        
        // Améliorer contraste et netteté
        let filter = ciImage
            .applyingFilter("CIColorControls", parameters: [
                "inputSaturation": 0,
                "inputContrast": 1.2,
                "inputBrightness": 0.1
            ])
            .applyingFilter("CISharpenLuminance", parameters: [
                "inputSharpness": 0.4
            ])
        
        guard let outputImage = context.createCGImage(filter, from: filter.extent) else {
            return image
        }
        
        return UIImage(cgImage: outputImage)
    }
    
    private func detectImageOrientation(_ image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

struct ExtractedData {
    let text: String
    let language: String
    let processingTime: TimeInterval
    let confidence: Float
    
    var performanceStatus: String {
        processingTime < 2.0 ? "✅ Performance OK" : "⚠️ Performance dégradée"
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case poorImageQuality
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "L'image fournie n'est pas valide"
        case .noTextFound:
            return "Aucun texte trouvé dans l'image"
        case .poorImageQuality:
            return "La qualité de l'image est insuffisante. Veuillez prendre une photo plus nette."
        }
    }
}

struct DocumentCameraViewController: UIViewControllerRepresentable {
    @Binding var scannedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraViewController
        
        init(_ parent: DocumentCameraViewController) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                parent.scannedImage = scan.imageOfPage(at: 0)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}