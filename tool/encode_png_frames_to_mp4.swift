import AVFoundation
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count == 6 else {
    fputs("usage: swift encode_png_frames_to_mp4.swift <framesDir> <outputMp4> <width> <height> <fps>\n", stderr)
    exit(2)
}

let framesDir = URL(fileURLWithPath: args[1], isDirectory: true)
let outputURL = URL(fileURLWithPath: args[2])
let width = Int(args[3])!
let height = Int(args[4])!
let fps = Int32(args[5])!

try? FileManager.default.removeItem(at: outputURL)

let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 6_000_000,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    ],
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(
    assetWriterInput: input,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
    ]
)

guard writer.canAdd(input) else {
    fputs("cannot add video input\n", stderr)
    exit(3)
}
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let frameFiles = try FileManager.default.contentsOfDirectory(at: framesDir, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasPrefix("frame_") && $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

func pixelBuffer(from image: NSImage, width: Int, height: Int) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let attrs = [
        kCVPixelBufferCGImageCompatibilityKey: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey: true,
    ] as CFDictionary
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    guard let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
    ) else { return nil }

    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    return buffer
}

var frameIndex: Int64 = 0
for file in frameFiles {
    while !input.isReadyForMoreMediaData {
        Thread.sleep(forTimeInterval: 0.005)
    }
    guard let image = NSImage(contentsOf: file),
          let buffer = pixelBuffer(from: image, width: width, height: height) else {
        fputs("failed to read frame \(file.path)\n", stderr)
        exit(4)
    }
    let time = CMTime(value: frameIndex, timescale: fps)
    if !adaptor.append(buffer, withPresentationTime: time) {
        fputs("failed to append frame \(frameIndex)\n", stderr)
        exit(5)
    }
    frameIndex += 1
}

input.markAsFinished()
let group = DispatchGroup()
group.enter()
writer.finishWriting {
    group.leave()
}
group.wait()

if writer.status != .completed {
    fputs("writer failed: \(writer.error?.localizedDescription ?? "unknown error")\n", stderr)
    exit(6)
}

print("wrote \(outputURL.path) frames=\(frameFiles.count)")
