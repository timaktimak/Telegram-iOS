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
    private var backgroundNodes: [ModernCallBackground: WallpaperBackgroundNode]
    private var background: ModernCallBackground?
    
    private var isAnimating = false
    private var presentationBackground: ModernCallBackground?
    
    init(context: AccountContext) {
        self.backgroundNodes = [:]
        for bg in ModernCallBackground.allCases {
            self.backgroundNodes[bg] = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
            self.backgroundNodes[bg]!.alpha = 0
        }
        super.init()
        for bg in ModernCallBackground.allCases {
            self.addSubnode(self.backgroundNodes[bg]!)
        }
        self.clipsToBounds = true
        self.isOpaque = true
    }
    
    private var lastSize: CGSize?
    func update(size: CGSize) {
        guard self.lastSize != size else { return }
        self.lastSize = size
        
        for bg in ModernCallBackground.allCases {
            self.backgroundNodes[bg]!.frame.size = size
            self.backgroundNodes[bg]!.updateLayout(size: size, transition: .immediate)
            
            let gradient = TelegramWallpaper.Gradient(id: nil, colors: bg.colors, settings: WallpaperSettings(blur: true))
            self.backgroundNodes[bg]!.update(wallpaper: .gradient(gradient))
            
            self.backgroundNodes[bg]!.updateIsLooping(true, duration: 0.4)
        }
    }
    
    func update(shift: CGPoint) {
        for bg in ModernCallBackground.allCases {
            self.backgroundNodes[bg]!.frame.origin = CGPoint(x: -shift.x, y: -shift.y)
        }
    }
    
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
