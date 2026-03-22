import SwiftUI

// MARK: - Clean Modern Components
// Simple, readable interface elements with proper contrast
// Features clean cards, readable text, and elegant simplicity

// MARK: - Glass Card
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = LiquidGlassTheme.Layout.spacing16
    var cornerRadius: CGFloat = LiquidGlassTheme.Layout.cornerRadiusLarge
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                LiquidGlassBackground(cornerRadius: cornerRadius, material: LiquidGlassTheme.LiquidGlass.regular)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LiquidGlassTheme.GlassEffects.primaryBorder,
                        lineWidth: 1.2
                    )
            )
            .shadow(
                color: LiquidGlassTheme.Colors.glassBase.opacity(0.3),
                radius: 20,
                x: 0,
                y: 10
            )
            .shadow(
                color: LiquidGlassTheme.Colors.primary.opacity(0.1),
                radius: 40,
                x: 0,
                y: 0
            )
    }
}

// MARK: - Authentic Liquid Glass Background (iOS 26)
struct LiquidGlassBackground: View {
    var cornerRadius: CGFloat = LiquidGlassTheme.Layout.cornerRadiusMedium
    var material: Material = LiquidGlassTheme.LiquidGlass.regular
    var intensity: Double = 1.0
    var enableTinting: Bool = true

    var body: some View {
        ZStack {
            // Base glass tint for depth
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(LiquidGlassTheme.Colors.glassBase.opacity(0.3 * intensity))

            // Native iOS Material for authentic blur
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.clear)
                .background(
                    material,
                    in: RoundedRectangle(cornerRadius: cornerRadius)
                )

            // Dynamic environmental tinting
            if enableTinting {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(LiquidGlassTheme.LiquidGlass.dynamicTint.opacity(intensity))
            }
        }
    }
}

// MARK: - Glass Button
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            LiquidGlassTheme.Haptics.light()
            action()
        }) {
            HStack(spacing: LiquidGlassTheme.Layout.spacing8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Text(title)
                    .font(LiquidGlassTheme.Typography.headline)
            }
            .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
            .padding(.horizontal, LiquidGlassTheme.Layout.spacing20)
            .padding(.vertical, LiquidGlassTheme.Layout.spacing12)
            .background(
                LiquidGlassBackground(
                    cornerRadius: LiquidGlassTheme.Layout.cornerRadiusCircle,
                    material: LiquidGlassTheme.LiquidGlass.thin,
                    intensity: isPressed ? 0.8 : 1.0
                )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .rotation3DEffect(
                .degrees(isPressed ? 2 : 0),
                axis: (x: 1, y: 0, z: 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                          pressing: { pressing in
                            withAnimation(LiquidGlassTheme.Animations.surfaceTap) {
                                isPressed = pressing
                            }
                          },
                          perform: {})
        .onHover { hovering in
            withAnimation(LiquidGlassTheme.Animations.glassFadeIn) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Floating Action Button
struct GlassFloatingActionButton: View {
    let icon: String
    let action: () -> Void
    
    @State private var isPressed = false
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            LiquidGlassTheme.Haptics.medium()
            withAnimation(LiquidGlassTheme.Animations.liquidRipple) {
                rotation += 90
            }
            action()
        }) {
            ZStack {
                // Background blur
                Circle()
                    .fill(LiquidGlassTheme.Colors.glassBase)
                    .background(.ultraThinMaterial)
                    .blur(radius: 1)
                
                // Gradient overlay
                LiquidGlassBackground(
                    cornerRadius: LiquidGlassTheme.Layout.cornerRadiusCircle,
                    material: LiquidGlassTheme.LiquidGlass.regular,
                    intensity: 1.2
                )
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: 56, height: 56)
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity,
                          pressing: { pressing in
                            withAnimation(LiquidGlassTheme.Animations.surfaceTap) {
                                isPressed = pressing
                            }
                          },
                          perform: {})
    }
}

// MARK: - Glass Segmented Control
struct GlassSegmentedControl: View {
    let items: [String]
    @Binding var selection: Int
    
    @Namespace private var namespace
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<items.count, id: \.self) { index in
                GlassSegmentButton(
                    title: items[index],
                    isSelected: selection == index,
                    namespace: namespace,
                    action: {
                        withAnimation(LiquidGlassTheme.Animations.liquidFlow) {
                            selection = index
                            LiquidGlassTheme.Haptics.selection()
                        }
                    }
                )
            }
        }
        .padding(4)
        .background(
            LiquidGlassBackground(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusLarge, material: LiquidGlassTheme.LiquidGlass.thin)
        )
        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusLarge)
                .stroke(
                    Color.white.opacity(0.2),
                    lineWidth: 1
                )
        )
    }
}

