import XCTest
@testable import ArgumentParser

final class ArgumentParserTests: XCTestCase {
    func testExample() {
        let arg = ["-c", "release", "--flag", "--no-flag", "--wrapper", "100"]
        struct Argument: ArgumentProtocol {
            var configuration: String = "debug"
            var flag = false
            var optional: String? = nil
            var inputs: [String] = []
            @OptionWrapper(name: "--wrapper", anotherName: "-W", description: "introduction", category: "Wrapper", defaultValue: 0, showDefault: true)
            var wrapper: Int
        }
        let parser = ArgumentParser<Argument>.init(toolName: "arg-test", overview: "none")
        
        parser.set(positionalInputKeyPath: \.inputs)
        parser.addOptionWrapper(keypath: \.$wrapper)
        parser.addValueOption(name: "-c", anotherName: "--configuration", description: "build setting", showDefault: true, keypath: \.configuration)
        parser.addFlagOption(name: "-F", anotherName: "--flag", description: "enable flag", keypath: \.flag)
        parser.addFlagOption(name: "--no-flag", anotherName: nil, description: "disable flag", category: "CANCEL", keypath: \.flag, setValue: false)
        parser.addValueOption(name: "-O", anotherName: "--optional", description: "test optional", showDefault: true, keypath: \.optional)
        print(try! parser.parse(arguments: arg))
        var s = ""
        parser.showHelp(to: &s)
        print(s)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
