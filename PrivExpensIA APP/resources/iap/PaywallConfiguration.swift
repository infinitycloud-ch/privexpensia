//
//  PaywallConfiguration.swift
//  PrivExpensIA
//
//  Created by DUPONT2 - Documentation & Research
//  Copyright © 2024 Moulinsart. All rights reserved.
//

import SwiftUI
import StoreKit
import Combine

// MARK: - Main Paywall View
@available(iOS 15.0, *)
struct PaywallView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @State private var selectedProductID: String = "com.moulinsart.privexpensia.pro.yearly"
    @State private var isPurchasing = false
    @State private var showSuccessAnimation = false
    @State private var showRestoreAlert = false
    @State private var animationOffset: CGFloat = 0
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground).opacity(0.1),
                    Color(.systemBackground).opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if showSuccessAnimation {
                successAnimationView
            } else {
                paywallContentView
            }
        }
        .onAppear {
            Task {
                await storeManager.loadProducts()
            }
        }
        .alert("Achats restaurés", isPresented: $showRestoreAlert) {
            Button("OK") { }
        } message: {
            Text("Vos achats précédents ont été restaurés avec succès.")
        }
    }
    
    private var paywallContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerView
                featuresComparisonView
                pricingView
                purchaseButtonsView
                footerView
            }
        }
        .background(Material.ultraThin)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            // Close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .background(Material.ultraThin, in: Circle())
                }
                .accessibilityLabel("Fermer")
                .accessibilityHint("Ferme la fenêtre d'abonnement")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // App icon and title
            VStack(spacing: 12) {
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(.primary)
                    .symbolEffect(.bounce.down, value: animationOffset)
                
                Text("PrivExpensIA Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Débloquez toutes les fonctionnalités premium")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("PrivExpensIA Pro. Débloquez toutes les fonctionnalités premium")
        }
        .padding(.bottom, 30)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animationOffset = 10
            }
        }
    }
    
    // MARK: - Features Comparison View
    private var featuresComparisonView: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("Comparaison des fonctionnalités")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.leading, 20)
                Spacer()
            }
            .padding(.bottom, 16)
            
            // Glass container
            VStack(spacing: 0) {
                // Header row
                HStack {
                    Text("Fonctionnalité")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Gratuit")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(width: 70)
                    
                    Text("Pro")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .frame(width: 70)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Material.regular)
                
                Divider()
                
                // Feature rows
                ForEach(FeatureRow.allFeatures, id: \.title) { feature in
                    featureRowView(feature: feature)
                    if feature != FeatureRow.allFeatures.last {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Material.thin)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 30)
    }
    
    private func featureRowView(feature: FeatureRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !feature.subtitle.isEmpty {
                    Text(feature.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Free tier
            feature.freeIcon
                .font(.title3)
                .frame(width: 70)
            
            // Pro tier
            feature.proIcon
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 70)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.title). \(feature.accessibilityDescription)")
    }
    
    // MARK: - Pricing View
    private var pricingView: some View {
        VStack(spacing: 16) {
            Text("Choisissez votre plan")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Yearly subscription (recommended)
                if let yearlyProduct = storeManager.products.first(where: { $0.id == "com.moulinsart.privexpensia.pro.yearly" }) {
                    subscriptionCard(
                        product: yearlyProduct,
                        isRecommended: true,
                        savingsText: "2 mois gratuits",
                        monthlyEquivalent: "8,33€/mois"
                    )
                }
                
                // Monthly subscription
                if let monthlyProduct = storeManager.products.first(where: { $0.id == "com.moulinsart.privexpensia.pro.monthly" }) {
                    subscriptionCard(
                        product: monthlyProduct,
                        isRecommended: false,
                        savingsText: nil,
                        monthlyEquivalent: nil
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 30)
    }
    
    private func subscriptionCard(
        product: Product,
        isRecommended: Bool,
        savingsText: String?,
        monthlyEquivalent: String?
    ) -> some View {
        Button(action: { selectedProductID = product.id }) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(product.displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            if isRecommended {
                                Text("RECOMMANDÉ")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if let savingsText = savingsText {
                            Text(savingsText)
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        
                        if let monthlyEquivalent = monthlyEquivalent {
                            Text(monthlyEquivalent)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(product.displayPrice)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(product.id.contains("yearly") ? "par an" : "par mois")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Image(systemName: selectedProductID == product.id ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(selectedProductID == product.id ? .blue : .secondary)
                        .padding(.leading, 8)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Material.thin)
                    .stroke(
                        selectedProductID == product.id ? Color.blue : Color.clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(selectedProductID == product.id ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: selectedProductID)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(product.displayName), \(product.displayPrice) \(product.id.contains("yearly") ? "par an" : "par mois")")
        .accessibilityHint(selectedProductID == product.id ? "Sélectionné" : "Touchez pour sélectionner ce plan")
        .accessibilityAddTraits(selectedProductID == product.id ? .isSelected : [])
    }
    
    // MARK: - Purchase Buttons View
    private var purchaseButtonsView: some View {
        VStack(spacing: 16) {
            // Main purchase button
            Button(action: { Task { await purchaseSelected() } }) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "crown.fill")
                    }
                    
                    Text(isPurchasing ? "Traitement..." : "Commencer l'essai gratuit")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isPurchasing || storeManager.products.isEmpty)
            .padding(.horizontal, 20)
            .accessibilityLabel("Commencer l'essai gratuit")
            .accessibilityHint("Démarre votre période d'essai gratuite")
            
            // Restore purchases button
            Button(action: { Task { await restorePurchases() } }) {
                Text("Restaurer les achats")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("Restaurer les achats")
            .accessibilityHint("Restaure vos achats précédents")
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        VStack(spacing: 12) {
            Text("• Annulez à tout moment dans les réglages de votre compte")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("• Votre abonnement se renouvelle automatiquement")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 20) {
                Button("Conditions d'utilisation") {
                    // Open terms of service
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Politique de confidentialité") {
                    // Open privacy policy
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Success Animation View
    private var successAnimationView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.green)
                    .scaleEffect(showSuccessAnimation ? 1.2 : 0.5)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSuccessAnimation)
                
                Text("Bienvenue dans Pro!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Toutes les fonctionnalités premium sont maintenant débloquées.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            Button("Continuer") {
                dismiss()
            }
            .font(.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Material.thin)
    }
    
    // MARK: - Purchase Methods
    private func purchaseSelected() async {
        guard let product = storeManager.products.first(where: { $0.id == selectedProductID }) else { return }
        
        isPurchasing = true
        
        do {
            let success = try await storeManager.purchase(product)
            
            if success {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSuccessAnimation = true
                }
                
                // Auto dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    dismiss()
                }
            }
        } catch {
            // Handle purchase error
            print("Purchase failed: \(error.localizedDescription)")
        }
        
        isPurchasing = false
    }
    
    private func restorePurchases() async {
        do {
            try await AppStore.sync()
            showRestoreAlert = true
        } catch {
            print("Restore failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Feature Row Model
struct FeatureRow {
    let title: String
    let subtitle: String
    let freeIcon: Image
    let proIcon: Image
    let accessibilityDescription: String
    
    static let allFeatures: [FeatureRow] = [
        FeatureRow(
            title: "Transactions",
            subtitle: "Nombre maximum",
            freeIcon: Image(systemName: "50.circle"),
            proIcon: Image(systemName: "infinity"),
            accessibilityDescription: "Gratuit: 50 transactions maximum. Pro: transactions illimitées"
        ),
        FeatureRow(
            title: "Catégories personnalisées",
            subtitle: "Organisez vos dépenses",
            freeIcon: Image(systemName: "10.circle"),
            proIcon: Image(systemName: "infinity"),
            accessibilityDescription: "Gratuit: 10 catégories maximum. Pro: catégories illimitées"
        ),
        FeatureRow(
            title: "Comptes multiples",
            subtitle: "Cartes et comptes bancaires",
            freeIcon: Image(systemName: "2.circle"),
            proIcon: Image(systemName: "infinity"),
            accessibilityDescription: "Gratuit: 2 comptes maximum. Pro: comptes illimités"
        ),
        FeatureRow(
            title: "Synchronisation cloud",
            subtitle: "Sauvegarde automatique",
            freeIcon: Image(systemName: "xmark.circle"),
            proIcon: Image(systemName: "checkmark.circle.fill"),
            accessibilityDescription: "Gratuit: non disponible. Pro: synchronisation cloud incluse"
        ),
        FeatureRow(
            title: "Rapports avancés",
            subtitle: "Analyses détaillées",
            freeIcon: Image(systemName: "xmark.circle"),
            proIcon: Image(systemName: "checkmark.circle.fill"),
            accessibilityDescription: "Gratuit: rapports de base uniquement. Pro: rapports avancés inclus"
        ),
        FeatureRow(
            title: "Export avancé",
            subtitle: "PDF, Excel, QIF",
            freeIcon: Image(systemName: "doc.text"),
            proIcon: Image(systemName: "doc.richtext"),
            accessibilityDescription: "Gratuit: export CSV uniquement. Pro: tous les formats d'export"
        ),
        FeatureRow(
            title: "Scan de reçus",
            subtitle: "IA automatique",
            freeIcon: Image(systemName: "xmark.circle"),
            proIcon: Image(systemName: "checkmark.circle.fill"),
            accessibilityDescription: "Gratuit: non disponible. Pro: scan automatique des reçus"
        ),
        FeatureRow(
            title: "Support prioritaire",
            subtitle: "Assistance dédiée",
            freeIcon: Image(systemName: "questionmark.circle"),
            proIcon: Image(systemName: "person.fill.checkmark"),
            accessibilityDescription: "Gratuit: support communautaire. Pro: support prioritaire"
        )
    ]
}

// MARK: - StoreKit Manager
@available(iOS 15.0, *)
@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    private let productIDs = [
        "com.moulinsart.privexpensia.pro.monthly",
        "com.moulinsart.privexpensia.pro.yearly",
        "com.moulinsart.privexpensia.business.tier"
    ]
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    init() {
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            
            await MainActor.run {
                self.products = storeProducts.sorted { product1, product2 in
                    // Sort yearly first, then monthly, then business
                    if product1.id.contains("yearly") { return true }
                    if product2.id.contains("yearly") { return false }
                    if product1.id.contains("monthly") { return true }
                    return false
                }
            }
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return true
            
        case .userCancelled, .pending:
            return false
            
        default:
            return false
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchasedProductIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.revocationDate == nil {
                    purchasedProductIDs.insert(transaction.productID)
                }
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
        
        await MainActor.run {
            self.purchasedProductIDs = purchasedProductIDs
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Subscription Status
    func hasActiveSubscription() -> Bool {
        return purchasedProductIDs.contains("com.moulinsart.privexpensia.pro.monthly") ||
               purchasedProductIDs.contains("com.moulinsart.privexpensia.pro.yearly")
    }
    
    func hasBusinessTier() -> Bool {
        return purchasedProductIDs.contains("com.moulinsart.privexpensia.business.tier")
    }
    
    func currentTier() -> SubscriptionTier {
        if hasBusinessTier() {
            return .business
        } else if hasActiveSubscription() {
            return .pro
        } else {
            return .free
        }
    }
}

// MARK: - Supporting Types
enum StoreError: Error {
    case failedVerification
}

enum SubscriptionTier {
    case free, pro, business
    
    var displayName: String {
        switch self {
        case .free: return "Gratuit"
        case .pro: return "Pro"
        case .business: return "Business"
        }
    }
}

// MARK: - Receipt Validation
struct ReceiptValidator {
    static func validateReceipt() async -> Bool {
        // Implementation for receipt validation
        // This would typically involve server-side validation
        return true
    }
    
    static func validateTransaction(_ transaction: Transaction) -> Bool {
        // Validate individual transaction
        return transaction.revocationDate == nil && 
               transaction.revocationReason == nil
    }
}

// MARK: - Usage Example
struct PaywallExampleUsage: View {
    @State private var showPaywall = false
    
    var body: some View {
        VStack {
            Button("Afficher le paywall") {
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            if #available(iOS 15.0, *) {
                PaywallView()
            } else {
                Text("iOS 15.0 requis pour StoreKit 2")
            }
        }
    }
}

#Preview {
    if #available(iOS 15.0, *) {
        PaywallView()
    } else {
        Text("iOS 15.0 requis pour la prévisualisation")
    }
}