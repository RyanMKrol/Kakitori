import SwiftUI

/// The panel a Pencil hold brings up over the canvas: the brush-angle lock, and the canvas actions
/// that are otherwise a reach away.
///
/// The angle is set here rather than read off the squeeze gesture itself. Reading it from the
/// gesture meant depending on `UIPencilInteraction.Squeeze.hoverPose`, which only exists while the
/// pencil is hovering in range — squeeze with the pencil away from the screen and there was no
/// angle to read, so the lock quietly never happened. A dial always has an angle.
@MainActor
struct BrushMenu: View {
    let controller: WritingCanvasController
    let onDismiss: () -> Void

    /// Live while dragging the dial; nil when it reflects whatever the controller holds.
    @State private var draggingAngle: CGFloat?

    private var angle: CGFloat {
        draggingAngle ?? controller.lockedBrushAngle ?? 0
    }

    private var isLocked: Bool {
        controller.lockedBrushAngle != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if WritingCanvas.canLockBrushAngle {
                angleSection
                Divider().background(KakitoriTheme.boxLine)
            }

            actionButton(
                title: "Clear canvas",
                systemImage: "trash",
                identifier: "brush-menu-clear",
                isProminent: false
            ) {
                controller.clear()
                onDismiss()
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(KakitoriTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(KakitoriTheme.boxLine, lineWidth: 1)
        )
        .shadow(color: KakitoriTheme.ink.opacity(0.18), radius: 24, y: 8)
        .accessibilityIdentifier("brush-menu")
    }

    private var header: some View {
        HStack {
            Text("BRUSH")
                .kakitoriFont(size: 12, weight: .semibold)
                .tracking(0.15)
                .foregroundStyle(KakitoriTheme.accent)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KakitoriTheme.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close brush menu")
            .accessibilityIdentifier("brush-menu-close")
        }
        .frame(height: 44)
    }

    private var angleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isLocked ? "Angle locked" : "Angle follows the pencil")
                .kakitoriFont(size: 15, weight: .semibold)
                .foregroundStyle(KakitoriTheme.ink)

            HStack(spacing: 20) {
                BrushAngleDial(angle: angle) { newAngle in
                    draggingAngle = newAngle
                    controller.previewBrushAngle(newAngle)
                } onCommit: { newAngle in
                    draggingAngle = nil
                    controller.lockBrushAngle(to: newAngle)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(Int(angle * 180 / .pi))°")
                        .kakitoriFont(size: 22, weight: .bold)
                        .foregroundStyle(KakitoriTheme.ink)
                        .accessibilityIdentifier("brush-angle-value")

                    Text(
                        "Turn the dial to set where the brush's edge points, then keep writing however you like to hold the pencil."
                    )
                    .kakitoriFont(size: 12)
                    .foregroundStyle(KakitoriTheme.ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isLocked {
                actionButton(
                    title: "Follow the pencil again",
                    systemImage: "arrow.counterclockwise",
                    identifier: "brush-menu-unlock",
                    isProminent: false
                ) {
                    draggingAngle = nil
                    controller.releaseBrushAngleLock()
                }
            }
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        identifier: String,
        isProminent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .kakitoriFont(size: 15, weight: .semibold)
            .foregroundStyle(isProminent ? KakitoriTheme.paper : KakitoriTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(isProminent ? KakitoriTheme.accent : KakitoriTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier(identifier)
    }
}

/// A dial for the brush's nib angle. Dragging anywhere in it points the nib at the touch, which is
/// a more direct way to say "this way round" than a slider of degrees.
@MainActor
struct BrushAngleDial: View {
    let angle: CGFloat
    let onChange: (CGFloat) -> Void
    let onCommit: (CGFloat) -> Void

    private let diameter: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .fill(KakitoriTheme.surface)

            Circle()
                .stroke(KakitoriTheme.boxLine, lineWidth: 1)

            // The nib: a bar through the middle, drawn at the angle it would ink at.
            Capsule()
                .fill(KakitoriTheme.ink)
                .frame(width: diameter * 0.62, height: 8)
                .rotationEffect(.radians(Double(angle)))

            Circle()
                .fill(KakitoriTheme.accent)
                .frame(width: 14, height: 14)
                .offset(handleOffset)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in onChange(angle(for: value.location)) }
                .onEnded { value in onCommit(angle(for: value.location)) }
        )
        .accessibilityIdentifier("brush-angle-dial")
        .accessibilityLabel("Brush angle")
        .accessibilityValue("\(Int(angle * 180 / .pi)) degrees")
        .accessibilityAdjustableAction { direction in
            let step = CGFloat.pi / 36 // 5°
            switch direction {
            case .increment: onCommit(angle + step)
            case .decrement: onCommit(angle - step)
            @unknown default: break
            }
        }
    }

    private var handleOffset: CGSize {
        let radius = diameter * 0.31
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }

    /// The angle from the dial's centre to `point`, in the dial's own coordinate space.
    private func angle(for point: CGPoint) -> CGFloat {
        let centre = CGPoint(x: diameter / 2, y: diameter / 2)
        return atan2(point.y - centre.y, point.x - centre.x)
    }
}
