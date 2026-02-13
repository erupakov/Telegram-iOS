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
        
        public func createWorkExperience(agencyName: String, startDate: Int32, endDate: Int32?, photoId: Int64?) -> Signal<String?, NoError> {
            _internal_createWorkExperience(account: account, agencyName: agencyName, startDate: startDate, endDate: endDate, photoId: photoId)
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
        
        public func updateProfileBackground(backgroundId: Int64) -> Signal<String?, NoError> {
            _internal_updateProfileBackground(account: account, backgroundId: backgroundId)
        }
        
        public func getUserProfile(peer: Peer?) -> Signal<UserProfileData?, NoError> {
            _internal_getUserProfile(account: account, peer: peer)
        }
        
        public func uploadPortfolioItem(file: Api.InputFile, type: String) -> Signal<String?, NoError> {
            _internal_uploadPortfolioItem(account: account, file: file, type: type)
        }
        
        public func getPortfolio(peer: Peer?, tab: String, offset: Int32, limit: Int32) -> Signal<String?, NoError> {
            _internal_getPortfolio(account: account, peer: peer, tab: tab, offset: offset, limit: limit)
        }
        
        // MARK: - OLD
        public func updateProfileNameAndBio(data: ProfileParametersData) -> Signal<String?, NoError> {
            _internal_updateProfileNameAndBio(account: account, data: data)
        }
        
        public func getFullUser(peer: Peer?) -> Signal<String?, NoError> {
            _internal_getFullUser(account: account, peer: peer)
        }
    }
}
