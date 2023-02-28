import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramAudio
import AccountContext
import LocalizedPeerData
import PhotoResources
import CallsEmoji
import TooltipUI
import AlertUI
import PresentationDataUtils
import DeviceAccess
import ContextUI
import SolidRoundedButtonNode
import ReplayKit

final class ModernCallPreviewableVideoNode: ViewControllerTracingNode, UIScrollViewDelegate {
//    private weak var controller: VoiceChatCameraPreviewController?
    private let sharedContext: SharedAccountContext
    private var presentationData: PresentationData
    
    private let cameraNode: PreviewVideoNode
    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let previewContainerNode: ASDisplayNode
    private let shimmerNode: ShimmerEffectForegroundNode
    private let doneButton: SolidRoundedButtonNode
    private var broadcastPickerView: UIView?
    private let cancelButton: HighlightableButtonNode
    
    private let placeholderTextNode: ImmediateTextNode
    private let placeholderIconNode: ASImageNode
    
    private var wheelNode: WheelControlNode
    private var selectedTabIndex: Int = 1
    private var containerLayout: (ContainerViewLayout, CGFloat)?

    private var applicationStateDisposable: Disposable?
    
    private let hapticFeedback = HapticFeedback()
    
    private let readyDisposable = MetaDisposable()
    
