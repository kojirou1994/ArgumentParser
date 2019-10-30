import Foundation

@propertyWrapper
public struct OptionWrapper<Value: ValueOption> {
    
    public let name: String
    public let anotherName: String?
    public let description: String
    public let category: String?
    public let showDefault: Bool
    
    public let defaultValue: Value
    public var wrappedValue: Value
    
    public init(name: String, anotherName: String? = nil, description: String, category: String? = nil, defaultValue: Value, showDefault: Bool = false) {
        self.name = name
        self.anotherName = anotherName
        self.description = description
        self.category = category
        self.showDefault = showDefault
        
        self.wrappedValue = defaultValue
        self.defaultValue = defaultValue
    }
    
    public var projectedValue: Self {
        get {
            return self
        }
        set {
            self = newValue
        }
    }
}
