public enum ArgumentParserError: Error {
    case noRequiredValue(String)
    case unknownOption(String)
    case unallowedPositionalInput(String)
    case invalidSubcommand(String)
    case invalidOptionValue(argument: String, type: String)
    case extraPositionalInput(String)
}


public struct ArgumentParserOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) { self.rawValue = rawValue }
    
//    public static let acceptUnknownOption = Self.init(rawValue: 1 << 0)
}

public final class ArgumentParser<Argument: ArgumentProtocol> {
    
    private var options = [Option]()
    
    public let toolName: String
    
    public let overview: String
    
    public let inputName: String
    
    private var positionalMode: PositionalMode?
    
    private typealias SubCommandHandler = (_ command: String, _ commandArguments: [String], _ argument: inout Argument) throws -> Void
    
    private enum PositionalMode {
        case subcommand(SubCommandHandler, information: [String: String])
        case positionalInputs(WritableKeyPath<Argument, [String]>)
        case singleInput(WritableKeyPath<Argument, String>)
    }
    
    public func set(positionalInputKeyPath: WritableKeyPath<Argument, [String]>) {
        positionalMode = .positionalInputs(positionalInputKeyPath)
    }
    
    public func set(singleInputKeyPath: WritableKeyPath<Argument, String>) {
        positionalMode = .singleInput(singleInputKeyPath)
    }
    
    public func set<C: SubCommand>(commandKeyPath: WritableKeyPath<Argument, C>, argumentKeyPath: WritableKeyPath<Argument, [String]>) {
        positionalMode = .subcommand({ (commandString, commandArguments, arg) in
            do {
                let command = try C.init(argument: commandString)
                arg[keyPath: commandKeyPath] = command
                arg[keyPath: argumentKeyPath] = commandArguments
            } catch {
                throw ArgumentParserError.invalidSubcommand(commandString)
            }
        }, information: C.informationDictionary)
    }
    
    private struct Option {
        let name: String
        let anotherName: String?
        let requireValue: Bool
        let description: String
        let valueHandler: OptionValueHandler
        
        init(name: String, anotherName: String? = nil, requireValue: Bool, description: String, valueHandler: @escaping OptionValueHandler) {
            assert(!name.isEmpty)
            assert(name.hasPrefix("-"))
            if anotherName != nil {
                assert(!anotherName!.isEmpty)
                assert(anotherName!.hasPrefix("-"))
            }
            self.name = name
            self.anotherName = anotherName
            self.requireValue = requireValue
            self.description = description
            self.valueHandler = valueHandler
        }
    }
    
    public init(toolName: String, overview: String, inputName: String = "INPUT") {
        self.toolName = toolName
        self.overview = overview
        self.inputName = inputName
    }
    
    public typealias OptionValueHandler = (_ value: String, _ argument: inout Argument) throws -> Void
    
    public func parse<C>(arguments: C) throws -> Argument
    where C: Sequence, C.Element == String {
        // prepare options
        var dic = [String : Option]()
        for a in options {
            assert(dic[a.name] == nil, "duplicate argument: \(a.name)")
            dic[a.name] = a
            if let anotherName = a.anotherName {
                assert(dic[anotherName] == nil, "duplicate argument: \(anotherName)")
                dic[anotherName] = a
            }
        }
        
        var result = Argument()
        var hasSingleInput = false
        
        var iterator = arguments.makeIterator()
        while let currentArgument = iterator.next() {
            if let option = dic[currentArgument] {
                if option.requireValue {
                    if let v = iterator.next() {
                        try option.valueHandler(v, &result)
                    } else {
                        throw ArgumentParserError.noRequiredValue(currentArgument)
                    }
                } else {
                    try option.valueHandler(currentArgument, &result)
                }
            } else if currentArgument.hasPrefix("-") {
                throw ArgumentParserError.unknownOption(currentArgument)
            } else if let positionalMode = self.positionalMode {
                switch positionalMode {
                case .positionalInputs(let inputKeyPath):
                    result[keyPath: inputKeyPath].append(currentArgument)
                case .subcommand(let handler, information: _):
                    var commandArguments = [String]()
                    while let v = iterator.next() {
                        commandArguments.append(v)
                    }
                    try handler(currentArgument, commandArguments, &result)
                case .singleInput(let inputKeyPath):
                    if hasSingleInput {
                        throw ArgumentParserError.extraPositionalInput(currentArgument)
                    }
                    result[keyPath: inputKeyPath] = currentArgument
                    hasSingleInput = true
                }
            } else {
                throw ArgumentParserError.unallowedPositionalInput(currentArgument)
            }
        }
        return result
    }
    
    public func addOption(name: String, anotherName: String?, requireValue: Bool, description: String, handler: @escaping OptionValueHandler) {
        options.append(.init(name: name, anotherName: anotherName, requireValue: requireValue, description: description, valueHandler: handler))
    }
    
    public func addValueOption<V: ValueOption>(name: String, anotherName: String?, description: String, keypath: WritableKeyPath<Argument, V>) {
        addOption(name: name, anotherName: anotherName, requireValue: true, description: description) { (v, arg) in
            arg[keyPath: keypath] = try .init(argument: v)
        }
    }
    
    public func addArrayValueOption<V: ValueOption>(name: String, anotherName: String?, description: String, keypath: WritableKeyPath<Argument, [V]>) {
        addOption(name: name, anotherName: anotherName, requireValue: true, description: description) { (v, arg) in
            arg[keyPath: keypath].append(try .init(argument: v))
        }
    }
    
    public func addValueOption<V: ValueOption>(name: String, anotherName: String?, description: String, keypath: WritableKeyPath<Argument, V?>) {
        addOption(name: name, anotherName: anotherName, requireValue: true, description: description) { (v, arg) in
            arg[keyPath: keypath] = try .init(argument: v)
        }
    }
    
    public func addFlagOption(name: String, anotherName: String?, description: String, keypath: WritableKeyPath<Argument, Bool>, setValue: Bool = true) {
        addOption(name: name, anotherName: anotherName, requireValue: false, description: description) { (_, arg) in
            arg[keyPath: keypath] = setValue
        }
    }
    
    @usableFromInline
    internal func generateUsage() -> String {
        var r = toolName
        if !options.isEmpty {
            r += " [OPTION]"
        }
        switch positionalMode {
        case .subcommand(_):
            r += " COMMAND"
        case .positionalInputs(_):
            r += " [\(inputName)]"
        case .singleInput(_):
            r += " \(inputName)"
        default:
            break
        }
        return r
    }
    
    @inlinable
    public func showHelp<Target: TextOutputStream>(to output: Target) {
        var output = output
        showHelp(to: &output)
    }
    
    public func showHelp<Target: TextOutputStream>(to output: inout Target) {
        let options = self.options.sorted(by: {$0.name < $1.name})
        let width = 24
        
        output.write("OVERVIEW: \(overview)\n\n")
        output.write("USAGE: \(generateUsage())\n\n")
        output.write("OPTIONS:\n")
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
            output.write("\n")
        }
        output.write("\n")
        
        if case .subcommand(_, let information) = positionalMode {
            output.write("SUBCOMMANDS:\n")
            for (command, des) in information.sorted(by: {$0.key < $1.key}) {
                output.write("  \(command)")
                var padding = width-command.count
                if padding <= 1 {
                    padding = width
                    output.write("\n  ")
                }
                for _ in 0..<padding {
                    output.write(" ")
                }
                output.write(des)
                output.write("\n")
            }
        }
    }
    
}

