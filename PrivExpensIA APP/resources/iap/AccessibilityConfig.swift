//
//  AccessibilityConfig.swift
//  PrivExpensIA
//
//  Created by DUPONT2 - Documentation & Research
//  Copyright © 2024 Moulinsart. All rights reserved.
//

import SwiftUI
import UIKit

// MARK: - Accessibility Configuration
struct AccessibilityConfig {
    
    // MARK: - VoiceOver Labels (French)
    struct VoiceOverLabels {
        
        // MARK: - Navigation
        static let closeButton = "Fermer"
        static let backButton = "Retour"
        static let nextButton = "Suivant"
        static let doneButton = "Terminé"
        
        // MARK: - Paywall
        static let paywallTitle = "Page d'abonnement PrivExpensIA Pro"
        static let paywallDescription = "Découvrez les fonctionnalités premium et choisissez votre abonnement"
        
        // MARK: - Subscription Plans
        static let monthlyPlan = "Abonnement mensuel"
        static let yearlyPlan = "Abonnement annuel"
        static let businessPlan = "Forfait business"
        static let recommendedBadge = "Recommandé"
        
        // MARK: - Features
        static let unlimitedTransactions = "Transactions illimitées"
        static let cloudSync = "Synchronisation cloud"
        static let advancedReports = "Rapports avancés"
        static let receiptScanning = "Scan de reçus"
        static let prioritySupport = "Support prioritaire"
        
        // MARK: - Actions
        static let startFreeTrial = "Commencer l'essai gratuit"
        static let subscribe = "S'abonner"
        static let restorePurchases = "Restaurer les achats"
        static let purchaseInProgress = "Achat en cours"
        
        // MARK: - Status
        static let subscriptionActive = "Abonnement actif"
        static let subscriptionExpired = "Abonnement expiré"
        static let freeTierActive = "Version gratuite active"
        
        // MARK: - Comparison Table
        static let featuresComparison = "Tableau de comparaison des fonctionnalités"
        static let featureAvailable = "Fonctionnalité disponible"
        static let featureNotAvailable = "Fonctionnalité non disponible"
        static let featureLimited = "Fonctionnalité limitée"
    }
    
    // MARK: - Accessibility Hints (French)
    struct AccessibilityHints {
        static let closePaywall = "Ferme la fenêtre d'abonnement et retourne à l'écran précédent"
        static let selectPlan = "Touchez pour sélectionner ce plan d'abonnement"
        static let purchaseButton = "Touchez pour démarrer votre période d'essai gratuite"
        static let restoreButton = "Touchez pour restaurer vos achats précédents"
        static let comparisonTable = "Balayez vers le haut ou le bas pour parcourir les fonctionnalités"
        static let pricingCard = "Touchez deux fois pour sélectionner ce plan"
    }
    
    // MARK: - Accessibility Traits
    struct AccessibilityTraits {
        static let subscriptionCard: AccessibilityTraits = [.button, .adjustable]
        static let featureRow: AccessibilityTraits = [.staticText]
        static let purchaseButton: AccessibilityTraits = [.button]
        static let closeButton: AccessibilityTraits = [.button]
        static let selectedPlan: AccessibilityTraits = [.button, .selected]
    }
}

// MARK: - Dynamic Type Support
struct DynamicTypeConfig {
    
    // MARK: - Font Scaling
    static func scaledFont(for textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        return Font.system(textStyle, design: .default, weight: weight)
    }
    
    static func scaledUIFont(for textStyle: UIFont.TextStyle, weight: UIFont.Weight = .regular) -> UIFont {
        let font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: textStyle).pointSize, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }
    
    // MARK: - Size Categories Support
    static func adaptiveSpacing(for sizeCategory: ContentSizeCategory) -> CGFloat {
        switch sizeCategory {
        case .extraSmall, .small, .medium:
            return 12
        case .large, .extraLarge:
            return 16
        case .extraExtraLarge, .extraExtraExtraLarge:
            return 20
        case .accessibilityMedium, .accessibilityLarge:
            return 24
        case .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
            return 28
        default:
            return 16
        }
    }
    
    static func adaptivePadding(for sizeCategory: ContentSizeCategory) -> EdgeInsets {
        let spacing = adaptiveSpacing(for: sizeCategory)
        return EdgeInsets(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)
    }
}

// MARK: - High Contrast Support
struct HighContrastConfig {
    
    static func adaptiveColor(
        normal: Color,
        highContrast: Color,
        for colorScheme: ColorScheme,
        isHighContrast: Bool
    ) -> Color {
        if isHighContrast {
            return highContrast
        }
        return normal
    }
    
