import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AvatarNode
//import MediaPlayer
import TelegramPresentationData

private let avatarFont = avatarPlaceholderFont(size: 42.0)

final class ModernCallAvatarNode: ASDisplayNode {
    
    let avatarNode: AvatarNode
    
    override init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        super.init()
        self.backgroundColor = .red
        self.addSubnode(self.avatarNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.avatarNode.frame = CGRect(origin: .zero, size: size)
        self.avatarNode.updateSize(size: size)
    }
}
