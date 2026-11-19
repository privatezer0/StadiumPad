import Foundation

/// Typed read-only requests; edits use a separate, guarded API.
public enum ReadCommand:Equatable,Sendable {
    case tunerProperties,stompProperties,commandProperties,cloneHierarchy,autoCab,snapshotCount,product,editBuffer,editBufferBytes,activePreset,activeSnapshot,dirty,contentRef(Int),contentPath(Int),contentData(Int),container(Int)
    public func message(id:Int32)throws->OSCMessage {
        let address:String;var values:[Value]=[.int(Int64(id))]
        switch self {
        case .tunerProperties:address="/MatchingPropertyValuesGet";values.append(.string("global.tuner.*"))
        case .commandProperties:address="/MatchingPropertyValuesGet";values.append(.string("global.assign.control.*"))
        case .stompProperties:address="/MatchingPropertyValuesGet";values.append(.string("preset.floorboard.stomp.*"))
        case .cloneHierarchy:address="/GetCloneHierarchy"
        case .snapshotCount:address="/SnapshotCountGet"
        case .autoCab:address="/PropertyValueGet";values.append(.string("global.modelselect.addcabblock"))
        case .product:address="/ProductInfoGet"
        case .editBuffer,.editBufferBytes:address="/EditBufferStateGet"
        case .activePreset:address="/PropertyValueGet";values.append(.string("server.active.preset.id"))
        case .dirty:address="/PropertyValueGet";values.append(.string("volatile.preset.edited"))
        case .contentPath(let n):guard n>0,Int32(exactly:n) != nil else{throw ProtocolError.invalid("Invalid library file reference.")};address="/GetContentPath";values.append(.int(Int64(n)))
        case .contentData(let n):guard n>0,Int32(exactly:n) != nil else{throw ProtocolError.invalid("Invalid preset reference.")};address="/GetContentData";values.append(.int(Int64(n)))
        case .container(let n):guard (-25 ... -1).contains(n) || (n>0 && n<=Int(Int32.max)) else{throw ProtocolError.invalid("Unsupported preset library.")};address="/GetContainerContents";values.append(.int(Int64(n)))
        case .activeSnapshot:address="/ActiveSnapshotIndexGet"
        case .contentRef(let n):guard Int32(exactly:n) != nil else{throw ProtocolError.invalid("Invalid preset reference.")};address="/GetContentRef";values.append(.int(Int64(n)))
        }
        return OSCMessage(address,values)
    }
    public var replyAddress:String {switch self {case .tunerProperties,.stompProperties,.commandProperties:return "/getMatchingPropertyValues";case .cloneHierarchy:return "/GetCloneHierarchy";case .snapshotCount:return "/getSnapshotCount";case .autoCab:return "/getPropertyValue";case .product:return "/getProductInfo";case .editBuffer,.editBufferBytes:return "/getEditBufferState";case .activePreset,.dirty:return "/getPropertyValue";case .activeSnapshot:return "/getActiveSnapshotIndex";case .contentRef:return "/GetContentRef";case .contentPath:return "/GetContentPath";case .contentData:return "/GetContentData";case .container:return "/GetContainerContents"}}
    public func decode(_ message:OSCMessage)throws->Value {
        if case .contentPath=self {guard message.values.count==3,message.values[2].integer==0,let path=message.values[1].text,!path.isEmpty else{throw ProtocolError.invalid("Invalid library file path.")};return .string(path)}
        let position:Int
        switch self {case .product,.contentRef,.contentPath,.contentData,.container,.cloneHierarchy:position=1;case .editBuffer,.editBufferBytes,.activePreset,.dirty,.autoCab,.stompProperties,.tunerProperties,.commandProperties:position=2;case .activeSnapshot,.snapshotCount:guard message.values.count>=2,case .int=message.values[1] else{throw ProtocolError.invalid("Invalid snapshot reply.")};return message.values[1]}
        guard message.values.count>position,case .binary(let data)=message.values[position] else{throw ProtocolError.invalid("Missing Stadium reply data.")}
        if self == .editBufferBytes {return .binary(data)}
        if case .contentData=self {return .binary(data)}
        let value=try MessagePack.decode(data)
        if self == .cloneHierarchy {return value}
        if case .container=self {guard case .array=value else{throw ProtocolError.invalid("Invalid library reply.")};return value}
        guard case .object=value else{throw ProtocolError.invalid("Unexpected Stadium reply shape.")}
        return value
    }
}
public struct SignalBlock:Identifiable,Equatable,Sendable {
    public var id:String;public var path:Int;public var position:Int;public var blockID:Int;public var slot:Int;public var model:Int;public var enabled:Bool
    public var values:[Int:Value];public var harnessValues:[Int:Value]
    public var parameters:[String:String] {Dictionary(uniqueKeysWithValues:values.map{(String($0.key),$0.value.scalar)})}
    public func value(_ definition:ParameterDefinition)->Value? {definition.harness ? harnessValues[definition.id]:values[definition.id]}
}
public struct DeviceSnapshot:Sendable {
    public var origin:UUID?
    public var product:Value;public var editBuffer:Value;public var preset:Value;public var activeSnapshot:Int;public var date:Date;public var rawEditBuffer:Data;public var dirty:Bool
    public init(product:Value,editBuffer:Value,preset:Value,activeSnapshot:Int,date:Date=Date(),rawEditBuffer:Data=Data(),dirty:Bool=false,origin:UUID?=nil) {self.origin=origin;self.product=product;self.editBuffer=editBuffer;self.preset=preset;self.activeSnapshot=activeSnapshot;self.date=date;self.rawEditBuffer=rawEditBuffer;self.dirty=dirty}
    public var firmware:String {let v=product["host"]["vers"];return ["majo","mino","patc"].map{v[$0].integer.map(String.init) ?? "?"}.joined(separator:".")}
    public var presetName:String {preset["name"].text ?? "Current preset"}
    public var presetID:Int? {preset["cid_"].integer}
    public var location:PresetSlot {PresetSlot(preset)}
    public var blocks:[SignalBlock] {
        var result:[SignalBlock]=[]
        for (path,flow) in editBuffer["sfg_"]["flow"].items.enumerated() {
            let list=flow["blks"].items
            for offset in stride(from:0,to:max(0,list.count-1),by:2) {
                guard let position=list[offset].integer else{continue}
                let block=list[offset+1],blockID=block["id__"].integer ?? -1
                func parameters(_ values:[Value])->[Int:Value] {var out:[Int:Value]=[:];for value in values {if let id=value["pid_"].integer {out[id]=value["valu"]}};return out}
                for (slot,model) in block["mdls"].items.enumerated() {
                    guard let modelID=model["id__"].integer else{continue}
                    result.append(SignalBlock(id:"\(path)-\(position)-\(slot)",path:path+1,position:position,blockID:blockID,slot:slot,model:modelID,enabled:block["enbl"].integer==1,values:parameters(model["parm"].items),harnessValues:parameters(block["hrns"]["parm"].items)))
                }
            }
        };return result
    }
    public func context(for block:SignalBlock)throws->EditContext {
        guard let id=presetID else{throw ProtocolError.invalid("The preset identity is unavailable.")}
        let context=EditContext(presetID:id,snapshot:activeSnapshot,path:block.path-1,blockID:block.blockID,slot:block.slot,modelID:block.model,position:block.position,origin:origin);try context.validate();return context
    }
}
