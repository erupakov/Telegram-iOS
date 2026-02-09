import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public class ProfileParametersData {
    let firstName: String?
    let lastName: String?
    let country: String?
    let about: String?
    let gender: Api.Gender?
    let birthDate: Int32?
    let height: Int32?
    let waist: Int32?
    let hips: Int32?
    let shoeSize: Int32?
    let hairLength: Int32?
    let hairColor: String?
    let eyeColor: String?
    let skinColor: String?
    let breastSize: String?
    let photoId: Int64?
    let backgroundId: Int64?
    
    public init(firstName: String?, lastName: String?, country: String?, about: String?, gender: Api.Gender?, birthDate: Int32?, height: Int32?, waist: Int32?, hips: Int32?, shoeSize: Int32?, hairLength: Int32?, hairColor: String?, eyeColor: String?, skinColor: String?, breastSize: String?, photoId: Int64?, backgroundId: Int64? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.country = country
        self.about = about
        self.gender = gender
        self.birthDate = birthDate
        self.height = height
        self.waist = waist
        self.hips = hips
        self.shoeSize = shoeSize
        self.hairLength = hairLength
        self.hairColor = hairColor
        self.eyeColor = eyeColor
        self.skinColor = skinColor
        self.breastSize = breastSize
        self.photoId = photoId
        self.backgroundId = backgroundId
    }
}
