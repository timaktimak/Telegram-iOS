import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit

private let compactNameFont = Font.regular(28.0)
private let regularNameFont = Font.regular(36.0)

private let compactStatusFont = Font.regular(16.0)
private let regularStatusFont = Font.regular(18.0)

private final class ModernCallActivityNode: ASDisplayNode {
    
    let circles: [ASDisplayNode]
    
    override init() {
        circles = [ASDisplayNode(), ASDisplayNode(), ASDisplayNode()]
        super.init()
    }
    
    override func didLoad() {
        super.didLoad()
        for circle in circles {
            circle.backgroundColor = UIColor.white
            circle.clipsToBounds = true
            circle.cornerRadius = 2
            addSubnode(circle)
        }
    }
    
    override func layout() {
        super.layout()
        for (i, circle) in circles.enumerated() {
            circle.frame = CGRect(x: 1, y: self.bounds.height / 2 - 2, width: 4, height: 4)
            circle.frame.origin.x += CGFloat(i * 7)
        }
    }
}

enum ModernCallStatus: Equatable {
    case text(string: String, loading: Bool)
    case timer((String, Bool) -> String, Double)
    case callEnded(Double)
    
    var isCallEnded: Bool {
        switch self {
        case .text, .timer:
            return false
        case .callEnded:
            return true
        }
    }
    
    var isTextWithLoading: Bool {
        switch self {
        case .text(_, true):
            return true
        default:
            return false
        }
    }
    
