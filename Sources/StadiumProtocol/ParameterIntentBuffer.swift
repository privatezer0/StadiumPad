import Foundation

/// Latest explicit user intent per control, scoped to a single confirmed edit run.
/// This buffer is discarded on failure/disconnect; it never retries a sent edit.
public struct ParameterIntentBuffer:Sendable {
    public struct Intent:Sendable {
        public let context:EditContext,definition:ParameterDefinition,value:Value,expected:Value
        public var key:String {ParameterIntentBuffer.key(context,definition)}
    }
    private var pending:[Intent]=[]
    private var acknowledged:[String:Value]=[:]
    public init(){}
    public static func key(_ c:EditContext,_ p:ParameterDefinition)->String {"\(c.origin?.uuidString ?? "")/\(c.presetID)/\(c.snapshot)/\(c.path)/\(c.blockID)/\(c.position)/\(c.slot)/\(c.modelID)/\(p.identity)"}
    public mutating func append(context:EditContext,definition:ParameterDefinition,value:Value,expected:Value)throws {
        try context.validate();let wire=try definition.validated(value)
        let next=Intent(context:context,definition:definition,value:wire,expected:expected)
        if let index=pending.firstIndex(where:{$0.key==next.key}) {pending[index]=Intent(context:context,definition:definition,value:wire,expected:pending[index].expected)}
        else {guard pending.count<32 else{throw ProtocolError.invalid("Too many pending controls. Wait for the current edits.")};pending.append(next)}
    }
    public mutating func take()->Intent? {
        guard !pending.isEmpty else{return nil};let item=pending.removeFirst()
        return Intent(context:item.context,definition:item.definition,value:item.value,expected:acknowledged[item.key] ?? item.expected)
    }
    public mutating func confirmed(_ intent:Intent){acknowledged[intent.key]=intent.value}
    public mutating func clear(){pending=[];acknowledged=[:]}
}
