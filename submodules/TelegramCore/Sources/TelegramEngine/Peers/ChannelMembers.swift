import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum ChannelMembersCategoryFilter {
    case all
    case search(String)
}

public enum ChannelMembersCategory {
    case recent(ChannelMembersCategoryFilter)
    case admins
    case contacts(ChannelMembersCategoryFilter)
    case bots(ChannelMembersCategoryFilter)
    case restricted(ChannelMembersCategoryFilter)
    case banned(ChannelMembersCategoryFilter)
    case mentions(threadId: MessageId?, filter: ChannelMembersCategoryFilter)
}

func _internal_channelMembers(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, category: ChannelMembersCategory = .recent(.all), offset: Int32 = 0, limit: Int32 = 64, hash: Int64 = 0) -> Signal<[RenderedChannelParticipant]?, NoError> {
    return postbox.transaction { transaction -> Signal<[RenderedChannelParticipant]?, NoError> in
        if let peer = transaction.getPeer(peerId) as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
            if case .broadcast = peer.info {
                if let _ = peer.adminRights {
                } else {
                    return .single(nil)
                }
            }
            if peer.flags.contains(.isMonoforum) {
                return .single(nil)
            }
            
            let apiFilter: Api.ChannelParticipantsFilter
            switch category {
                case let .recent(filter):
                    switch filter {
                        case .all:
                            apiFilter = .channelParticipantsRecent
                        case let .search(query):
                            apiFilter = .channelParticipantsSearch(Api.ChannelParticipantsFilter.Cons_channelParticipantsSearch(q: query))
                    }
                case let .mentions(threadId, filter):
                    switch filter {
                        case .all:
                            var flags: Int32 = 0
                            if threadId != nil {
                                flags |= 1 << 1
                            }
                            apiFilter = .channelParticipantsMentions(Api.ChannelParticipantsFilter.Cons_channelParticipantsMentions(flags: flags, q: nil, topMsgId: threadId?.id))
                        case let .search(query):
                            var flags: Int32 = 0
                            if threadId != nil {
                                flags |= 1 << 1
                            }
                            if !query.isEmpty {
                                flags |= 1 << 0
                            }
                            apiFilter = .channelParticipantsMentions(Api.ChannelParticipantsFilter.Cons_channelParticipantsMentions(flags: flags, q: query.isEmpty ? nil : query, topMsgId: threadId?.id))
                    }
                case .admins:
                    apiFilter = .channelParticipantsAdmins
                case let .contacts(filter):
                    switch filter {
                        case .all:
                            apiFilter = .channelParticipantsContacts(Api.ChannelParticipantsFilter.Cons_channelParticipantsContacts(q: ""))
                        case let .search(query):
                            apiFilter = .channelParticipantsContacts(Api.ChannelParticipantsFilter.Cons_channelParticipantsContacts(q: query))
                    }
                case .bots:
                    apiFilter = .channelParticipantsBots
                case let .restricted(filter):
                    switch filter {
                        case .all:
                            apiFilter = .channelParticipantsBanned(Api.ChannelParticipantsFilter.Cons_channelParticipantsBanned(q: ""))
                        case let .search(query):
                            apiFilter = .channelParticipantsBanned(Api.ChannelParticipantsFilter.Cons_channelParticipantsBanned(q: query))
                    }
                case let .banned(filter):
                    switch filter {
                        case .all:
                            apiFilter = .channelParticipantsKicked(Api.ChannelParticipantsFilter.Cons_channelParticipantsKicked(q: ""))
                        case let .search(query):
                            apiFilter = .channelParticipantsKicked(Api.ChannelParticipantsFilter.Cons_channelParticipantsKicked(q: query))
                    }
            }
            return network.request(Api.functions.channels.getParticipants(channel: inputChannel, filter: apiFilter, offset: offset, limit: limit, hash: hash))
            |> retryRequestIfNotFrozen
            |> mapToSignal { result -> Signal<[RenderedChannelParticipant]?, NoError> in
                guard let result else {
                    return .single(nil)
                }
                // DIVO: teamgram может отдать участников без (части) объектов в `users`. Раньше такой
                // участник молча выкидывался — список был пустым при ненулевом счётчике. Теперь берём
                // пира из локальной базы, а совсем неизвестных догружаем через users.getUsers.
                let parsed: Signal<(participants: [ChannelParticipant], peerIds: Set<PeerId>, missingUsers: [Api.InputUser])?, NoError> = postbox.transaction { transaction -> (participants: [ChannelParticipant], peerIds: Set<PeerId>, missingUsers: [Api.InputUser])? in
                    switch result {
                        case let .channelParticipants(channelParticipantsData):
                            let (participants, chats, users) = (channelParticipantsData.participants, channelParticipantsData.chats, channelParticipantsData.users)
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                            let channelParticipants = CachedChannelParticipants(apiParticipants: participants).participants
                            var peerIds = parsedPeers.allIds
                            var missingUsers: [Api.InputUser] = []
                            for participant in channelParticipants {
                                peerIds.insert(participant.peerId)
                                if parsedPeers.get(participant.peerId) == nil, transaction.getPeer(participant.peerId) == nil, participant.peerId.namespace == Namespaces.Peer.CloudUser {
                                    missingUsers.append(.inputUser(.init(userId: participant.peerId.id._internalGetInt64Value(), accessHash: 0)))
                                }
                            }
                            return (channelParticipants, peerIds, missingUsers)
                        case .channelParticipantsNotModified:
                            return nil
                    }
                }
                return parsed
                |> mapToSignal { parsed -> Signal<[RenderedChannelParticipant]?, NoError> in
                    guard let parsed else {
                        return .single(nil)
                    }
                    let resolveMissingUsers: Signal<Void, NoError>
                    if !parsed.missingUsers.isEmpty {
                        resolveMissingUsers = network.request(Api.functions.users.getUsers(id: parsed.missingUsers))
                        |> `catch` { _ -> Signal<[Api.User], NoError> in
                            return .single([])
                        }
                        |> mapToSignal { users -> Signal<Void, NoError> in
                            return postbox.transaction { transaction -> Void in
                                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                            }
                        }
                    } else {
                        resolveMissingUsers = .single(Void())
                    }
                    return resolveMissingUsers
                    |> mapToSignal { _ -> Signal<[RenderedChannelParticipant]?, NoError> in
                        return postbox.transaction { transaction -> [RenderedChannelParticipant]? in
                            var peers: [PeerId: Peer] = [:]
                            for id in parsed.peerIds {
                                if let peer = transaction.getPeer(id) {
                                    peers[peer.id] = peer
                                }
                            }
                            var items: [RenderedChannelParticipant] = []
                            for participant in parsed.participants {
                                if let peer = peers[participant.peerId] {
                                    var renderedPresences: [PeerId: PeerPresence] = [:]
                                    if let presence = transaction.getPeerPresence(peerId: participant.peerId) {
                                        renderedPresences[participant.peerId] = presence
                                    }
                                    items.append(RenderedChannelParticipant(participant: participant, peer: peer, peers: peers, presences: renderedPresences))
                                }
                            }
                            return items
                        }
                    }
                }
            }
        } else {
            return .single([])
        }
    } |> switchToLatest
}
