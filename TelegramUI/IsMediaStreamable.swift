import Foundation
import Postbox
import TelegramCore

func isMediaStreamable(message: Message, media: TelegramMediaFile) -> Bool {
    if message.containsSecretMedia {
        return false
    }
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return false
    }
    guard let size = media.size else {
        return false
    }
    if size < 1 * 1024 * 1024 {
        return false
    }
    if media.isAnimated {
        return false
    }
    for attribute in media.attributes {
        if case let .Video(video) = attribute {
            if video.flags.contains(.supportsStreaming) {
                return true
            }
            break
        }
    }
    return false
}
