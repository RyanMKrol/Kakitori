import SwiftUI

private struct BorderPath: Shape {
    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: 0)
    }
}

private struct DashedCrossPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY

        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))

        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))

        return path
    }
}

struct GuideBox: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(KakitoriTheme.paper)

            BorderPath()
                .stroke(KakitoriTheme.boxLine, lineWidth: 0.5)

            DashedCrossPath()
                .stroke(KakitoriTheme.boxLine, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview("Guide Box") {
    GuideBox()
        .frame(width: 160, height: 160)
}
