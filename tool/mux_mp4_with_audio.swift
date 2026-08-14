import AVFoundation
import Foundation

let args = CommandLine.arguments
guard args.count == 4 else {
    fputs("usage: swift mux_mp4_with_audio.swift <videoMp4> <audioFile> <outputMp4>\n", stderr)
    exit(2)
}

let videoURL = URL(fileURLWithPath: args[1])
let audioURL = URL(fileURLWithPath: args[2])
let outputURL = URL(fileURLWithPath: args[3])

try? FileManager.default.removeItem(at: outputURL)

let composition = AVMutableComposition()
let videoAsset = AVURLAsset(url: videoURL)
let audioAsset = AVURLAsset(url: audioURL)

guard
    let videoSourceTrack = videoAsset.tracks(withMediaType: .video).first,
    let videoTrack = composition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: kCMPersistentTrackID_Invalid
    )
else {
    fputs("missing video track\n", stderr)
    exit(3)
}

try videoTrack.insertTimeRange(
    CMTimeRange(start: .zero, duration: videoAsset.duration),
    of: videoSourceTrack,
    at: .zero
)
videoTrack.preferredTransform = videoSourceTrack.preferredTransform

if
    let audioSourceTrack = audioAsset.tracks(withMediaType: .audio).first,
    let audioTrack = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
    )
{
    let duration = min(videoAsset.duration, audioAsset.duration)
    try audioTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: duration),
        of: audioSourceTrack,
        at: .zero
    )
} else {
    fputs("missing audio track\n", stderr)
    exit(4)
}

guard let exporter = AVAssetExportSession(
    asset: composition,
    presetName: AVAssetExportPresetHighestQuality
) else {
    fputs("could not create exporter\n", stderr)
    exit(5)
}

exporter.outputURL = outputURL
exporter.outputFileType = .mp4
exporter.shouldOptimizeForNetworkUse = true

let group = DispatchGroup()
group.enter()
exporter.exportAsynchronously {
    group.leave()
}
group.wait()

if exporter.status != .completed {
    fputs("export failed: \(exporter.error?.localizedDescription ?? "unknown error")\n", stderr)
    exit(6)
}

print("wrote \(outputURL.path)")
