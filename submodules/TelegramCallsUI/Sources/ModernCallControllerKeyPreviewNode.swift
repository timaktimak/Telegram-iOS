import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import LegacyComponents
import WallpaperBackgroundNode
import AccountContext
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import DeviceAccess
import ContextUI

private let emojiFont = Font.regular(28.0)
private let textFont = Font.regular(15.0)

private final class OverlayNode: ASDisplayNode {
    private let backgroundNode: WallpaperBackgroundNode
    private var background: ModernCallBackground?
    
    init(context: AccountContext) {
        self.backgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        super.init()
        self.clipsToBounds = true
        self.isOpaque = true
        self.addSubnode(self.backgroundNode)
    }
    
    func update(size: CGSize) {
        self.backgroundNode.frame.size = size
        self.backgroundNode.updateLayout(size: size, transition: .immediate)
    }
    
    func update(shift: CGPoint) {
        self.backgroundNode.frame.origin = CGPoint(x: -shift.x, y: -shift.y)
    }
    
    func update(background: ModernCallBackground) {
        let gradient = TelegramWallpaper.Gradient(id: nil, colors: background.colors, settings: WallpaperSettings(blur: true))
        backgroundNode.update(wallpaper: .gradient(gradient))
        backgroundNode.updateIsLooping(false)
        backgroundNode.updateIsLooping(true)
    }
}

final class ModernCallControllerKeyPreviewNode: ASDisplayNode {
    private let titleTextNode: ASTextNode
    private let subtitleTextNode: ASTextNode
    private let okTextNode: ASTextNode
    
    private var blurView: UIVisualEffectView!
    private let overlay: OverlayNode
    
    private let separator: ASDisplayNode
    var dismiss: (() -> Void)?
    
    private var validLayout: CGSize?
    
    init(context: AccountContext) {
        self.titleTextNode = ASTextNode()
        self.titleTextNode.displaysAsynchronously = false
        self.titleTextNode.attributedText = NSAttributedString(string: "This call is end-to-end encrypted", font: Font.medium(16), textColor: UIColor.white)
        self.titleTextNode.textAlignment = .center
        
        self.subtitleTextNode = ASTextNode()
        self.subtitleTextNode.displaysAsynchronously = false
        self.subtitleTextNode.attributedText = NSAttributedString(string: "If the emoji on Emma's screen are the same, this call is 100% secure.", font: Font.regular(16), textColor: UIColor.white)
        self.subtitleTextNode.textAlignment = .center
        
        self.okTextNode = ASTextNode()
        self.okTextNode.displaysAsynchronously = false
        self.okTextNode.attributedText = NSAttributedString(string: "OK", font: Font.regular(20), textColor: UIColor.white)
        self.okTextNode.textAlignment = .center
        
        self.separator = ASDisplayNode()
        self.separator.backgroundColor = UIColor(rgb: 0x0, alpha: 0.4)
        
        self.overlay = OverlayNode(context: context)
        
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        
        super.init()
        self.displaysAsynchronously = false
        self.view.addSubview(self.blurView)
        self.addSubnode(self.separator)
        self.addSubnode(self.titleTextNode)
        self.addSubnode(self.subtitleTextNode)
        self.addSubnode(self.okTextNode)
        self.addSubnode(self.overlay)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.clipsToBounds = true
        self.layer.cornerRadius = 20
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        if let isDark = self.isDark {
            let effect = UIBlurEffect(style: isDark ? .dark : .light)
            self.blurView.effect = effect
            
            self.separator.alpha = isDark ? 1.0 : 0.0
            self.overlay.alpha = isDark ? 0.0 : 1.0
        }
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    
    private var isDark: Bool?
    
    func set(isDark: Bool, animated: Bool) {
        guard self.isDark != isDark else { return }
        self.isDark = isDark
        
        if self.isNodeLoaded {
            let block: () -> Void = {
                let effect = UIBlurEffect(style: isDark ? .dark : .light)
                self.blurView.effect = effect
                
                self.separator.alpha = isDark ? 1.0 : 0.0
                self.overlay.alpha = isDark ? 0.0 : 1.0
            }
            if animated {
                UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut) {
                    block()
                }
            } else {
                block()
            }
        }
    }
    
    func updateLayout(size: CGSize) {
        guard self.validLayout != size else { return }
        self.validLayout = size
        
        self.titleTextNode.frame = CGRect(x: 0, y: 78, width: size.width, height: 20)
        self.subtitleTextNode.frame = CGRect(x: 0, y: self.titleTextNode.frame.maxY + 10, width: size.width, height: 42)
        self.okTextNode.frame = CGRect(x: 0, y: size.height - 40, width: size.width, height: 25)
        
        let pixel = 1.0 / UIScreen.main.scale
        self.overlay.frame = CGRect(x: 0, y: size.height - 56.0 - pixel, width: size.width, height: pixel)
        self.separator.frame = CGRect(x: 0, y: size.height - 56.0 - pixel, width: size.width, height: pixel)
        
        self.blurView.frame = CGRect(origin: .zero, size: size)
    }
    
    func updateBackgroundSize(size: CGSize) {
        self.overlay.update(size: size)
    }
    
    func updateShift(point: CGPoint) {
        self.overlay.update(shift: CGPoint(x: point.x + self.overlay.frame.origin.x,
                                           y: point.y + self.overlay.frame.origin.y))
    }
    
    func update(background: ModernCallBackground) {
        self.overlay.update(background: background)
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismiss?()
        }
    }
}