    var shareCamera: ((Bool) -> Void)?
    var switchCamera: (() -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(sharedContext: SharedAccountContext, cameraNode: PreviewVideoNode) {
        
        self.sharedContext = sharedContext
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
        self.cameraNode = cameraNode
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.clipsToBounds = true
        self.backgroundNode.cornerRadius = 16.0
        
        let backgroundColor = UIColor(rgb: 0x000000)
    
        self.contentBackgroundNode = ASDisplayNode()
        self.contentBackgroundNode.backgroundColor = backgroundColor
        
        let title =  self.presentationData.strings.VoiceChat_VideoPreviewTitle
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: UIColor(rgb: 0xffffff))
                
        self.doneButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: UIColor(rgb: 0xffffff), foregroundColor: UIColor(rgb: 0x4f5352)), font: .bold, height: 48.0, cornerRadius: 24.0, gloss: false)
        self.doneButton.title = self.presentationData.strings.VoiceChat_VideoPreviewContinue
        
        if #available(iOS 12.0, *) {
            let broadcastPickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 52.0))
            broadcastPickerView.alpha = 0.02
            broadcastPickerView.isHidden = true
            broadcastPickerView.preferredExtension = "\(self.sharedContext.applicationBindings.appBundleId).BroadcastUpload"
            broadcastPickerView.showsMicrophoneButton = false
            self.broadcastPickerView = broadcastPickerView
        }
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Common_Cancel, font: Font.regular(17.0), textColor: UIColor(rgb: 0xffffff)), for: [])
        
        self.previewContainerNode = ASDisplayNode()
        self.previewContainerNode.clipsToBounds = true
        self.previewContainerNode.cornerRadius = 11.0
        self.previewContainerNode.backgroundColor = UIColor(rgb: 0x2b2b2f)
        
        self.shimmerNode = ShimmerEffectForegroundNode(size: 200.0)
        self.previewContainerNode.addSubnode(self.shimmerNode)
                
        self.placeholderTextNode = ImmediateTextNode()
        self.placeholderTextNode.alpha = 0.0
        self.placeholderTextNode.maximumNumberOfLines = 3
        self.placeholderTextNode.textAlignment = .center
        
        self.placeholderIconNode = ASImageNode()
        self.placeholderIconNode.alpha = 0.0
        self.placeholderIconNode.contentMode = .scaleAspectFit
        self.placeholderIconNode.displaysAsynchronously = false
        
        self.wheelNode = WheelControlNode(items: [WheelControlNode.Item(title: UIDevice.current.model == "iPad" ? self.presentationData.strings.VoiceChat_VideoPreviewTabletScreen : self.presentationData.strings.VoiceChat_VideoPreviewPhoneScreen), WheelControlNode.Item(title: self.presentationData.strings.VoiceChat_VideoPreviewFrontCamera), WheelControlNode.Item(title: self.presentationData.strings.VoiceChat_VideoPreviewBackCamera)], selectedIndex: self.selectedTabIndex)
        
        super.init()
        
        self.backgroundColor = UIColor.red
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
                
        self.wrappingScrollNode.addSubnode(self.backgroundNode)
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        
        self.backgroundNode.addSubnode(self.contentBackgroundNode)
        self.contentContainerNode.addSubnode(self.previewContainerNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        self.doneButton.backgroundColor = UIColor.blue
        self.contentContainerNode.addSubnode(self.doneButton)
        if let broadcastPickerView = self.broadcastPickerView {
            self.contentContainerNode.view.addSubview(broadcastPickerView)
        }
        self.contentContainerNode.addSubnode(self.cancelButton)
                
        self.previewContainerNode.addSubnode(self.cameraNode)
        
        self.previewContainerNode.addSubnode(self.placeholderIconNode)
        self.previewContainerNode.addSubnode(self.placeholderTextNode)
        
        self.previewContainerNode.addSubnode(self.wheelNode)
        self.wheelNode.backgroundColor = UIColor.green

        self.wheelNode.selectedIndexChanged = { [weak self] index in
            if let strongSelf = self {
                if (index == 1 && strongSelf.selectedTabIndex == 2) || (index == 2 && strongSelf.selectedTabIndex == 1) {
                    strongSelf.switchCamera?()
                }
                if index == 0 && [1, 2].contains(strongSelf.selectedTabIndex) {
                    strongSelf.broadcastPickerView?.isHidden = false
                    strongSelf.cameraNode.updateIsBlurred(isBlurred: true, light: false, animated: true)
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                    transition.updateAlpha(node: strongSelf.placeholderTextNode, alpha: 1.0)
                    transition.updateAlpha(node: strongSelf.placeholderIconNode, alpha: 1.0)
                } else if [1, 2].contains(index) && strongSelf.selectedTabIndex == 0 {
                    strongSelf.broadcastPickerView?.isHidden = true
                    strongSelf.cameraNode.updateIsBlurred(isBlurred: false, light: false, animated: true)
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                    transition.updateAlpha(node: strongSelf.placeholderTextNode, alpha: 0.0)
                    transition.updateAlpha(node: strongSelf.placeholderIconNode, alpha: 0.0)
                }
                strongSelf.selectedTabIndex = index
            }
        }
        
        self.doneButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.shareCamera?(true)
            }
        }
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        
        self.readyDisposable.set(self.cameraNode.ready.start(next: { [weak self] ready in
            if let strongSelf = self, ready {
                Queue.mainQueue().after(0.07) {
                    strongSelf.shimmerNode.alpha = 0.0
                    strongSelf.shimmerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }))
    }
    
    deinit {
        self.readyDisposable.dispose()
        self.applicationStateDisposable?.dispose()
    }
       
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
    }
    
    override func didLoad() {
        super.didLoad()
        
        let leftSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.leftSwipeGesture))
        leftSwipeGestureRecognizer.direction = .left
        let rightSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.rightSwipeGesture))
        rightSwipeGestureRecognizer.direction = .right
        
        self.view.addGestureRecognizer(leftSwipeGestureRecognizer)
        self.view.addGestureRecognizer(rightSwipeGestureRecognizer)
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
    }
    
    @objc func leftSwipeGesture() {
        if self.selectedTabIndex < 2 {
            self.wheelNode.setSelectedIndex(self.selectedTabIndex + 1, animated: true)
            self.wheelNode.selectedIndexChanged(self.wheelNode.selectedIndex)
        }
    }
    
    @objc func rightSwipeGesture() {
        if self.selectedTabIndex > 0 {
            self.wheelNode.setSelectedIndex(self.selectedTabIndex - 1, animated: true)
            self.wheelNode.selectedIndexChanged(self.wheelNode.selectedIndex)
        }
    }
    
    @objc func cancelPressed() {
        self.cancel?()
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    func animateRadialMask(from fromRect: CGRect, to toRect: CGRect) {
        let maskLayer = CAShapeLayer()
        maskLayer.frame = fromRect
        
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(origin: CGPoint(), size: fromRect.size))
        maskLayer.path = path
        
        self.layer.mask = maskLayer
        
        let topLeft = CGPoint(x: 0.0, y: 0.0)
        let topRight = CGPoint(x: self.bounds.width, y: 0.0)
        let bottomLeft = CGPoint(x: 0.0, y: self.bounds.height)
        let bottomRight = CGPoint(x: self.bounds.width, y: self.bounds.height)
        
        func distance(_ v1: CGPoint, _ v2: CGPoint) -> CGFloat {
            let dx = v1.x - v2.x
            let dy = v1.y - v2.y
            return sqrt(dx * dx + dy * dy)
        }
        
        var maxRadius = distance(toRect.center, topLeft)
        maxRadius = max(maxRadius, distance(toRect.center, topRight))
        maxRadius = max(maxRadius, distance(toRect.center, bottomLeft))
        maxRadius = max(maxRadius, distance(toRect.center, bottomRight))
        maxRadius = ceil(maxRadius)
        
        let targetFrame = CGRect(origin: CGPoint(x: toRect.center.x - maxRadius, y: toRect.center.y - maxRadius), size: CGSize(width: maxRadius * 2.0, height: maxRadius * 2.0))
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 3, curve: .easeInOut)
        transition.updatePosition(layer: maskLayer, position: targetFrame.center)
        transition.updateTransformScale(layer: maskLayer, scale: maxRadius * 2.0 / fromRect.width, completion: { [weak self] _ in
            self?.layer.mask = nil
        })
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        let targetBounds = self.bounds
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: -offset)
        self.dimNode.position = CGPoint(x: dimPosition.x, y: dimPosition.y - offset)
        transition.animateView({
            self.bounds = targetBounds
            self.dimNode.position = dimPosition
        })

        self.applicationStateDisposable = (self.sharedContext.applicationBindings.applicationIsActive
        |> filter { !$0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { /*[weak self]*/ _ in
//            guard let strongSelf = self else {
//                return
//            }
            
            // TODO:
//            strongSelf.controller?.dismiss()
        })
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        var dimCompleted = false
        var offsetCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && offsetCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            offsetCompleted = true
            internalCompletion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) {
                return self.dimNode.view
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancel?()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        let isLandscape: Bool
        if layout.size.width > layout.size.height {
            isLandscape = true
        } else {
            isLandscape = false
        }
        let isTablet: Bool
        if case .regular = layout.metrics.widthClass {
            isTablet = true
        } else {
            isTablet = false
        }
        
        var insets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
    
        let contentSize: CGSize
        if isLandscape {
            if isTablet {
                contentSize = CGSize(width: 870.0, height: 690.0)
            } else {
                contentSize = CGSize(width: layout.size.width, height: layout.size.height)
            }
        } else {
            if isTablet {
                contentSize = CGSize(width: 600.0, height: 960.0)
            } else {
                contentSize = CGSize(width: layout.size.width, height: layout.size.height - insets.top - 8.0)
            }
        }
        
        let sideInset = floor((layout.size.width - contentSize.width) / 2.0)
        let contentFrame: CGRect
        if isTablet {
            contentFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((layout.size.height - contentSize.height) / 2.0)), size: contentSize)
        } else {
            contentFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentSize.height), size: contentSize)
        }
        var backgroundFrame = contentFrame
        if !isTablet {
            backgroundFrame.size.height += 2000.0
        }
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: contentFrame.width, height: .greatestFiniteMagnitude))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 20.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
                
        var previewSize: CGSize
        var previewFrame: CGRect
        let previewAspectRatio: CGFloat = 1.85
        if isLandscape {
            let previewHeight = contentFrame.height
            previewSize = CGSize(width: min(contentFrame.width - layout.safeInsets.left - layout.safeInsets.right, ceil(previewHeight * previewAspectRatio)), height: previewHeight)
            previewFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((contentFrame.width - previewSize.width) / 2.0), y: 0.0), size: previewSize)
        } else {
            previewSize = CGSize(width: contentFrame.width, height: min(contentFrame.height, ceil(contentFrame.width * previewAspectRatio)))
            previewFrame = CGRect(origin: CGPoint(), size: previewSize)
        }
