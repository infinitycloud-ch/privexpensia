import SwiftUI

// MARK: - Liquid Glass Design System - iOS 26
// Authentic Apple Liquid Glass implementation
// Using native iOS Materials, dynamic blur, and vibrancy

struct LiquidGlassTheme {
    
    // MARK: - Color Palette
    struct Colors {
        // Check if dark mode is enabled
        private static var isDarkMode: Bool {
            UserDefaults.standard.bool(forKey: "darkModeEnabled")
        }
        
        // Primary Colors - Clean and Professional
        static var primary: Color {
            isDarkMode ?
                Color(red: 10/255, green: 132/255, blue: 255/255) :   // iOS Blue for dark
                Color(red: 0/255, green: 122/255, blue: 255/255)      // iOS Blue for light
        }
        
        static var primaryLight: Color {
            isDarkMode ?
                Color(red: 64/255, green: 156/255, blue: 255/255) :
                Color(red: 52/255, green: 146/255, blue: 255/255)
        }
        
        static var primaryDark: Color {
            isDarkMode ?
                Color(red: 0/255, green: 108/255, blue: 221/255) :
                Color(red: 0/255, green: 98/255, blue: 211/255)
        }
        
        // Accent Colors - Dynamic based on theme
        static var accent: Color {
            isDarkMode ?
                Color(red: 255/255, green: 65/255, blue: 105/255) :   // Brighter pink for dark mode
                Color(red: 255/255, green: 45/255, blue: 85/255)      // Vibrant pink for light mode
        }
        
        static var accentLight: Color {
            isDarkMode ?
                Color(red: 255/255, green: 112/255, blue: 143/255) :
                Color(red: 255/255, green: 92/255, blue: 123/255)
        }
        
        static var accentDark: Color {
            isDarkMode ?
                Color(red: 199/255, green: 10/255, blue: 43/255) :
                Color(red: 219/255, green: 10/255, blue: 53/255)
        }
        
        // Glass Base Colors for underlying content
        static var glassBase: Color {
            isDarkMode ?
                Color.black.opacity(0.1) :    // Subtle dark base
                Color.white.opacity(0.1)      // Subtle light base
        }
        
        static var glassTint: Color {
            isDarkMode ?
                Color.white.opacity(0.05) :   // Subtle white tint for dark
                Color.black.opacity(0.02)     // Subtle black tint for light
        }
        
        static var backgroundMain: Color {
            isDarkMode ?
                Color.black :                                         // True black background
                Color(red: 242/255, green: 242/255, blue: 247/255)   // Light gray background
        }
        
        static var glassUltraLight: Color {
            isDarkMode ?
                Color.white.opacity(0.01) :   // Very subtle in dark mode
                Color.white.opacity(0.02)
        }
        
        // Semantic Colors
        static let success = Color(red: 52/255, green: 199/255, blue: 89/255)
        static let warning = Color(red: 255/255, green: 149/255, blue: 0/255)
        static let error = Color(red: 255/255, green: 59/255, blue: 48/255)
        static let info = Color(red: 0/255, green: 122/255, blue: 255/255)
        
        // Text Colors - High Contrast and Readable
        static var textPrimary: Color {
            isDarkMode ?
                Color.white :                                         // Pure white for dark mode
                Color.black                                           // Pure black for light mode
        }
        
        static var textSecondary: Color {
            isDarkMode ?
                Color(red: 174/255, green: 174/255, blue: 178/255) : // iOS secondary text dark
                Color(red: 60/255, green: 60/255, blue: 67/255)      // iOS secondary text light
        }
        
        static var textTertiary: Color {
            isDarkMode ?
                Color(red: 99/255, green: 99/255, blue: 102/255) :   // iOS tertiary text dark
                Color(red: 142/255, green: 142/255, blue: 147/255)   // iOS tertiary text light
        }
        
        static var textQuaternary: Color {
            isDarkMode ?
                Color(red: 72/255, green: 72/255, blue: 74/255) :    // iOS quaternary text dark
                Color(red: 188/255, green: 188/255, blue: 192/255)   // iOS quaternary text light
        }
        
