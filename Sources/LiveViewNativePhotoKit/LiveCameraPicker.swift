//
//  LiveCameraPicker.swift
//  LiveViewNativePhotoKit
//
//  Created by Carson Katri on 10/24/24.
//

import LiveViewNative
import LiveViewNativeCore
import SwiftUI
import UIKit
import UniformTypeIdentifiers
@preconcurrency import AVKit
import OSLog

private let logger = Logger(subsystem: "LiveViewNativePhotoKit", category: "LiveCameraPicker")

@LiveElement
struct LiveCameraPicker<Root: RootRegistry>: View {
    @LiveElementIgnored
    @State
    private var isPresented: Bool = false
    
    @LiveElementIgnored
    @Environment(\.formModel)
    private var formModel
    
    @LiveAttribute("data-phx-upload-ref")
    var phxUploadRef: String?
    
    var name: String?
    
    var cameraDevice: UIImagePickerController.CameraDevice = .rear
    var allowsEditing: Bool = false
    var cameraCaptureMode: UIImagePickerController.CameraCaptureMode = .photo
    var cameraFlashMode: UIImagePickerController.CameraFlashMode = .auto
    var videoMaximumDuration: Double = 600
    var videoQuality: UIImagePickerController.QualityType = .typeMedium
    
    var width: Int?
    var height: Int?
    
    var body: some View {
        Button {
            isPresented = true
        } label: {
            $liveElement.children()
        }
        .fullScreenCover(isPresented: $isPresented) {
            ImagePickerView(
                width: width,
                height: height,
                cameraDevice: cameraDevice,
                allowsEditing: allowsEditing,
                cameraCaptureMode: cameraCaptureMode,
                cameraFlashMode: cameraFlashMode,
                videoMaximumDuration: videoMaximumDuration,
                videoQuality: videoQuality
            ) { contents, fileType in
                guard let phxUploadRef else { return }
                Task {
                    do {
                        try await formModel?.queueFileUpload(name: name ?? "photo", id: phxUploadRef, contents: contents, fileType: fileType, fileName: name ?? "photo", coordinator: $liveElement.context.coordinator)
                    } catch {
                        logger.log(level: .error, "\(error.localizedDescription)")
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
    
    struct ImagePickerView: UIViewControllerRepresentable {
        let width: Int?
        let height: Int?
        
        let cameraDevice: UIImagePickerController.CameraDevice
        let allowsEditing: Bool
        let cameraCaptureMode: UIImagePickerController.CameraCaptureMode
        let cameraFlashMode: UIImagePickerController.CameraFlashMode
        let videoMaximumDuration: Double
        let videoQuality: UIImagePickerController.QualityType
        
        let onCapture: (Data, UTType) -> ()
        
        @Environment(\.dismiss) private var dismiss
        
        func makeUIViewController(context: Context) -> UIImagePickerController {
            let controller = UIImagePickerController()
            controller.sourceType = .camera
            
            controller.showsCameraControls = true
            controller.cameraDevice = cameraDevice
            controller.allowsEditing = allowsEditing
            if cameraCaptureMode == .video {
                controller.mediaTypes = [UTType.movie.identifier]
            }
            controller.cameraCaptureMode = cameraCaptureMode
            controller.cameraFlashMode = cameraFlashMode
            controller.videoMaximumDuration = videoMaximumDuration
            controller.videoQuality = videoQuality
            
            controller.delegate = context.coordinator
            return controller
        }
        
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
            let parent: ImagePickerView
            
            init(_ parent: ImagePickerView) {
                self.parent = parent
            }
            
            func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                parent.dismiss()
            }
            
            func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
                // resize captured images/videos before upload if specified.
                
                func size(relativeTo originalSize: CGSize) -> CGSize {
                    switch (parent.width.flatMap(CGFloat.init), parent.height.flatMap(CGFloat.init)) {
                    case (.none, .none):
                        originalSize
                    case (.some(let width), .none):
                        .init(width: width, height: originalSize.height * (width / originalSize.width))
                    case (.none, .some(let height)):
                        .init(width: originalSize.width * (height / originalSize.height), height: height)
                    case (.some(let width), .some(let height)):
                        .init(width: width, height: height)
                    }
                }

                if let mediaURL = info[.mediaURL] as? URL {
                    Task {
                        do {
                            let asset = AVURLAsset(url: mediaURL)
                            guard let track = try await asset.loadTracks(withMediaType: .video).first,
                                  let originalAudioTrack = try await asset.loadTracks(withMediaType: .audio).first
                            else { return parent.dismiss() }
                            
                            let naturalSize = try await track.load(.naturalSize)
                            let minFrameDuration = try await track.load(.minFrameDuration)
                            let duration = try await asset.load(.duration)
                            let preferredTransform = try await track.load(.preferredTransform)
                            
                            let originalSize: CGSize = if preferredTransform.tx == 0 && preferredTransform.ty == 0 {
                                // landscape
                                naturalSize
                            } else {
                                // portrait, width/height are flipped
                                .init(width: naturalSize.height, height: naturalSize.width)
                            }
                            
                            let newSize = size(relativeTo: originalSize)
                            
                            let composition = AVMutableComposition()
                            
                            guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
                            else { return parent.dismiss() }
                            try compositionTrack.insertTimeRange(.init(start: .zero, duration: duration), of: track, at: .zero)
                            
                            let instruction = AVMutableVideoCompositionInstruction()
                            instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
                            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
                            layerInstruction.setTransform(
                                preferredTransform.concatenating(CGAffineTransform(scaleX: newSize.width / originalSize.width, y: newSize.height / originalSize.height)),
                                at: .zero
                            )
                            instruction.layerInstructions = [
                                layerInstruction
                            ]
                            
                            let videoComposition = AVMutableVideoComposition()
                            videoComposition.instructions = [
                                instruction
                            ]
                            videoComposition.frameDuration = minFrameDuration
                            videoComposition.renderSize = newSize
                            
                            if let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) {
                                try audioTrack.insertTimeRange(.init(start: .zero, duration: duration), of: originalAudioTrack, at: .zero)
                            }
                            
                            guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
                            else { return parent.dismiss() }
                            
                            exporter.shouldOptimizeForNetworkUse = true
                            exporter.videoComposition = videoComposition
                            
                            let exportURL = mediaURL.deletingPathExtension().appendingPathExtension("mp4")
                            exporter.outputFileType = .mp4
                            exporter.outputURL = exportURL
                            await exporter.export()
                            
                            parent.onCapture(try Data(contentsOf: exportURL), .mpeg4Movie)
                            parent.dismiss()
                        } catch {
                            logger.error("\(error.localizedDescription)")
                            parent.dismiss()
                        }
                    }
                } else if let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) {
                    let image = if parent.width != nil || parent.height != nil {
                        image.resized(to: size(relativeTo: image.size))
                    } else {
                        image
                    }
                    guard let data = image?.pngData() else { return parent.dismiss() }
                    parent.onCapture(data, .png)
                    parent.dismiss()
                }
            }
        }
    }
}

