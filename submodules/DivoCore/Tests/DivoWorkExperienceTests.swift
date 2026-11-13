import Foundation
import XCTest
@testable import DivoCore

/// Опыт работы — только для «нанимаемых» (модели/таланты); у агентств, брендов и прочих `agency_employee` его нет.
final class DivoWorkExperienceTests: XCTestCase {

    func testHiringRoleHasNoWorkExperience() {
        XCTAssertFalse(DivoWorkExperience.isAllowed(profileRole: "agency_employee", isMyProfile: false))
        XCTAssertFalse(DivoWorkExperience.isAllowed(profileRole: "agency_employee", isMyProfile: true))
    }

    func testTalentRolesKeepWorkExperience() {
        XCTAssertTrue(DivoWorkExperience.isAllowed(profileRole: "model", isMyProfile: false))
        XCTAssertTrue(DivoWorkExperience.isAllowed(profileRole: "new_face", isMyProfile: false))
        XCTAssertTrue(DivoWorkExperience.isAllowed(profileRole: nil, isMyProfile: false))
    }
}
