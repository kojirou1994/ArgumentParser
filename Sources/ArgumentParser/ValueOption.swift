public protocol ValueOption {
    init(argument: String) throws
}

extension ValueOption where Self: RawRepresentable, Self.RawValue == String {
    
    public init(argument: String) throws {
        guard let v = Self.init(rawValue: argument) else {
            throw ArgumentParserError.invalidOptionValue(argument: argument, type: String(describing: Self.self))
        }
        self = v
    }
    
}

extension ValueOption where Self: RawRepresentable, Self.RawValue: ValueOption {
    
    public init(argument: String) throws {
        guard let v = Self.init(rawValue: try RawValue(argument: argument)) else {
            throw ArgumentParserError.invalidOptionValue(argument: argument, type: String(describing: Self.self))
        }
        self = v
    }
    
}

extension ValueOption where Self: LosslessStringConvertible {
    public init(argument: String) throws {
        guard let v = Self.init(argument) else {
            throw ArgumentParserError.invalidOptionValue(argument: argument, type: String(describing: Self.self))
        }
        self = v
    }
}

extension String: ValueOption {}

extension Bool: ValueOption {}

extension Int: ValueOption {}

extension Double: ValueOption {}
