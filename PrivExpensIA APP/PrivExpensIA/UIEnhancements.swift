import SwiftUI
import UIKit

// MARK: - UI Enhancements
// Smooth animations, haptic feedback, and polished UX

// MARK: - Haptic Feedback Manager
class HapticManager {
    static let shared = HapticManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        if Constants.UI.hapticFeedbackEnabled {
            impactLight.prepare()
            impactMedium.prepare()
            impactHeavy.prepare()
            selectionFeedback.prepare()
            notificationFeedback.prepare()
        }
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard Constants.UI.hapticFeedbackEnabled else { return }
        
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        default:
            break
        }
    }
    
    func selection() {
        guard Constants.UI.hapticFeedbackEnabled else { return }
        selectionFeedback.selectionChanged()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard Constants.UI.hapticFeedbackEnabled else { return }
        notificationFeedback.notificationOccurred(type)
    }
}

// MARK: - Smooth Animation Modifiers
struct SmoothScale: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                              pressing: { pressing in
                                isPressed = pressing
                                if pressing {
                                    HapticManager.shared.impact(.light)
                                }
                              },
                              perform: {})
    }
}

struct FadeInAppear: ViewModifier {
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: Constants.UI.animationDuration)) {
                    opacity = 1
                }
            }
    }
}

struct SlideInFromBottom: ViewModifier {
    @State private var offset: CGFloat = 100
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    offset = 0
                    opacity = 1
                }
            }
    }
}

// MARK: - Enhanced Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Constants.UI.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(Constants.UI.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.1),
                   radius: configuration.isPressed ? 2 : 4,
                   y: configuration.isPressed ? 1 : 2)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    HapticManager.shared.impact(.medium)
                }
            }
    }
}

struct SuccessButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Constants.UI.successColor)
            .foregroundColor(.white)
            .cornerRadius(Constants.UI.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Loading Indicator
struct LoadingIndicator: View {
    @State private var isAnimating = false
    let text: String
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 3)
                    .opacity(0.3)
                    .foregroundColor(Constants.UI.primaryColor)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundColor(Constants.UI.primaryColor)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            }
            .frame(width: 50, height: 50)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Success Animation
struct SuccessCheckmark: View {
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var checkmarkTrim: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Constants.UI.successColor)
                .frame(width: 60, height: 60)
                .scaleEffect(scale)
                .opacity(opacity)
            
            Path { path in
                path.move(to: CGPoint(x: 20, y: 30))
                path.addLine(to: CGPoint(x: 28, y: 38))
                path.addLine(to: CGPoint(x: 40, y: 22))
            }
            .trim(from: 0, to: checkmarkTrim)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 60, height: 60)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1
                opacity = 1
            }
            
            withAnimation(.easeInOut(duration: 0.3).delay(0.3)) {
                checkmarkTrim = 1
            }
            
            HapticManager.shared.notification(.success)
        }
    }
}

// MARK: - Error Shake Animation
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

// MARK: - Enhanced Error View
struct ErrorView: View {
    let message: String
    @State private var attempts = 0
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(Constants.UI.errorColor)
                .modifier(ShakeEffect(animatableData: CGFloat(attempts)))
            
            Text(message)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                attempts += 1
                HapticManager.shared.notification(.warning)
                onRetry()
            }) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .onAppear {
            HapticManager.shared.notification(.error)
        }
    }
}

// MARK: - Onboarding Tooltip
struct OnboardingTooltip: View {
    let tip: String
    @State private var isVisible = false
    
    var body: some View {
        if isVisible {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                
                Text(tip)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(Constants.UI.cornerRadius)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    func show() {
        withAnimation(.spring()) {
            isVisible = true
        }
        
        // Auto-hide after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                isVisible = false
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    func smoothScale() -> some View {
        modifier(SmoothScale())
    }
    
    func fadeInAppear() -> some View {
        modifier(FadeInAppear())
    }
    
    func slideInFromBottom() -> some View {
        modifier(SlideInFromBottom())
    }
    
    func shake(attempts: Int) -> some View {
        modifier(ShakeEffect(animatableData: CGFloat(attempts)))
    }
    
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(Constants.UI.cornerRadius)
            .shadow(color: .black.opacity(Double(Constants.UI.shadowOpacity)),
                   radius: 4, x: 0, y: 2)
    }
}