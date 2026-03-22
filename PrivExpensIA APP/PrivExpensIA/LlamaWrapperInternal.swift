import Foundation

// MARK: - Llama Wrapper Internal
// This is a copy of the LlamaWrapper code that works with conditional compilation
// When llama.xcframework is added to the project via Xcode UI, this will use real inference

#if canImport(llama)
import llama
private let llamaModuleAvailable = true
#else
private let llamaModuleAvailable = false
#endif

public final class LlamaWrapperInternal {
    public static let shared = LlamaWrapperInternal()

    #if canImport(llama)
    private var model: OpaquePointer?
    private var context: OpaquePointer?
    private var sampler: UnsafeMutablePointer<llama_sampler>?
    #endif

    private var isInitialized = false

    public var isModelLoaded: Bool {
        #if canImport(llama)
        return isInitialized && model != nil
        #else
        return false
        #endif
    }

    public var isLlamaAvailable: Bool {
        return llamaModuleAvailable
    }

    private init() {
        #if canImport(llama)
        llama_backend_init()
        #else
        #endif
    }

    deinit {
        unloadModel()
        #if canImport(llama)
        llama_backend_free()
        #endif
    }

    // MARK: - Model Loading

    public func loadModel(from url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LlamaWrapperInternalError.modelNotFound(url.path)
        }

        #if canImport(llama)
        unloadModel()

        let startTime = Date()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 0
        modelParams.use_mmap = true

        guard let loadedModel = llama_model_load_from_file(url.path, modelParams) else {
            throw LlamaWrapperInternalError.failedToLoadModel
        }
        self.model = loadedModel

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = 2048
        ctxParams.n_batch = 512
        ctxParams.n_threads = Int32(min(8, ProcessInfo.processInfo.processorCount))
        ctxParams.n_threads_batch = ctxParams.n_threads

        guard let ctx = llama_init_from_model(loadedModel, ctxParams) else {
            llama_model_free(loadedModel)
            self.model = nil
            throw LlamaWrapperInternalError.failedToCreateContext
        }
        self.context = ctx