//        previewFrame = bounds
        transition.updateFrame(node: self.previewContainerNode, frame: previewFrame)
        transition.updateFrame(node: self.shimmerNode, frame: CGRect(origin: CGPoint(), size: previewFrame.size))
        self.shimmerNode.update(foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.07))
        self.shimmerNode.updateAbsoluteRect(previewFrame, within: layout.size)
        
        let cancelButtonSize = self.cancelButton.measure(CGSize(width: (previewFrame.width - titleSize.width) / 2.0, height: .greatestFiniteMagnitude))
        let cancelButtonFrame = CGRect(origin: CGPoint(x: previewFrame.minX + 17.0, y: 20.0), size: cancelButtonSize)
        transition.updateFrame(node: self.cancelButton, frame: cancelButtonFrame)
        
        self.cameraNode.frame =  CGRect(origin: CGPoint(), size: previewSize)
        self.cameraNode.updateLayout(size: previewSize, layoutMode: isLandscape ? .fillHorizontal : .fillVertical, transition: .immediate)
      
        self.placeholderTextNode.attributedText = NSAttributedString(string: presentationData.strings.VoiceChat_VideoPreviewShareScreenInfo, font: Font.semibold(16.0), textColor: .white)
        self.placeholderIconNode.image = generateTintedImage(image: UIImage(bundleImageName: isTablet ? "Call/ScreenShareTablet" : "Call/ScreenSharePhone"), color: .white)
        
        let placeholderTextSize = self.placeholderTextNode.updateLayout(CGSize(width: previewSize.width - 80.0, height: 100.0))
        transition.updateFrame(node: self.placeholderTextNode, frame: CGRect(origin: CGPoint(x: floor((previewSize.width - placeholderTextSize.width) / 2.0), y: floorToScreenPixels(previewSize.height / 2.0) + 10.0), size: placeholderTextSize))
        if let imageSize = self.placeholderIconNode.image?.size {
            transition.updateFrame(node: self.placeholderIconNode, frame: CGRect(origin: CGPoint(x: floor((previewSize.width - imageSize.width) / 2.0), y: floorToScreenPixels(previewSize.height / 2.0) - imageSize.height - 8.0), size: imageSize))
        }

        let buttonInset: CGFloat = 16.0
        let buttonMaxWidth: CGFloat = 360.0
        
        let buttonWidth = min(buttonMaxWidth, contentFrame.width - buttonInset * 2.0)
        let doneButtonHeight = self.doneButton.updateLayout(width: buttonWidth, transition: transition)
        transition.updateFrame(node: self.doneButton, frame: CGRect(x: floorToScreenPixels((contentFrame.width - buttonWidth) / 2.0), y: previewFrame.maxY - doneButtonHeight - buttonInset, width: buttonWidth, height: doneButtonHeight))
        self.broadcastPickerView?.frame = self.doneButton.frame
        
        let wheelFrame = CGRect(origin: CGPoint(x: 16.0 + previewFrame.minX, y: previewFrame.maxY - doneButtonHeight - buttonInset - 36.0 - 20.0), size: CGSize(width: previewFrame.width - 32.0, height: 36.0))
        self.wheelNode.updateLayout(size: wheelFrame.size, transition: transition)
        transition.updateFrame(node: self.wheelNode, frame: wheelFrame)
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentFrame)
    }
}