    // MARK: - High Contrast Color Palette
    struct Colors {
        // Primary colors with high contrast variants
        static let primaryNormal = Color.blue
        static let primaryHighContrast = Color.black
        
        static let secondaryNormal = Color.gray
        static let secondaryHighContrast = Color.black
        
        static let backgroundNormal = Color(.systemBackground)
        static let backgroundHighContrast = Color.white
        
        static let textNormal = Color.primary
        static let textHighContrast = Color.black
        
        // Success/Error colors
        static let successNormal = Color.green
        static let successHighContrast = Color.black
        
        static let errorNormal = Color.red
        static let errorHighContrast = Color.black
        
        // Border colors for better definition
        static let borderNormal = Color.clear
        static let borderHighContrast = Color.black
    }
}

// MARK: - Reduce Motion Support
struct ReduceMotionConfig {
    
    static func adaptiveAnimation<V: Equatable>(
        _ animation: Animation?,
        value: V,
        isReduceMotionEnabled: Bool
    ) -> Animation? {
        return isReduceMotionEnabled ? nil : animation
    }
    
    static func adaptiveTransition(
        _ transition: AnyTransition,
        isReduceMotionEnabled: Bool
    ) -> AnyTransition {
        return isReduceMotionEnabled ? .opacity : transition
    }
}

// MARK: - Focus Management
@available(iOS 15.0, *)
struct AccessibilityFocusManager {
    
    enum FocusField: Hashable {
        case closeButton
        case yearlyPlan
        case monthlyPlan
        case purchaseButton
        case restoreButton
    }
    
    static func setInitialFocus() -> FocusField {
        return .yearlyPlan // Focus on recommended plan
    }
    
    static func nextFocus(from current: FocusField) -> FocusField {
        switch current {
        case .closeButton:
            return .yearlyPlan
        case .yearlyPlan:
            return .monthlyPlan
        case .monthlyPlan:
            return .purchaseButton
        case .purchaseButton:
            return .restoreButton
        case .restoreButton:
            return .closeButton
        }
    }
}

// MARK: - Accessibility-Enhanced Views
struct AccessiblePaywallView: View {
    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    
    @State private var selectedPlan: String = "yearly"
    @FocusState private var focusedField: AccessibilityFocusManager.FocusField?
    
    var body: some View {
        ScrollView {
            VStack(spacing: DynamicTypeConfig.adaptiveSpacing(for: sizeCategory)) {
                headerSection
                featuresSection
                pricingSection
                purchaseSection
            }
            .padding(DynamicTypeConfig.adaptivePadding(for: sizeCategory))
        }
        .background(adaptiveBackground)
        .onAppear {
            focusedField = AccessibilityFocusManager.setInitialFocus()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AccessibilityConfig.VoiceOverLabels.paywallTitle)
        .accessibilityHint(AccessibilityConfig.VoiceOverLabels.paywallDescription)
    }
    
