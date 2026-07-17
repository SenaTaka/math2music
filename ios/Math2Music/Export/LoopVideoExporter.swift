import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation

enum ExportResolution: String, CaseIterable, Identifiable {
    case fullHD
    case ultraHD

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .fullHD:
            return CGSize(width: 1080, height: 1920)
        case .ultraHD:
            return CGSize(width: 2160, height: 3840)
        }
    }

    var displayName: String {
        switch self {
        case .fullHD:
            return "1080p"
        case .ultraHD:
            return "4K"
        }
    }
}

/// Deterministic offline export: because the loop-mode visuals are a pure
/// function of loop progress and the audio can be synthesized offline, the
/// exporter re-renders both from scratch into a watermark-free, permission-
/// free, mathematically seamless MP4 (H.264 + AAC). No ReplayKit, no screen
/// capture, no dropped frames.
enum LoopVideoExporter {
    struct Config: Sendable {
        let duration: Double
        let size: CGSize
        let amplitudes: [Double]
        let theme: NeonTheme
        let baseFrequency: Double
        let minFrequencyHz: Double
        let maxFrequencyHz: Double
        let volume: Double
        let scale: MusicalScale
    }

    enum ExportError: Error {
        case writerSetupFailed
        case pixelBufferUnavailable
        case renderContextUnavailable
        case appendFailed
    }

    static let frameRate = 30

    static func export(
        config: Config,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let filename = "math2music-loop-\(Int(Date().timeIntervalSince1970)).mp4"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let width = Int(config.size.width)
        let height = Int(config.size.height)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: width >= 2000 ? 24_000_000 : 9_000_000
            ],
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192_000,
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = false

        guard writer.canAdd(videoInput), writer.canAdd(audioInput) else {
            throw ExportError.writerSetupFailed
        }
        writer.add(videoInput)
        writer.add(audioInput)
        guard writer.startWriting() else {
            throw writer.error ?? ExportError.writerSetupFailed
        }
        writer.startSession(atSourceTime: .zero)

        // --- Audio first (small buffer, encodes fast) ---
        let audio = OfflineAudioRenderer.renderLoop(config: config)
        progress(0.1)
        try await appendAudio(audio, to: audioInput)
        audioInput.markAsFinished()
        progress(0.15)

        // --- Deterministic video frames ---
        let totalFrames = max(1, Int(config.duration * Double(frameRate)))
        var unusedWaveBuffer: [Double] = []
        for frame in 0..<totalFrames {
            while !videoInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 4_000_000)
            }
            guard let pool = adaptor.pixelBufferPool else {
                throw ExportError.pixelBufferUnavailable
            }
            var pixelBufferOut: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBufferOut)
            guard let pixelBuffer = pixelBufferOut else {
                throw ExportError.pixelBufferUnavailable
            }

            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            guard let base = CVPixelBufferGetBaseAddress(pixelBuffer),
                  let cg = CGContext(
                      data: base,
                      width: width,
                      height: height,
                      bitsPerComponent: 8,
                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                          | CGBitmapInfo.byteOrder32Little.rawValue
                  )
            else {
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                throw ExportError.renderContextUnavailable
            }

            // SceneRenderer draws in top-left canvas coordinates; flip the
            // bottom-left CGBitmapContext to match.
            cg.translateBy(x: 0, y: CGFloat(height))
            cg.scaleBy(x: 1, y: -1)

            let loopProgress = Double(frame) / Double(totalFrames)
            let input = SceneRenderer.FrameInput(
                amplitudes: config.amplitudes,
                theme: config.theme,
                phaseTime: loopProgress * 2.0 * Double.pi,
                effectBoost: 1.3,
                loopProgress: loopProgress
            )
            SceneRenderer.draw(
                in: cg,
                size: config.size,
                input: input,
                waveBuffer: &unusedWaveBuffer
            )
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

            let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(frameRate))
            if !adaptor.append(pixelBuffer, withPresentationTime: time) {
                throw writer.error ?? ExportError.appendFailed
            }
            progress(0.15 + 0.8 * Double(frame + 1) / Double(totalFrames))
        }
        videoInput.markAsFinished()

        // End the session exactly at the loop boundary so the last video
        // frame is held for one frame period (not two) and the video track
        // length equals the audio track length — no freeze at the seam.
        writer.endSession(
            atSourceTime: CMTime(value: CMTimeValue(totalFrames), timescale: CMTimeScale(frameRate))
        )
        await writer.finishWriting()
        if writer.status == .failed {
            throw writer.error ?? ExportError.writerSetupFailed
        }
        progress(1.0)
        return url
    }

    private static func appendAudio(
        _ audio: OfflineAudioRenderer.RenderedAudio,
        to input: AVAssetWriterInput
    ) async throws {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: audio.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 8,
            mFramesPerPacket: 1,
            mBytesPerFrame: 8,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        var formatDescriptionOut: CMAudioFormatDescription?
        let formatStatus = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescriptionOut
        )
        guard formatStatus == noErr, let format = formatDescriptionOut else {
            throw ExportError.writerSetupFailed
        }

        let bytesPerFrame = 8
        let timescale = CMTimeScale(Int32(audio.sampleRate))
        let totalFrames = audio.samples.count / 2
        let chunkFrames = 22050  // 0.5 s
        var framePosition = 0

        while framePosition < totalFrames {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 4_000_000)
            }
            let framesThisChunk = min(chunkFrames, totalFrames - framePosition)
            let byteCount = framesThisChunk * bytesPerFrame

            var blockBufferOut: CMBlockBuffer?
            let blockStatus = CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: byteCount,
                blockAllocator: nil,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: byteCount,
                flags: kCMBlockBufferAssureMemoryNowFlag,
                blockBufferOut: &blockBufferOut
            )
            guard blockStatus == kCMBlockBufferNoErr, let blockBuffer = blockBufferOut else {
                throw ExportError.writerSetupFailed
            }

            let copyStatus = audio.samples.withUnsafeBufferPointer { pointer -> OSStatus in
                guard let baseAddress = pointer.baseAddress else {
                    return OSStatus(-1)
                }
                return CMBlockBufferReplaceDataBytes(
                    with: baseAddress + framePosition * 2,
                    blockBuffer: blockBuffer,
                    offsetIntoDestination: 0,
                    dataLength: byteCount
                )
            }
            guard copyStatus == kCMBlockBufferNoErr else {
                throw ExportError.writerSetupFailed
            }

            var timing = CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: timescale),
                presentationTimeStamp: CMTime(
                    value: CMTimeValue(framePosition),
                    timescale: timescale
                ),
                decodeTimeStamp: .invalid
            )
            var sampleBufferOut: CMSampleBuffer?
            let sampleStatus = CMSampleBufferCreate(
                allocator: kCFAllocatorDefault,
                dataBuffer: blockBuffer,
                dataReady: true,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: format,
                sampleCount: CMItemCount(framesThisChunk),
                sampleTimingEntryCount: 1,
                sampleTimingArray: &timing,
                sampleSizeEntryCount: 0,
                sampleSizeArray: nil,
                sampleBufferOut: &sampleBufferOut
            )
            guard sampleStatus == noErr, let sampleBuffer = sampleBufferOut else {
                throw ExportError.writerSetupFailed
            }
            if !input.append(sampleBuffer) {
                throw ExportError.appendFailed
            }
            framePosition += framesThisChunk
        }
    }
}
