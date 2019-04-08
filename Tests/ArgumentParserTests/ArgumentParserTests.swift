import XCTest
@testable import ArgumentParser

final class ArgumentParserTests: XCTestCase {
    func testExample() {
        let arg = ["-c", "release"]
        var c = "debug"
        let release = Option.init(short: "-c", long: "--configuration", requireValue: true, description: "build setting") { (v) in
            c = v
        }
        let parser = ArgumentParser.init(options: [release]) { (input) in
            
        }
        try! parser.parse(arguments: arg)
        XCTAssertEqual(c, "release")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
