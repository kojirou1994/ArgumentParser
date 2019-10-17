import XCTest
@testable import ArgumentParser

final class ArgumentParserTests: XCTestCase {
    func testExample() {
        let arg = ["-c", "release", "--flag", "--no-flag"]
        struct Argument: ArgumentProtocol {
            var configuration: String = "debug"
            var flag = false
            var optional: String? = nil
            var inputs: [String] = []
        }
        let parser = ArgumentParser<Argument>.init(toolName: "arg-test", overview: "none")
        
        parser.set(positionalInputKeyPath: \.inputs)
        parser.addValueOption(name: "-c", anotherName: "--configuration", description: "build setting", keypath: \.configuration)
        parser.addFlagOption(name: "-F", anotherName: "--flag", description: "enable flag", keypath: \.flag)
        parser.addFlagOption(name: "--no-flag", anotherName: nil, description: "disable flag", keypath: \.flag, setValue: false)
        parser.addOptionalValueOption(name: "-O", anotherName: "--optional", description: "test optional", keypath: \.optional)
        print(try! parser.parse(arguments: arg))
        var s = ""
        parser.showHelp(to: &s)
        print(s)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
