import Foundation

public enum EditCommand:Sendable {
    case parameter(EditContext,ParameterDefinition,Value)
    case tuner(Bool)
    case controller(Int,Int),model(EditContext,Int),snapshot(Int),copySnapshot(Int,Int)
    case save(Int),load(Int),createUser(position:Int,name:String),storeNewPreset(Int,Data)
    public func message(id:Int32)throws->OSCMessage {
        var values:[Value]=[.int(Int64(id))];let address:String
        switch self {
        case .parameter(let context,let definition,let value):
            try context.validate();let wire=try definition.validated(value)
            if definition.harness {
                address="/HarnessParamValueSet";values += [.int(Int64(context.path)),.int(Int64(context.position)),.int(Int64(definition.id)),wire,.int(-1)]
            } else {
                address="/ParamValueSet";values += [.int(Int64(context.path)),.int(Int64(context.position)),.int(Int64(context.slot)),.int(Int64(definition.id)),wire,.int(-1)]
            }
        case .tuner(let enabled):
            let key=enabled ? "volatile.held.taptempo":"volatile.press.exittuner"
            var blob=Data("lavppgsm".utf8);blob.append(0x83)
            for (field,value) in [(Int64(0x6b65795f),Value.string(key)),(Int64(0x74797065),Value.string("i")),(Int64(0x76616c5f),Value.int(11))] {blob.append(try MessagePack.encode(.int(field)));blob.append(try MessagePack.encode(value))}
            address="/PropertyValueSet";values += [.int(0),.binary(blob)]
        case .controller(let controller,let value):
            try Self.validID(controller);guard value==0 || value==1 else{throw ProtocolError.invalid("Invalid switch input.")}
            address="/ControllerValueSet";values += [.int(Int64(controller)),.number(Double(value))]
        case .model(let context,let model):
            try context.validate();guard (1...13).contains(context.position%14),model>=0,model<=Int(Int32.max) else{throw ProtocolError.invalid("Choose an effect block and a valid model.")}
            address="/ModelSet";values += [.int(Int64(context.path)),.int(Int64(context.position)),.int(Int64(context.slot)),.int(Int64(model))]
        case .snapshot(let index):
            guard (0..<8).contains(index) else{throw ProtocolError.invalid("Invalid snapshot.")};address="/activateSnapshot";values += [.int(Int64(index)),.int(0)]
        case .copySnapshot(let source,let target):
            guard (0..<8).contains(source),(0..<8).contains(target),source != target else{throw ProtocolError.invalid("Invalid snapshot copy.")};address="/CopySnapshot";values += [.int(Int64(source)),.int(Int64(target))]
        case .save(let content):try Self.validID(content);address="/SavePresetWithCID";values += [.int(Int64(content)),.int(-1),.int(-1)]
        case .load(let content):try Self.validID(content);address="/LoadPresetWithCID";values.append(.int(Int64(content)))
        case .createUser(let position,let draft):
            guard (0..<512).contains(position) else{throw ProtocolError.invalid("Choose an empty User preset location.")}
            let name=try Self.validName(draft)
            let attrs=try MessagePack.encode(.object(["blck":.int(-1),"colr":.int(0),"dvcp":.string("ALL"),"flow":.int(-1),"name":.string(name)]))
            address="/CreateContent";values += [.int(-2),.int(Int64(position)),.int(2),.binary(attrs)]
        case .storeNewPreset(let content,let bytes):
            try Self.validID(content);guard bytes.count>8,bytes.starts(with:Data("_sbepgsm".utf8)) else{throw ProtocolError.invalid("Unrecognized native preset body.")}
            _ = try MessagePack.decode(bytes);address="/SetContentData";values += [.int(Int64(content)),.binary(bytes)]
        }
        return OSCMessage(address,values)
    }
    static func validID(_ id:Int)throws {guard id>0,id<=Int(Int32.max) else{throw ProtocolError.invalid("Invalid saved preset destination.")}}
    public static func validName(_ draft:String)throws->String {
        let name=draft.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty,name.unicodeScalars.count<=32,!name.unicodeScalars.contains(where:{$0.value<32 || $0.value==127}) else{throw ProtocolError.invalid("Enter a preset name from 1 to 32 characters.")};return name
    }
    public static func acknowledge(_ message:OSCMessage)throws {
        guard message.address=="/status",message.values.count>=3,message.values[1].integer==0,let result=message.values[2].integer,result>=0 else{throw ProtocolError.invalid("The Stadium did not confirm the operation. Check the device before trying again.")}
    }
    public static func allocatedID(_ message:OSCMessage)throws->Int {
        guard message.address=="/status",message.values.count>=3,let id=message.values[1].integer,id>0,id<=Int(Int32.max),let result=message.values[2].integer,result>=0 else{throw ProtocolError.invalid("Preset creation was not confirmed. Check the location before retrying.")};return id
    }
}
public func sameParameterValue(_ a:Value,_ b:Value)->Bool {
    if a==b{return true}
    if let a=a.numeric,let b=b.numeric {return a.isFinite && b.isFinite && abs(a-b)<=0.00005*max(1,abs(b))}
    if let a=a.boolean,let b=b.boolean {return a==b}
    return false
}
