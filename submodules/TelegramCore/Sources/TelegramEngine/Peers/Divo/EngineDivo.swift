import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public extension TelegramEngine {
    final class EngineDivo {
        private let account: Account
        
        init(account: Account) {
            self.account = account
        }
        
        public func uploadedPhoto(resource: Data) -> Signal<Int64?, NoError> {
            return _internal_uploadedPhoto(account: account, resource: resource)
        }
    }
}
