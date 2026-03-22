import SwiftUI

// MARK: - Beta Feedback View
struct BetaFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var rating = 3
    @State private var category = "General"
    @State private var showingThankYou = false
    
    private let categories = ["General", "Bug Report", "Feature Request", "Performance", "UI/UX"]
    
    var body: some View {
        ZStack {
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()
            
            if showingThankYou {
                thankYouView
            } else {
                feedbackForm
            }
        }
    }
    
    private var feedbackForm: some View {
        ScrollView {
            VStack(spacing: LiquidGlassTheme.Layout.spacing20) {
                // Header
                headerSection
                
                // Rating Section
                ratingSection
                
                // Category Section
                categorySection
                
                // Feedback Text
                feedbackSection
                
                // Submit Button
                submitButton
            }
            .padding(.horizontal, LiquidGlassTheme.Layout.spacing20)
            .padding(.bottom, LiquidGlassTheme.Layout.spacing40)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            LiquidGlassTheme.Colors.accent,
                            LiquidGlassTheme.Colors.primary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(LocalizationManager.shared.localized("feedback_title"))
                .font(LiquidGlassTheme.Typography.displaySmall)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            
            Text(LocalizationManager.shared.localized("feedback_subtitle"))
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
        }
        .padding(.top, LiquidGlassTheme.Layout.spacing32)
    }
    
    private var ratingSection: some View {
        GlassCard {
            VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                Text(LocalizationManager.shared.localized("feedback_rating_question"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                HStack(spacing: LiquidGlassTheme.Layout.spacing16) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: {
                            rating = star
                            LiquidGlassTheme.Haptics.light()
                        }) {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(
                                    star <= rating ? 
                                    Color.yellow : 
                                    LiquidGlassTheme.Colors.textTertiary
                                )
                        }
                    }
                }
            }
        }
    }
    
    private var categorySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing12) {
                Text(LocalizationManager.shared.localized("feedback_category"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LiquidGlassTheme.Layout.spacing8) {
                        ForEach(categories, id: \.self) { cat in
                            CategoryChip(
                                title: cat,
                                isSelected: category == cat,
                                action: {
                                    category = cat
                                    LiquidGlassTheme.Haptics.selection()
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    
    private var feedbackSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing12) {
                Text(LocalizationManager.shared.localized("feedback_your_feedback"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                TextEditor(text: $feedbackText)
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    .frame(minHeight: 150)
                    .padding(LiquidGlassTheme.Layout.spacing8)
                    .background(
                        RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusSmall)
                            .fill(LiquidGlassTheme.Colors.glassBase)
                    )
                    .overlay(
                        Group {
                            if feedbackText.isEmpty {
                                Text(LocalizationManager.shared.localized("feedback_placeholder"))
                                    .font(LiquidGlassTheme.Typography.body)
                                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                                    .padding(LiquidGlassTheme.Layout.spacing12)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .allowsHitTesting(false)
                            }
                        }
                    )
            }
        }
    }
    
    private var submitButton: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing12) {
            GlassButton(LocalizationManager.shared.localized("feedback_submit"), icon: "paperplane.fill") {
                submitFeedback()
            }
            .disabled(feedbackText.isEmpty)
            .opacity(feedbackText.isEmpty ? 0.6 : 1.0)
            
            Button(LocalizationManager.shared.localized("button_cancel")) {
                dismiss()
            }
            .font(LiquidGlassTheme.Typography.body)
            .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
        }
    }
    
    private var thankYouView: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing24) {
            SuccessAnimationView()
            
            Text(LocalizationManager.shared.localized("feedback_thank_you"))
                .font(LiquidGlassTheme.Typography.displaySmall)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            
            Text(LocalizationManager.shared.localized("feedback_thank_you_message"))
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
    }
    
    private func submitFeedback() {
        let feedback = BetaFeedback(
            message: feedbackText,
            rating: rating,
            category: category
        )
        
        AnalyticsManager.shared.submitFeedback(feedback)
        LiquidGlassTheme.Haptics.success()
        
        withAnimation(AnimationManager.Glass.fadeIn) {
            showingThankYou = true
        }
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(LiquidGlassTheme.Typography.callout)
                .foregroundColor(
                    isSelected ? 
                    LiquidGlassTheme.Colors.textPrimary : 
                    LiquidGlassTheme.Colors.textSecondary
                )
                .padding(.horizontal, LiquidGlassTheme.Layout.spacing16)
                .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
                .background(
                    Capsule()
                        .fill(
                            isSelected ? 
                            LiquidGlassTheme.Colors.accent.opacity(0.2) : 
                            LiquidGlassTheme.Colors.glassBase
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? 
                            LiquidGlassTheme.Colors.accent : 
                            Color.clear,
                            lineWidth: 1
                        )
                )
        }
    }
}

#Preview {
    BetaFeedbackView()
}