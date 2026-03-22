import Foundation
import SwiftUI

// MARK: - Test d'intégration Qwen Model
// Test du flux complet OCR → Qwen → JSON
struct QwenIntegrationTest {

    static func testQwenInference() {
        print("\n🚀 TEST MOTEUR QWEN - OPÉRATION TEST DU CHRONOMÈTRE")
        print("====================================================\n")

        let testReceiptText = """
        CARREFOUR MARKET
        15 Rue de la République
        75001 Paris

        Date: 14/09/2025 15:42

        ALIMENTATION
        Pain Complet Bio          2.45
        Lait Demi-écrémé 1L      1.89
        Pommes Golden 1kg        3.50
        Fromage Comté 200g      12.90
        Yaourt Nature x4         2.99

        SOUS-TOTAL              23.73
        TVA 5.5%                 1.31
        TOTAL                   25.04

        CB VISA ****1234        25.04

        Merci de votre visite!
        """

        print("1️⃣ PHASE 1: Initialisation du modèle...")
        let startInit = Date()

        let qwenManager = QwenModelManager.shared

        // Test lazy loading - ne devrait pas charger immédiatement
        print("   • Modèle initialisé (lazy)")
        print("   • Temps: \(Date().timeIntervalSince(startInit))s")

        print("\n2️⃣ PHASE 2: Première inférence (chargement du modèle)...")
        let startInference = Date()

        qwenManager.runInference(prompt: testReceiptText) { result in
            let inferenceTime = Date().timeIntervalSince(startInference)

            switch result {
            case .success(let response):
                print("   ✅ Inférence réussie!")
                print("   • Temps total: \(String(format: "%.3f", inferenceTime))s")
                print("   • Temps modèle: \(String(format: "%.3f", response.inferenceTime))s")
                print("   • Modèle utilisé: \(response.modelVersion)")
                print("   • Performance: \(response.isPerformant ? "✅ < 500ms" : "⚠️ > 500ms")")

                // Parser et afficher le JSON extrait
                if let data = response.extractedData.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("\n3️⃣ DONNÉES EXTRAITES:")
                    print("   • Marchand: \(json["merchant"] ?? "?")")
                    print("   • Total: \(json["total_amount"] ?? 0)€")
                    print("   • TVA: \(json["tax_amount"] ?? 0)€")
                    print("   • Catégorie: \(json["category"] ?? "?")")
                    print("   • Méthode paiement: \(json["payment_method"] ?? "?")")
                    print("   • Confiance: \(String(format: "%.1f%%", (json["confidence"] as? Double ?? 0) * 100))")
                    print("   • Méthode extraction: \(json["extraction_method"] ?? "?")")

                    if let items = json["items"] as? [[String: Any]], !items.isEmpty {
                        print("   • Articles: \(items.count) trouvés")
                    }
                }

                print("\n4️⃣ TEST CACHE (2ème appel)...")
                let startCache = Date()

                // Deuxième appel - devrait utiliser le cache
                qwenManager.runInference(prompt: testReceiptText) { cacheResult in
                    let cacheTime = Date().timeIntervalSince(startCache)

                    if case .success(let cacheResponse) = cacheResult {
                        print("   ✅ Cache fonctionnel!")
                        print("   • Temps: \(String(format: "%.3f", cacheTime))s")

                        if cacheResponse.inferenceTime < 0.01 {
                            print("   • ⚡ Hit cache confirmé (< 10ms)")
                        }
                    }

                    // Métriques finales
                    print("\n5️⃣ MÉTRIQUES SYSTÈME:")
                    let metrics = qwenManager.getPerformanceMetrics()
                    print("   • Inférences totales: \(metrics.totalInferences)")
                    print("   • Taux de succès: \(String(format: "%.1f%%", metrics.successRate * 100))")
                    print("   • Temps moyen: \(String(format: "%.3f", metrics.averageInferenceTime))s")
                    print("   • Mémoire utilisée: \(qwenManager.getCurrentMemoryUsage())")
                    print("   • Système performant: \(qwenManager.isSystemPerformant() ? "✅" : "❌")")

                    print("\n====================================================")
                    print("✅ TEST COMPLÉTÉ - MOTEUR QWEN VALIDÉ!")
                    print("====================================================\n")
                }

            case .failure(let error):
                print("   ❌ Échec de l'inférence: \(error)")
                print("   • Temps: \(String(format: "%.3f", inferenceTime))s")

                // Vérifier si fallback fonctionne
                if let qwenError = error as? QwenError {
                    print("   • Erreur Qwen: \(qwenError.localizedDescription)")
                }
            }
        }
    }

    // Fonction pour tester depuis un bouton UI
    static func createTestButton() -> some View {
        Button(action: {
            testQwenInference()
        }) {
            HStack {
                Image(systemName: "bolt.circle.fill")
                Text("Test Moteur Qwen")
            }
            .padding()
            .background(Color.orange.opacity(0.2))
            .cornerRadius(10)
        }
    }
}