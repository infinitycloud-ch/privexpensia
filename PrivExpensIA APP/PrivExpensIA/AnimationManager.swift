import SwiftUI

// MARK: - Animation Manager
// NO VERTICAL BOUNCE! Only horizontal springs allowed
// All animations optimized for 60 FPS

class AnimationManager: ObservableObject {
    static let shared = AnimationManager()
    
    private init() {}
    
    // MARK: - Animation Constants
    enum Duration {
        static let instant: TimeInterval = 0.1
        static let quick: TimeInterval = 0.2
        static let normal: TimeInterval = 0.3
        static let slow: TimeInterval = 0.5
        static let verySlow: TimeInterval = 0.8
    }
    
    // MARK: - Horizontal Spring Animations (NO VERTICAL!)
    enum Springs {
        // Smooth horizontal springs
        static let horizontalSmooth = Animation.spring(response: 0.4, dampingFraction: 0.85)
            .speed(1.2)
        
        // Quick horizontal spring
        static let horizontalQuick = Animation.spring(response: 0.3, dampingFraction: 0.75)
            .speed(1.5)
        
        // Gentle horizontal spring
        static let horizontalGentle = Animation.spring(response: 0.5, dampingFraction: 0.9)
        
        // Snappy horizontal spring
        static let horizontalSnappy = Animation.spring(response: 0.25, dampingFraction: 0.8)
            .speed(2.0)
        
        // Scale animation (uniform, not vertical)
        static let scale = Animation.spring(response: 0.3, dampingFraction: 0.7)
        
        // Rotation animation
        static let rotation = Animation.spring(response: 0.4, dampingFraction: 0.75)
    }
    
    // MARK: - Ease Animations
    enum Eases {
        static let easeIn = Animation.easeIn(duration: Duration.quick)
        static let easeOut = Animation.easeOut(duration: Duration.quick)
        static let easeInOut = Animation.easeInOut(duration: Duration.normal)
        static let linear = Animation.linear(duration: Duration.normal)
    }
    
    // MARK: - Glass UI Specific Animations
    enum Glass {
        // Card appear animation
        static let cardAppear = Animation
            .timingCurve(0.68, -0.2, 0.265, 1.2, duration: Duration.normal)
        
        // Glass fade in
        static let fadeIn = Animation
            .easeOut(duration: Duration.quick)
        
        // Glass fade out
        static let fadeOut = Animation
            .easeIn(duration: Duration.instant)
        
        // Blur transition
        static let blurTransition = Animation
            .easeInOut(duration: Duration.normal)
        
        // Tab switch (horizontal only!)
        static let tabSwitch = Animation
            .spring(response: 0.35, dampingFraction: 0.85)
        
        // List item slide (horizontal)
        static let listItemSlide = Animation
            .spring(response: 0.3, dampingFraction: 0.8)
    }
    
    // MARK: - Gesture Animations
    enum Gestures {
        // Swipe horizontal
        static let swipeHorizontal = Animation
            .interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.25)
        
        // Drag horizontal
        static let dragHorizontal = Animation
            .interactiveSpring(response: 0.4, dampingFraction: 0.85, blendDuration: 0.3)
        
        // Tap feedback
        static let tapFeedback = Animation
            .easeInOut(duration: 0.1)
        
        // Long press
        static let longPress = Animation
            .easeOut(duration: 0.15)
    }
    
    // MARK: - Transition Helpers
    static func slideFromLeading() -> AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
    
    static func slideFromTrailing() -> AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static func scaleAndFade() -> AnyTransition {
        AnyTransition.scale(scale: 0.8).combined(with: .opacity)
    }
    
    static func glassAppear() -> AnyTransition {
        AnyTransition.modifier(
            active: GlassAppearModifier(opacity: 0, blur: 20, scale: 0.9),
            identity: GlassAppearModifier(opacity: 1, blur: 0, scale: 1)
        )
    }
    
    // MARK: - Animation Modifiers
    struct GlassAppearModifier: ViewModifier {
        let opacity: Double
        let blur: CGFloat
        let scale: CGFloat
        
        func body(content: Content) -> some View {
            content
                .opacity(opacity)
                .blur(radius: blur)
                .scaleEffect(scale)
        }
    }
    
    // MARK: - Haptic Feedback Helpers
    static func withHaptic<T>(_ type: UIImpactFeedbackGenerator.FeedbackStyle = .light, 
                             action: () -> T) -> T {
        let generator = UIImpactFeedbackGenerator(style: type)
        generator.impactOccurred()
        return action()
    }
    
    static func withSelectionHaptic<T>(action: () -> T) -> T {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        return action()
    }
    
    // MARK: - Animation Timing Functions
    static func staggeredAnimation(index: Int, totalCount: Int) -> Animation {
        let delay = Double(index) * 0.05
        return Glass.cardAppear.delay(delay)
    }
    
    static func chainedAnimation(step: Int) -> Animation {
        let delay = Double(step) * Duration.quick
        return Springs.horizontalSmooth.delay(delay)
    }
    
    // MARK: - Performance Optimizations
    static func shouldAnimate() -> Bool {
        // Check if reduce motion is enabled
        !UIAccessibility.isReduceMotionEnabled
    }
    
    static func animationSpeed() -> Double {
        // Adjust speed based on device performance
        if ProcessInfo.processInfo.processorCount >= 6 {
            return 1.0 // Full speed for newer devices
        } else {
            return 0.8 // Slightly slower for older devices
        }
    }
}

// MARK: - View Extensions for Animations
extension View {
    // Apply horizontal slide animation
    func horizontalSlide(isActive: Bool, offset: CGFloat = 100) -> some View {
        self.offset(x: isActive ? 0 : offset)
            .animation(AnimationManager.Springs.horizontalSmooth, value: isActive)
    }
    
    // Apply glass appearance animation
    func glassAppear(isVisible: Bool) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible ? 0 : 10)
            .scaleEffect(isVisible ? 1 : 0.9)
            .animation(AnimationManager.Glass.cardAppear, value: isVisible)
    }
    
    // Apply tap animation (scale only, no bounce)
    func tapAnimation(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(AnimationManager.Gestures.tapFeedback, value: isPressed)
    }
    
    // Apply horizontal swipe gesture
    func horizontalSwipeGesture(onSwipe: @escaping (SwipeDirection) -> Void) -> some View {
        self.gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    AnimationManager.withSelectionHaptic {
                        if value.translation.width > 0 {
                            onSwipe(.right)
                        } else if value.translation.width < 0 {
                            onSwipe(.left)
                        }
                    }
                }
        )
    }
}

// MARK: - Helper Types
enum SwipeDirection {
    case left, right
}