import Foundation
import DivoCore
import FaceSearchUI

extension ProfileModel {
    public init(faceSearchResult result: FRSearchResult) {
        let mainImageURL = result.image.flatMap(URL.init(string:))
        let location = FaceSearchResultsMapper.countryText(code: result.countryCode, name: result.countryName) ?? ""
        self.init(
            name: result.fullName ?? "",
            age: FaceSearchResultsMapper.computeAge(from: result.birthday),
            location: location,
            isVerified: false,
            likesCount: "0",
            viewsCount: "0",
            savesCount: "0",
            biography: "",
            socialMediaHandles: [],
            userId: result.userId,
            role: result.role,
            mainImageURL: mainImageURL,
            avatarImageURL: mainImageURL
        )
    }
}
