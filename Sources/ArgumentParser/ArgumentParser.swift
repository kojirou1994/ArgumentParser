public enum ArgumentParserError: Error {
    case nonRequiredValue(String)
    case unknownOption(String)
    case invalidOptionValue(argument: String, type: String)
}

public typealias ArgumentHandler = (String) throws -> ()

public struct ArgumentParser {
    
    public let options: [Option]
    
    public let usage: String
    
    public init(usage: String, options: [Option]) {
        self.usage = usage
        self.options = options.sorted()
    }

    @discardableResult
    public func parse<C>(arguments: C) throws -> [String]
        where C: Sequence, C.Element == String {
        var dic = [String : Option]()
        var inputs = [String]()
        for a in options {
            assert(dic[a.name] == nil)
            dic[a.name] = a
            if let anotherName = a.anotherName {
                assert(dic[anotherName] == nil)
                dic[anotherName] = a
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
                inputs.append(argument)
            }
        }
        return inputs
    }
    
    public func showHelp<Target: TextOutputStream>(to output: Target) {
        var output = output
        let width = 24
        output.write("USAGE: \(usage)")
        output.write("OPTIONS:")
        options.forEach { (opt) in
            let name = "\(opt.name)\(opt.anotherName == nil ? "" : ", \(opt.anotherName!)")"
            output.write("  \(name)")
            var padding = width-name.count
            if padding <= 1 {
                padding = width
                output.write("\n  ")
            }
            for _ in 0..<padding {
                output.write(" ")
            }
            output.write(opt.description)
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
            throw ArgumentParserError.invalidOptionValue(argument: argument, type: "Bool")
        }
    }
}

extension Int: OptionValue {
    public init(argument: String) throws {
        if let v = Int(argument) {
            self = v
        } else {
            throw ArgumentParserError.invalidOptionValue(argument: argument, type: "Int")
        }
    }
}

extension Double: OptionValue {
    public init(argument: String) throws {
        if let v = Double(argument) {
            self = v
        } else {
            throw ArgumentParserError.invalidOptionValue(argument: argument, type: "Double")
        }
    }
}
