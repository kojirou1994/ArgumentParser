public protocol ValueOption {
    init(argument: String) throws
    
    var argument: String { get }
}

extension ValueOption where Self: RawRepresentable, Self.RawValue == String {
    public init(argument: String) throws {
        guard let v = Self.init(rawValue: argument) else {
            throw ArgumentParserError.invalidOptionValue(argument: argument, type: String(describing: Self.self))
        }
        self = v
    }
    
    public var argument: String { rawValue }
}

extension ValueOption where Self: RawRepresentable, Self.RawValue: ValueOption {
    public init(argument: String) throws {
        guard let v = Self.init(rawValue: try RawValue(argument: argument)) else {
            throw ArgumentParserError.invalidOptionValue(argument: argument, type: String(describing: Self.self))
        }
        self = v
    }
    
    public var argument: String { rawValue.argument }
}

extension ValueOption where Self: LosslessStringConvertible {
    public init(argument: String) throws {
        guard let v = Self.init(argument) else {
            throw ArgumentParserError.invalidOptionValue(argument: argument, type: String(describing: Self.self))
        }
        self = v
    }
    
    public var argument: String { description }
}

extension Optional: ValueOption where Wrapped: ValueOption {
    public init(argument: String) throws {
        self = .some(try .init(argument: argument))
    }
    
    public var argument: String { String(describing: self) }
}

extension String: ValueOption {}

extension Bool: ValueOption {}

extension Int: ValueOption {}

extension Int8: ValueOption {}

extension Int16: ValueOption {}

extension Int32: ValueOption {}

extension Int64: ValueOption {}

extension UInt: ValueOption {}

extension UInt8: ValueOption {}

extension UInt16: ValueOption {}

extension UInt32: ValueOption {}

extension UInt64: ValueOption {}

extension Double: ValueOption {}

extension Float: ValueOption {}
