import Foundation
import XCTest
@testable import DivoCore

/// Размер обуви — с шагом в полразмера: сырое значение слайдера (35.18007662835248) не показываем и не отправляем.
final class DivoMeasuringShoeSizeTests: XCTestCase {

    func testRawSliderValueRoundedToHalfSize() {
        XCTAssertEqual(DivoMeasuring.metricValue(display: 35.18007662835248, kind: .shoeSize, system: .metric), 35.0)
        XCTAssertEqual(DivoMeasuring.metricValue(display: 40.27, kind: .shoeSize, system: .metric), 40.5)
    }

    func testDisplayStringHasNoLongFraction() {
        XCTAssertEqual(DivoMeasuring.valueString(metric: 35.18007662835248, kind: .shoeSize, system: .metric), "35")
        XCTAssertEqual(DivoMeasuring.rangeString(fromMetric: 35.18007662835248, toMetric: 40.27, kind: .shoeSize, system: .metric), "35-40.5")
    }

    func testHalfSizeIsKept() {
        XCTAssertEqual(DivoMeasuring.valueString(metric: 38.5, kind: .shoeSize, system: .metric), "38.5")
    }

    func testImperialShoeSizeKeepsOffsetAndHalfSteps() {
        XCTAssertEqual(DivoMeasuring.metricValue(display: 6.1, kind: .shoeSize, system: .imperial), 38.0)
        XCTAssertEqual(DivoMeasuring.displayValue(metric: 38.5, kind: .shoeSize, system: .imperial), 6.5)
    }
}