    static func ==(lhs: ModernCallStatus, rhs: ModernCallStatus) -> Bool {
        switch lhs {
        case let .text(text, loading):
            if case .text(text, loading) = rhs {
                return true
            } else {
                return false
            }
        case let .timer(_, referenceTime):
            if case .timer(_, referenceTime) = rhs {
                return true
            } else {
                return false
            }
        case let .callEnded(referenceTime):
            if case .callEnded(referenceTime) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

final class ModernCallControllerStatusNode: ASDisplayNode {
    private let titleNode: TextNode
    private let statusContainerNode: ASDisplayNode
    private let statusNode: TextNode
    private let statusMeasureNode: TextNode
    private let receptionNode: ModernCallControllerReceptionNode
    private let callEndedNode: ASImageNode
    
    private let titleActivateAreaNode: AccessibilityAreaNode
    private let statusActivateAreaNode: AccessibilityAreaNode
    
    private let activityNode: ModernCallActivityNode
    
    
    // Call Ended меняет title а не статус
    
    var title: String = ""
    var subtitle: String = ""
    var status: ModernCallStatus? = nil {
        didSet {
            if self.status != oldValue {
                self.statusTimer?.invalidate()
                
                var animate = true
                if case .timer = oldValue, case .callEnded = self.status {
                    animate = false
                }
                if animate {
                    if let snapshotView = self.statusContainerNode.view.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = self.statusContainerNode.frame
                        self.view.insertSubview(snapshotView, belowSubview: self.statusContainerNode.view)
                        
                        let duration = 0.3
                        
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                        snapshotView.layer.animateScale(from: 1.0, to: 0.3, duration: duration, removeOnCompletion: false)
                        snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -snapshotView.frame.height / 2.0), duration: duration, delay: 0.0, removeOnCompletion: false, additive: true)
                        
                        self.statusContainerNode.layer.animateScale(from: 0.3, to: 1.0, duration: duration)
                        self.statusContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
                        self.statusContainerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: snapshotView.frame.height / 2.0), to: CGPoint(), duration: duration, delay: 0.0, additive: true)
                    }
                }
                                
                if case .timer = self.status {
                    self.statusTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        if let strongSelf = self, let validLayoutWidth = strongSelf.validLayoutWidth {
                            let _ = strongSelf.updateLayout(constrainedWidth: validLayoutWidth, transition: .immediate)
                        }
                    }, queue: Queue.mainQueue())
                    self.statusTimer?.start()
                } else {
                    if let validLayoutWidth = self.validLayoutWidth {
                        let _ = self.updateLayout(constrainedWidth: validLayoutWidth, transition: .immediate)
                    }
                }
            }
        }
    }
    var reception: Int32? {
        didSet {
            if self.reception != oldValue {
                if let reception = self.reception {
                    self.receptionNode.reception = reception
                    
                    if oldValue == nil {
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
                        transition.updateAlpha(node: self.receptionNode, alpha: 1.0)
                    }
                } else if self.reception == nil, oldValue != nil {
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .spring)
                    transition.updateAlpha(node: self.receptionNode, alpha: 0.0)
                }
                
                if (oldValue == nil) != (self.reception != nil) {
                    if let validLayoutWidth = self.validLayoutWidth {
                        let _ = self.updateLayout(constrainedWidth: validLayoutWidth, transition: .immediate)
                    }
                }
            }
        }
    }
    
    private var statusTimer: SwiftSignalKit.Timer?
    private var validLayoutWidth: CGFloat?
    
    private var renderedTitle: String?
    
    override init() {
        self.titleNode = TextNode()
        self.statusContainerNode = ASDisplayNode()
        self.statusNode = TextNode()
        self.statusNode.displaysAsynchronously = false
        self.statusMeasureNode = TextNode()
       
        self.receptionNode = ModernCallControllerReceptionNode()
        self.receptionNode.alpha = 0.0
        
        self.callEndedNode = ASImageNode()
        self.callEndedNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallEnded"), color: .white)
        self.callEndedNode.isHidden = true
        
        self.titleActivateAreaNode = AccessibilityAreaNode()
        self.titleActivateAreaNode.accessibilityTraits = .staticText
        
        self.statusActivateAreaNode = AccessibilityAreaNode()
        self.statusActivateAreaNode.accessibilityTraits = [.staticText, .updatesFrequently]
        
        self.activityNode = ModernCallActivityNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusContainerNode)
        self.statusContainerNode.addSubnode(self.statusNode)
        self.statusContainerNode.addSubnode(self.receptionNode)
        self.statusContainerNode.addSubnode(self.callEndedNode)
        self.statusContainerNode.addSubnode(self.activityNode)
        
        self.addSubnode(self.titleActivateAreaNode)
        self.addSubnode(self.statusActivateAreaNode)
    }
    
    deinit {
        self.statusTimer?.invalidate()
    }
    
    func setVisible(_ visible: Bool, transition: ContainedViewLayoutTransition) {
        let alpha: CGFloat = visible ? 1.0 : 0.0
        transition.updateAlpha(node: self.titleNode, alpha: alpha)
        transition.updateAlpha(node: self.statusContainerNode, alpha: alpha)
    }
    
    func updateLayout(constrainedWidth: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayoutWidth = constrainedWidth
        
        let nameFont: UIFont
        let statusFont: UIFont
        if constrainedWidth < 330.0 {
            nameFont = compactNameFont
            statusFont = compactStatusFont
        } else {
            nameFont = regularNameFont
            statusFont = regularStatusFont
        }
        
        var statusOffset: CGFloat = 0.0
        let statusText: String
        let statusMeasureText: String
        switch self.status {
        case nil:
            statusText = ""
            statusMeasureText = ""
        case let .text(text, loading):
            statusText = text
            statusMeasureText = text
            if loading {
                statusOffset -= 13.0
            }
        case let .callEnded(referenceTime):
            let duration = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
            let durationString: String
            let measureDurationString: String
            if duration > 60 * 60 {
                durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
                measureDurationString = "00:00:00"
            } else {
                durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
                measureDurationString = "00:00"
            }
            statusText = durationString
            statusMeasureText = measureDurationString
            statusOffset += 13.0
        case let .timer(format, referenceTime):
            let duration = Int32(CFAbsoluteTimeGetCurrent() - referenceTime)
            let durationString: String
            let measureDurationString: String
            if duration > 60 * 60 {
                durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
                measureDurationString = "00:00:00"
            } else {
                durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
                measureDurationString = "00:00"
            }
            statusText = format(durationString, false)
            statusMeasureText = format(measureDurationString, true)
            if self.reception != nil {
                statusOffset += 13.0
            }
        }
        
        var title = self.title
        if case .callEnded = self.status {
            title = "Call Ended"
        }
        if title != self.renderedTitle, !title.isEmpty, self.renderedTitle?.isEmpty == false {
            if let snapshotView = self.titleNode.view.snapshotView(afterScreenUpdates: false) {
                snapshotView.frame = self.titleNode.frame
                self.view.addSubview(snapshotView)
                
                let duration = 0.3
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                self.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
            }
        }
        self.renderedTitle = title
        
        let spacing: CGFloat = 1.0
        let (titleLayout, titleApply) = TextNode.asyncLayout(self.titleNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: nameFont, textColor: .white), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)))
        let (statusMeasureLayout, statusMeasureApply) = TextNode.asyncLayout(self.statusMeasureNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: statusMeasureText, font: statusFont, textColor: .white), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)))
        let (statusLayout, statusApply) = TextNode.asyncLayout(self.statusNode)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: statusText, font: statusFont, textColor: .white), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets(top: 2.0, left: 2.0, bottom: 2.0, right: 2.0)))
        
        let _ = titleApply()
        let _ = statusApply()
        let _ = statusMeasureApply()
        
        self.titleActivateAreaNode.accessibilityLabel = self.title
        self.statusActivateAreaNode.accessibilityLabel = statusText
        
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((constrainedWidth - titleLayout.size.width) / 2.0), y: 0.0), size: titleLayout.size)
        self.statusContainerNode.frame = CGRect(origin: CGPoint(x: 0.0, y: titleLayout.size.height + spacing), size: CGSize(width: constrainedWidth, height: statusLayout.size.height))
        self.statusNode.frame = CGRect(origin: CGPoint(x: floor((constrainedWidth - statusMeasureLayout.size.width) / 2.0) + statusOffset, y: 0.0), size: statusLayout.size)
        self.activityNode.frame = CGRect(x: self.statusNode.frame.maxX + 4, y: self.statusNode.frame.origin.y, width: 20, height: self.statusNode.frame.height)
        
        let iconSize = CGSize(width: 20.0, height: 20.0)
        
        self.receptionNode.frame = CGRect(origin: CGPoint(x: self.statusNode.frame.minX - receptionNodeSize.width - 6.0, y: self.statusNode.frame.midY - receptionNodeSize.height / 2.0), size: receptionNodeSize)
        self.callEndedNode.frame = CGRect(origin: CGPoint(x: self.statusNode.frame.minX - iconSize.width - 6.0, y: self.statusNode.frame.origin.y + self.statusNode.frame.height / 2.0 - 20.0 / 2.0), size: CGSize(width: 20, height: 20))
        
        let callEndedWasHidden = self.callEndedNode.isHidden
        self.callEndedNode.isHidden = self.status?.isCallEnded != true
        if callEndedWasHidden && !self.callEndedNode.isHidden {
            self.callEndedNode.layer.removeAllAnimations()
            self.callEndedNode.layer.animateAlpha(from: 0, to: 1, duration: 0.3)
            self.callEndedNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -8.0), to: CGPoint(), duration: 0.3, additive: true)
        }
        
        self.activityNode.isHidden = self.status?.isTextWithLoading != true
        for (i, circle) in self.activityNode.circles.enumerated() {
            if self.activityNode.isHidden {
                circle.layer.removeAllAnimations()
            } else if circle.layer.animation(forKey: "activity") == nil {
                let animation = CABasicAnimation(keyPath: "transform.scale")
                animation.fromValue = 0.5
                animation.toValue = 1
                animation.duration = 0.5
                animation.autoreverses = true
                animation.isRemovedOnCompletion = false
                animation.repeatCount = Float.greatestFiniteMagnitude
                animation.beginTime = CACurrentMediaTime() + CFTimeInterval(i) * 0.15
                circle.layer.add(animation, forKey: "activity")
            }
        }
        
