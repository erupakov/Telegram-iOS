import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public extension TelegramEngine {
    final class EventsEngine {
        private let account: Account
        
        init(account: Account) {
            self.account = account
        }
        
        public func getEvent(eventId: Int) -> Signal<String?, NoError> {
            return _getEvent(account: self.account, eventId: eventId)
        }
        
        public func createEvent(eventModel: EventModel) -> Signal<String?, NoError> {
            _internal_createEvent(account: account, event: eventModel)
        }
        
        public func getCountries() -> Signal<String?, NoError> {
            _internal_getCountries(account: account)
        }
        public func getEvents() -> Signal<[EventModel]?, NoError> {
            _internal_getEvents(account: account)
        }
    }
}
