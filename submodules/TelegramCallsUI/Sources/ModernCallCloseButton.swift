import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AvatarNode
import TelegramPresentationData

private func drawClose(context: CGContext, size: CGSize, clear: Bool, fillColor: UIColor) {
    context.setFillColor(fillColor.cgColor)
    context.fill([CGRect(origin: .zero, size: size)])
    if clear {
        context.setBlendMode(.clear)
    }
    let textSize = CGSize(width: 45, height: 21)
    let attributedString = NSAttributedString(string: "Close", font: Font.semibold(17), textColor: UIColor.white)
    attributedString.draw(in: CGRect(origin: CGPoint(x: (size.width - textSize.width) / 2, y: (size.height - textSize.height) / 2), size: textSize))
}

private final class CloseImageLayer: ActionlessLayer {
    
    static let size = CGSize(width: 48, height: 22)
    
    override init() {
        super.init()
        
        UIGraphicsBeginImageContextWithOptions(Self.size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            fatalError()
        }
        drawClose(context: context, size: Self.size, clear: true, fillColor: UIColor.white)
        let image = context.makeImage()!
        self.contents = image
    }
    
    func hideAnimated(duration: Double, beginTime: Double) {
        let positionAnimation = CABasicAnimation(keyPath: "position.x")
        positionAnimation.toValue = self.frame.maxX
        positionAnimation.duration = duration
        positionAnimation.beginTime = beginTime
        positionAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        positionAnimation.fillMode = .forwards
        positionAnimation.isRemovedOnCompletion = false
        self.add(positionAnimation, forKey: "positionAnimation")
        
        let boundsAnimation = CABasicAnimation(keyPath: "bounds")
        boundsAnimation.toValue = CGRect(origin: .zero, size: CGSize(width: 0, height: self.bounds.height))
        boundsAnimation.duration = duration
        boundsAnimation.beginTime = beginTime
        boundsAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        boundsAnimation.fillMode = .forwards
        boundsAnimation.isRemovedOnCompletion = false
        self.add(boundsAnimation, forKey: "boundsAnimation")
        
        let contentsAnimation = CABasicAnimation(keyPath: "contentsRect")
        contentsAnimation.toValue = CGRect(x: 1.0, y: 0.0, width: 0.0, height: 1.0)
        contentsAnimation.duration = duration
        contentsAnimation.beginTime = beginTime
        contentsAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        contentsAnimation.fillMode = .forwards
        self.add(contentsAnimation, forKey: "contentsAnimation")
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

private final class CloseImageLayerBackground: ActionlessLayer {
    
    static let size = CGSize(width: 48, height: 22)
    
    override init() {
        super.init()
        
        UIGraphicsBeginImageContextWithOptions(Self.size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            fatalError()
        }
        drawClose(context: context, size: Self.size, clear: false, fillColor: UIColor.white.withAlphaComponent(0.25))
        let image = context.makeImage()!
        self.contents = image
    }
    
    func showAnimated(duration: Double, beginTime: Double) {
        let positionAnimation = CABasicAnimation(keyPath: "position.x")
        positionAnimation.toValue = self.frame.maxX + Self.size.width / 2.0
        positionAnimation.duration = duration
        positionAnimation.beginTime = beginTime
        positionAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        positionAnimation.fillMode = .forwards
        positionAnimation.isRemovedOnCompletion = false
        self.add(positionAnimation, forKey: "positionAnimation")
        
        let boundsAnimation = CABasicAnimation(keyPath: "bounds")
        boundsAnimation.toValue = CGRect(origin: .zero, size: CGSize(width: Self.size.width, height: self.bounds.height))
        boundsAnimation.duration = duration
        boundsAnimation.beginTime = beginTime
        boundsAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        boundsAnimation.fillMode = .forwards
        boundsAnimation.isRemovedOnCompletion = false
        self.add(boundsAnimation, forKey: "boundsAnimation")
        
        let contentsAnimation = CABasicAnimation(keyPath: "contentsRect")
        contentsAnimation.fromValue = CGRect(x: 0.0, y: 0.0, width: 0.0, height: 1.0)
        contentsAnimation.toValue = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        contentsAnimation.duration = duration
        contentsAnimation.beginTime = beginTime
        contentsAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        contentsAnimation.fillMode = .forwards
        self.add(contentsAnimation, forKey: "contentsAnimation")
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

private enum AngleType: CaseIterable {
    case topLeft, bottomLeft, topRight, bottomRight
}

private class ActionlessLayer: CALayer {
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
}

private class ActionlessShapeLayer: CAShapeLayer {
    override func action(forKey event: String) -> CAAction? {
        return nil
    }
}

private final class Angle: ActionlessShapeLayer {
    var type: AngleType = .topLeft
    
    init(type: AngleType) {
        super.init()
        self.type = type
        self.fillColor = UIColor.white.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        let w = self.bounds.width
        let h = self.bounds.height
        let start: CGPoint = {
            switch type {
            case .topLeft: return CGPoint(x: 0.0, y: h)
            case .bottomLeft: return CGPoint(x: w, y: h)
            case .topRight: return CGPoint(x: 0.0, y: 0.0)
            case .bottomRight: return CGPoint(x: w, y: 0.0)
            }
        }()
        let center: CGPoint = {
            switch type {
            case .topLeft: return CGPoint(x: w, y: h)
            case .bottomLeft: return CGPoint(x: w, y: 0.0)
            case .topRight: return CGPoint(x: 0.0, y: h)
            case .bottomRight: return CGPoint(x: 0.0, y: 0.0)
            }
        }()
        let startAngle: CGFloat = {
            switch type {
            case .topLeft: return .pi
            case .bottomLeft: return .pi / 2.0
            case .topRight: return .pi * 3.0 / 2.0
            case .bottomRight: return 0
            }
        }()
        let path = UIBezierPath()
        path.move(to: start)
        path.addArc(withCenter: center, radius: w, startAngle: startAngle, endAngle: startAngle + .pi / 2, clockwise: true)
        path.addLine(to: center)
        path.close()
        self.path = path.cgPath
    }
}

private final class Stripe: ActionlessShapeLayer {
    
    var isTop: Bool
    
    init(isTop: Bool) {
        self.isTop = isTop
        super.init()
        self.fillColor = UIColor.white.withAlphaComponent(0.25).cgColor
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSublayers() {
        super.layoutSublayers()
        let radius = self.bounds.height
        let path = UIBezierPath()
        if self.isTop {
            path.move(to: CGPoint(x: 0, y: self.bounds.height))
            path.addArc(withCenter: CGPoint(x: radius, y: radius), radius: radius, startAngle: .pi, endAngle: .pi * 3.0 / 2.0, clockwise: true)
            path.addLine(to: CGPoint(x: self.bounds.width - radius, y: 0))
            path.addArc(withCenter: CGPoint(x: self.bounds.width - radius, y: radius), radius: radius, startAngle: .pi * 3.0 / 2.0, endAngle: .pi * 2.0, clockwise: true)
        } else {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addArc(withCenter: CGPoint(x: radius, y: 0), radius: radius, startAngle: .pi, endAngle: .pi / 2.0, clockwise: false)
            path.addLine(to: CGPoint(x: self.bounds.width - radius, y: radius))
            path.addArc(withCenter: CGPoint(x: self.bounds.width - radius, y: 0), radius: radius, startAngle: .pi / 2.0, endAngle: 0, clockwise: false)
        }
        path.close()
        self.path = path.cgPath
    }
}

final class ModernCallCloseButton: ASDisplayNode {
    
    private var center: CloseImageLayer!
    
    private var centerBackground: CloseImageLayerBackground!
    
    private var topBackground: Stripe!
    private var botBackground: Stripe!
    
    private var leftBackground: ActionlessLayer!
    private var rightBackground: ActionlessLayer!
    
    private var topAngle: Angle!
    private var botAngle: Angle!
    private var topRightAngle: Angle!
    private var botRightAngle: Angle!
    
    private var top: ActionlessLayer!
    private var bottom: ActionlessLayer!
    private var left: ActionlessLayer!
    private var right: ActionlessLayer!
    
    private var topAngExtension: ActionlessLayer!
    private var botAngExtension: ActionlessLayer!
    
    private let bigRadius = CGFloat(14)
    private let smallRadius = CGFloat(10)
    
    override init() {
        super.init()

        Queue.mainQueue().after(2) {
            self.startAnimating()
        }
    }
    
    func startAnimating() {
        
        let duration = 8.0
        let currentTime = CACurrentMediaTime()
        
        let angleSlide = CABasicAnimation(keyPath: "position")
        angleSlide.byValue = CGPoint(x: self.bounds.width - 2.0 * bigRadius, y: 0)
        angleSlide.duration = duration
        angleSlide.timingFunction = CAMediaTimingFunction(name: .linear)
        angleSlide.fillMode = .forwards
        angleSlide.isRemovedOnCompletion = false
        self.topAngle.add(angleSlide, forKey: "angleSlide")
        self.botAngle.add(angleSlide, forKey: "angleSlide")
        
        let collapse = CABasicAnimation(keyPath: "bounds.size.width")
        collapse.toValue = 0.0
        collapse.duration = duration
        collapse.timingFunction = CAMediaTimingFunction(name: .linear)
        collapse.fillMode = .forwards
        collapse.isRemovedOnCompletion = false
        self.top.add(collapse, forKey: "collapse")
        self.bottom.add(collapse, forKey: "collapse")
        
        let shift = CABasicAnimation(keyPath: "position.x")
        shift.toValue = self.bounds.width - bigRadius
        shift.duration = duration
        shift.timingFunction = CAMediaTimingFunction(name: .linear)
        shift.fillMode = .forwards
        shift.isRemovedOnCompletion = false
        self.top.add(shift, forKey: "shift")
        self.bottom.add(shift, forKey: "shift")
        
        let leftX = CABasicAnimation(keyPath: "position.x")
        leftX.toValue = self.center.frame.minX
        leftX.duration = duration * self.left.bounds.width / self.top.bounds.width
        leftX.timingFunction = CAMediaTimingFunction(name: .linear)
        leftX.fillMode = .forwards
        leftX.isRemovedOnCompletion = false
        self.left.add(leftX, forKey: "leftX")
        
        let leftWidth = CABasicAnimation(keyPath: "bounds.size.width")
        leftWidth.toValue = 0
        leftWidth.duration = duration * self.left.bounds.width / self.top.bounds.width
        leftWidth.timingFunction = CAMediaTimingFunction(name: .linear)
        leftWidth.fillMode = .forwards
        leftWidth.isRemovedOnCompletion = false
        self.left.add(leftWidth, forKey: "leftWidth")
        
        let rightX = CABasicAnimation(keyPath: "position.x")
        rightX.toValue = self.frame.width - bigRadius
        rightX.duration = duration * ((self.top.frame.width - self.center.frame.width) / 2.0 - bigRadius) / self.top.bounds.width
        rightX.timingFunction = CAMediaTimingFunction(name: .linear)
        rightX.fillMode = .forwards
        rightX.isRemovedOnCompletion = false
        rightX.beginTime = currentTime + duration * (1.0 - (self.top.frame.width - self.center.bounds.width) / 2.0 / self.top.bounds.width) + duration * bigRadius / self.top.bounds.width
        self.right.add(rightX, forKey: "rightX")
        
        let rightWidth = CABasicAnimation(keyPath: "bounds.size.width")
        rightWidth.toValue = 2.0 * bigRadius
        rightWidth.duration = duration * ((self.top.frame.width - self.center.frame.width) / 2.0 - bigRadius) / self.top.bounds.width
        rightWidth.timingFunction = CAMediaTimingFunction(name: .linear)
        rightWidth.fillMode = .forwards
        rightWidth.isRemovedOnCompletion = false
        rightWidth.beginTime = currentTime + duration * (1.0 - (self.top.frame.width - self.center.bounds.width) / 2.0 / self.top.bounds.width) + duration * bigRadius / self.top.bounds.width
        self.right.add(rightWidth, forKey: "rightWidth")
        
        let dur = duration * self.center.frame.width / self.top.frame.width
        let beg = currentTime + duration * (self.left.frame.width / self.top.frame.width)
        self.center.hideAnimated(duration: dur, beginTime: beg)
        self.centerBackground.showAnimated(duration: dur, beginTime: beg)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.topBackground = Stripe(isTop: true)
        self.layer.addSublayer(self.topBackground)
        self.botBackground = Stripe(isTop: false)
        self.layer.addSublayer(self.botBackground)
        
        self.leftBackground = ActionlessLayer()
        self.leftBackground.backgroundColor = UIColor.white.withAlphaComponent(0.25).cgColor
        self.layer.addSublayer(self.leftBackground)
        self.rightBackground = ActionlessLayer()
        self.rightBackground.backgroundColor = UIColor.white.withAlphaComponent(0.25).cgColor
        self.layer.addSublayer(self.rightBackground)
        
        self.centerBackground = CloseImageLayerBackground()
        self.layer.addSublayer(self.centerBackground)
        
        self.topAngle = Angle(type: .topLeft)
        self.layer.addSublayer(self.topAngle)
        self.topAngExtension = ActionlessLayer()
        self.topAngExtension.backgroundColor = UIColor.white.cgColor
        self.topAngle.addSublayer(self.topAngExtension)
        self.botAngle = Angle(type: .bottomLeft)
        self.layer.addSublayer(self.botAngle)
        self.botAngExtension = ActionlessLayer()
        self.botAngExtension.backgroundColor = UIColor.white.cgColor
        self.botAngle.addSublayer(self.botAngExtension)
        
        self.topRightAngle = Angle(type: .topRight)
        self.layer.addSublayer(topRightAngle)
        self.botRightAngle = Angle(type: .bottomRight)
        self.layer.addSublayer(botRightAngle)
        
        self.top = ActionlessLayer()
        self.layer.addSublayer(self.top)
        self.top.backgroundColor = UIColor.white.cgColor
        self.bottom = ActionlessLayer()
        self.layer.addSublayer(self.bottom)
        self.bottom.backgroundColor = UIColor.white.cgColor
        self.left = ActionlessLayer()
        self.layer.addSublayer(self.left)
        self.left.backgroundColor = UIColor.white.cgColor
        self.right = ActionlessLayer()
        self.layer.addSublayer(self.right)
        self.right.backgroundColor = UIColor.white.cgColor
        
        self.center = CloseImageLayer()
        self.layer.addSublayer(self.center)
    }
    
    override func layout() {
        super.layout()
        
        let br = self.bigRadius
        
        self.leftBackground.frame = CGRect(x: 0, y: br, width: (self.bounds.width - CloseImageLayer.size.width) / 2.0, height: CloseImageLayer.size.height)
        self.rightBackground.frame = CGRect(x: (self.bounds.width + CloseImageLayer.size.width) / 2.0, y: br, width: (self.bounds.width - CloseImageLayer.size.width) / 2.0, height: CloseImageLayer.size.height)
        
        let pixel = 1.0 / UIScreen.main.scale
        self.topAngle.frame = CGRect(x: 0, y: 0, width: br, height: br)
        self.topAngExtension.frame = CGRect(x: self.topAngle.bounds.width - pixel, y: 0, width: pixel, height: self.topAngle.bounds.height)
        self.top.frame = CGRect(x: 14, y: 0, width: self.bounds.width - 2.0 * br, height: br)
        self.bottom.frame = CGRect(x: 14, y: self.bounds.height - br, width: self.bounds.width - 2.0 * br, height: br)
        self.botAngExtension.frame = CGRect(x: self.botAngle.bounds.width - pixel, y: 0, width: pixel, height: self.botAngle.bounds.height)
        self.botAngle.frame = CGRect(x: 0, y: self.frame.height - 14, width: 14, height: 14)
        
        self.topRightAngle.frame = CGRect(x: self.bounds.width - br, y: 0, width: br, height: br)
        self.botRightAngle.frame = CGRect(x: self.bounds.width - br, y: self.bounds.height - br, width: br, height: br)
        
        let h = (self.bounds.width - CloseImageLayer.size.width) / 2.0
        self.left.frame = CGRect(x: 0, y: br, width: h, height: CloseImageLayer.size.height)
        self.centerBackground.frame = CGRect(origin: CGPoint(x: h, y: br), size: CGSize(width: 0, height: CloseImageLayer.size.height))
        self.center.frame = CGRect(origin: CGPoint(x: h, y: br), size: CloseImageLayer.size)
        self.right.frame = CGRect(x: h + CloseImageLayer.size.width, y: br, width: h, height: CloseImageLayer.size.height)
        
        self.topBackground.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: br)
        self.botBackground.frame = CGRect(x: 0, y: self.bounds.height - br, width: self.bounds.width, height: br)
    }

}