//        self.logoNode.isHidden = !statusDisplayLogo
//        if let image = self.logoNode.image, let firstLineRect = statusMeasureLayout.linesRects().first {
//            let firstLineOffset = floor((statusMeasureLayout.size.width - firstLineRect.width) / 2.0)
//            self.logoNode.frame = CGRect(origin: CGPoint(x: self.statusNode.frame.minX + firstLineOffset - image.size.width - 7.0, y: 5.0), size: image.size)
//        }
        
        self.titleActivateAreaNode.frame = self.titleNode.frame
        self.statusActivateAreaNode.frame = self.statusContainerNode.frame
        
        return titleLayout.size.height + spacing + statusLayout.size.height
    }
}


private final class ModernCallControllerReceptionNodeParameters: NSObject {
    let reception: Int32
    
    init(reception: Int32) {
        self.reception = reception
    }
}

private let receptionNodeSize = CGSize(width: 20.0, height: 20.0)

private class ActionlessLayer: CALayer {
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
}

final class ModernCallControllerReceptionNode : ASDisplayNode {
    var reception: Int32 = 0 {
        didSet {
            animateIfNeeded()
        }
    }
    
    private var presentationReception: Int32 = 0
    private var isAnimating = false
    
    private let duration = 0.2
    
    private var bars: [ActionlessLayer] = []
    
