import Foundation
import XCTest
@testable import DivoCore

/// Подпись роли из бэка: «New Face» / «Новое Лицо» показываем как «Талант», остальные подписи — как есть.
final class DivoRoleLabelTests: XCTestCase {

    func testLegacyNewFaceLabelsBecomeTalent() {
        XCTAssertEqual(DivoRoleLabel.display("Новое Лицо"), DivoStrings.roleNewFace)
        XCTAssertEqual(DivoRoleLabel.display("  new face "), DivoStrings.roleNewFace)
        XCTAssertEqual(DivoRoleLabel.display("Новые лица"), DivoStrings.roleNewFace)
    }

    func testOtherLabelsAreKept() {
        XCTAssertEqual(DivoRoleLabel.display("Photographer"), "Photographer")
        XCTAssertEqual(DivoRoleLabel.display("Модель"), "Модель")
        XCTAssertNil(DivoRoleLabel.display(nil))
    }
}
