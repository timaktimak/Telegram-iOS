import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AvatarNode
import TelegramPresentationData

private class ActionlessShapeLayer: CAShapeLayer {
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
}

final class ModernCallEmojiTooltip: ASControlNode {
    private var notch: ActionlessShapeLayer!
    private var background: ActionlessShapeLayer!
    private var blurView: UIVisualEffectView!
    private let icon: ASImageNode
    private let text: ASTextNode
    
    override init() {
        self.text = ASTextNode()
        self.text.displaysAsynchronously = true
        self.text.attributedText = NSAttributedString(string: "Encryption key of this call", font: Font.regular(15), textColor: UIColor.white)
        
        self.icon = ASImageNode()
        self.icon.contentMode = .center
        self.icon.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/PanelBadgeLock"), color: UIColor.white)
        
        super.init()
        self.isOpaque = false
        self.clipsToBounds = false
        self.addSubnode(self.text)
        self.addSubnode(self.icon)
    }
    
    override func didLoad() {
        super.didLoad()
        self.blurView = UIVisualEffectView()
        self.blurView.isUserInteractionEnabled = false
        self.view.insertSubview(self.blurView, at: 0)
    }
    
    private var isDark: Bool?
    
    func set(isDark: Bool, animated: Bool) {
        guard self.isDark != isDark else { return }
        self.isDark = isDark
        
        let block: () -> Void = {
            let effect = UIBlurEffect(style: isDark ? .dark : .light)
            self.blurView.effect = effect
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0.0, options: .curveEaseInOut) {
                block()
            }
        } else {
            block()
        }
    }
    
    override func layout() {
        super.layout()
        
        let notchSize = CGSize(width: 22, height: 6)
        
        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: notchSize.height, width: self.bounds.width, height: self.bounds.height), cornerRadius: 10.0)
        path.move(to: CGPoint(x: self.bounds.width * 0.74, y: notchSize.height))
        path.addCurve(to: CGPoint(x: path.currentPoint.x + notchSize.width / 2.0, y: 0.0),
                      controlPoint1: CGPoint(x: path.currentPoint.x + notchSize.width / 2.0 - notchSize.width * 0.6 / 2.0, y: notchSize.height),
                      controlPoint2: CGPoint(x: path.currentPoint.x + notchSize.width / 2.0 - notchSize.width * 0.15 / 2.0, y: 0.0))
        path.addCurve(to: CGPoint(x: path.currentPoint.x + notchSize.width / 2.0, y: notchSize.height),
                      controlPoint1: CGPoint(x: path.currentPoint.x + notchSize.width * 0.15 / 2.0, y: 0.0),
                      controlPoint2: CGPoint(x: path.currentPoint.x + notchSize.width * 0.6 / 2.0, y: notchSize.height))
        
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        
        self.blurView.frame = CGRect(x: 0, y: -notchSize.height, width: self.bounds.width, height: notchSize.height + self.bounds.height)
        self.blurView.layer.mask = mask
        
        self.icon.frame = CGRect(x: 16, y: 9, width: 9, height: 19)
        self.text.frame = self.bounds.inset(by: UIEdgeInsets(top: 9, left: 31, bottom: 9, right: 4))
    }
}
