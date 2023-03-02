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
        self.notch = ActionlessShapeLayer()
        self.layer.addSublayer(self.notch)
        self.notch.fillColor = UIColor.white.withAlphaComponent(0.25).cgColor
//        self.notch.backgroundColor = UIColor.red.cgColor
        
        self.background = ActionlessShapeLayer()
        self.layer.addSublayer(self.background)
        self.background.fillColor = UIColor.white.withAlphaComponent(0.25).cgColor
        
    }
    
    override func layout() {
        super.layout()
        
        let notchSize = CGSize(width: 22, height: 6)
        self.notch.frame = CGRect(origin: CGPoint(x: self.bounds.width * 0.74, y: -notchSize.height), size: notchSize)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: notchSize.height))
        path.addCurve(to: CGPoint(x: notchSize.width / 2.0, y: 0.0),
                      controlPoint1: CGPoint(x: notchSize.width / 2.0 - notchSize.width * 0.6 / 2.0, y: notchSize.height),
                      controlPoint2: CGPoint(x: notchSize.width / 2.0 - notchSize.width * 0.15 / 2.0, y: 0.0))
        path.addCurve(to: CGPoint(x: notchSize.width, y: notchSize.height),
                      controlPoint1: CGPoint(x: notchSize.width / 2.0 + notchSize.width * 0.15 / 2.0, y: 0.0),
                      controlPoint2: CGPoint(x: notchSize.width / 2.0 + notchSize.width * 0.6 / 2.0, y: notchSize.height))
        path.close()
        self.notch.path = path.cgPath
        
        self.background.frame = self.bounds
        self.background.path = UIBezierPath(roundedRect: self.background.frame, cornerRadius: 10.0).cgPath
        
        self.icon.frame = CGRect(x: 16, y: 9, width: 9, height: 19)
        self.text.frame = self.bounds.inset(by: UIEdgeInsets(top: 9, left: 31, bottom: 9, right: 4))
        
    }
}
