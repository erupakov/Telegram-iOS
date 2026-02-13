import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_uploadedPhoto(account: Account, resource: Data) -> Signal<Int64?, NoError> {
    let upload = multipartUpload(
        network: account.network,
        postbox: account.postbox,
        source: .data(resource),
        encrypt: false,
        tag: TelegramMediaResourceFetchTag(statsCategory: .image, userContentType: .image),
        hintFileSize: Int64(resource.count),
        hintFileIsLarge: false,
        forceNoBigParts: false
    )
    
    let uploadSignal: Signal<MultipartUploadResult, NoError> = Signal { subscriber in
        return upload.start(next: { next in
            subscriber.putNext(next)
        }, error: { _ in
            subscriber.putNext(.progress(0.0))
            subscriber.putCompletion()
        }, completed: {
            subscriber.putCompletion()
        })
    }
    
    return uploadSignal
    |> mapToSignal { result -> Signal<Int64?, NoError> in
        switch result {
        case let .inputFile(inputFile):
            return account.network.request(Api.functions.messages.uploadMedia(
                flags: 0,
                businessConnectionId: nil,
                peer: .inputPeerEmpty,
                media: .inputMediaUploadedPhoto(flags: 0, file: inputFile, stickers: nil, ttlSeconds: nil)
            ))
            |> map { response -> Int64? in
                switch response {
                case let .messageMediaPhoto(_, photo, _):
                    if let photo = photo {
                        switch photo {
                        case let .photo(_, id, _, _, _, _, _, _):
                            return id
                        case let .photoEmpty(id):
                            return id
                        }
                    }
                default:
                    break
                }
                return nil
            }
            |> `catch` { _ -> Signal<Int64?, NoError> in
                return .single(nil)
            }
        default:
            return .complete()
        }
    }
    |> filter { $0 != nil }
    |> take(1)
}

func _internal_getInputFile(account: Account, resource: Data) -> Signal<Api.InputFile?, NoError> {
    let upload = multipartUpload(
        network: account.network,
        postbox: account.postbox,
        source: .data(resource),
        encrypt: false,
        tag: TelegramMediaResourceFetchTag(statsCategory: .image, userContentType: .image),
        hintFileSize: Int64(resource.count),
        hintFileIsLarge: false,
        forceNoBigParts: false
    )
    
    return Signal { subscriber in
        return upload.start(next: { result in
            switch result {
            case let .inputFile(inputFile):
                subscriber.putNext(inputFile)
                subscriber.putCompletion()
            case .progress:
                break
            default:
                subscriber.putCompletion()
            }
        }, error: { _ in
            subscriber.putNext(nil)
            subscriber.putCompletion()
        })
    }
}
