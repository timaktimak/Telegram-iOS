import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import LegacyComponents

private let emojiFont = Font.regular(28.0)
private let textFont = Font.regular(15.0)

final class ModernCallControllerKeyPreviewNode: ASDisplayNode {
    private let titleTextNode: ASTextNode
    private let subtitleTextNode: ASTextNode
    private let okTextNode: ASTextNode
    
    private var topBlur: UIVisualEffectView!
    private var botBlur: UIVisualEffectView!
    
    private let separator: ASDisplayNode
    private let dismiss: () -> Void
    
    private var validLayout: CGSize?
    
    init(title: String, subtitle: String, ok: String, dismiss: @escaping () -> Void) {
        self.titleTextNode = ASTextNode()
        self.titleTextNode.displaysAsynchronously = false
        self.titleTextNode.attributedText = NSAttributedString(string: title, font: Font.medium(16), textColor: UIColor.white)
        self.titleTextNode.textAlignment = .center
        
        self.subtitleTextNode = ASTextNode()
        self.subtitleTextNode.displaysAsynchronously = false
        self.subtitleTextNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(16), textColor: UIColor.white)
        self.subtitleTextNode.textAlignment = .center
        
        self.okTextNode = ASTextNode()
        self.okTextNode.displaysAsynchronously = false
        self.okTextNode.attributedText = NSAttributedString(string: ok, font: Font.regular(20), textColor: UIColor.white)
        self.okTextNode.textAlignment = .center
        
        self.separator = ASDisplayNode()
        self.separator.backgroundColor = UIColor(rgb: 0x0, alpha: 0.75)
        
        self.dismiss = dismiss
        
        super.init()
        self.displaysAsynchronously = false
        self.addSubnode(self.separator)
        self.addSubnode(self.titleTextNode)
        self.addSubnode(self.subtitleTextNode)
        self.addSubnode(self.okTextNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.clipsToBounds = true
        self.layer.cornerRadius = 20
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        self.topBlur = UIVisualEffectView()
        self.view.insertSubview(self.topBlur, at: 0)
        
        self.botBlur = UIVisualEffectView()
        self.view.insertSubview(self.botBlur, at: 1)
        
        if let isDark {
            let effect = UIBlurEffect(style: isDark ? .dark : .light)
            self.topBlur.effect = effect
            self.botBlur.effect = effect
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
                self.topBlur.effect = effect
                self.botBlur.effect = effect
            }
            if animated {
                UIView.animate(withDuration: 0.3) {
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
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismiss()
        }
    }
    
    override func layout() {
        super.layout()
        let pixel = 1.0 / UIScreen.main.scale
        self.separator.frame = CGRect(x: 0, y: self.bounds.height - 56.0 - pixel, width: self.bounds.width, height: pixel)
        
        self.topBlur.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height - 56.0 - pixel)
        self.botBlur.frame = CGRect(x: 0, y: self.bounds.height - 56.0, width: self.bounds.width, height: 56.0)
    }
}
