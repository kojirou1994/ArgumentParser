public protocol SubCommand: ValueOption, Hashable {
    
    static var informationDictionary: [String: String] { get }
    
    static var availableCommands: [Self] { get }
    
    var command: String { get }
    
    var description: String { get }
    
}

extension SubCommand {
    
    public static var informationDictionary: [String: String] {
        .init(uniqueKeysWithValues: Self.availableCommands.map { ($0.command, $0.description) })
    }
    
}
