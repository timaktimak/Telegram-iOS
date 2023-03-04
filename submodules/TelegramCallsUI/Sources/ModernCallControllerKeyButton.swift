import Foundation
import UIKit
import Display
import AsyncDisplayKit
import CallsEmoji

private let labelFont = Font.regular(22.0)
private let largeFont = Font.regular(33.0)
private let nodeSize = CGSize(width: 24.0, height: 24.0)
private let largeNodeSize = CGSize(width: 48.0, height: 48.0)

private class ModernEmojiNode: ASDisplayNode {
    var emoji: String = "" {
        didSet {
            self.small.attributedText = NSAttributedString(string: emoji, font: labelFont, textColor: .black)
            let _ = self.small.updateLayout(CGSize(width: 100.0, height: 100.0))
            self.large.attributedText = NSAttributedString(string: emoji, font: largeFont, textColor: .black)
            let _ = self.large.updateLayout(CGSize(width: 100.0, height: 100.0))
        }
    }
    
    let small: ImmediateTextNode
    let large: ImmediateTextNode
    
    override init() {
        self.small = ImmediateTextNode()
        self.small.textAlignment = .center
        self.small.verticalAlignment = .middle
        self.large = ImmediateTextNode()
        self.large.textAlignment = .center
        self.large.verticalAlignment = .middle
        super.init()
        self.addSubnode(self.small)
        self.addSubnode(self.large)
        self.large.alpha = 0.0
    }
    
    override func layout() {
        super.layout()
        self.small.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        self.large.bounds = CGRect(origin: CGPoint(), size: largeNodeSize)
        self.large.position = CGPoint(x: self.bounds.width / 2.0, y: self.bounds.height / 2.0)
    }
    
    func update(large: Bool, duration: Double) {
        if large {
            self.small.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
            self.large.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, removeOnCompletion: false)
        } else {
            self.small.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, removeOnCompletion: false)
            self.large.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false)
        }
    }
}

final class ModernCallControllerKeyButton: HighlightableButtonNode {
    private let nodes: [ModernEmojiNode]
    private var nodePositions: [CGFloat]
    
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
        self.nodes = (0 ..< 4).map { _ in ModernEmojiNode() }
        self.nodePositions = (0 ..< 4).map { _ in 0.0 }
       
        super.init(pointerStyle: nil)
        
        self.nodes.forEach({ self.addSubnode($0) })
    }
    
    func animateAppearance(duration: Double, timingFunction: CAMediaTimingFunction) {
        for (i, node) in self.nodes.enumerated() {
            let positionAnimation = CABasicAnimation(keyPath: "transform.translation.x")
            positionAnimation.byValue = CGFloat(self.nodes.count - i) * nodeSize.width
            positionAnimation.toValue = 0.0
            positionAnimation.duration = duration
            positionAnimation.timingFunction = timingFunction
            node.layer.add(positionAnimation, forKey: "positionAnimation")
            
            let opacityAnimation = CABasicAnimation(keyPath: "opacity")
            opacityAnimation.fromValue = 0.0
            opacityAnimation.toValue = 1.0
            opacityAnimation.duration = duration
            opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            node.layer.add(opacityAnimation, forKey: "opacityAnimation")
        }
        
//        let positionAnimation = CABasicAnimation(keyPath: "transform.translation.x")
//        positionAnimation.byValue = -20.0
//        positionAnimation.toValue = 0.0
//        positionAnimation.duration = duration
//        positionAnimation.timingFunction = timingFunction
//        self.layer.add(positionAnimation, forKey: "positionAnimation")
    }
    
    func animateSpread(duration: Double) {
        for node in self.nodes {
            node.update(large: true, duration: duration)
        }
        
        let spread = CABasicAnimation(keyPath: "transform.translation.x")
        spread.duration = duration
        spread.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        spread.fillMode = .forwards
        spread.isRemovedOnCompletion = false
        
        let by: [CGFloat] = [-42.0, -14.0, 14.0, 42.0]
        for (i, node) in self.nodes.enumerated() {
            spread.toValue = by[i]
            node.layer.add(spread, forKey: "spread")
        }
        
        let size = CABasicAnimation(keyPath: "bounds.size")
        size.duration = duration
        size.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        size.fillMode = .forwards
        size.isRemovedOnCompletion = false
        size.toValue = largeNodeSize
        for node in self.nodes {
            node.layer.add(size, forKey: "enlarge")
        }
        
        let centrify = CABasicAnimation(keyPath: "position")
        centrify.duration = duration
        centrify.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        centrify.fillMode = .forwards
        centrify.isRemovedOnCompletion = false
        centrify.toValue = CGPoint(x: 24.0, y: 24.0)
        for node in self.nodes {
            node.small.layer.add(centrify, forKey: "centrify")
            node.large.layer.add(centrify, forKey: "centrify")
        }
    }
    
    func animateShrink(duration: Double) {
        for node in self.nodes {
            node.update(large: false, duration: duration)
        }
        
        let shrink = CABasicAnimation(keyPath: "transform.translation.x")
        shrink.duration = duration
        shrink.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shrink.fillMode = .forwards
        shrink.isRemovedOnCompletion = false
        shrink.toValue = 0.0
        for node in self.nodes {
            node.layer.add(shrink, forKey: "shrink")
        }
        
        let size = CABasicAnimation(keyPath: "bounds.size")
        size.duration = duration
        size.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        size.fillMode = .forwards
        size.isRemovedOnCompletion = false
        size.toValue = nodeSize
        for node in self.nodes {
            node.layer.add(size, forKey: "minify")
        }
        
        let centrify = CABasicAnimation(keyPath: "position")
        centrify.duration = duration
        centrify.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        centrify.fillMode = .forwards
        centrify.isRemovedOnCompletion = false
        centrify.toValue = CGPoint(x: 12.0, y: 12.0)
        for node in self.nodes {
            node.small.layer.add(centrify, forKey: "centrifyBack")
            node.large.layer.add(centrify, forKey: "centrifyBack")
        }
    }
    
    override func measure(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 102.0, height: 26.0)
    }
    
    override func layout() {
        super.layout()
        
        var index = 0
        for node in self.nodes {
            node.frame = CGRect(origin: CGPoint(x: CGFloat(index) * (nodeSize.width + 2.0), y: (self.bounds.height - nodeSize.height) / 2.0), size: nodeSize)
            index += 1
        }
        self.nodePositions = self.nodes.map { $0.layer.position.x }
    }
}

