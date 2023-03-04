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

public enum ModernCallBackground: Int, CaseIterable {
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
    
    private var backgroundNodes: [ModernCallBackground: WallpaperBackgroundNode]
    
    let context: AccountContext
    
    public init(context: AccountContext) {
        self.backgroundNodes = [:]
        for bg in ModernCallBackground.allCases {
            self.backgroundNodes[bg] = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
            self.backgroundNodes[bg]!.alpha = 0
        }
        self.context = context
        super.init()
        for bg in ModernCallBackground.allCases {
            self.addSubnode(self.backgroundNodes[bg]!)
        }
    }
    
    private var lastSize: CGSize?
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        guard self.lastSize != size else { return }
        self.lastSize = size
        
        for bg in ModernCallBackground.allCases {
            transition.updateFrame(node: self.backgroundNodes[bg]!, frame: CGRect(origin: .zero, size: size))
            self.backgroundNodes[bg]!.updateLayout(size: size, transition: transition)
            
            let gradient = TelegramWallpaper.Gradient(id: nil, colors: bg.colors, settings: WallpaperSettings(blur: true))
            self.backgroundNodes[bg]!.update(wallpaper: .gradient(gradient))
            
            self.backgroundNodes[bg]!.updateIsLooping(true, duration: 0.4)
        }
    }
    
    private var isAnimating = false
    private var background: ModernCallBackground?
    private var presentationBackground: ModernCallBackground?
    
    func update(background: ModernCallBackground) {
        self.background = background
        animateIfNeeded()
    }
    
    private let duration = 0.4
    private func animateIfNeeded() {
        guard !isAnimating, let new = self.background, new != self.presentationBackground else { return }
        
        let old = self.presentationBackground
        self.presentationBackground = new
        
        guard let actualOld = old else {
            self.backgroundNodes[new]!.alpha = 1
            return
        }
        
        isAnimating = true
                
        self.backgroundNodes[actualOld]!.layer.zPosition = 0
        self.backgroundNodes[new]!.layer.zPosition = 1
        
        self.backgroundNodes[new]!.alpha = 1
        self.backgroundNodes[new]!.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration) { _ in
            self.isAnimating = false
            self.animateIfNeeded()
        }
    }
}
