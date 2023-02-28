import Foundation
import UIKit
import Display
import AsyncDisplayKit
import CallsEmoji

private let labelFont = Font.regular(22.0)

private class ModernEmojiNode: ASDisplayNode {
    var emoji: String = "" {
        didSet {
            self.node.attributedText = NSAttributedString(string: emoji, font: labelFont, textColor: .black)
            let _ = self.node.updateLayout(CGSize(width: 100.0, height: 100.0))
        }
    }
    
    private let node: ImmediateTextNode
    
    override init() {
        self.node = ImmediateTextNode()
        super.init()
        self.addSubnode(self.node)
    }
    
    override func layout() {
        super.layout()
        self.node.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
    }
}

final class ModernCallControllerKeyButton: HighlightableButtonNode, CAAnimationDelegate {
    private let containerNode: ASDisplayNode
    private let nodes: [ModernEmojiNode]
    
    var key: String = "" {
        didSet {
            var index = 0
            for emoji in self.key {
                guard index < 4 else {
                    return
                }
                self.nodes[index].emoji = String(emoji)
                index += 1
            }
        }
    }
    
    init() {
        self.containerNode = ASDisplayNode()
        self.nodes = (0 ..< 4).map { _ in ModernEmojiNode() }
       
        super.init(pointerStyle: nil)
        
        self.addSubnode(self.containerNode)
        self.nodes.forEach({ self.containerNode.addSubnode($0) })
    }
    
    func animateAppearance() {
        for (i, node) in self.nodes.enumerated() {
            let positionAnimation = CABasicAnimation(keyPath: "position.x")
            let shift = CGFloat(self.nodes.count - i) * 29.0
//            let shift = CGFloat(i + 1) * 20.0
            positionAnimation.fromValue = node.layer.position.x - shift
            positionAnimation.duration = 3.0
            positionAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            node.layer.add(positionAnimation, forKey: "positionAnimation")
            
            let opacityAnimation = CABasicAnimation(keyPath: "opacity")
            opacityAnimation.fromValue = 0.0
            opacityAnimation.toValue = 1.0
            opacityAnimation.duration = 3.0
            opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            node.layer.add(opacityAnimation, forKey: "opacityAnimation")
        }
    }
    
    
    
    func animatedSpread(duration: Double) {
        let spread = CABasicAnimation(keyPath: "position.x")
        spread.duration = duration
        spread.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        spread.delegate = self
        
//        spread.fillMode = .forwards
//        spread.isRemovedOnCompletion = false
        
        let by: [CGFloat] = [-12.0, -4.0, 4.0, 12.0]
        for (i, node) in self.nodes.enumerated() {
            spread.toValue = (node.layer.presentation() ?? node.layer).position.x + by[i]
            spread.completion = { _ in
                node.layer.position.x = spread.toValue as! CGFloat
            }
            node.layer.add(spread, forKey: "spread\(i)")
//            node.layer.position.x = node.layer.position.x + by[i]
//            node.layer.removeAnimation(forKey: "shrink")
        }
    }
    
    func animatedShrink(duration: Double) {
        let shrink = CABasicAnimation(keyPath: "position.x")
        shrink.duration = duration
        shrink.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shrink.delegate = self
//        shrink.fillMode = .forwards
//        shrink.isRemovedOnCompletion = false
        
        let by: [CGFloat] = [-12.0, -4.0, 4.0, 12.0]
        for (i, node) in self.nodes.enumerated() {
            shrink.toValue = (node.layer.presentation() ?? node.layer).position.x - by[i]
            shrink.completion = { _ in
                node.layer.position.x = shrink.toValue as! CGFloat
            }
            node.layer.add(shrink, forKey: "shrink\(i)")
//            node.layer.position.x = node.layer.position.x - by[i]
//            node.layer.removeAnimation(forKey: "spread")
        }
        
//        shrink.byValue = 12.0
//        self.nodes[0].layer.add(shrink, forKey: "shrink")
//        shrink.byValue = 4.0
//        self.nodes[1].layer.add(shrink, forKey: "shrink")
//        shrink.byValue = -4.0
//        self.nodes[2].layer.add(shrink, forKey: "shrink")
//        shrink.byValue = -12.0
//        self.nodes[3].layer.add(shrink, forKey: "shrink")
    }
    
//    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
//        guard let anim = anim as? CABasicAnimation else { return }
//        if let node = self.nodes.first(where: { $0.layer.animation(forKey: "spread") == anim }) {
//            CATransaction.begin()
//            CATransaction.setDisableActions(true)
//            node.layer.position.x = anim.toValue as! CGFloat
//            CATransaction.commit()
//        }
//        if let node = self.nodes.first(where: { $0.layer.animation(forKey: "shrink") == anim }) {
//            CATransaction.begin()
//            CATransaction.setDisableActions(true)
//            node.layer.position.x = anim.toValue as! CGFloat
//            CATransaction.commit()
//        }
//    }
    
    override func measure(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 114.0, height: 26.0)
    }
    
    override func layout() {
        super.layout()
        
        self.containerNode.frame = self.bounds
        
        var index = 0
        let nodeSize = CGSize(width: 29.0, height: self.bounds.size.height)
        for node in self.nodes {
            node.frame = CGRect(origin: CGPoint(x: CGFloat(index) * nodeSize.width, y: 0.0), size: nodeSize)
            index += 1
        }
    }
}

