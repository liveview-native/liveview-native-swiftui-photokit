import LiveViewNative
import LiveViewNativeStylesheet
import SwiftUI

public extension Addons {
    @MainActor
    @Addon
    struct PhotoKit<Root: RootRegistry> {
        public enum TagName: String {
            case photosPicker = "PhotosPicker"
            case liveCameraPicker = "LiveCameraPicker"
        }
        
        @ViewBuilder
        public static func lookup(_ name: TagName, element: ElementNode) -> some View {
            switch name {
            case .photosPicker:
                PhotosPicker<Root>()
            case .liveCameraPicker:
                LiveCameraPicker<Root>()
            }
        }
    }
}
