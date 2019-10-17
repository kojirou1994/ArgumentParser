public protocol SubCommand: ValueOption, Hashable {
    
    static var informationDictionary: [String: String] { get }
    
    var description: String { get }
    
}

extension SubCommand where Self: CaseIterable & RawRepresentable, Self.RawValue == String {
    static var informationDictionary: [String: String] {
        .init(uniqueKeysWithValues: Self.allCases.map { ($0.rawValue, $0.description) })
    }
}
