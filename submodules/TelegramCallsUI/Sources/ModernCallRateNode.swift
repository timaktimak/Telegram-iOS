import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AvatarNode
import TelegramPresentationData
import AnimatedStickerNode
import TelegramAnimatedStickerNode

final class ModernCallRateNode: ASDisplayNode {
    private let background: ASDisplayNode
    private let title: ASTextNode
    private let subtitle: ASTextNode
    private var starContainerNode: ASDisplayNode
    private let starNodes: [ASButtonNode]
    private var rating: Int?
    
    private var recognizer: UIPanGestureRecognizer!
    
    private let apply: (Int) -> Void
    private let dismiss: () -> Void
    
    init(apply: @escaping (Int) -> Void, dismiss: @escaping () -> Void) {
        self.apply = apply
        self.dismiss = dismiss
        self.background = ASDisplayNode()
        self.background.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        self.background.cornerRadius = 20
        self.title = ASTextNode()
        self.title.attributedText = NSAttributedString(string: "Rate This Call", font: Font.medium(16), textColor: UIColor.white)
        self.title.textAlignment = .center
        self.subtitle = ASTextNode()
        self.subtitle.attributedText = NSAttributedString(string: "Please rate the quality of this call.", font: Font.regular(16), textColor: UIColor.white)
        self.subtitle.textAlignment = .center
        self.starContainerNode = ASDisplayNode()
        var starNodes: [ASButtonNode] = []
        for _ in 0 ..< 5 {
            starNodes.append(ASButtonNode())
        }
        self.starNodes = starNodes
        
        for node in self.starNodes {
            node.setImage(generateTintedImage(image: UIImage(bundleImageName: "Call/CallModernStar"), color: UIColor.white), for: [])
            let highlighted = generateTintedImage(image: UIImage(bundleImageName: "Call/CallModernStarSelected"), color: UIColor.white)
            node.setImage(highlighted, for: [.selected])
            node.setImage(highlighted, for: [.selected, .highlighted])
        }
        
        super.init()
        self.recognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        
        self.isUserInteractionEnabled = true
        self.addSubnode(self.background)
        self.addSubnode(self.title)
        self.addSubnode(self.subtitle)
        
        for node in self.starNodes {
            node.addTarget(self, action: #selector(self.starPressed(_:)), forControlEvents: .touchDown)
            node.addTarget(self, action: #selector(self.starReleased(_:)), forControlEvents: .touchUpInside)
            self.starContainerNode.addSubnode(node)
        }
        self.addSubnode(self.starContainerNode)
    }
    
    override func layout() {
        super.layout()
        self.background.frame = self.bounds
        self.title.frame = CGRect(x: 0.0, y: 20.0, width: self.bounds.width, height: 20.0)
        self.subtitle.frame = CGRect(x: 0.0, y: self.title.frame.maxY + 10.0, width: self.bounds.width, height: 20.0)
        
        let starSize = CGSize(width: 42.0, height: 38.0)
        let starsWidth = starSize.width * CGFloat(self.starNodes.count)
        self.starContainerNode.frame = CGRect(origin: CGPoint(x: (self.bounds.width - starsWidth) / 2.0, y: self.subtitle.frame.maxY + 13.0), size: CGSize(width: starsWidth, height: starSize.height))
        for i in 0 ..< self.starNodes.count {
            let node = self.starNodes[i]
            node.frame = CGRect(x: starSize.width * CGFloat(i), y: 0.0, width: starSize.width, height: starSize.height)
        }
    }
    
    
    
    override func didLoad() {
        super.didLoad()
        
        self.starContainerNode.view.addGestureRecognizer(recognizer)
    }
    
    @objc func panGesture(_ gestureRecognizer: UIPanGestureRecognizer) {
        let location = gestureRecognizer.location(in: self.starContainerNode.view)
        var selectedNode: ASButtonNode?
        for node in self.starNodes {
            if node.frame.contains(location) {
                selectedNode = node
                break
            }
        }
        if let selectedNode = selectedNode {
            switch gestureRecognizer.state {
                case .began, .changed:
                    self.starPressed(selectedNode)
                case .ended:
                    self.starReleased(selectedNode)
                case .cancelled:
                    self.resetStars()
                default:
                    break
            }
        } else {
            self.resetStars()
        }
    }
    
    private func resetStars() {
        for i in 0 ..< self.starNodes.count {
            let node = self.starNodes[i]
            node.isSelected = false
        }
    }
    
    @objc func starPressed(_ sender: ASButtonNode) {
        if let index = self.starNodes.firstIndex(of: sender) {
            self.rating = index + 1
            for i in 0 ..< self.starNodes.count {
                let node = self.starNodes[i]
                node.isSelected = i <= index
            }
        }
    }
    
    @objc func starReleased(_ sender: ASButtonNode) {
        if let index = self.starNodes.firstIndex(of: sender) {
            self.rating = index + 1
            let animation = CAKeyframeAnimation(keyPath: "transform.scale")
            animation.values = [1, 1.16, 1]
            animation.keyTimes = [0, 0.5, 1]
            animation.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut), CAMediaTimingFunction(name: .easeInEaseOut)]
            animation.duration = 0.16
            animation.isRemovedOnCompletion = true
            
            var lastSelected: ASDisplayNode?
            for i in 0 ..< self.starNodes.count {
                let node = self.starNodes[i]
                node.isSelected = i <= index
                if node.isSelected {
                    lastSelected = node
                    node.layer.add(animation, forKey: nil)
                }
            }
            
            if let rating = self.rating, let lastSelected = lastSelected {
                let size = CGSize(width: 100, height: 100)
                let node = DefaultAnimatedStickerNodeImpl()
                node.setup(source: AnimatedStickerNodeLocalFileSource(name: "ModernCallStars"), width: Int(size.width), height: Int(size.height), mode: .direct(cachePathPrefix: nil))
                node.frame = CGRect(origin: .zero, size: size)
                node.position = lastSelected.position
                self.starContainerNode.addSubnode(node)
                
                node.completed = { [weak self] x in
                    self?.dismiss()
                }
                node.playOnce()
                
                self.apply(rating)
                self.isUserInteractionEnabled = false
            }
        }
    }
    
}
