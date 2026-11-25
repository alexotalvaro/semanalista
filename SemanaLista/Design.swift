import SwiftUI
import UIKit

// MARK: - Paleta

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    // Fondos
    static let paper = Color(light: 0xF3F7FE, dark: 0x07101F)
    static let paperDeep = Color(light: 0xE6EFFC, dark: 0x0B1729)
    static let card = Color(light: 0xFFFFFF, dark: 0x101D33)

    // Texto
    static let ink = Color(light: 0x0B1B33, dark: 0xEDF4FF)
    static let inkSoft = Color(light: 0x52637B, dark: 0xA9B9CF)
    static let inkFaint = Color(light: 0x8797AC, dark: 0x7487A0)

    // Azul principal
    static let terracotta = Color(light: 0x2E6BFF, dark: 0x4C86FF)
    static let terracottaDeep = Color(light: 0x1746C8, dark: 0xB7CEFF)
    static let terracottaSoft = Color(light: 0xE3EDFF, dark: 0x16294A)

    // Azul secundario y estados completados
    static let olive = Color(light: 0x0AA7C2, dark: 0x3ED0E6)
    static let oliveSoft = Color(light: 0xDDF6FA, dark: 0x0C2E38)

    // Azules auxiliares
    static let sand = Color(light: 0xD7E5F7, dark: 0x1B2C47)
    static let line = Color(light: 0xD9E5F3, dark: 0x233451)
    static let sky = Color(light: 0x6FC8FF, dark: 0x7DD3FC)
    static let indigo = Color(light: 0x4F46E5, dark: 0x8B93FF)
    static let navy = Color(light: 0x0A2540, dark: 0x071A33)
}

