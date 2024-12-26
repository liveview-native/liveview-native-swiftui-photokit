//
//  PhotoPicker.swift
//  LiveViewNativePhotoKit
//
//  Created by Carson Katri on 10/24/24.
//

import LiveViewNative
import LiveViewNativeCore
import SwiftUI
import Photos
import PhotosUI
import OSLog

private let logger = Logger(subsystem: "LiveViewNativePhotoKit", category: "PhotosPicker")

@MainActor
@LiveElement
struct PhotosPicker<Root: RootRegistry>: View {
    @LiveElementIgnored
    @State
    private var selection: [PhotosPickerItem] = []
    
    @LiveElementIgnored
    @Environment(\.formModel) private var formModel
    
    @LiveAttribute("data-phx-upload-ref")
    var phxUploadRef: String?
    
    var name: String?
    
    var maxSelectionCount: Int?
    var selectionBehavior: PhotosPickerSelectionBehavior = .default
    var matching: PHPickerFilter?
    var preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic
    
    var body: some View {
        let label = UncheckedSendable(wrappedValue: $liveElement.children())
        PhotosUI.PhotosPicker(
            selection: $selection,
            maxSelectionCount: maxSelectionCount,
            selectionBehavior: selectionBehavior,
            matching: matching,
            preferredItemEncoding: preferredItemEncoding
        ) {
            label.wrappedValue
        }
        .onChange(of: selection) { (_: [PhotosPickerItem], selection: [PhotosPickerItem]) in
            guard !selection.isEmpty,
                  let phxUploadRef
            else { return }
            Task {
                do {
                    for photo in selection {
                        guard let data = try await photo.loadTransferable(type: Data.self)
                        else { continue }
                        try await formModel?.queueFileUpload(name: name ?? "photo", id: phxUploadRef, contents: data, fileType: .png, fileName: name ?? "photo", coordinator: $liveElement.context.coordinator)
                    }
                } catch {
                    logger.log(level: .error, "\(error.localizedDescription)")
                }
            }
            self.selection = []
        }
    }
}

@propertyWrapper
struct UncheckedSendable<T>: @unchecked Sendable {
    let wrappedValue: T
    
    init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}

extension PhotosPickerSelectionBehavior: @retroactive AttributeDecodable {
    public init(from attribute: Attribute?, on element: ElementNode) throws {
        guard let value = attribute?.value
        else { throw AttributeDecodingError.missingAttribute(Self.self) }
        switch value {
        case "default":
            self = .default
        case "ordered":
            self = .ordered
        case "continuous":
            self = .continuous
        case "continuousAndOrdered":
            self = .continuousAndOrdered
        default:
            throw AttributeDecodingError.badValue(Self.self)
        }
    }
}

extension PHPickerFilter: @retroactive AttributeDecodable, @retroactive Decodable {
    public init(from attribute: Attribute?, on element: ElementNode) throws {
        guard let value = attribute?.value
        else { throw AttributeDecodingError.missingAttribute(Self.self) }
        if let singleValue = try? JSONDecoder().decode(PHPickerFilter.self, from: Data(value.utf8)) {
            self = singleValue
        } else {
            self = .any(of: try JSONDecoder().decode([PHPickerFilter].self, from: Data(value.utf8)))
        }
    }
    
    public init(from decoder: any Decoder) throws {
        switch try decoder.singleValueContainer().decode(String.self) {
        case "images":
            self = .images
        case "videos":
            self = .videos
        case "livePhotos":
            self = .livePhotos
        case "depthEffectPhotos":
            self = .depthEffectPhotos
        case "bursts":
            self = .bursts
        case "panoramas":
            self = .panoramas
        case "screenshots":
            self = .screenshots
        case "screenRecordings":
            self = .screenRecordings
        case "slomoVideos":
            self = .slomoVideos
        case "timelapseVideos":
            self = .timelapseVideos
        case "cinematicVideos":
            self = .cinematicVideos
        case "spatialMedia":
            if #available(iOS 18.0, *) {
                self = .spatialMedia
            } else {
                self = .any(of: [])
            }
        case let `default`:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown PHPickerFilter '\(`default`)'"))
        }
    }
}

extension PhotosPickerItem.EncodingDisambiguationPolicy: @retroactive AttributeDecodable {
    public init(from attribute: Attribute?, on element: ElementNode) throws {
        guard let value = attribute?.value
        else { throw AttributeDecodingError.missingAttribute(Self.self) }
        switch value {
        case "automatic":
            self = .automatic
        case "current":
            self = .current
        case "compatible":
            self = .compatible
        default:
            throw AttributeDecodingError.badValue(Self.self)
        }
    }
}
