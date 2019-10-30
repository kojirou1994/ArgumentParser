public enum ArgumentParserError: Error, CustomStringConvertible {
    case noRequiredValue(String)
    case unknownOption(String)
    case unallowedPositionalInput(String)
    case invalidSubcommand(String)
    case unallowedSubcommandArguments([String])
    case invalidOptionValue(argument: String, type: String)
    case extraPositionalInput(String)
    
    public var description: String {
        switch self {
        case .extraPositionalInput(let v):
            return "More than one input which is not allowed: \(v)."
        case .invalidOptionValue(let argument, let type):
            return "The argument \"\(argument)\" cannot be parsed to destination type \(type)."
        case .invalidSubcommand(let v):
            return "Unallowd subcommand: \(v)."
        case .noRequiredValue(let v):
            return "No required value for argument \(v)."
        case .unallowedPositionalInput(let v):
            return "Unallowed input: \(v)."
        case .unallowedSubcommandArguments(let v):
            return "Option for subcommand is not allowed: \(v)"
        case .unknownOption(let v):
            return "Unallowed option: \(v)"
        }
    }
}

public struct ArgumentParserOptions: OptionSet {
    public let rawValue: Int
    
    public init(rawValue: Int) { self.rawValue = rawValue }
    
//    public static let acceptUnknownOption = Self.init(rawValue: 1 << 0)
    
//    public static let trimWhitespaces = Self.init(rawValue: 1 << 1)
    
//    public static let dropEmptyArgument = Self.init(rawValue: 1 << 1)
}

public final class ArgumentParser<Argument: ArgumentProtocol> {
    
    private var _options = [_Option]()
    
    public let toolName: String
    
    public let overview: String
    
    public let inputName: String
    
    private var positionalMode: PositionalMode?
    
    private let defaultValue: Argument
    
    private typealias SubCommandHandler = (_ command: String, _ commandArguments: [String], _ argument: inout Argument) throws -> Void
    
    private enum PositionalMode {
        case subcommand(SubCommandHandler, information: [String: String])
        case positionalInputs(WritableKeyPath<Argument, [String]>)
        case singleInput(WritableKeyPath<Argument, String>)
    }
    
    public func generateSubparser<T: ArgumentProtocol, C: SubCommand>(type: T.Type, command: C, inputName: String) -> ArgumentParser<T> {
        return .init(toolName: self.toolName + " " + command.command, overview: command.description, inputName: inputName)
    }
    
    public func set(positionalInputKeyPath: WritableKeyPath<Argument, [String]>) {
        positionalMode = .positionalInputs(positionalInputKeyPath)
    }
    
    public func set(singleInputKeyPath: WritableKeyPath<Argument, String>) {
        positionalMode = .singleInput(singleInputKeyPath)
    }
    
    public func set<C: SubCommand>(commandKeyPath: WritableKeyPath<Argument, C>) {
        positionalMode = .subcommand({ (commandString, commandArguments, arg) in
            do {
                let command = try C.init(argument: commandString)
                arg[keyPath: commandKeyPath] = command
            } catch {
                throw ArgumentParserError.invalidSubcommand(commandString)
            }
            if !commandArguments.isEmpty {
                throw ArgumentParserError.unallowedSubcommandArguments(commandArguments)
            }
        }, information: C.informationDictionary)
    }
    
