import SwiftUI

// MARK: - Credits View
struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LiquidGlassTheme.Colors.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: LiquidGlassTheme.Layout.spacing24) {
                    // Header
                    headerSection
                    
                    // App Info
                    appInfoCard
                    
                    // Team Credits
                    teamCreditsCard
                    
                    // Technologies
                    technologiesCard
                    
                    // Legal
                    legalCard
                }
                .padding(.horizontal, LiquidGlassTheme.Layout.spacing20)
                .padding(.bottom, LiquidGlassTheme.Layout.spacing40)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: LiquidGlassTheme.Layout.spacing16) {
            Image(systemName: "doc.text.image.fill")
                .font(.system(size: 60))
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
            
            Text(LocalizationManager.shared.localized("app_name"))
                .font(LiquidGlassTheme.Typography.displaySmall)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            
            Text(LocalizationManager.shared.localized("app_version"))
                .font(LiquidGlassTheme.Typography.caption1)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
        }
        .padding(.top, LiquidGlassTheme.Layout.spacing32)
    }
    
    private var appInfoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing12) {
                Text(LocalizationManager.shared.localized("credits_about"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                Text(LocalizationManager.shared.localized("credits_about_description"))
                    .font(LiquidGlassTheme.Typography.body)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    private var teamCreditsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing16) {
                Text(LocalizationManager.shared.localized("credits_team"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing12) {
                    CreditRow(role: "Development", name: "DUPONT1")
                    CreditRow(role: "QA Lead", name: "TINTIN")
                    CreditRow(role: "Architecture", name: "NESTOR")
                    CreditRow(role: "Research", name: "DUPONT2")
                }
            }
        }
    }
    
    private var technologiesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing16) {
                Text(LocalizationManager.shared.localized("credits_technologies"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing8) {
                    TechRow(icon: "swift", name: "Swift & SwiftUI")
                    TechRow(icon: "eye.fill", name: "Vision Framework")
                    TechRow(icon: "cpu", name: "MLX Framework")
                    TechRow(icon: "sparkles", name: "Qwen2.5 AI Model")
                    TechRow(icon: "lock.shield.fill", name: "On-Device Processing")
                }
            }
        }
    }
    
    private var legalCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: LiquidGlassTheme.Layout.spacing12) {
                Text(LocalizationManager.shared.localized("credits_legal"))
                    .font(LiquidGlassTheme.Typography.headline)
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                
                Text(LocalizationManager.shared.localized("credits_copyright"))
                    .font(LiquidGlassTheme.Typography.caption1)
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
                
                Text(LocalizationManager.shared.localized("credits_privacy_statement"))
                    .font(LiquidGlassTheme.Typography.caption2)
                    .foregroundColor(LiquidGlassTheme.Colors.textTertiary)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

struct CreditRow: View {
    let role: String
    let name: String
    
    var body: some View {
        HStack {
            Text(role)
                .font(LiquidGlassTheme.Typography.caption1)
                .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
            
            Spacer()
            
            Text(name)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
        }
    }
}

struct TechRow: View {
    let icon: String
    let name: String
    
    var body: some View {
        HStack(spacing: LiquidGlassTheme.Layout.spacing12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(LiquidGlassTheme.Colors.accent)
                .frame(width: 24)
            
            Text(name)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
        }
    }
}

#Preview {
    CreditsView()
}