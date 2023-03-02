import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData

private let labelFont = Font.regular(17.0)
private let smallLabelFont = Font.regular(15.0)

private enum ToastDescription: Equatable {
    enum Key: Hashable {
        case camera
        case microphone
        case mute
        case battery
    }
    
    case camera
    case microphone
    case mute
    case battery
    
    var key: Key {
        switch self {
        case .camera:
            return .camera
        case .microphone:
            return .microphone
        case .mute:
            return .mute
        case .battery:
            return .battery
        }
    }
}

struct ModernCallControllerToastContent: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let camera = ModernCallControllerToastContent(rawValue: 1 << 0)
    public static let microphone = ModernCallControllerToastContent(rawValue: 1 << 1)
    public static let mute = ModernCallControllerToastContent(rawValue: 1 << 2)
    public static let battery = ModernCallControllerToastContent(rawValue: 1 << 3)
}

final class ModernCallControllerToastContainerNode: ASDisplayNode {
    private var toastNodes: [ToastDescription.Key: ModernCallControllerToastItemNode] = [:]
    private var visibleToastNodes: [ModernCallControllerToastItemNode] = []
    
    private let strings: PresentationStrings
    
    private var validLayout: (CGFloat, CGFloat)?
    
    private var content: ModernCallControllerToastContent?
    private var appliedContent: ModernCallControllerToastContent?
    var title: String = ""
    
    init(strings: PresentationStrings) {
        self.strings = strings
        
        super.init()
    }
    
    private func updateToastsLayout(strings: PresentationStrings, content: ModernCallControllerToastContent, width: CGFloat, bottomInset: CGFloat, animated: Bool) -> CGFloat {
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.3, curve: .spring)
        } else {
            transition = .immediate
        }
        
        self.appliedContent = content
        
        let spacing: CGFloat = 18.0
    
        var height: CGFloat = 0.0
        var toasts: [ToastDescription] = []
        
//        if content.contains(.camera) {
//            toasts.append(.camera)
//        }
//        if content.contains(.microphone) {
//            toasts.append(.microphone)
//        }
        if content.contains(.mute) {
            toasts.append(.mute)
        }
//        if content.contains(.battery) {
//            toasts.append(.battery)
//        }
        
        var transitions: [ToastDescription.Key: (ContainedViewLayoutTransition, CGFloat, Bool)] = [:]
        var validKeys: [ToastDescription.Key] = []
        for toast in toasts {
            validKeys.append(toast.key)
            var toastTransition = transition
            var animateIn = false
            let toastNode: ModernCallControllerToastItemNode
            if let current = self.toastNodes[toast.key] {
                toastNode = current
            } else {
                toastNode = ModernCallControllerToastItemNode()
                self.toastNodes[toast.key] = toastNode
                self.addSubnode(toastNode)
                self.visibleToastNodes.append(toastNode)
                toastTransition = .immediate
                animateIn = transition.isAnimated
            }
            let toastContent: ModernCallControllerToastItemNode.Content
            switch toast {
                case .camera:
                    toastContent = ModernCallControllerToastItemNode.Content(
                        key: .camera,
                        image: .camera,
                        text: strings.Call_CameraOff(self.title).string
                    )
                case .microphone:
                    toastContent = ModernCallControllerToastItemNode.Content(
                        key: .microphone,
                        image: .microphone,
                        text: strings.Call_MicrophoneOff(self.title).string
                    )
                case .mute:
                    toastContent = ModernCallControllerToastItemNode.Content(
                        key: .mute,
                        image: .microphone,
                        text: "Your microphone is turned off"
                    )
                case .battery:
                    toastContent = ModernCallControllerToastItemNode.Content(
                        key: .battery,
                        image: .battery,
                        text: strings.Call_BatteryLow(self.title).string
                    )
            }
            let toastHeight = toastNode.update(width: width, content: toastContent, transition: toastTransition)
            transitions[toast.key] = (toastTransition, toastHeight, animateIn)
        }
        
        var removedKeys: [ToastDescription.Key] = []
        for (key, toastNode) in self.toastNodes {
            if !validKeys.contains(key) {
                removedKeys.append(key)
                self.visibleToastNodes.removeAll { $0 === toastNode }
                if animated {
                    toastNode.animateOut(transition: transition) { [weak toastNode] in
                        toastNode?.removeFromSupernode()
                    }
                } else {
                    toastNode.removeFromSupernode()
                }
            }
        }
        for key in removedKeys {
            self.toastNodes.removeValue(forKey: key)
        }
        
        for toastNode in self.visibleToastNodes {
            if let content = toastNode.currentContent, let (_, toastHeight, animateIn) = transitions[content.key] {
                ContainedViewLayoutTransition.immediate.updateFrame(node: toastNode, frame: CGRect(x: 0.0, y: height, width: width, height: toastHeight))
                height += toastHeight + spacing
                
                if animateIn {
                    toastNode.animateIn()
                }
            }
        }
        if height > 0.0 {
            height -= spacing
        }
        
        return height
    }
    
    func updateLayout(strings: PresentationStrings, content: ModernCallControllerToastContent?, constrainedWidth: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (constrainedWidth, bottomInset)
        
        self.content = content
        
        if let content = self.content {
            return self.updateToastsLayout(strings: strings, content: content, width: constrainedWidth, bottomInset: bottomInset, animated: transition.isAnimated)
        } else {
            return 0.0
        }
    }
    
    func set(isDark: Bool, animated: Bool) {
        self.toastNodes[.mute]?.set(isDark: isDark, animated: animated)
    }
}