    private func animateIfNeeded() {
        if isAnimating {
            return
        }
        if reception > presentationReception {
            animate(begin: presentationReception, end: reception, fill: true)
        }
        if reception < presentationReception {
            animate(begin: presentationReception - 1, end: reception - 1, fill: false)
        }
    }
    
    private func animate(begin: Int32, end: Int32, fill: Bool) {
        assert(begin != end)
        
        isAnimating = true
        presentationReception = reception
        
        let step = (end - begin) / abs(end - begin)
        var delay = 0.0
        var i = begin
        while i != end {
            if i + step == end {
                self.animate(bar: self.bars[Int(i)], delay: delay, filled: fill, completion: { [weak self] in
                    self?.isAnimating = false
                    self?.animateIfNeeded()
                })
            } else {
                self.animate(bar: self.bars[Int(i)], delay: delay, filled: fill, completion: { })
            }
            
            delay += duration / 2.0
            i += step
        }
    }
    
    private func animate(bar: ActionlessLayer, delay: Double, filled: Bool, completion: @escaping () -> Void) {
        let currentTime = CACurrentMediaTime()
        
        if let presentation = bar.presentation() {
            bar.opacity = presentation.opacity
        }
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.toValue = filled ? 1.0 : 0.5
        opacity.duration = duration / 2.0
        opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        opacity.beginTime = currentTime + delay + (filled ? 0.0 : duration / 2.0)
        opacity.isRemovedOnCompletion = false
        opacity.fillMode = .forwards
        bar.add(opacity, forKey: "barOpacity")
        
        let position = CABasicAnimation(keyPath: "position.y")
        position.byValue = -2.0 / UIScreen.main.scale
        position.duration = duration
        position.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        position.autoreverses = true
        position.beginTime = currentTime + delay
        bar.add(position, forKey: "barPosition")
        
        let height = CABasicAnimation(keyPath: "bounds.size.height")
        height.byValue = 4.0 / UIScreen.main.scale
        height.duration = duration
        height.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        height.autoreverses = true
        height.beginTime = currentTime + delay
        height.completion = { _ in
            completion()
        }
        bar.add(height, forKey: "barHeight")
    }
    
    override init() {
        super.init()
        
        self.isOpaque = false
        self.isLayerBacked = true
    }
    
    override func didLoad() {
        super.didLoad()
        for _ in 0..<4 {
            let bar = ActionlessLayer()
            bar.backgroundColor = UIColor.white.cgColor
            bar.opacity = 0.5
            bar.masksToBounds = false
            bar.cornerRadius = 1
            self.bars.append(bar)
            self.layer.addSublayer(bar)
        }
    }
    
    override func layout() {
        super.layout()
        var x = 1.0
        var h = 3.0
        for bar in self.bars {
            bar.frame = CGRect(x: x, y: self.bounds.height - 4.0 - h, width: 3.0, height: h)
            x += 5.0
            h += 3.0
        }
    }
}
