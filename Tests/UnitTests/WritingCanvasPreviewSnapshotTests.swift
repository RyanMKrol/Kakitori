@testable import Kakitori
import SwiftUI
import XCTest

@MainActor
final class WritingCanvasPreviewSnapshotTests: XCTestCase {
    /// Renders TraceGuideLayer with glyphs visible to a scratch PNG for visual inspection.
    func testTraceGuideLayerVisibleRendersToImage() throws {
        let units = TargetSegmenter.segment("ありがとう")

        let content = ZStack {
            TraceGuideLayer(units: units, isVisible: true)
            WritingCanvas(controller: WritingCanvasController())
        }
        .background(KakitoriTheme.paper)
        .frame(width: 600, height: 400)

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 600, height: 400)

        let window = UIWindow(frame: hostingController.view.frame)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        let renderer = UIGraphicsImageRenderer(bounds: hostingController.view.bounds)
        let image = renderer.image { _ in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(image.size.width, 0)

        let data = try XCTUnwrap(image.pngData())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("trace-guide-layer-visible.png")
        try data.write(to: url)
    }

    /// Renders TraceGuideLayer with glyphs hidden to a scratch PNG for visual inspection.
    func testTraceGuideLayerHiddenRendersToImage() throws {
        let units = TargetSegmenter.segment("ありがとう")

        let content = ZStack {
            TraceGuideLayer(units: units, isVisible: false)
            WritingCanvas(controller: WritingCanvasController())
        }
        .background(KakitoriTheme.paper)
        .frame(width: 600, height: 400)

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 600, height: 400)

        let window = UIWindow(frame: hostingController.view.frame)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        let renderer = UIGraphicsImageRenderer(bounds: hostingController.view.bounds)
        let image = renderer.image { _ in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(image.size.width, 0)

        let data = try XCTUnwrap(image.pngData())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("trace-guide-layer-hidden.png")
        try data.write(to: url)
    }

    /// Renders the same content as WritingCanvas's `#Preview` to a scratch PNG so it can be
    /// visually inspected without an app screen hosting the component yet.
    func testPreviewRendersToImage() throws {
        let controller = WritingCanvasController()

        let content = VStack(spacing: 16) {
            WritingCanvas(controller: controller)
                .frame(width: 500, height: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(KakitoriTheme.inkFaint, lineWidth: 1)
                )

            HStack(spacing: 16) {
                Button("Undo") {}
                    .accessibilityIdentifier("canvas-undo")
                Button("Clear") {}
                    .accessibilityIdentifier("canvas-clear")
            }
        }
        .padding()
        .background(KakitoriTheme.paper)
        .frame(width: 560, height: 320)

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.frame = CGRect(x: 0, y: 0, width: 560, height: 320)

        let window = UIWindow(frame: hostingController.view.frame)
        window.rootViewController = hostingController
        window.isHidden = false
        hostingController.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        let renderer = UIGraphicsImageRenderer(bounds: hostingController.view.bounds)
        let image = renderer.image { _ in
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
        XCTAssertGreaterThan(image.size.width, 0)

        let data = try XCTUnwrap(image.pngData())
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("writing-canvas-preview.png")
        try data.write(to: url)
    }
}