        // Liquid Glass Background Gradient - Vibrant & Dynamic
        static var backgroundGradient: LinearGradient {
            if isDarkMode {
                // Dark mode: Deep cosmic gradient with purples and blues
                return LinearGradient(
                    colors: [
                        Color(red: 12/255, green: 24/255, blue: 54/255),   // Deep navy
                        Color(red: 58/255, green: 12/255, blue: 85/255),   // Rich purple
                        Color(red: 15/255, green: 45/255, blue: 72/255),   // Deep blue
                        Color.black
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                // Light mode: Bright ethereal gradient with light blues and pinks
                return LinearGradient(
                    colors: [
                        Color(red: 230/255, green: 240/255, blue: 255/255),  // Soft blue white
                        Color(red: 255/255, green: 230/255, blue: 240/255),  // Soft pink white
                        Color(red: 240/255, green: 250/255, blue: 255/255),  // Light cyan
                        Color(red: 250/255, green: 245/255, blue: 255/255)   // Light lavender
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        
        // Liquid Glass Mesh - OS 26 Multi-dimensional Colors
        static let meshColors = [
            primary,
            accent,
            Color(red: 120/255, green: 70/255, blue: 255/255),  // Violet prism
            Color(red: 30/255, green: 215/255, blue: 210/255),  // Aqua crystal
            Color(red: 255/255, green: 140/255, blue: 80/255),  // Amber refraction
            Color(red: 180/255, green: 255/255, blue: 120/255)  // Emerald light
        ]
    }
    
    // MARK: - Typography
    struct Typography {
        // Font Family
        static let fontFamily = "SF Pro Display"
        static let fontFamilyRounded = "SF Pro Rounded"
        
        // Font Sizes
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .semibold, design: .default)
        static let title2 = Font.system(size: 22, weight: .medium, design: .default)
        static let title3 = Font.system(size: 20, weight: .medium, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        
        // Display Fonts
        static let displayLarge = Font.system(size: 56, weight: .black, design: .rounded)
        static let displayMedium = Font.system(size: 42, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 36, weight: .semibold, design: .rounded)
    }
    
    // MARK: - Spacing & Layout
    struct Layout {
        // Spacing
        static let spacing2: CGFloat = 2
        static let spacing4: CGFloat = 4
        static let spacing8: CGFloat = 8
        static let spacing12: CGFloat = 12
        static let spacing16: CGFloat = 16
        static let spacing20: CGFloat = 20
        static let spacing24: CGFloat = 24
        static let spacing32: CGFloat = 32
        static let spacing40: CGFloat = 40
        static let spacing48: CGFloat = 48
        
        // Corner Radius
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 16
        static let cornerRadiusLarge: CGFloat = 24
        static let cornerRadiusXLarge: CGFloat = 32
        static let cornerRadiusCircle: CGFloat = 9999
        
        // Blur Radius
        static let blurLight: CGFloat = 8
        static let blurMedium: CGFloat = 16
        static let blurHeavy: CGFloat = 32
        static let blurUltra: CGFloat = 64
    }
    
    // MARK: - Liquid Glass Materials (iOS 26)
    struct LiquidGlass {
        // Native iOS Materials for authentic glass effects
        static let ultraThin = Material.ultraThin
        static let thin = Material.thin
        static let regular = Material.regular
        static let thick = Material.thick
        static let ultraThick = Material.ultraThick

        // Glass Opacity Levels for layering
        static let glassUltraLight: Double = 0.05
        static let glassLight: Double = 0.1
        static let glassRegular: Double = 0.15
        static let glassThick: Double = 0.2
        static let glassUltraThick: Double = 0.25

        // Vibrancy Effects for text over glass
        static func vibrancyEffect(intensity: Double = 1.0) -> Color {
            // Simulates vibrancy by adjusting text color based on material intensity
            if intensity < 0.3 {
                return Colors.textPrimary
            } else if intensity < 0.6 {
                return Colors.textPrimary.opacity(0.95)
            } else if intensity < 0.9 {
                return Colors.textPrimary.opacity(0.9)
            } else {
                return Colors.textPrimary.opacity(0.85)
            }
        }

        // Dynamic tinting based on environment
        static var dynamicTint: Color {
            UserDefaults.standard.bool(forKey: "darkModeEnabled") ?
                Color.white.opacity(0.03) :
                Color.black.opacity(0.02)
        }
    }

    // MARK: - Shadows
    struct Shadows {
        struct ShadowStyle {
            let color: Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }
        
        static let soft = ShadowStyle(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let medium = ShadowStyle(
            color: Color.black.opacity(0.15),
            radius: 16,
            x: 0,
            y: 8
        )
        
        static let heavy = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 24,
            x: 0,
            y: 12
        )
        
        static let glow = ShadowStyle(
            color: Colors.primary.opacity(0.3),
            radius: 32,
            x: 0,
            y: 0
        )
        
        static let innerShadow = ShadowStyle(
            color: Color.black.opacity(0.2),
            radius: 4,
            x: 0,
            y: -2
        )
    }
    
    // MARK: - Liquid Glass OS 26 Animations
    struct Animations {
        // Liquid Glass fluid springs - optimized for glass-like behavior
        static let liquidFlow = Animation.spring(response: 0.6, dampingFraction: 0.9, blendDuration: 0.2)
        static let liquidRipple = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.15)
        static let liquidReflection = Animation.spring(response: 0.35, dampingFraction: 0.85, blendDuration: 0.1)

        // Enhanced easing for glass transitions
        static let glassTransition = Animation.easeInOut(duration: 0.4).delay(0.05)
        static let glassEmerge = Animation.easeOut(duration: 0.35)
        static let glassRecede = Animation.easeIn(duration: 0.25)

        // OS 26 Liquid Glass signature curves
        static let liquidAppear = Animation.timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.6)
        static let liquidDisappear = Animation.timingCurve(0.4, 0.0, 1.0, 1.0, duration: 0.4)
        static let liquidRefract = Animation.timingCurve(0.68, -0.6, 0.32, 1.6, duration: 0.45)

        // Contextual fade with glass properties
        static let glassFadeIn = Animation.linear(duration: 0.25).delay(0.1)
        static let glassFadeOut = Animation.linear(duration: 0.2)

        // Spatial depth animations
        static let depthScale = Animation.spring(response: 0.5, dampingFraction: 0.85)
        static let surfaceTap = Animation.easeInOut(duration: 0.12)
        static let liquidDeform = Animation.spring(response: 0.3, dampingFraction: 0.75)
    }
    
    // MARK: - Liquid Glass OS 26 Effects
    struct GlassEffects {
        // Enhanced Material Hierarchy
        static let liquidUltraLight = Material.ultraThin
        static let liquidLight = Material.thin
        static let liquidMedium = Material.regular
        static let liquidHeavy = Material.thick
        static let liquidPrismatic = Material.ultraThick

        // OS 26 Enhanced blur parameters
        static let adaptiveBlur: CGFloat = 24
        static let contextualSaturation: Double = 2.1
        static let ambientBrightness: Double = 0.15
        static let refractionIndex: Double = 1.4

        // Liquid Glass vibrancy modes
        static let liquidLuminance = BlendMode.plusLighter
        static let liquidShadow = BlendMode.plusDarker
        static let liquidSpectrum = BlendMode.overlay
        static let liquidRefraction = BlendMode.softLight

        // Multi-layer border system
        static let primaryBorder = LinearGradient(
            colors: [
                Color.white.opacity(0.8),
                Color.white.opacity(0.3),
                Color.white.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accentBorder = LinearGradient(
            colors: [
                Colors.primary.opacity(0.6),
                Colors.accent.opacity(0.4),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Haptic Feedback
    struct Haptics {
        static func light() {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        static func medium() {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        static func heavy() {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
        
        static func success() {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
        
        static func warning() {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
        }
        
        static func error() {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }
        
        static func selection() {
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
    }
}