extension UIImagePickerController.CameraDevice: @retroactive AttributeDecodable {
    public init(from attribute: Attribute?, on element: ElementNode) throws {
        guard let value = attribute?.value
        else { throw AttributeDecodingError.missingAttribute(Self.self) }
        
        switch value {
        case "front":
            self = .front
        case "rear":
            self = .rear
        default:
            throw AttributeDecodingError.badValue(Self.self)
        }
    }
}

extension UIImagePickerController.CameraCaptureMode: @retroactive AttributeDecodable {
    public init(from attribute: Attribute?, on element: ElementNode) throws {
        guard let value = attribute?.value
        else { throw AttributeDecodingError.missingAttribute(Self.self) }
        
        switch value {
        case "photo":
            self = .photo
        case "video":
            self = .video
        default:
            throw AttributeDecodingError.badValue(Self.self)
        }
    }
}

extension UIImagePickerController.CameraFlashMode: @retroactive AttributeDecodable {
    public init(from attribute: Attribute?, on element: ElementNode) throws {
        guard let value = attribute?.value
        else { throw AttributeDecodingError.missingAttribute(Self.self) }
        
        switch value {
        case "auto":
            self = .auto
        case "off":
            self = .off
        case "on":
            self = .on
        default:
            throw AttributeDecodingError.badValue(Self.self)
        }
    }
}

extension UIImagePickerController.QualityType: @retroactive AttributeDecodable {
    public init(from attribute: Attribute?, on element: ElementNode) throws {
        guard let value = attribute?.value
        else { throw AttributeDecodingError.missingAttribute(Self.self) }
        
        switch value {
        case "type640x480":
            self = .type640x480
        case "typeIFrame960x540":
            self = .typeIFrame960x540
        case "typeIFrame1280x720":
            self = .typeIFrame1280x720
        case "typeHigh":
            self = .typeHigh
        case "typeMedium":
            self = .typeMedium
        case "typeLow":
            self = .typeLow
        default:
            throw AttributeDecodingError.badValue(Self.self)
        }
    }
}

fileprivate extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        self.draw(in: CGRect(origin: .zero, size: size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
