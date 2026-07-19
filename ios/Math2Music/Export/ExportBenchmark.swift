import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Debug-only performance harness for `LoopVideoExporter`, gated behind the
/// `EXPORT_BENCH` environment variable so it never runs in a normal launch.
/// Renders a fixed formula at both export resolutions, prints elapsed time
/// for each run, and dumps one still frame as PNG so before/after visual
/// diffs can be checked by eye. Invoke with:
///   SIMCTL_CHILD_EXPORT_BENCH=1 xcrun simctl launch --console <udid> <bundle-id>
enum ExportBenchmark {
    static func run() async {
        let amplitudes: [Double] = [1.5, 1.061, 0.866, 0.75, 0.671, 0.612, 0.567, 0]
        let theme = NeonTheme.all[0]

        if ProcessInfo.processInfo.environment["EXPORT_BENCH_APPEND"] == "1" {
            await appendOnlyProbe()
            return
        }

        await dumpStillFrame(amplitudes: amplitudes, theme: theme)

        var lines: [String] = []
        for resolution in [ExportResolution.fullHD, .ultraHD] {
            var elapsedRuns: [Double] = []
            for run in 0..<2 {
                let config = LoopVideoExporter.Config(
                    duration: 6.0,
                    size: resolution.size,
                    amplitudes: amplitudes,
                    theme: theme,
                    baseFrequency: 110,
                    minFrequencyHz: 60,
                    maxFrequencyHz: 2000,
                    volume: 0.8,
                    scale: .off,
                    waveform: .sine
                )
                let start = Date()
                do {
                    let url = try await LoopVideoExporter.export(config: config) { _ in }
                    try? FileManager.default.removeItem(at: url)
                } catch {
                    let line = "EXPORT_BENCH \(resolution.displayName) run=\(run) FAILED: \(error)"
                    print(line)
                    lines.append(line)
                }
                let elapsed = Date().timeIntervalSince(start)
                elapsedRuns.append(elapsed)
                let line = "EXPORT_BENCH \(resolution.displayName) run=\(run) elapsed=\(elapsed)"
                print(line)
                lines.append(line)
            }
            let median = elapsedRuns.sorted()[elapsedRuns.count / 2]
            let line = "EXPORT_BENCH_RESULT \(resolution.displayName) median=\(median)"
            print(line)
            lines.append(line)
        }

        // Also persist to a file: print() output isn't reliably captured
        // when this harness is driven via `xcodebuild test` (XCUITest host)
        // instead of `simctl launch --console`.
        let resultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("math2music_bench_result.txt")
        try? lines.joined(separator: "\n").write(to: resultURL, atomically: true, encoding: .utf8)
    }

    /// Measures the writer/encode path alone: renders nothing, appends a
    /// single black 4K frame 180 times (= 6s at 30fps). Static content is a
    /// lower bound on real encode cost, so a large number here proves the
    /// encoder — not rendering — bounds export time on this platform.
    private static func appendOnlyProbe() async {
        let size = ExportResolution.ultraHD.size
        let width = Int(size.width)
        let height = Int(size.height)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bench_append.mp4")
        try? FileManager.default.removeItem(at: url)
        do {
            let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 24_000_000],
            ])
            videoInput.expectsMediaDataInRealTime = false
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                ]
            )
            writer.add(videoInput)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            // Rotate several buffers: re-appending one buffer stalls the
            // encoder pipeline (append blocks until the encoder releases it),
            // which would overstate encode cost.
            guard let pool = adaptor.pixelBufferPool else { return }
            var buffers: [CVPixelBuffer] = []
            for _ in 0..<4 {
                var bufferOut: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &bufferOut)
                guard let buffer = bufferOut else { return }
                buffers.append(buffer)
            }
            let start = Date()
            for frame in 0..<180 {
                while !videoInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 4_000_000)
                }
                adaptor.append(buffers[frame % 4], withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
            }
            videoInput.markAsFinished()
            await writer.finishWriting()
            print("EXPORT_BENCH_APPEND 4K 180frames elapsed=\(Date().timeIntervalSince(start))")
            try? FileManager.default.removeItem(at: url)
        } catch {
            print("EXPORT_BENCH_APPEND FAILED: \(error)")
        }
    }

    /// Renders a single representative frame (mid-loop, so the wave trail is
    /// populated) to a PNG on disk for visual before/after comparison.
    private static func dumpStillFrame(amplitudes: [Double], theme: NeonTheme) async {
        let size = ExportResolution.fullHD.size
        let width = Int(size.width)
        let height = Int(size.height)
        guard let cg = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            print("EXPORT_BENCH_FRAME FAILED: no context")
            return
        }
        cg.translateBy(x: 0, y: CGFloat(height))
        cg.scaleBy(x: 1, y: -1)

        let loopProgress = 0.35
        var unusedWaveBuffer: [Double] = []
        let input = SceneRenderer.FrameInput(
            amplitudes: amplitudes,
            theme: theme,
            phaseTime: loopProgress * 2.0 * Double.pi,
            effectBoost: 1.3,
            loopProgress: loopProgress,
            waveform: .sine
        )
        SceneRenderer.draw(in: cg, size: size, input: input, waveBuffer: &unusedWaveBuffer)

        guard let image = cg.makeImage() else {
            print("EXPORT_BENCH_FRAME FAILED: no image")
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("math2music_bench_frame.png")
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else {
            print("EXPORT_BENCH_FRAME FAILED: no destination")
            return
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        print("EXPORT_BENCH_FRAME \(url.path)")
    }
}
