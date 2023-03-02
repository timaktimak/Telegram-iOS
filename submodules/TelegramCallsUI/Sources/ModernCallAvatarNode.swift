import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AvatarNode
//import MediaPlayer
import TelegramPresentationData

private let avatarFont = avatarPlaceholderFont(size: 52.0)

enum ModernCallAvatarMode {
    case pulsing, showingVolume, end
}

final class ModernCallAvatarNode: ASDisplayNode {
    
    let avatarNode: AvatarNode
    let voiceNode: ModernVoiceBlobNode
    
    var mode: ModernCallAvatarMode? {
        didSet {
            assert(Thread.isMainThread)
            guard self.mode != oldValue else { return }
            
            switch self.mode {
            case .pulsing:
                self.layer.removeAnimation(forKey: "pulsing")
                
                let animation = CABasicAnimation(keyPath: "transform.scale")
                animation.fromValue = 0.98
                animation.toValue = 1.06
                animation.duration = 0.9
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.autoreverses = true
                animation.isRemovedOnCompletion = false
                animation.repeatCount = Float.greatestFiniteMagnitude
                self.layer.add(animation, forKey: "pulsing")
                
                self.voiceNode.startAnimating()
            case .showingVolume:
                if oldValue == .pulsing {
                    let animationAvatar = CAKeyframeAnimation(keyPath: "transform.scale")
                    animationAvatar.values = [self.layer.presentation()?.value(forKeyPath: "transform.scale") as Any, 1.16, 0.96, 1]
                    animationAvatar.keyTimes = [0, 0.4, 0.8, 1]
                    animationAvatar.fillMode = .forwards
                    animationAvatar.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut)]
                    animationAvatar.calculationMode = .cubic // TODO: timur
                    animationAvatar.duration = 0.5
                    self.avatarNode.layer.add(animationAvatar, forKey: "transitionToConnected")
                    
                    let animationVoice = CAKeyframeAnimation(keyPath: "transform.scale")
                    animationVoice.values = [self.layer.presentation()?.value(forKeyPath: "transform.scale") as Any, 1.34, 0.96, 1]
                    animationVoice.keyTimes = [0, 0.4, 0.8, 1]
                    animationAvatar.calculationMode = .cubic // TODO: timur
                    animationVoice.fillMode = .forwards
                    animationVoice.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut)]
                    animationVoice.duration = 0.5
                    self.voiceNode.layer.add(animationVoice, forKey: "transitionToConnected")
                    
                    self.layer.removeAnimation(forKey: "pulsing")
                }
            case .end:
                let animation = CABasicAnimation(keyPath: "transform.scale")
                animation.toValue = 1.0
                animation.duration = 0.3
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                animation.isRemovedOnCompletion = false
                animation.fillMode = .forwards
                animation.completion = { _ in
                    self.layer.removeAnimation(forKey: "pulsing")
                }
                self.layer.add(animation, forKey: "end")
                
                self.voiceNode.stopAnimating()
            case nil:
                break
            }
        }
    }
    
    override init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.voiceNode = ModernVoiceBlobNode(
            maxLevel: 5,
            mediumBlobRange: (1.2, 1.4),
            bigBlobRange: (1.2, 1.4)
        )
        super.init()
        self.addSubnode(self.voiceNode)
        self.voiceNode.setColor(UIColor.white, mediumAlpha: 0.2, bigAlpha: 0.1)
        self.addSubnode(self.avatarNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.voiceNode.frame = CGRect(origin: CGPoint(x: 1, y: 1), size: CGSize(width: size.width - 2, height: size.height - 2))
        self.avatarNode.frame = CGRect(origin: .zero, size: size)
        self.avatarNode.updateSize(size: size)
    }
    
    // TODO: timur figure out how to get audio volume
}