        let samplerChain = llama_sampler_chain_init(llama_sampler_chain_default_params())
        llama_sampler_chain_add(samplerChain, llama_sampler_init_temp(0.3))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_k(40))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(samplerChain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        self.sampler = samplerChain

        isInitialized = true

        let loadTime = Date().timeIntervalSince(startTime)
        #else
        throw LlamaWrapperInternalError.llamaNotAvailable
        #endif
    }

    public func unloadModel() {
        #if canImport(llama)
        if let sampler = sampler {
            llama_sampler_free(sampler)
            self.sampler = nil
        }
        if let context = context {
            llama_free(context)
            self.context = nil
        }
        if let model = model {
            llama_model_free(model)
            self.model = nil
        }
        #endif
        isInitialized = false
    }

    // MARK: - Inference

    #if canImport(llama)
    public func generateText(prompt: String, maxTokens: Int = 256) throws -> String {
        guard let model = model, let context = context, let sampler = sampler else {
            throw LlamaWrapperInternalError.modelNotLoaded
        }

        let startTime = Date()

        let vocab = llama_model_get_vocab(model)

        if let kv = llama_get_memory(context) {
            llama_memory_clear(kv, true)
        }

        let maxInputTokens = Int32(prompt.utf8.count + 128)
        var tokens = [llama_token](repeating: 0, count: Int(maxInputTokens))
        let nTokens = llama_tokenize(vocab, prompt, Int32(prompt.utf8.count), &tokens, maxInputTokens, true, true)

        guard nTokens > 0 else {
            throw LlamaWrapperInternalError.tokenizationFailed
        }

        tokens = Array(tokens.prefix(Int(nTokens)))

        var batch = llama_batch_init(512, 0, 1)
        defer { llama_batch_free(batch) }

        for (i, token) in tokens.enumerated() {
            batch.token[i] = token
            batch.pos[i] = Int32(i)
            batch.n_seq_id[i] = 1
            batch.seq_id[i]![0] = 0
            batch.logits[i] = (i == tokens.count - 1) ? 1 : 0
        }
        batch.n_tokens = Int32(tokens.count)

        guard llama_decode(context, batch) == 0 else {
            throw LlamaWrapperInternalError.decodeFailed
        }

        var response = ""
        var currentPosition = Int32(tokens.count)

        for _ in 0..<maxTokens {
            let newToken = llama_sampler_sample(sampler, context, -1)

            if llama_vocab_is_eog(vocab, newToken) {
                break
            }

            var buf = [CChar](repeating: 0, count: 64)
            let len = llama_token_to_piece(vocab, newToken, &buf, 64, 0, false)
            if len > 0 {
                let tokenStr = String(cString: Array(buf.prefix(Int(len))) + [0])
                response += tokenStr
            }

            if response.contains("}") {
                let openBraces = response.filter { $0 == "{" }.count
                let closeBraces = response.filter { $0 == "}" }.count
                if openBraces > 0 && openBraces == closeBraces {
                    break
                }
            }

            batch.n_tokens = 0
            batch.token[0] = newToken
            batch.pos[0] = currentPosition
            batch.n_seq_id[0] = 1
            batch.seq_id[0]![0] = 0
            batch.logits[0] = 1
            batch.n_tokens = 1
            currentPosition += 1

            guard llama_decode(context, batch) == 0 else {
                break
            }
        }

        let inferenceTime = Date().timeIntervalSince(startTime)

        return response
    }
    #endif

    // MARK: - Expense Extraction

    public func extractExpense(from ocrText: String) throws -> ExpenseExtractionResponseInternal {
        #if canImport(llama)
        let prompt = """
        <|im_start|>system
        You are a receipt parser. Extract information and return ONLY valid JSON.
        Fields: merchant, total_amount, tax_amount, date (YYYY-MM-DD), category, currency.
        Categories: Alimentation, Restaurant, Transport, Shopping, Sante, Loisirs, Autre.
        <|im_end|>
        <|im_start|>user
        Receipt:
        \(ocrText.prefix(500))

        JSON:
        <|im_end|>
        <|im_start|>assistant
        """

        let startTime = Date()
        let response = try generateText(prompt: prompt, maxTokens: 200)
        let inferenceTime = Date().timeIntervalSince(startTime)

        return parseExpenseResponse(response, inferenceTime: inferenceTime)
        #else
        throw LlamaWrapperInternalError.llamaNotAvailable
        #endif
    }

    private func parseExpenseResponse(_ response: String, inferenceTime: TimeInterval) -> ExpenseExtractionResponseInternal {
        var jsonString = response
        if let jsonStart = response.range(of: "{"),
           let jsonEnd = response.range(of: "}", options: .backwards) {
            jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ExpenseExtractionResponseInternal(
                merchant: "Unknown",
                totalAmount: 0,
                taxAmount: 0,
                date: nil,
                category: "Autre",
                currency: "CHF",
                confidence: 0.3,
                inferenceTime: inferenceTime,
                method: "LLM-Qwen-ParseError"
            )
        }

        return ExpenseExtractionResponseInternal(
            merchant: json["merchant"] as? String ?? "Unknown",
            totalAmount: parseAmount(json["total_amount"]),
            taxAmount: parseAmount(json["tax_amount"]),
            date: parseDate(json["date"] as? String),
            category: json["category"] as? String ?? "Autre",
            currency: json["currency"] as? String ?? "CHF",
            confidence: 0.9,
            inferenceTime: inferenceTime,
            method: "LLM-Qwen-Real"
        )
    }

    private func parseAmount(_ value: Any?) -> Double {
        // Handle Double directly
        if let doubleValue = value as? Double {
            return doubleValue
        }
        // Handle Int
        if let intValue = value as? Int {
            return Double(intValue)
        }
        // Handle String (LLM often returns "271.00" as string)
        if let stringValue = value as? String {
            let cleaned = stringValue.replacingOccurrences(of: ",", with: ".")
            return Double(cleaned) ?? 0
        }
        return 0
    }

    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - Response Types

public struct ExpenseExtractionResponseInternal {
    public let merchant: String
    public let totalAmount: Double
    public let taxAmount: Double
    public let date: Date?
    public let category: String
    public let currency: String
    public let confidence: Double
    public let inferenceTime: TimeInterval
    public let method: String

    public var isFromRealLLM: Bool {
        method.contains("LLM") && method.contains("Real")
    }
}

// MARK: - Errors

public enum LlamaWrapperInternalError: LocalizedError {
    case llamaNotAvailable
    case modelNotFound(String)
    case failedToLoadModel
    case failedToCreateContext
    case modelNotLoaded
    case tokenizationFailed
    case decodeFailed
    case inferenceFailed

    public var errorDescription: String? {
        switch self {
        case .llamaNotAvailable:
            return "llama.xcframework not added to project. Add via Xcode UI: Target > General > Frameworks"
        case .modelNotFound(let path):
            return "Model not found at: \(path)"
        case .failedToLoadModel:
            return "Failed to load model"
        case .failedToCreateContext:
            return "Failed to create context"
        case .modelNotLoaded:
            return "Model not loaded"
        case .tokenizationFailed:
            return "Tokenization failed"
        case .decodeFailed:
            return "Decode failed"
        case .inferenceFailed:
            return "Inference failed"
        }
    }
}
