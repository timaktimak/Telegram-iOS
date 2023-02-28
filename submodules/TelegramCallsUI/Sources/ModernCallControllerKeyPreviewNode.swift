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
    
    private let topBackground: ASDisplayNode
    private let botBackground: ASDisplayNode
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
        
        self.topBackground = ASDisplayNode()
        self.topBackground.clipsToBounds = false
        self.botBackground = ASDisplayNode()
        self.botBackground.clipsToBounds = false
        self.separator = ASDisplayNode()
        
        self.dismiss = dismiss
        
        super.init()
        self.displaysAsynchronously = false
        self.addSubnode(self.topBackground)
        self.addSubnode(self.botBackground)
        self.addSubnode(self.separator)
        self.addSubnode(self.titleTextNode)
        self.addSubnode(self.subtitleTextNode)
        self.addSubnode(self.okTextNode)
    }
    
    func set(isDark: Bool) {
        self.topBackground.backgroundColor = isDark ? UIColor(rgb: 0x0, alpha: 0.5) : UIColor(rgb: 0xFFFFFF, alpha: 0.25)
        self.botBackground.backgroundColor = isDark ? UIColor(rgb: 0x0, alpha: 0.5) : UIColor(rgb: 0xFFFFFF, alpha: 0.25)
        self.separator.backgroundColor = UIColor(rgb: 0x0, alpha: 0.75)
        self.separator.isHidden = !isDark
    }
    
    func updateLayout(size: CGSize) {
        guard self.validLayout != size else { return }
        self.validLayout = size
        
        self.titleTextNode.frame = CGRect(x: 0, y: 78, width: size.width, height: 20)
        self.subtitleTextNode.frame = CGRect(x: 0, y: self.titleTextNode.frame.maxY + 10, width: size.width, height: 42)
        self.okTextNode.frame = CGRect(x: 0, y: size.height - 40, width: size.width, height: 25)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.topBackground.cornerRadius = 20
        self.topBackground.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        self.botBackground.cornerRadius = 20
        self.botBackground.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismiss()
        }
    }
    
    override func layout() {
        super.layout()
        let pixel = 1.0 / UIScreen.main.scale
        self.topBackground.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height - 56.0 - pixel)
        self.separator.frame = CGRect(x: 0, y: self.bounds.height - 56.0 - pixel, width: self.bounds.width, height: pixel)
        self.botBackground.frame = CGRect(x: 0, y: self.bounds.height - 56.0, width: self.bounds.width, height: 56.0)
    }
}