private let textFont = Font.with(size: 14.0, design: .camera, weight: .regular)
private let selectedTextFont = Font.with(size: 14.0, design: .camera, weight: .semibold)

private class WheelControlNode: ASDisplayNode, UIGestureRecognizerDelegate {
    struct Item: Equatable {
        public let title: String
        
        public init(title: String) {
            self.title = title
        }
    }

    private let maskNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    private var itemNodes: [HighlightTrackingButtonNode]
    
    private var validLayout: CGSize?

    private var _items: [Item]
    private var _selectedIndex: Int = 0
    
    public var selectedIndex: Int {
        get {
            return self._selectedIndex
        }
        set {
            guard newValue != self._selectedIndex else {
                return
            }
            self._selectedIndex = newValue
            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public func setSelectedIndex(_ index: Int, animated: Bool) {
        guard index != self._selectedIndex else {
            return
        }
        self._selectedIndex = index
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    public var selectedIndexChanged: (Int) -> Void = { _ in }
        
    public init(items: [Item], selectedIndex: Int) {
        self._items = items
        self._selectedIndex = selectedIndex
        
        self.maskNode = ASDisplayNode()
        self.maskNode.setLayerBlock({
            let maskLayer = CAGradientLayer()
            maskLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
            maskLayer.locations = [0.0, 0.15, 0.85, 1.0]
            maskLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            maskLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
            return maskLayer
        })
        self.containerNode = ASDisplayNode()
        
        self.itemNodes = items.map { item in
            let itemNode = HighlightTrackingButtonNode()
            itemNode.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
            itemNode.titleNode.maximumNumberOfLines = 1
            itemNode.titleNode.truncationMode = .byTruncatingTail
            itemNode.accessibilityLabel = item.title
            itemNode.accessibilityTraits = [.button]
            itemNode.hitTestSlop = UIEdgeInsets(top: -10.0, left: -5.0, bottom: -10.0, right: -5.0)
            itemNode.setTitle(item.title.uppercased(), with: textFont, with: .white, for: .normal)
            itemNode.titleNode.shadowColor = UIColor.black.cgColor
            itemNode.titleNode.shadowOffset = CGSize()
            itemNode.titleNode.layer.shadowRadius = 2.0
            itemNode.titleNode.layer.shadowOpacity = 0.3
            itemNode.titleNode.layer.masksToBounds = false
            itemNode.titleNode.layer.shouldRasterize = true
            itemNode.titleNode.layer.rasterizationScale = UIScreen.main.scale
            return itemNode
        }
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.containerNode)
        
        self.itemNodes.forEach(self.containerNode.addSubnode(_:))
        self.setupButtons()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.layer.mask = self.maskNode.layer
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        transition.updateFrame(node: self.maskNode, frame: bounds)
        
        let spacing: CGFloat = 15.0
        if !self.itemNodes.isEmpty {
            var leftOffset: CGFloat = 0.0
            var selectedItemNode: ASDisplayNode?
            for i in 0 ..< self.itemNodes.count {
                let itemNode = self.itemNodes[i]
                let itemSize = itemNode.measure(size)
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: leftOffset, y: (size.height - itemSize.height) / 2.0), size: itemSize))
                
                leftOffset += itemSize.width + spacing
                
                let isSelected = self.selectedIndex == i
                if isSelected {
                    selectedItemNode = itemNode
                }
                if itemNode.isSelected != isSelected {
                    itemNode.isSelected = isSelected
                    let title = itemNode.attributedTitle(for: .normal)?.string ?? ""
                    itemNode.setTitle(title, with: isSelected ? selectedTextFont : textFont, with: isSelected ? UIColor(rgb: 0xffd60a) : .white, for: .normal)
                    if isSelected {
                        itemNode.accessibilityTraits.insert(.selected)
                    } else {
                        itemNode.accessibilityTraits.remove(.selected)
                    }
                }
            }
            
            let totalWidth = leftOffset - spacing
            if let selectedItemNode = selectedItemNode {
                let itemCenter = selectedItemNode.frame.center
                transition.updateFrame(node: self.containerNode, frame: CGRect(x: bounds.width / 2.0 - itemCenter.x, y: 0.0, width: totalWidth, height: bounds.height))
                
                for i in 0 ..< self.itemNodes.count {
                    let itemNode = self.itemNodes[i]
                    let convertedBounds = itemNode.view.convert(itemNode.bounds, to: self.view)
                    let position = convertedBounds.center
                    let offset = position.x - bounds.width / 2.0
                    let angle = abs(offset / bounds.width * 0.99)
                    let sign: CGFloat = offset > 0 ? 1.0 : -1.0
                    
                    var transform = CATransform3DMakeTranslation(-22.0 * angle * angle * sign, 0.0, 0.0)
                    transform = CATransform3DRotate(transform, angle, 0.0, sign, 0.0)
                    transition.animateView {
                        itemNode.transform = transform
                    }
                }
            }
        }
    }
    
    private func setupButtons() {
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
            itemNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
        }
    }
    
    @objc private func buttonPressed(_ button: HighlightTrackingButtonNode) {
        guard let index = self.itemNodes.firstIndex(of: button) else {
            return
        }
        
        self._selectedIndex = index
        self.selectedIndexChanged(index)
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .animated(duration: 0.2, curve: .slide))
        }
    }
}