extension AppAppearance {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppGradient {
    static let brand = LinearGradient(
        colors: [
            Color(light: 0x4F8DFF, dark: 0x5D97FF),
            Color(light: 0x2E6BFF, dark: 0x3B78FF),
            Color(light: 0x1746C8, dark: 0x2458D8)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let brandSoft = LinearGradient(
        colors: [
            Color(light: 0xF7FAFF, dark: 0x0D1B30),
            Color(light: 0xE3EDFF, dark: 0x12294A)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let hero = LinearGradient(
        colors: [
            Color(light: 0x071A33, dark: 0x020812),
            Color(light: 0x0F3A73, dark: 0x071F42),
            Color(light: 0x2E6BFF, dark: 0x1B4FCC)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cyan = LinearGradient(
        colors: [
            Color(light: 0x67E8F9, dark: 0x7DEBFA),
            Color(light: 0x0AA7C2, dark: 0x22C7DD)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cyanSoft = LinearGradient(
        colors: [
            Color(light: 0xF3FDFF, dark: 0x0A222B),
            Color(light: 0xDFF7FB, dark: 0x0C2C36)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let card = LinearGradient(
        colors: [
            Color(light: 0xFFFFFF, dark: 0x12203A),
            Color(light: 0xFBFDFF, dark: 0x0D1829)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let stroke = LinearGradient(
        colors: [
            Color(light: 0xFFFFFF, dark: 0x2A3D5C),
            Color(light: 0xD9E5F3, dark: 0x1C2C47)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Fondo

struct AppBackground: View {
    var body: some View {
        // El degradado es el único elemento que participa en el layout. Las
        // manchas van en un overlay para que sus 430 pt no ensanchen la app en
        // pantallas pequeñas (iPhone mini, SE o 17e).
        LinearGradient(
            colors: [
                Color(light: 0xF7FAFF, dark: 0x050B16),
                Color(light: 0xEDF4FE, dark: 0x081426),
                Color(light: 0xF4F8FE, dark: 0x0A1A2E)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            ZStack {
                Circle()
                    .fill(Color(hex: 0x3B82F6).opacity(0.13))
                    .frame(width: 430, height: 430)
                    .blur(radius: 90)
                    .offset(x: 175, y: -330)

                Circle()
                    .fill(Color(hex: 0x22D3EE).opacity(0.11))
                    .frame(width: 370, height: 370)
                    .blur(radius: 85)
                    .offset(x: -185, y: 320)

                Circle()
                    .fill(Color(hex: 0x6366F1).opacity(0.07))
                    .frame(width: 310, height: 310)
                    .blur(radius: 75)
                    .offset(x: 140, y: 520)

                LinearGradient(
                    colors: [
                        Color(light: 0xFFFFFF, dark: 0x16243D).opacity(0.5),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .clipped()
        .ignoresSafeArea()
    }
}

extension View {
    /// Bloquea cualquier desplazamiento o rebote horizontal del `ScrollView`.
    /// Solo se permite el movimiento vertical de las tarjetas.
    func verticalOnlyScroll() -> some View {
        scrollBounceBehavior(.basedOnSize, axes: [.vertical, .horizontal])
            .scrollClipDisabled(false)
    }

    /// Fija el ancho del contenido al ancho visible del `ScrollView`. Si algún
    /// hijo intenta ser más ancho que la pantalla, se recorta en lugar de
    /// permitir que todo el contenido se desplace a izquierda o derecha.
    func lockedScrollWidth() -> some View {
        containerRelativeFrame(.horizontal)
    }
}

// MARK: - Tarjetas

struct CardModifier: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 24
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppGradient.card)
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.35)
                            : Color(hex: 0x0A2540).opacity(0.07),
                        radius: 24, x: 0, y: 12
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.18)
                            : Color(hex: 0x2E6BFF).opacity(0.04),
                        radius: 4, x: 0, y: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppGradient.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 18, radius: CGFloat = 24) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

// MARK: - Tipografía

struct ScreenHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let eyebrow {
                Text(L10n.t(eyebrow).uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .tracking(1.7)
                    .foregroundStyle(Color.terracotta)
            }
            Text(L10n.t(title))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
                .tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(L10n.t(subtitle))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Font {
    static func serifTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: - Botones

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(enabled ? AppGradient.brand : LinearGradient(
                        colors: [Color.inkFaint.opacity(0.55), Color.inkFaint.opacity(0.38)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(enabled ? 0.24 : 0.1), lineWidth: 1)
            )
            .shadow(color: enabled ? Color.terracotta.opacity(0.32) : .clear, radius: 18, x: 0, y: 9)
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.card.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppGradient.stroke, lineWidth: 1)
                    )
                    .shadow(color: Color(hex: 0x0A2540).opacity(0.05), radius: 12, y: 6)
            )
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Chips

struct SelectChip: View {
    let title: String
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(selected ? .white : Color.inkSoft)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(selected ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(Color.card))
            )
            .overlay(
                Capsule().stroke(selected ? Color.terracottaDeep.opacity(0.35) : Color.line, lineWidth: 1)
            )
            .shadow(color: selected ? Color.terracotta.opacity(0.22) : .clear, radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct CategoryTag: View {
    let category: PrepCategory
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.symbol)
                .font(.system(size: compact ? 8 : 9, weight: .bold))
            Text(category.label)
                .font(.system(size: compact ? 9 : 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Color.terracottaDeep)
        .padding(.horizontal, compact ? 7 : 8)
        .padding(.vertical, compact ? 3 : 4)
        .background(Capsule().fill(Color.terracottaSoft.opacity(0.9)))
    }
}

struct AIBadge: View {
    let source: PlanSource

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: source.isAI ? "sparkles" : "square.stack.3d.up")
                .font(.system(size: 10, weight: .bold))
            Text(source.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(source.isAI ? .white : Color.inkSoft)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(source.isAI ? AnyShapeStyle(AppGradient.brand) : AnyShapeStyle(Color.paperDeep))
        )
        .overlay(
            Capsule().stroke(source.isAI ? Color.white.opacity(0.22) : Color.line, lineWidth: 1)
        )
        .shadow(color: source.isAI ? Color.terracotta.opacity(0.25) : .clear, radius: 9, y: 4)
    }
}

// MARK: - Selector de modelo

struct ModelPresetMenu: View {
    let provider: APIProvider
    @Binding var model: String

    var body: some View {
        if provider.presetModels.isEmpty {
            EmptyView()
        } else {
            Menu {
                ForEach(provider.presetModels, id: \.self) { preset in
                    Button {
                        model = preset
                    } label: {
                        if model == preset {
                            Label(preset, systemImage: "checkmark")
                        } else {
                            Text(preset)
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text("Modelos sugeridos")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.terracotta)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.terracottaSoft.opacity(0.9)))
            }
        }
    }
}

// MARK: - Avisos

struct StoreNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        case success, warning, info
    }

    let id = UUID()
    let kind: Kind
    let text: String

    var symbol: String {
        switch kind {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    var tint: Color {
        switch kind {
        case .success: .olive
        case .warning: .terracotta
        case .info: .terracotta
        }
    }
}

struct NoticeBanner: View {
    let notice: StoreNotice
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: notice.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(notice.tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(notice.tint.opacity(0.13)))

            Text(notice.text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.inkFaint)
                    .padding(5)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(notice.tint.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(notice.tint.opacity(0.16), lineWidth: 1)
        )
    }
}

// MARK: - Flujo de chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        let height = y + rowHeight
        return CGSize(width: proposal.width ?? max(0, x - spacing), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Detalles

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.line.opacity(0.85))
            .frame(height: 1)
    }
}

struct EmptyHint: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.terracotta)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.terracottaSoft))
            Text(L10n.t(title))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
            Text(L10n.t(text))
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }
}
