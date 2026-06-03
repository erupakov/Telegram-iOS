import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi


public enum RequestLocalizationPreviewError {
    case generic
}

func _internal_requestLocalizationPreview(network: Network, identifier: String) -> Signal<LocalizationInfo, RequestLocalizationPreviewError> {
    // DIVO PATCH: langPack="ios" вместо "" — teamgram-сервер не делает fallback на ENV langPack, отвечает LANG_PACK_INVALID на пустой. Откатить при merge upstream если бэк починит сервер.
    return network.request(Api.functions.langpack.getLanguage(langPack: "ios", langCode: identifier))
    |> mapError { _ -> RequestLocalizationPreviewError in
        return .generic
    }
    |> map { language -> LocalizationInfo in
        return LocalizationInfo(apiLanguage: language)
    }
}