final class ModernCallVideoNode: ASDisplayNode, PreviewVideoNode {
    private let videoTransformContainer: ASDisplayNode
    private let videoView: PresentationCallVideoView
    
    private var effectView: UIVisualEffectView?
    private let videoPausedNode: ImmediateTextNode
    
    private var isBlurred: Bool = false
    private var currentCornerRadius: CGFloat = 0.0
    
    private let isReadyUpdated: () -> Void
    private(set) var isReady: Bool = false
    private var isReadyTimer: SwiftSignalKit.Timer?
    
    private let readyPromise = ValuePromise(false)
    var ready: Signal<Bool, NoError> {
        return self.readyPromise.get()
    }
    
    private let isFlippedUpdated: (ModernCallVideoNode) -> Void
    
    private(set) var currentOrientation: PresentationCallVideoView.Orientation
    private(set) var currentAspect: CGFloat = 0.0
    
    private var previousVideoHeight: CGFloat?
    
    init(videoView: PresentationCallVideoView, disabledText: String?, assumeReadyAfterTimeout: Bool, isReadyUpdated: @escaping () -> Void, orientationUpdated: @escaping () -> Void, isFlippedUpdated: @escaping (ModernCallVideoNode) -> Void) {
        self.isReadyUpdated = isReadyUpdated
        self.isFlippedUpdated = isFlippedUpdated
        
        self.videoTransformContainer = ASDisplayNode()
        self.videoView = videoView
        videoView.view.clipsToBounds = true
        videoView.view.backgroundColor = .black
        
        self.currentOrientation = videoView.getOrientation()
        self.currentAspect = videoView.getAspect()
        
        self.videoPausedNode = ImmediateTextNode()
        self.videoPausedNode.alpha = 0.0
        self.videoPausedNode.maximumNumberOfLines = 3
        
        super.init()
        
        self.backgroundColor = UIColor.gray
//        self.backgroundColor = .black
        self.clipsToBounds = true
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
        
        self.videoTransformContainer.view.addSubview(self.videoView.view)
        self.addSubnode(self.videoTransformContainer)
        
        if let disabledText = disabledText {
            self.videoPausedNode.attributedText = NSAttributedString(string: disabledText, font: Font.regular(17.0), textColor: .white)
            self.addSubnode(self.videoPausedNode)
        }
        
        self.videoView.setOnFirstFrameReceived { [weak self] aspectRatio in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if !strongSelf.isReady {
                    strongSelf.isReady = true
                    strongSelf.readyPromise.set(true)
                    strongSelf.isReadyTimer?.invalidate()
                    strongSelf.isReadyUpdated()
                }
            }
        }
        