    private var adaptiveBackground: some View {
        Group {
            if reduceTransparency {
                Color(.systemBackground)
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground).opacity(0.9),
                        Color(.systemBackground).opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: DynamicTypeConfig.adaptiveSpacing(for: sizeCategory)) {
            // Close button with proper accessibility
            HStack {
                Spacer()
                Button(action: {}) {
                    Image(systemName: "xmark.circle.fill")
                        .font(DynamicTypeConfig.scaledFont(for: .title2))
                        .foregroundColor(adaptiveCloseButtonColor)
                }
                .accessibilityLabel(AccessibilityConfig.VoiceOverLabels.closeButton)
                .accessibilityHint(AccessibilityConfig.AccessibilityHints.closePaywall)
                .focused($focusedField, equals: .closeButton)
            }
            
            // App icon and title
            VStack(spacing: DynamicTypeConfig.adaptiveSpacing(for: sizeCategory)) {
                Image(systemName: "creditcard.and.123")
                    .font(DynamicTypeConfig.scaledFont(for: .largeTitle))
                    .foregroundColor(adaptivePrimaryColor)
                    .accessibilityHidden(true) // Decorative icon
                
                Text("PrivExpensIA Pro")
                    .font(DynamicTypeConfig.scaledFont(for: .largeTitle, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("Débloquez toutes les fonctionnalités premium")
                    .font(DynamicTypeConfig.scaledFont(for: .headline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("PrivExpensIA Pro. Débloquez toutes les fonctionnalités premium")
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: DynamicTypeConfig.adaptiveSpacing(for: sizeCategory)) {
            Text("Fonctionnalités incluses")
                .font(DynamicTypeConfig.scaledFont(for: .title2, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            
            LazyVStack(spacing: DynamicTypeConfig.adaptiveSpacing(for: sizeCategory)) {
                ForEach(AccessibleFeature.allFeatures, id: \.title) { feature in
                    AccessibleFeatureRow(feature: feature)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AccessibilityConfig.VoiceOverLabels.featuresComparison)
        .accessibilityHint(AccessibilityConfig.AccessibilityHints.comparisonTable)
    }
    
    private var pricingSection: some View {
        VStack(spacing: DynamicTypeConfig.adaptiveSpacing(for: sizeCategory)) {
            Text("Choisissez votre plan")
                .font(DynamicTypeConfig.scaledFont(for: .title2, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            
            // Yearly plan (recommended)
            AccessiblePricingCard(
                title: "Abonnement annuel",
                price: "99,99€",
                period: "par an",
                savings: "2 mois gratuits",
                isRecommended: true,
                isSelected: selectedPlan == "yearly",
                onSelect: { selectedPlan = "yearly" }
            )
            .focused($focusedField, equals: .yearlyPlan)
            
            // Monthly plan
            AccessiblePricingCard(
                title: "Abonnement mensuel",
                price: "9,99€",
                period: "par mois",
                savings: nil,
                isRecommended: false,
                isSelected: selectedPlan == "monthly",
                onSelect: { selectedPlan = "monthly" }
            )
            .focused($focusedField, equals: .monthlyPlan)
        }
    }
    
    private var purchaseSection: some View {
        VStack(spacing: DynamicTypeConfig.adaptiveSpacing(for: sizeCategory)) {
            // Purchase button
            Button(action: {}) {
                HStack {
                    Image(systemName: "crown.fill")
                        .accessibilityHidden(true)
                    
                    Text("Commencer l'essai gratuit")
                        .font(DynamicTypeConfig.scaledFont(for: .headline, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(adaptivePrimaryColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(adaptiveBorderColor, lineWidth: differentiateWithoutColor ? 2 : 0)
                )
            }
            .accessibilityLabel(AccessibilityConfig.VoiceOverLabels.startFreeTrial)
            .accessibilityHint(AccessibilityConfig.AccessibilityHints.purchaseButton)
            .focused($focusedField, equals: .purchaseButton)
            
            // Restore purchases
            Button(action: {}) {
                Text("Restaurer les achats")
                    .font(DynamicTypeConfig.scaledFont(for: .subheadline))
                    .foregroundColor(adaptivePrimaryColor)
            }
            .accessibilityLabel(AccessibilityConfig.VoiceOverLabels.restorePurchases)
            .accessibilityHint(AccessibilityConfig.AccessibilityHints.restoreButton)
            .focused($focusedField, equals: .restoreButton)
            
            // Legal text
            VStack(spacing: 8) {
                Text("Annulez à tout moment dans les réglages")
                    .font(DynamicTypeConfig.scaledFont(for: .caption))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 20) {
                    Button("Conditions") {}
                        .font(DynamicTypeConfig.scaledFont(for: .caption))
                        .foregroundColor(adaptivePrimaryColor)
                    
                    Button("Confidentialité") {}
                        .font(DynamicTypeConfig.scaledFont(for: .caption))
                        .foregroundColor(adaptivePrimaryColor)
                }
            }
            .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Adaptive Colors
    private var adaptivePrimaryColor: Color {
        if #available(iOS 14.0, *) {
            return HighContrastConfig.adaptiveColor(
                normal: HighContrastConfig.Colors.primaryNormal,
                highContrast: HighContrastConfig.Colors.primaryHighContrast,
                for: colorScheme,
                isHighContrast: differentiateWithoutColor
            )
        }
        return .blue
    }
    
    private var adaptiveCloseButtonColor: Color {
        return differentiateWithoutColor ? .primary : .secondary
    }
    
    private var adaptiveBorderColor: Color {
        return differentiateWithoutColor ? .primary : .clear
    }
}

// MARK: - Accessible Feature Row
struct AccessibleFeatureRow: View {
    let feature: AccessibleFeature
    
    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    
    var body: some View {
        HStack(spacing: DynamicTypeConfig.adaptiveSpacing(for: sizeCategory)) {
            // Feature icon
            Image(systemName: feature.iconName)
                .font(DynamicTypeConfig.scaledFont(for: .title3))
                .foregroundColor(adaptiveIconColor)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            
            // Feature details
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(DynamicTypeConfig.scaledFont(for: .subheadline, weight: .medium))
                
                if !feature.description.isEmpty {
                    Text(feature.description)
                        .font(DynamicTypeConfig.scaledFont(for: .caption))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Checkmark for Pro features
            Image(systemName: "checkmark.circle.fill")
                .font(DynamicTypeConfig.scaledFont(for: .title3))
                .foregroundColor(.green)
                .accessibilityLabel(AccessibilityConfig.VoiceOverLabels.featureAvailable)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(feature.title). \(feature.description). \(AccessibilityConfig.VoiceOverLabels.featureAvailable)")
    }
    
    private var adaptiveIconColor: Color {
        return differentiateWithoutColor ? .primary : .blue
    }
}

// MARK: - Accessible Pricing Card
struct AccessiblePricingCard: View {
    let title: String
    let price: String
    let period: String
    let savings: String?
    let isRecommended: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    
    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DynamicTypeConfig.adaptiveSpacing(for: sizeCategory)) {
                // Header with title and recommended badge
                HStack {
                    Text(title)
                        .font(DynamicTypeConfig.scaledFont(for: .headline, weight: .semibold))
                    
                    if isRecommended {
                        Text("RECOMMANDÉ")
                            .font(DynamicTypeConfig.scaledFont(for: .caption2, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .accessibilityLabel(AccessibilityConfig.VoiceOverLabels.recommendedBadge)
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(DynamicTypeConfig.scaledFont(for: .title2))
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .accessibilityHidden(true) // Status conveyed through traits
                }
                
                // Savings text
                if let savings = savings {
                    Text(savings)
                        .font(DynamicTypeConfig.scaledFont(for: .subheadline))
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                
                // Price
                HStack(alignment: .firstTextBaseline) {
                    Text(price)
                        .font(DynamicTypeConfig.scaledFont(for: .title, weight: .bold))
                    
                    Text(period)
                        .font(DynamicTypeConfig.scaledFont(for: .caption))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(adaptiveBorderColor, lineWidth: adaptiveBorderWidth)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(
                ReduceMotionConfig.adaptiveAnimation(
                    .easeInOut(duration: 0.2),
                    value: isSelected,
                    isReduceMotionEnabled: false // Would check environment
                ),
                value: isSelected
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(AccessibilityConfig.AccessibilityHints.pricingCard)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private var adaptiveBorderColor: Color {
        if isSelected {
            return .blue
        } else if differentiateWithoutColor {
            return .primary
        } else {
            return .clear
        }
    }
    
    private var adaptiveBorderWidth: CGFloat {
        return (isSelected || differentiateWithoutColor) ? 2 : 0
    }
    
    private var accessibilityLabel: String {
        var label = "\(title), \(price) \(period)"
        
        if let savings = savings {
            label += ", \(savings)"
        }
        
        if isRecommended {
            label += ", \(AccessibilityConfig.VoiceOverLabels.recommendedBadge)"
        }
        
        return label
    }
}

// MARK: - Accessible Feature Model
struct AccessibleFeature {
    let title: String
    let description: String
    let iconName: String
    
    static let allFeatures: [AccessibleFeature] = [
        AccessibleFeature(
            title: "Transactions illimitées",
            description: "Enregistrez autant de transactions que nécessaire",
            iconName: "infinity.circle"
        ),
        AccessibleFeature(
            title: "Synchronisation cloud",
            description: "Vos données synchronisées sur tous vos appareils",
            iconName: "icloud.fill"
        ),
        AccessibleFeature(
            title: "Rapports avancés",
            description: "Analyses détaillées de vos finances",
            iconName: "chart.bar.fill"
        ),
        AccessibleFeature(
            title: "Scan de reçus",
            description: "Numérisez automatiquement vos reçus",
            iconName: "doc.text.viewfinder"
        ),
        AccessibleFeature(
            title: "Support prioritaire",
            description: "Assistance dédiée et rapide",
            iconName: "person.fill.checkmark"
        ),
        AccessibleFeature(
            title: "Export avancé",
            description: "PDF, Excel, et autres formats",
            iconName: "square.and.arrow.up"
        )
    ]
}

// MARK: - Accessibility Testing Helper
struct AccessibilityTestingView: View {
    var body: some View {
        VStack {
            Text("Test d'accessibilité")
                .font(.title)
                .accessibilityAddTraits(.isHeader)
            
            Button("Tester VoiceOver") {
                UIAccessibility.post(notification: .announcement, argument: "Test VoiceOver fonctionnel")
            }
            .accessibilityHint("Teste l'annonce VoiceOver")
            
            Button("Tester focus") {
                // Test focus management
            }
            .accessibilityHint("Teste la gestion du focus")
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    if #available(iOS 15.0, *) {
        AccessiblePaywallView()
    } else {
        Text("iOS 15.0 requis")
    }
}