import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_requestUpdatePeerIsBlocked(account: Account, peerId: PeerId, isBlocked: Bool) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let updateLocalIsBlocked: () -> Signal<Void, NoError> = {
                return account.postbox.transaction { transaction -> Void in
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        let previous: CachedUserData
                        if let current = current as? CachedUserData {
                            previous = current
                        } else {
                            previous = CachedUserData()
                        }
                        return previous.withUpdatedIsBlocked(isBlocked)
                    })
                }
            }
            let request: Signal<Api.Bool, MTRpcError>
            if isBlocked {
                request = account.network.request(Api.functions.contacts.block(flags: 0, id: inputPeer))
            } else {
                request = account.network.request(Api.functions.contacts.unblock(flags: 0, id: inputPeer))
            }
            let mtprotoBlock: Signal<Void, NoError> = request
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if result != nil {
                        return updateLocalIsBlocked()
                    } else {
                        return .complete()
                    }
                }
            // DIVO: блок пользователя — через REST (/user/block), teamgram синхронизирует сервер.
            // contacts.block остаётся только для тех, у кого нет DIVO-аккаунта (боты и т.п.).
            if let user = peer as? TelegramUser, user.botInfo == nil, peerId != account.peerId, let handler = DivoChatBlockBridge.handler {
                return handler(peerId.id._internalGetInt64Value(), isBlocked)
                |> mapToSignal { outcome -> Signal<Void, NoError> in
                    switch outcome {
                    case .done:
                        return updateLocalIsBlocked()
                    case .notDivoUser:
                        return mtprotoBlock
                    case .failed:
                        return .complete()
                    }
                }
            }
            return mtprotoBlock
        } else {
            return .complete()
        }
    } |> switchToLatest
}

func _internal_requestUpdatePeerIsBlockedFromStories(account: Account, peerId: PeerId, isBlocked: Bool) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let flags: Int32 = 1 << 0
            let signal: Signal<Api.Bool, MTRpcError>
            if isBlocked {
                signal = account.network.request(Api.functions.contacts.block(flags: flags, id: inputPeer))
            } else {
                signal = account.network.request(Api.functions.contacts.unblock(flags: flags, id: inputPeer))
            }
            return signal
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        if result != nil {
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                let previous: CachedUserData
                                if let current = current as? CachedUserData {
                                    previous = current
                                } else {
                                    previous = CachedUserData()
                                }
                                var userFlags = previous.flags
                                if isBlocked {
                                    userFlags.insert(.isBlockedFromStories)
                                } else {
                                    userFlags.remove(.isBlockedFromStories)
                                }
                                return previous.withUpdatedFlags(userFlags)
                            })
                        }
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
