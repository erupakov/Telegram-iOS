import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public extension TelegramEngine {
    final class ProfileEngine {
        private let account: Account
        
        init(account: Account) {
            self.account = account
        }
        
        public func getWorkHistory(peer: Peer?) -> Signal<[WorkExperienceModel]?, NoError> {
            _internal_getWorkHistory(account: account, peer: peer)
        }
        
        public func createWorkExperience(agencyName: String, startDate: Int32, endDate: Int32?) -> Signal<String?, NoError> {
            _internal_createWorkExperience(account: account, agencyName: agencyName, startDate: startDate, endDate: endDate)
        }
        
        public func deleteWorkExperience(id: Int64) -> Signal<Bool?, NoError> {
            _internal_deleteWorkExperience(account: account, id: id)
        }
        
        public func updateSocialLinks(
            instagram: String,
            tiktok: String,
            youtube: String,
            website: String
        ) -> Signal<String?, NoError> {
            _internal_updateSocialLinks(
                account: account,
                instagram: instagram,
                tiktok: tiktok,
                youtube: youtube,
                website: website
            )
        }
        
        public func updateProfile(data: ProfileParametersData) -> Signal<String?, NoError> {
            _internal_updateProfile(account: account, data: data)
        }
        
        public func getUserProfile(peer: Peer?) -> Signal<UserProfileData?, NoError> {
            _internal_getUserProfile(account: account, peer: peer)
        }
        
        public func updateProfileNameAndBio(data: ProfileParametersData) -> Signal<String?, NoError> {
            _internal_updateProfileNameAndBio(account: account, data: data)
        }
        
        public func getFullUser(peer: Peer?) -> Signal<String?, NoError> {
            _internal_getFullUser(account: account, peer: peer)
        }
    }
}
