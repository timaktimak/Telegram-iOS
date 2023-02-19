import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramAudio
import AccountContext
import LocalizedPeerData
import PhotoResources
import CallsEmoji
import TooltipUI
import AlertUI
import PresentationDataUtils
import DeviceAccess
import ContextUI
import WallpaperBackgroundNode

private let connectingColors: [UInt32] = [0xAC65D4, 0x7261DA, 0x5295D6, 0x616AD5]
private let activeColors: [UInt32] = [0xBAC05D, 0x3C9C8F, 0x53A6DE, 0x398D6F]
private let weakNetworkColors: [UInt32] = [0xC94986, 0xFF7E46, 0xB84498, 0xF4992E]

public enum ModernCallBackground {
    case connecting, active, weakNetwork
    
    var colors: [UInt32] {
        switch self {
        case .connecting:
            return connectingColors
        case .active:
            return activeColors
        case .weakNetwork:
            return weakNetworkColors
        }
    }
}

public class ModernCallBackgroundNode: ASDisplayNode {
    
    private let backgroundNode: WallpaperBackgroundNode
    
    let context: AccountContext
    private var background: ModernCallBackground?
    private var validLayout: CGSize?
    
    public init(context: AccountContext) {
        self.backgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        self.context = context
        super.init()
        self.addSubnode(backgroundNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = size
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: .zero, size: size))
        self.backgroundNode.updateLayout(size: size, transition: transition)
        if isFirstLayout, let background = background {
            update(background: background, force: true)
        }
    }
    
    func update(background: ModernCallBackground, force: Bool = false) {
        if force || self.background != background {
            self.background = background
            
            let gradient = TelegramWallpaper.Gradient(id: nil, colors: background.colors, settings: WallpaperSettings(blur: true)) // TODO: timur
            backgroundNode.update(wallpaper: .gradient(gradient))
            //      if DeviceMetrics.performance.isGraphicallyCapable { // TODO: timur
            backgroundNode.updateIsLooping(false)
            backgroundNode.updateIsLooping(true)
        }
        
    }
}
