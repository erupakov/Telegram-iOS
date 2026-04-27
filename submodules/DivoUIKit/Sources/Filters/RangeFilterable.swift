import Foundation

public protocol RangeFilterable: Comparable {
    var doubleValue: Double { get }
    init(_ value: Double)
}

extension Int: RangeFilterable {
    public var doubleValue: Double { return Double(self) }
}

extension Double: RangeFilterable {
    public var doubleValue: Double { return self }
}

extension Float: RangeFilterable {
    public var doubleValue: Double { return Double(self) }
}