struct GlassSegmentButton: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(LiquidGlassTheme.Typography.callout)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(
                    isSelected ? LiquidGlassTheme.Colors.textPrimary : LiquidGlassTheme.Colors.textSecondary
                )
                .padding(.horizontal, LiquidGlassTheme.Layout.spacing16)
                .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
                .background(
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                                .fill(LiquidGlassTheme.Colors.glassBase)
                                .background(LiquidGlassTheme.GlassEffects.liquidLight, in: RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium))
                                .overlay(
                                    RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                                        .stroke(LiquidGlassTheme.GlassEffects.accentBorder, lineWidth: 0.8)
                                )
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Glass Tab Bar
struct GlassTabBar: View {
    let items: [(icon: String, title: String)]
    @Binding var selection: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                GlassTabItem(
                    icon: items[index].icon,
                    title: items[index].title,
                    isSelected: selection == index,
                    action: {
                        withAnimation(LiquidGlassTheme.Animations.liquidFlow) {
                            selection = index
                            LiquidGlassTheme.Haptics.light()
                        }
                    }
                )
            }
        }
        .padding(.horizontal, LiquidGlassTheme.Layout.spacing8)
        .padding(.vertical, LiquidGlassTheme.Layout.spacing4)
        .background(
            LiquidGlassBackground(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge, material: LiquidGlassTheme.LiquidGlass.thick)
            .shadow(
                color: Color.black.opacity(0.15),
                radius: 25,
                x: 0,
                y: -8
            )
            .shadow(
                color: LiquidGlassTheme.Colors.primary.opacity(0.1),
                radius: 50,
                x: 0,
                y: 0
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct GlassTabItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .symbolVariant(isSelected ? .fill : .none)
                
                Text(title)
                    .font(LiquidGlassTheme.Typography.caption2)
            }
            .foregroundColor(
                isSelected ? LiquidGlassTheme.Colors.accent : LiquidGlassTheme.Colors.textSecondary
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, LiquidGlassTheme.Layout.spacing8)
            .background(
                isSelected ?
                AnyView(
                    Capsule()
                        .fill(LiquidGlassTheme.Colors.glassBase)
                        .padding(.horizontal, 8)
                ) : AnyView(Color.clear)
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Glass Text Field
struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: LiquidGlassTheme.Layout.spacing12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(LiquidGlassTheme.Colors.textSecondary)
            }
            
            TextField(placeholder, text: $text)
                .font(LiquidGlassTheme.Typography.body)
                .foregroundColor(LiquidGlassTheme.Colors.textPrimary)
                .focused($isFocused)
                .onSubmit {
                    LiquidGlassTheme.Haptics.light()
                }
        }
        .padding(LiquidGlassTheme.Layout.spacing16)
        .background(
            LiquidGlassBackground(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium, material: isFocused ? LiquidGlassTheme.LiquidGlass.regular : LiquidGlassTheme.LiquidGlass.thin, intensity: isFocused ? 1.2 : 0.8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusMedium)
                .stroke(
                    LinearGradient(
                        colors: [
                            isFocused ? LiquidGlassTheme.Colors.accent.opacity(0.5) : Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(LiquidGlassTheme.Animations.liquidFlow, value: isFocused)
    }
}

// MARK: - Liquid Glass OS 26 Floating Navigation
struct LiquidGlassFloatingNav: View {
    let items: [(icon: String, title: String)]
    @Binding var selection: Int
    @State private var hoverIndex: Int? = nil
    @State private var showTitles = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<items.count, id: \.self) { index in
                LiquidGlassNavItem(
                    icon: items[index].icon,
                    title: items[index].title,
                    isSelected: selection == index,
                    isHovered: hoverIndex == index,
                    showTitle: showTitles || hoverIndex == index,
                    action: {
                        withAnimation(LiquidGlassTheme.Animations.liquidRipple) {
                            selection = index
                            LiquidGlassTheme.Haptics.light()
                        }
                    }
                )
                .onHover { hovering in
                    withAnimation(LiquidGlassTheme.Animations.glassFadeIn) {
                        hoverIndex = hovering ? index : nil
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            LiquidGlassBackground(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge, material: LiquidGlassTheme.LiquidGlass.thick)
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.Layout.cornerRadiusXLarge)
                    .stroke(LiquidGlassTheme.GlassEffects.primaryBorder, lineWidth: 1.5)
            )
        )
        .shadow(
            color: Color.black.opacity(0.2),
            radius: 30,
            x: 0,
            y: 15
        )
        .shadow(
            color: LiquidGlassTheme.Colors.primary.opacity(0.15),
            radius: 60,
            x: 0,
            y: 0
        )
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation(LiquidGlassTheme.Animations.liquidFlow) {
                showTitles.toggle()
                LiquidGlassTheme.Haptics.medium()
            }
        }
    }
}

struct LiquidGlassNavItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let isHovered: Bool
    let showTitle: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .symbolVariant(isSelected ? .fill : .none)
                    .symbolRenderingMode(.hierarchical)

                if showTitle {
                    Text(title)
                        .font(LiquidGlassTheme.Typography.caption1)
                        .fontWeight(.medium)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .foregroundStyle(
                isSelected ?
                    LinearGradient(
                        colors: [LiquidGlassTheme.Colors.primary, LiquidGlassTheme.Colors.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [LiquidGlassTheme.Colors.textSecondary, LiquidGlassTheme.Colors.textTertiary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
            .padding(.horizontal, showTitle ? 12 : 8)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(LiquidGlassTheme.Colors.glassBase.opacity(0.3))
                            .background(
                                LiquidGlassTheme.GlassEffects.liquidLight,
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .stroke(LiquidGlassTheme.GlassEffects.accentBorder, lineWidth: 1)
                            )
                    } else if isHovered {
                        Capsule()
                            .fill(LiquidGlassTheme.Colors.glassBase.opacity(0.5))
                    }
                }
            )
            .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.02 : 1.0))
            .rotation3DEffect(
                .degrees(isSelected ? 5 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}