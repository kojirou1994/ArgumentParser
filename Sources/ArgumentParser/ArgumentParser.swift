public enum ArgumentParserError: Error {
    case nonRequiredValue(String)
    case unknownOption(String)
    case invalidOptionValue(String, String)
}

public typealias ArgumentHandler = (String) throws -> ()

public struct ArgumentParser {
    
    public let options: [Option]
    
    public let usage: String
    
    public let positionalInput: ArgumentHandler
    
    public init(usage: String, options: [Option], positionalInput: @escaping ArgumentHandler) {
        self.usage = usage
        self.options = options.sorted()
        self.positionalInput = positionalInput
    }
    
    /// Parse arguments.
    ///
    /// - Parameter arguments: cli arguments, Sequence of String.
    /// - Throws: ArgumentParserError or other errors from the ArgumentHandlers
    public func parse<C>(arguments: C) throws where C: Sequence, C.Element == String {
        var dic = [String : Option]()
        for a in options {
            dic[a.name] = a
            if a.anotherName != nil {
                dic[a.anotherName!] = a
            }
        }
        
        var enume = arguments.makeIterator()
        while let argument = enume.next() {
            if let option = dic[argument] {
                if option.requireValue {
                    if let v = enume.next() {
                        try option.didGetValue(v)
                    } else {
                        throw ArgumentParserError.nonRequiredValue(argument)
                    }
                } else {
                    try option.didGetValue(argument)
                }
            } else if argument.hasPrefix("-") {
                throw ArgumentParserError.unknownOption(argument)
            } else {
                try positionalInput(argument)
            }
        }
    }
    
    public func showHelp<Target>(to output: inout Target) where Target : TextOutputStream {
        let width = 24
        print("USAGE: \(usage)", to: &output)
        print("OPTIONS:", to: &output)
        options.forEach { (opt) in
            let name = "\(opt.name)\(opt.anotherName == nil ? "" : ", \(opt.anotherName!)")"
            print("  \(name)", terminator: "", to: &output)
            var padding = width-name.count
            if padding <= 1 {
                padding = width
                print("\n  ", terminator: "", to: &output)
            }
            for _ in 0..<padding {
                print(" ", terminator: "", to: &output)
            }
            print(opt.description, to: &output)
        }
    }
    
}

public struct Option {
    public let name: String
    public let anotherName: String?
    public let requireValue: Bool
    public let description: String
    public let didGetValue: ArgumentHandler
    
    public init(name: String, anotherName: String? = nil, requireValue: Bool, description: String, didGetValue: @escaping ArgumentHandler) {
        self.name = name
        self.anotherName = anotherName
        self.requireValue = requireValue
        self.description = description
        self.didGetValue = didGetValue
    }
}

extension Option: Comparable {
    
    public static func < (lhs: Option, rhs: Option) -> Bool {
        return lhs.name < rhs.name
    }
    
    public static func == (lhs: Option, rhs: Option) -> Bool {
        return lhs.name == rhs.name
    }
    
    
}

public protocol OptionValue {
    init(argument: String) throws
}

extension Bool: OptionValue {
    public init(argument: String) throws {
        switch argument {
        case "true":
            self = true
        case "false":
            self = false
        default:
            throw ArgumentParserError.invalidOptionValue(argument, "Bool")
        }
    }
}

extension Int: OptionValue {
    public init(argument: String) throws {
        if let v = Int(argument) {
            self = v
        } else {
            throw ArgumentParserError.invalidOptionValue(argument, "Int")
        }
    }
}

extension Double: OptionValue {
    public init(argument: String) throws {
        if let v = Double(argument) {
            self = v
        } else {
            throw ArgumentParserError.invalidOptionValue(argument, "Double")
        }
    }
}
