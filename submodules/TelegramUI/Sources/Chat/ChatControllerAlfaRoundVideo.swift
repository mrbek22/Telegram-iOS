import Foundation
import UIKit
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import OverlayStatusController

/// AlfaGram: picks one video from the photo library and hands back a temporary copy of it.
final class AlfaRoundVideoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private let completion: (URL?) -> Void

    init(completion: @escaping (URL?) -> Void) {
        self.completion = completion
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        let completion = self.completion
        guard let provider = results.first?.itemProvider, provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
            completion(nil)
            return
        }
        provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier, completionHandler: { url, _ in
            // The file exists only inside this callback: copy it out.
            var copy: URL?
            if let url {
                let target = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("alfa_src_" + UUID().uuidString + "." + (url.pathExtension.isEmpty ? "mov" : url.pathExtension))
                do {
                    try FileManager.default.copyItem(at: url, to: target)
                    copy = target
                } catch {
                }
            }
            DispatchQueue.main.async {
                completion(copy)
            }
        })
    }
}

/// AlfaGram: a centered square crop of the first minute of `source`, 400×400 MP4 — a round video message.
private func alfaMakeRoundVideo(source: URL, completion: @escaping (URL?, Double) -> Void) {
    let asset = AVURLAsset(url: source)
    guard let track = asset.tracks(withMediaType: .video).first else {
        completion(nil, 0.0)
        return
    }
    let side: CGFloat = 400.0
    let orientedRect = CGRect(origin: CGPoint(), size: track.naturalSize).applying(track.preferredTransform)
    let width = abs(orientedRect.width)
    let height = abs(orientedRect.height)
    let cropSide = min(width, height)
    if cropSide <= 0.0 {
        completion(nil, 0.0)
        return
    }
    let duration = CMTimeMinimum(asset.duration, CMTime(seconds: 60.0, preferredTimescale: 600))

    var transform = track.preferredTransform
    transform = transform.concatenating(CGAffineTransform(translationX: -orientedRect.minX, y: -orientedRect.minY))
    transform = transform.concatenating(CGAffineTransform(translationX: -(width - cropSide) / 2.0, y: -(height - cropSide) / 2.0))
    transform = transform.concatenating(CGAffineTransform(scaleX: side / cropSide, y: side / cropSide))

    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    layerInstruction.setTransform(transform, at: CMTime.zero)
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: CMTime.zero, duration: duration)
    instruction.layerInstructions = [layerInstruction]
    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = CGSize(width: side, height: side)
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    videoComposition.instructions = [instruction]

    guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
        completion(nil, 0.0)
        return
    }
    let output = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("alfa_round_" + UUID().uuidString + ".mp4")
    export.outputURL = output
    export.outputFileType = .mp4
    export.videoComposition = videoComposition
    export.timeRange = CMTimeRange(start: CMTime.zero, duration: duration)
    export.shouldOptimizeForNetworkUse = true
    export.exportAsynchronously(completionHandler: {
        let ok = export.status == .completed
        DispatchQueue.main.async {
            completion(ok ? output : nil, duration.seconds)
        }
    })
}

extension ChatControllerImpl {
    /// AlfaGram: «Round video from the gallery» — pick a video, crop it to a circle-ready square (≤ 1 min) and send it.
    func alfaPickGalleryRoundVideo() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        let delegate = AlfaRoundVideoPickerDelegate(completion: { [weak self] url in
            guard let self else {
                return
            }
            self.alfaRoundVideoPickerDelegate = nil
            guard let url else {
                return
            }
            let presentationData = self.presentationData
            let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            self.present(statusController, in: .window(.root))
            alfaMakeRoundVideo(source: url, completion: { [weak self, weak statusController] output, duration in
                statusController?.dismiss()
                let _ = try? FileManager.default.removeItem(at: url)
                guard let self, let output, let data = try? Data(contentsOf: output) else {
                    return
                }
                let _ = try? FileManager.default.removeItem(at: output)
                self.alfaSendRoundVideo(data: data, duration: duration)
            })
        })
        self.alfaRoundVideoPickerDelegate = delegate
        picker.delegate = delegate
        self.chatDisplayNode.dismissInput()
        self.present(picker, animated: true, completion: nil)
    }

    private func alfaSendRoundVideo(data: Data, duration: Double) {
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        self.context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data, synchronous: true)
        let media = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: Int64(data.count), attributes: [.FileName(fileName: "video.mp4"), .Video(duration: duration, size: PixelDimensions(width: 400, height: 400), flags: [.instantRoundVideo], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: [])
        let message: EnqueueMessage = .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: media), threadId: self.chatLocation.threadId, replyToMessageId: self.presentationInterfaceState.interfaceState.replyMessageSubject?.subjectModel, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
        self.sendMessages([message])
    }
}
