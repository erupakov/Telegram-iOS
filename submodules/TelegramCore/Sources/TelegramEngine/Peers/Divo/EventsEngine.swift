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
        
        public func getEvent(eventId: Int) -> Signal<EventModel?, NoError> {
            return _getEvent(account: self.account, eventId: eventId)
        }
        
        public func createEvent(eventModel: EventModel, id: Int64) -> Signal<String?, NoError> {
            _internal_createEvent(account: account, event: eventModel, id: id)
        }
        
        public func getCountries() -> Signal<String?, NoError> {
            _internal_getCountries(account: account)
        }
        public func getEvents() -> Signal<[EventModel]?, NoError> {
            _internal_getEvents(account: account)
        }
        public func addEventPhoto(eventId: Int64, photoId: Int64) -> Signal<String?, NoError> {
            _internal_addEventPhoto(account: account, eventId: eventId, photoId: photoId)
        }
    }
}
