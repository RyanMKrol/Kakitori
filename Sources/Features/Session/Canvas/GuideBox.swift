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
    let traceGlyph: String?

    init(traceGlyph: String? = nil) {
        self.traceGlyph = traceGlyph
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(KakitoriTheme.paper)

            BorderPath()
                .stroke(KakitoriTheme.boxLine, lineWidth: 0.5)

            DashedCrossPath()
                .stroke(KakitoriTheme.boxLine, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))

            if let glyph = traceGlyph {
                GeometryReader { geometry in
                    let fontSize = geometry.size.width * 0.72
                    Text(glyph)
                        .font(.custom("Hiragino Mincho ProN", size: fontSize))
                        .foregroundStyle(KakitoriTheme.inkFaint)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview("Guide Box") {
    GuideBox()
        .frame(width: 160, height: 160)
}
