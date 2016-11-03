import Foundation
import Postbox
import TelegramCore

enum ChatListNodeEntryId: Hashable, CustomStringConvertible {
    case Search
    case Hole(Int64)
    case PeerId(Int64)
    
    var hashValue: Int {
        switch self {
        case .Search:
            return 0
        case let .Hole(peerId):
            return peerId.hashValue
        case let .PeerId(peerId):
            return peerId.hashValue
        }
    }
    
    var description: String {
        switch self {
        case .Search:
            return "search"
        case let .Hole(value):
            return "hole(\(value))"
        case let .PeerId(value):
            return "peerId(\(value))"
        }
    }
    
    static func <(lhs: ChatListNodeEntryId, rhs: ChatListNodeEntryId) -> Bool {
        return lhs.hashValue < rhs.hashValue
    }
    
    static func ==(lhs: ChatListNodeEntryId, rhs: ChatListNodeEntryId) -> Bool {
        switch lhs {
        case .Search:
            switch rhs {
            case .Search:
                return true
            default:
                return false
            }
        case let .Hole(lhsId):
            switch rhs {
            case .Hole(lhsId):
                return true
            default:
                return false
            }
        case let .PeerId(lhsId):
            switch rhs {
            case let .PeerId(rhsId):
                return lhsId == rhsId
            default:
                return false
            }
        }
    }
}

enum ChatListNodeEntry: Comparable, Identifiable {
    case SearchEntry
    case MessageEntry(Message, CombinedPeerReadState?, PeerNotificationSettings?)
    case HoleEntry(ChatListHole)
    case Nothing(MessageIndex)
    
    var index: MessageIndex {
        switch self {
            case .SearchEntry:
                return MessageIndex.absoluteUpperBound()
            case let .MessageEntry(message, _, _):
                return MessageIndex(message)
            case let .HoleEntry(hole):
                return hole.index
            case let .Nothing(index):
                return index
        }
    }
    
    var stableId: ChatListNodeEntryId {
        switch self {
            case .SearchEntry:
                return .Search
            case let .MessageEntry(message, _, _):
                return .PeerId(message.id.peerId.toInt64())
            case let .HoleEntry(hole):
                return .Hole(Int64(hole.index.id.id))
            case let .Nothing(index):
                return .PeerId(index.id.peerId.toInt64())
        }
    }
    
    static func <(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    static func ==(lhs: ChatListNodeEntry, rhs: ChatListNodeEntry) -> Bool {
        switch lhs {
            case .SearchEntry:
                switch rhs {
                case .SearchEntry:
                    return true
                default:
                    return false
                }
            case let .MessageEntry(lhsMessage, lhsUnreadCount, lhsNotificationSettings):
                switch rhs {
                case let .MessageEntry(rhsMessage, rhsUnreadCount, rhsNotificationSettings):
                    if lhsMessage.id != rhsMessage.id || lhsMessage.flags != rhsMessage.flags || lhsUnreadCount != rhsUnreadCount {
                        return false
                    }
                    if let lhsNotificationSettings = lhsNotificationSettings, let rhsNotificationSettings = rhsNotificationSettings {
                        if !lhsNotificationSettings.isEqual(to: rhsNotificationSettings) {
                            return false
                        }
                    } else if (lhsNotificationSettings != nil) != (rhsNotificationSettings != nil) {
                        return false
                    }
                    return true
                default:
                    break
                }
            case let .HoleEntry(lhsHole):
                switch rhs {
                case let .HoleEntry(rhsHole):
                    return lhsHole == rhsHole
                default:
                    return false
                }
            case let .Nothing(lhsIndex):
                switch rhs {
                case let .Nothing(rhsIndex):
                    return lhsIndex == rhsIndex
                default:
                    return false
                }
        }
        return false
    }
}

func chatListNodeEntriesForView(_ view: ChatListView) -> [ChatListNodeEntry] {
    var result: [ChatListNodeEntry] = []
    for entry in view.entries {
        switch entry {
            case let .MessageEntry(message, combinedReadState, notificationSettings):
                result.append(.MessageEntry(message, combinedReadState, notificationSettings))
            case let .HoleEntry(hole):
                result.append(.HoleEntry(hole))
            case let .Nothing(index):
                result.append(.Nothing(index))
        }
    }
    if view.laterIndex == nil {
        result.append(.SearchEntry)
    }
    return result
}