private class ModernCallControllerToastItemNode: ASDisplayNode {
    struct Content: Equatable {
        enum Image {
            case camera
            case microphone
            case battery
        }
        
        var key: ToastDescription.Key
        var image: Image
        var text: String
        
        init(key: ToastDescription.Key, image: Image, text: String) {
            self.key = key
            self.image = image
            self.text = text
        }
    }
    
    let clipNode: ASDisplayNode
    let textNode: ImmediateTextNode
    var effectView: UIVisualEffectView!
    
    private var isDark: Bool?
    
    private(set) var currentContent: Content?
    private(set) var currentWidth: CGFloat?
    private(set) var currentHeight: CGFloat?
    
    override init() {
        self.clipNode = ASDisplayNode()
        self.clipNode.clipsToBounds = true
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 1
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.clipNode)
        self.clipNode.addSubnode(self.textNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.effectView = UIVisualEffectView()
        self.effectView.isUserInteractionEnabled = false
        self.clipNode.view.insertSubview(self.effectView, at: 0)
        
        if let isDark = self.isDark {
            self.effectView.effect = UIBlurEffect(style: isDark ? .dark : .light)
        }
        
        self.clipNode.layer.cornerRadius = 14.0
        if #available(iOS 13.0, *) {
            self.clipNode.layer.cornerCurve = .continuous
        }
    }
    
    func set(isDark: Bool, animated: Bool) {
        guard self.isDark != isDark else { return }
        self.isDark = isDark
        
        if self.isNodeLoaded {
            let block: () -> Void = {
                let effect = UIBlurEffect(style: isDark ? .dark : .light)
                self.effectView.effect = effect
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
    
    func update(width: CGFloat, content: Content, transition: ContainedViewLayoutTransition) -> CGFloat {
        let inset: CGFloat = 12.0
        let isNarrowScreen = width <= 320.0
        let font = isNarrowScreen ? smallLabelFont : labelFont
        let topInset: CGFloat = isNarrowScreen ? 5.0 : 4.0
                
        if self.currentContent != content || self.currentWidth != width {
            self.currentContent = content
            self.currentWidth = width
                  
            self.textNode.attributedText = NSAttributedString(string: content.text, font: font, textColor: .white)
            
            let textSize = self.textNode.updateLayout(CGSize(width: width - inset * 2.0, height: 100.0))
            
            let backgroundSize = CGSize(width: textSize.width + inset * 2.0, height: max(28.0, textSize.height + 4.0 * 2.0))
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((width - backgroundSize.width) / 2.0), y: 0.0), size: backgroundSize)
            
            transition.updateFrame(node: self.clipNode, frame: backgroundFrame)
            transition.updateFrame(view: self.effectView, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            
            self.textNode.frame = CGRect(origin: CGPoint(x: inset, y: topInset), size: textSize)
            
            self.currentHeight = backgroundSize.height
        }
        return self.currentHeight ?? 28.0
    }
    
    func animateIn() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4, damping: 105.0)
    }
    
    func animateOut(transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        transition.updateTransformScale(node: self, scale: 0.1)
        transition.updateAlpha(node: self, alpha: 0.0, completion: { _ in
            completion()
        })
    }
}
