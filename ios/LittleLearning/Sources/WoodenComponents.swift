import SwiftUI

typealias Wood = WoodlandTokens

/// Keep teaching illustrations legible when their interaction is disabled after a correct answer.
struct IllustrationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

struct PadFramesKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] { [:] }
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func woodText(_ role: WoodlandTokens.TypeRole) -> some View { modifier(WoodlandTextStyle(role: role)) }
}

struct Tray<Content: View>: View {
    var padding: CGFloat = Wood.Spacing.lg
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding)
            .background {
                RoundedRectangle(cornerRadius: Wood.Radius.tray, style: .continuous)
                    .fill(Wood.Palette.traySide).offset(y: 6)
                    .shadow(color: Wood.Palette.textPrimary.opacity(0.08), radius: 12, y: 12)
                RoundedRectangle(cornerRadius: Wood.Radius.tray, style: .continuous)
                    .fill(Wood.Palette.tray)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Wood.Radius.tray, style: .continuous)
                    .strokeBorder(Wood.Palette.borderDecorative, lineWidth: Wood.Stroke.control)
            }
    }
}

struct WoodIconButton: View {
    var symbol: String
    var label: String
    var yellow = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(yellow ? Wood.Palette.onHint : Wood.Palette.textPrimary)
                .frame(width: Wood.Size.touchMinimum, height: Wood.Size.touchMinimum)
                .background {
                    Circle().fill(yellow ? Wood.Palette.hintSide : Wood.Palette.traySide).offset(y: 4)
                    Circle().fill(yellow ? Wood.Palette.hint : Wood.Palette.secondaryFill)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct SecondaryWoodStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.woodText(Wood.Typography.label)
            .foregroundStyle(enabled ? Wood.Palette.textPrimary : Wood.Palette.disabledInk)
            .padding(.horizontal, Wood.Spacing.md).padding(.vertical, Wood.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: Wood.Size.touchMinimum)
            .background(enabled ? Wood.Palette.secondaryFill : Wood.Palette.disabledFill,
                        in: RoundedRectangle(cornerRadius: Wood.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Wood.Radius.control, style: .continuous)
                    .strokeBorder(Wood.Palette.slotStroke, lineWidth: configuration.isPressed ? 2 : 1)
            }
    }
}

struct LilyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w * 0.52, y: h * 0.42))
        p.addLine(to: CGPoint(x: w * 0.77, y: h * 0.06))
        p.addCurve(to: CGPoint(x: w * 0.94, y: h * 0.68), control1: CGPoint(x: w * 1.03, y: h * 0.16), control2: CGPoint(x: w * 1.03, y: h * 0.45))
        p.addCurve(to: CGPoint(x: w * 0.10, y: h * 0.76), control1: CGPoint(x: w * 0.77, y: h * 1.08), control2: CGPoint(x: w * 0.26, y: h * 1.05))
        p.addCurve(to: CGPoint(x: w * 0.61, y: h * 0.02), control1: CGPoint(x: -w * 0.18, y: h * 0.39), control2: CGPoint(x: w * 0.08, y: -h * 0.11))
        p.addLine(to: CGPoint(x: w * 0.52, y: h * 0.42))
        p.closeSubpath()
        return p
    }
}

/// Original vector illustration; no web assets or image dependencies.
struct LittleDuck: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Ellipse().fill(Wood.Palette.hintSide).frame(width: w * 0.15, height: h * 0.08).offset(x: -w * 0.08, y: h * 0.40)
                Ellipse().fill(Wood.Palette.hintSide).frame(width: w * 0.15, height: h * 0.08).offset(x: w * 0.15, y: h * 0.40)
                Ellipse().fill(Wood.Palette.hint).frame(width: w * 0.76, height: h * 0.55).offset(x: -w * 0.06, y: h * 0.17)
                Ellipse().fill(Wood.Palette.object).frame(width: w * 0.25, height: h * 0.12).offset(x: w * 0.35, y: -h * 0.13)
                Circle().fill(Wood.Palette.hint).frame(width: w * 0.51).offset(x: w * 0.12, y: -h * 0.19)
                Circle().fill(Wood.Palette.textPrimary).frame(width: w * 0.055).offset(x: w * 0.23, y: -h * 0.23)
                Ellipse().fill(Wood.Palette.hintSide.opacity(0.45)).frame(width: w * 0.34, height: h * 0.25).rotationEffect(.degrees(-20)).offset(x: -w * 0.10, y: h * 0.17)
                Capsule().fill(.white.opacity(0.45)).frame(width: w * 0.12, height: h * 0.025).rotationEffect(.degrees(-25)).offset(x: -w * 0.15, y: h * 0.09)
            }.frame(width: w, height: h)
        }
        .accessibilityHidden(true)
    }
}

struct PondArtwork: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Wood.Radius.control).fill(Wood.Palette.successBackground)
            HStack(alignment: .bottom, spacing: Wood.Spacing.md) {
                LilyShape().fill(Wood.Palette.success).frame(width: 64, height: 42).rotationEffect(.degrees(-12))
                VStack(spacing: 0) {
                    LittleDuck().frame(width: 86, height: 86)
                    LilyShape().fill(Wood.Palette.success).frame(width: 96, height: 58)
                }
                LilyShape().fill(Wood.Palette.success).frame(width: 52, height: 35).rotationEffect(.degrees(15))
            }.padding(Wood.Spacing.lg)
        }
        .accessibilityHidden(true)
    }
}