    public func set<C: SubCommand>(commandKeyPath: WritableKeyPath<Argument, C?>) {
        positionalMode = .subcommand({ (commandString, commandArguments, arg) in
            do {
                let command = try C.init(argument: commandString)
                arg[keyPath: commandKeyPath] = command
            } catch {
                throw ArgumentParserError.invalidSubcommand(commandString)
            }
            if !commandArguments.isEmpty {
                throw ArgumentParserError.unallowedSubcommandArguments(commandArguments)
            }
        }, information: C.informationDictionary)
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
    
    public func set<C: SubCommand>(commandKeyPath: WritableKeyPath<Argument, C?>, argumentKeyPath: WritableKeyPath<Argument, [String]>) {
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
    
    private struct _Option {
        let name: String
        let anotherName: String?
        let requireValue: Bool
        let description: String
        let category: String?
        let defaultValue: String?
        let valueHandler: OptionValueHandler
        
        init(name: String, anotherName: String? = nil, requireValue: Bool,
             description: String, category: String?, defaultValue: String?,
             valueHandler: @escaping OptionValueHandler) {
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
            self.category = category
            self.defaultValue = defaultValue
        }
    }
    
    public init(toolName: String, overview: String, inputName: String = "INPUT") {
        self.toolName = toolName
        self.overview = overview
        self.inputName = inputName
        self.defaultValue = .init()
    }
    
    public typealias OptionValueHandler = (_ value: String, _ argument: inout Argument) throws -> Void
    
    public func parse<C>(arguments: C) throws -> Argument
    where C: Sequence, C.Element == String {
        // prepare options
        var dic = [String : _Option]()
        for a in _options {
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
    
    public func addOption(name: String, anotherName: String?, requireValue: Bool,
                          description: String, category: String? = nil, defaultValue: String? = nil,
                          handler: @escaping OptionValueHandler) {
        _options.append(.init(name: name, anotherName: anotherName, requireValue: requireValue, description: description, category: category, defaultValue: defaultValue, valueHandler: handler))
    }
    
    public func addOptionWrapper<V: ValueOption>(keypath: WritableKeyPath<Argument, OptionWrapper<V>>) {
        let defaultWrapper = defaultValue[keyPath: keypath]
        addOption(name: defaultWrapper.name, anotherName: defaultWrapper.anotherName, requireValue: true,
                  description: defaultWrapper.description, category: defaultWrapper.category,
                  defaultValue: defaultWrapper.showDefault ? String(describing: defaultWrapper.defaultValue) : nil) { (v, arg) in
            arg[keyPath: keypath].wrappedValue = try .init(argument: v)
        }
    }
    
    public func addValueOption<V: ValueOption>(
        name: String, anotherName: String?, description: String,
        category: String? = nil, showDefault: Bool = false,
        keypath: WritableKeyPath<Argument, V>) {
        addOption(name: name, anotherName: anotherName, requireValue: true,
                  description: description, category: category,
                  defaultValue: showDefault ? String(describing: defaultValue[keyPath: keypath]) : nil) { (v, arg) in
            arg[keyPath: keypath] = try .init(argument: v)
        }
    }
    
//    public func addValueOption<V: ValueOption>(
//        name: String, anotherName: String?, description: String,
//        category: String? = nil, showDefault: Bool = false,
//        keypath: WritableKeyPath<Argument, V?>) {
//        let dv: String?
//        if showDefault {
//            if let v = defaultValue[keyPath: keypath] {
//                dv = String(describing: v)
//            } else {
//                dv = "nil"
//            }
//        } else {
//            dv = nil
//        }
//        addOption(name: name, anotherName: anotherName, requireValue: true,
//                  description: description, category: category,
//                  defaultValue: dv) { (v, arg) in
//            arg[keyPath: keypath] = try .init(argument: v)
//        }
//    }
    
    public func addArrayValueOption<V: ValueOption>(name: String, anotherName: String?, description: String, keypath: WritableKeyPath<Argument, [V]>) {
        addOption(name: name, anotherName: anotherName, requireValue: true, description: description) { (v, arg) in
            arg[keyPath: keypath].append(try .init(argument: v))
        }
    }
    
    public func addFlagOption(
        name: String, anotherName: String?, description: String,
        category: String? = nil, showDefault: Bool = false,
        keypath: WritableKeyPath<Argument, Bool>, setValue: Bool = true) {
        addOption(name: name, anotherName: anotherName, requireValue: false,
                  description: description, category: category,
                  defaultValue: showDefault ? String(describing: defaultValue[keyPath: keypath]) : nil) { (_, arg) in
            arg[keyPath: keypath] = setValue
        }
    }
    
    @usableFromInline
    internal func generateUsage() -> String {
        var r = toolName
        if !_options.isEmpty {
            r += " [OPTION]"
        }
        switch positionalMode {
        case .subcommand(_):
            r += " COMMAND [COMMAND_OPTION]"
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
        let width = 24
        
        func printOptions(_ v: [_Option], category: String?) {
            if v.isEmpty {
                return
            }
            let sortedOptions = v.sorted(by: {$0.name < $1.name})
            if let c = category {
                output.write(c)
                output.write(" ")
            }
            output.write("OPTIONS:\n")
            sortedOptions.forEach { (opt) in
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
                if let dv = opt.defaultValue {
                    output.write(" [default: \(dv)]")
                }
                output.write("\n")
            }
            
            output.write("\n")
        }
        
        var categoryOpts = [String: [_Option]]()
        var generalOpts = [_Option]()
        
        for opt in self._options {
            if let c = opt.category {
                categoryOpts[c, default: .init()].append(opt)
            } else {
                generalOpts.append(opt)
            }
        }
        
        output.write("OVERVIEW: \(overview)\n\n")
        output.write("USAGE: \(generateUsage())\n\n")
        
        printOptions(generalOpts, category: nil)
        for category in categoryOpts.keys.sorted() {
            printOptions(categoryOpts[category] ?? [], category: category)
        }
        
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

