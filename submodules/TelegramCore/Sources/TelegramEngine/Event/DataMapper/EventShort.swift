import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

//TODO: для примера
extension Api.event.Short {
    var id: Int64? {
        if case let .short(_, id, _, _, _, _, _, _, _, _, _, _) = self {
            return id
        }
        return nil
    }
    
    var title: String? {
        if case let .short(_, _, _, title, _, _, _, _, _, _, _, _) = self {
            return title
        }
        return nil
    }
    
    var coverPhotoMedia: TelegramMediaImage? {
        if case let .short(_, _, _, _, coverPhoto, _, _, _, _, _, _, _) = self,
           case let .photo(photo, _) = coverPhoto {
            return telegramMediaImageFromApiPhoto(photo)
        }
        return nil
    }
}