        self.videoView.setOnOrientationUpdated { [weak self] orientation, aspect in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.currentOrientation != orientation || strongSelf.currentAspect != aspect {
                    strongSelf.currentOrientation = orientation
                    strongSelf.currentAspect = aspect
                    orientationUpdated()
                }
            }
        }
        
        self.videoView.setOnIsMirroredUpdated { [weak self] _ in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isFlippedUpdated(strongSelf)
            }
        }
        
        if assumeReadyAfterTimeout {
            self.isReadyTimer = SwiftSignalKit.Timer(timeout: 3.0, repeat: false, completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if !strongSelf.isReady {
                    strongSelf.isReady = true
                    strongSelf.readyPromise.set(true)
                    strongSelf.isReadyUpdated()
                }
            }, queue: .mainQueue())
        }
        self.isReadyTimer?.start()
    }
    
    deinit {
        self.isReadyTimer?.invalidate()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
    }
    
    func animateRadialMask(from fromRect: CGRect, to toRect: CGRect) {
        let maskLayer = CAShapeLayer()
        maskLayer.frame = fromRect
        
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(origin: CGPoint(), size: fromRect.size))
        maskLayer.path = path
        
        self.layer.mask = maskLayer
        
        let topLeft = CGPoint(x: 0.0, y: 0.0)
        let topRight = CGPoint(x: self.bounds.width, y: 0.0)
        let bottomLeft = CGPoint(x: 0.0, y: self.bounds.height)
        let bottomRight = CGPoint(x: self.bounds.width, y: self.bounds.height)
        
        func distance(_ v1: CGPoint, _ v2: CGPoint) -> CGFloat {
            let dx = v1.x - v2.x
            let dy = v1.y - v2.y
            return sqrt(dx * dx + dy * dy)
        }
        
        var maxRadius = distance(toRect.center, topLeft)
        maxRadius = max(maxRadius, distance(toRect.center, topRight))
        maxRadius = max(maxRadius, distance(toRect.center, bottomLeft))
        maxRadius = max(maxRadius, distance(toRect.center, bottomRight))
        maxRadius = ceil(maxRadius)
        
        let targetFrame = CGRect(origin: CGPoint(x: toRect.center.x - maxRadius, y: toRect.center.y - maxRadius), size: CGSize(width: maxRadius * 2.0, height: maxRadius * 2.0))
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 3, curve: .easeInOut)
        transition.updatePosition(layer: maskLayer, position: targetFrame.center)
        transition.updateTransformScale(layer: maskLayer, scale: maxRadius * 2.0 / fromRect.width, completion: { [weak self] _ in
            self?.layer.mask = nil
        })
    }
    
    func updateLayout(size: CGSize, layoutMode: VideoNodeLayoutMode, transition: ContainedViewLayoutTransition) {
        self.updateLayout(size: size, cornerRadius: self.currentCornerRadius, isOutgoing: true, deviceOrientation: .portrait, isCompactLayout: false, transition: transition)
    }
    
    func updateLayout(size: CGSize, cornerRadius: CGFloat, isOutgoing: Bool, deviceOrientation: UIDeviceOrientation, isCompactLayout: Bool, transition: ContainedViewLayoutTransition) {
        self.currentCornerRadius = cornerRadius
        
        var rotationAngle: CGFloat
        if false && isOutgoing && isCompactLayout {
            rotationAngle = CGFloat.pi / 2.0
        } else {
            switch self.currentOrientation {
            case .rotation0:
                rotationAngle = 0.0
            case .rotation90:
                rotationAngle = CGFloat.pi / 2.0
            case .rotation180:
                rotationAngle = CGFloat.pi
            case .rotation270:
                rotationAngle = -CGFloat.pi / 2.0
            }
            
            var additionalAngle: CGFloat = 0.0
            switch deviceOrientation {
            case .portrait:
                additionalAngle = 0.0
            case .landscapeLeft:
                additionalAngle = CGFloat.pi / 2.0
            case .landscapeRight:
                additionalAngle = -CGFloat.pi / 2.0
            case .portraitUpsideDown:
                rotationAngle = CGFloat.pi
            default:
                additionalAngle = 0.0
            }
            rotationAngle += additionalAngle
            if abs(rotationAngle - CGFloat.pi * 3.0 / 2.0) < 0.01 {
                rotationAngle = -CGFloat.pi / 2.0
            }
            if abs(rotationAngle - (-CGFloat.pi)) < 0.01 {
                rotationAngle = -CGFloat.pi + 0.001
            }
        }
        
        let rotateFrame = abs(rotationAngle.remainder(dividingBy: CGFloat.pi)) > 1.0
        let fittingSize: CGSize
        if rotateFrame {
            fittingSize = CGSize(width: size.height, height: size.width)
        } else {
            fittingSize = size
        }
        
        let unboundVideoSize = CGSize(width: self.currentAspect * 10000.0, height: 10000.0)
        
        var fittedVideoSize = unboundVideoSize.fitted(fittingSize)
        if fittedVideoSize.width < fittingSize.width || fittedVideoSize.height < fittingSize.height {
            let isVideoPortrait = unboundVideoSize.width < unboundVideoSize.height
            let isFittingSizePortrait = fittingSize.width < fittingSize.height
            
            if isCompactLayout && isVideoPortrait == isFittingSizePortrait {
                fittedVideoSize = unboundVideoSize.aspectFilled(fittingSize)
            } else {
                let maxFittingEdgeDistance: CGFloat
                if isCompactLayout {
                    maxFittingEdgeDistance = 200.0
                } else {
                    maxFittingEdgeDistance = 400.0
                }
                if fittedVideoSize.width > fittingSize.width - maxFittingEdgeDistance && fittedVideoSize.height > fittingSize.height - maxFittingEdgeDistance {
                    fittedVideoSize = unboundVideoSize.aspectFilled(fittingSize)
                }
            }
        }
        
        let rotatedVideoHeight: CGFloat = max(fittedVideoSize.height, fittedVideoSize.width)
        
        let videoFrame: CGRect = CGRect(origin: CGPoint(), size: fittedVideoSize)
        
        let videoPausedSize = self.videoPausedNode.updateLayout(CGSize(width: size.width - 16.0, height: 100.0))
        transition.updateFrame(node: self.videoPausedNode, frame: CGRect(origin: CGPoint(x: floor((size.width - videoPausedSize.width) / 2.0), y: floor((size.height - videoPausedSize.height) / 2.0)), size: videoPausedSize))
        
        self.videoTransformContainer.bounds = CGRect(origin: CGPoint(), size: videoFrame.size)
        if transition.isAnimated && !videoFrame.height.isZero, let previousVideoHeight = self.previousVideoHeight, !previousVideoHeight.isZero {
            let scaleDifference = previousVideoHeight / rotatedVideoHeight
            if abs(scaleDifference - 1.0) > 0.001 {
                transition.animateTransformScale(node: self.videoTransformContainer, from: scaleDifference, additive: true)
            }
        }
        self.previousVideoHeight = rotatedVideoHeight
        transition.updatePosition(node: self.videoTransformContainer, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransformRotation(view: self.videoTransformContainer.view, angle: rotationAngle)
        
        let localVideoFrame = CGRect(origin: CGPoint(), size: videoFrame.size)
        self.videoView.view.bounds = localVideoFrame
        self.videoView.view.center = localVideoFrame.center
        // TODO: properly fix the issue
        // On iOS 13 and later metal layer transformation is broken if the layer does not require compositing
        self.videoView.view.alpha = 0.995
        
        if let effectView = self.effectView {
            transition.updateFrame(view: effectView, frame: localVideoFrame)
        }
        
        transition.updateCornerRadius(layer: self.layer, cornerRadius: self.currentCornerRadius)
    }
    
    func updateIsBlurred(isBlurred: Bool, light: Bool = false, animated: Bool = true) {
        if self.hasScheduledUnblur {
            self.hasScheduledUnblur = false
        }
        if self.isBlurred == isBlurred {
            return
        }
        self.isBlurred = isBlurred
        
        if isBlurred {
            if self.effectView == nil {
                let effectView = UIVisualEffectView()
                self.effectView = effectView
                effectView.frame = self.videoTransformContainer.bounds
                self.videoTransformContainer.view.addSubview(effectView)
            }
            if animated {
                UIView.animate(withDuration: 0.3, animations: {
                    self.videoPausedNode.alpha = 1.0
                    self.effectView?.effect = UIBlurEffect(style: light ? .light : .dark)
                })
            } else {
                self.effectView?.effect = UIBlurEffect(style: light ? .light : .dark)
            }
        } else if let effectView = self.effectView {
            self.effectView = nil
            UIView.animate(withDuration: 0.3, animations: {
                self.videoPausedNode.alpha = 0.0
                effectView.effect = nil
            }, completion: { [weak effectView] _ in
                effectView?.removeFromSuperview()
            })
        }
    }
    
    private var hasScheduledUnblur = false
    func flip(withBackground: Bool) {
        if withBackground {
            self.backgroundColor = .black
        }
        UIView.transition(with: withBackground ? self.videoTransformContainer.view : self.view, duration: 0.4, options: [.transitionFlipFromLeft, .curveEaseOut], animations: {
            UIView.performWithoutAnimation {
                self.updateIsBlurred(isBlurred: true, light: false, animated: false)
            }
        }) { finished in
            self.backgroundColor = nil
            self.hasScheduledUnblur = true
            Queue.mainQueue().after(0.5) {
                if self.hasScheduledUnblur {
                    self.updateIsBlurred(isBlurred: false)
                }
            }
        }
    }
}
