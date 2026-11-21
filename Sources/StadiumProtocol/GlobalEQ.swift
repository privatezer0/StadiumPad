import Foundation

public enum EQOutput:Int,CaseIterable,Codable,Sendable {
    case quarter,xlr,phones
    public var key:String {["_qtr","_xlr","_pho"][rawValue]}
    public var wire:String {["qtr","xlr","phones"][rawValue]}
    public var name:String {["1/4\"","XLR","Phones"][rawValue]}
}
public enum EQBand:Int,CaseIterable,Codable,Sendable {
    case lowCut,lowShelf,low,mid,high,highShelf,highCut
    public var wire:String {["lowcut","lowshelf","low","mid","high","highshelf","highcut"][rawValue]}
    public var name:String {["Low Cut","Low Shelf","Low","Mid","High","High Shelf","High Cut"][rawValue]}
    public var parameters:[EQParameter] {switch self {case .lowCut,.highCut:return [.enable,.frequency,.slope];case .lowShelf,.highShelf:return [.enable,.frequency,.gain];default:return [.enable,.frequency,.gain,.q]}}
}
public enum EQParameter:Int,CaseIterable,Codable,Sendable {
    case enable=1,frequency,gain,q,slope,level
    public var name:String {switch self {case .enable:return "Enable";case .frequency:return "Frequency";case .gain:return "Gain";case .q:return "Q";case .slope:return "Slope";case .level:return "Level"}}
    public var range:ClosedRange<Double> {switch self {case .enable:return 0...1;case .frequency:return 20...20000;case .gain:return -24...24;case .q:return 0.1...20;case .slope:return 0...3;case .level:return -60...12}}
    public func validated(_ value:Value)throws->Value {
        if self == .enable {guard let flag=value.boolean else{throw ProtocolError.invalid("Invalid EQ switch value.")};return .bool(flag)}
        guard let number=value.numeric,number.isFinite,range.contains(number) else{throw ProtocolError.invalid("EQ \(name) is outside its native range.")}
        if self == .slope {guard let n=Int32(exactly:number) else{throw ProtocolError.invalid("Choose an EQ slope.")};return .int(Int64(n))}
        return .number(Double(Float(number)))
    }
    public func display(_ value:Value)->String {
        guard let n=value.numeric else{return value.boolean==true ? "On":"Off"}
        switch self {case .frequency:return n>=1000 ? String(format:"%.1f kHz",n/1000):String(format:"%.0f Hz",n);case .gain,.level:return String(format:"%.1f dB",n);case .q:return String(format:"%.1f",n);case .slope:return "\((Int(n)+1)*6) dB/octave";case .enable:return n==0 ? "Off":"On"}
    }
}
public struct GlobalEQState:Sendable {
    public let origin:UUID?;public let value:Value;public let raw:Data
    public init(value:Value,origin:UUID?=nil,raw:Data=Data())throws {
        guard Set(value.object.keys)==Set(["_qtr","_xlr","_pho","anyl","post"]),value["anyl"].integer != nil,value["post"].integer != nil else{throw ProtocolError.invalid("Unsupported Global EQ state. Refresh before editing.")}
        for output in EQOutput.allCases {_ = try Self.validateOutput(value[output.key],output:output)}
        self.value=value;self.origin=origin;self.raw=raw
    }
    public func output(_ output:EQOutput)->Value {value[output.key]}
    public func parameter(_ output:EQOutput,_ band:EQBand,_ parameter:EQParameter)->Value {Self.parameter(in:value[output.key],band:band,parameter:parameter)}
    public static func parameter(in output:Value,band:EQBand,parameter:EQParameter)->Value {
        if parameter == .level {return output["olvl"]["valu"]}
        return output["eqbs"].items.first{$0["band"].integer==band.rawValue}?["para"].items.first{$0["parm"].integer==parameter.rawValue}?["valu"] ?? .null
    }
    public static func defaults(_ output:EQOutput,enabled:Bool=false)->Value {
        let frequencies:[Double]=[20,80,150,2000,5000,8000,20000]
        let bands=EQBand.allCases.map {band in Value.object(["band":.int(Int64(band.rawValue)),"para":.array(band.parameters.map {p in
            let v:Value
            switch p {case .enable:v = .bool(true);case .frequency:v = .number(frequencies[band.rawValue]);case .gain,.level:v = .number(0);case .q:v = .number(Double(Float(0.707)));case .slope:v = .int(1)}
            return .object(["parm":.int(Int64(p.rawValue)),"valu":v])
        })])}
        return .object(["out_":.int(Int64(output.rawValue)),"enab":.bool(enabled),"drty":.bool(false),"eqbs":.array(bands),"olvl":.object(["parm":.int(3),"valu":.number(0)])])
    }
    @discardableResult public static func validateOutput(_ value:Value,output:EQOutput)throws->Value {
        guard Set(value.object.keys)==Set(["out_","enab","drty","eqbs","olvl"]),value["out_"].integer==output.rawValue,value["enab"].boolean != nil,value["drty"].boolean != nil,value["eqbs"].items.count==7,Set(value["eqbs"].items.compactMap{$0["band"].integer})==Set(0..<7),Set(value["olvl"].object.keys)==Set(["parm","valu"]),value["olvl"]["parm"].integer==3 else{throw ProtocolError.invalid("The complete EQ output is unavailable or has unknown fields. Nothing was changed.")}
        _ = try EQParameter.level.validated(value["olvl"]["valu"])
        for band in EQBand.allCases {
            guard let row=value["eqbs"].items.first(where:{$0["band"].integer==band.rawValue}),Set(row.object.keys)==Set(["band","para"]),row["para"].items.count==band.parameters.count,Set(row["para"].items.compactMap{$0["parm"].integer})==Set(band.parameters.map(\.rawValue)) else{throw ProtocolError.invalid("The EQ band is incomplete.")}
            for p in band.parameters {guard let row=row["para"].items.first(where:{$0["parm"].integer==p.rawValue}),Set(row.object.keys)==Set(["parm","valu"]) else{throw ProtocolError.invalid("Unknown EQ parameter fields.")};_ = try p.validated(row["valu"])}
        };return value
    }
    public static func sameOutput(_ a:Value,_ b:Value,ignoreEnabled:Bool=false)->Bool {
        guard ignoreEnabled || a["enab"].boolean==b["enab"].boolean else{return false}
        for band in EQBand.allCases {for p in band.parameters {let x=parameter(in:a,band:band,parameter:p),y=parameter(in:b,band:band,parameter:p);if p == .enable {if x.boolean != y.boolean {return false}}else if !sameParameterValue(x,y){return false}}}
        return sameParameterValue(a["olvl"]["valu"],b["olvl"]["valu"])
    }
    public static func isTransition(_ value:Value,from before:Value,to desired:Value)->Bool {
        guard [before["enab"].boolean,desired["enab"].boolean].contains(value["enab"].boolean) else{return false}
        for band in EQBand.allCases {for p in band.parameters+[.level] {
            let current=parameter(in:value,band:band,parameter:p),a=parameter(in:before,band:band,parameter:p),b=parameter(in:desired,band:band,parameter:p)
            if p == .enable {guard current.boolean==a.boolean || current.boolean==b.boolean else{return false}}
            else {guard sameParameterValue(current,a) || sameParameterValue(current,b) else{return false}}
        }};return true
    }
    public func sameSettings(_ other:GlobalEQState)->Bool {EQOutput.allCases.allSatisfy{Self.sameOutput(output($0),other.output($0))} && value["anyl"]==other.value["anyl"] && value["post"]==other.value["post"]}
}
public struct GlobalEQChange:Sendable {
    public let band:EQBand;public let parameter:EQParameter;public let value:Value
    public init(_ band:EQBand,_ parameter:EQParameter,_ value:Value){self.band=band;self.parameter=parameter;self.value=value}
    public var id:String {"\(band.rawValue)-\(parameter.rawValue)"}
}
public enum GlobalEQOperation:Sendable {
    case parameters([GlobalEQChange]),parameter(EQBand,EQParameter,Value),enabled(Bool),replace(Value),reset
    public func applying(to state:GlobalEQState,output:EQOutput)throws->GlobalEQState {
        var root=state.value.object,target=root[output.key]!.object
        switch self {
        case .parameters(let changes):
            guard !changes.isEmpty,changes.count<=32,Set(changes.map(\.id)).count==changes.count else{throw ProtocolError.invalid("Invalid EQ gesture batch.")};var result=state;for change in changes {result=try GlobalEQOperation.parameter(change.band,change.parameter,change.value).applying(to:result,output:output)};return result
        case .enabled(let enabled):target["enab"] = .bool(enabled)
        case .reset:target=GlobalEQState.defaults(output,enabled:target["enab"]?.boolean==true).object
        case .replace(let copied):
            guard let original=EQOutput(rawValue:copied["out_"].integer ?? -1) else{throw ProtocolError.invalid("Invalid copied EQ.")};try GlobalEQState.validateOutput(copied,output:original)
            // Native Paste copies the source bypass state along with its bands.
            target=copied.object;target["out_"] = .int(Int64(output.rawValue))
        case .parameter(let band,let p,let value):
            let wire=try p.validated(value)
            if p == .level {target["olvl"] = .object(["parm":.int(3),"valu":wire])}
            else {guard band.parameters.contains(p) else{throw ProtocolError.invalid("This EQ band does not have that control.")};target["eqbs"] = .array(target["eqbs"]!.items.map {row in guard row["band"].integer==band.rawValue else{return row};var row=row.object;row["para"] = .array(row["para"]!.items.map {parameter in guard parameter["parm"].integer==p.rawValue else{return parameter};return .object(["parm":.int(Int64(p.rawValue)),"valu":wire])});return .object(row)})}
        }
        target["drty"] = .bool(!GlobalEQState.sameOutput(.object(target),GlobalEQState.defaults(output),ignoreEnabled:true));root[output.key] = .object(target)
        return try GlobalEQState(value:.object(root),origin:state.origin)
    }
    /// Match the desktop's live gesture messages. Whole-output replacement is
    /// reserved for native Paste/Reset, not used as a substitute for a parameter edit.
    public func liveUpdates(in state:GlobalEQState,output:EQOutput)throws->[EQDSPUpdate] {
        let desired=try applying(to:state,output:output),prefix="dsp.globaleq."+output.wire
        switch self {
        case .parameters(let changes):return try changes.flatMap{try GlobalEQOperation.parameter($0.band,$0.parameter,$0.value).liveUpdates(in:state,output:output)}
        case .parameter(let band,let parameter,_):
            let value=desired.parameter(output,band,parameter)
            if parameter == .level {return [EQDSPUpdate(key:prefix+".level",value:value)]}
            let suffix:[EQParameter:String] = [.enable:"enable",.frequency:"freq",.gain:"gain",.q:"q",.slope:"slope"]
            return [EQDSPUpdate(key:prefix+"."+band.wire+"."+suffix[parameter]!,value:.object(["parm":.int(Int64(parameter.rawValue)),"valu":value]))]
        case .enabled:return [EQDSPUpdate(key:prefix+".enable",value:desired.output(output)["enab"])]
        case .replace,.reset:return [EQDSPUpdate(key:prefix,value:desired.output(output))]
        }
    }
    public static func propertyMessage(key:String,value:Value,id:Int32)throws->OSCMessage {
        guard key=="globals.eq" || EQOutput.allCases.contains(where:{key=="dsp.globaleq."+$0.wire}) else{throw ProtocolError.invalid("Unsupported Global EQ property.")}
        if key=="globals.eq" {_ = try GlobalEQState(value:value)}
        else if let output=EQOutput.allCases.first(where:{key=="dsp.globaleq."+$0.wire}) {try GlobalEQState.validateOutput(value,output:output)}
        return try encodeProperty(key:key,value:value,id:id)
    }
    fileprivate static func encodeProperty(key:String,value:Value,id:Int32)throws->OSCMessage {
        let payload:Value = .object(["key_":.string(key),"type":.string("v"),"val_":value])
        var blob=Data("lavppgsm".utf8);blob.append(try nativeEncode(payload))
        return OSCMessage("/PropertyValueSet",[.int(Int64(id)),.int(0),.binary(blob)])
    }
    /// Only validated EQ settings use numeric FourCC keys; never native preset bodies.
    static func nativeEncode(_ value:Value)throws->Data {
        switch value {
        case .object(let map):
            guard map.count<16 else{throw ProtocolError.invalid("EQ object too large.")};var bytes=Data([0x80|UInt8(map.count)])
            for key in map.keys.sorted(){guard key.utf8.count==4 else{throw ProtocolError.invalid("Unknown native EQ key.")};let code=key.utf8.reduce(UInt32(0)){($0<<8)|UInt32($1)};bytes.append(0xce);bytes.appendBE(code);bytes.append(try nativeEncode(map[key]!))};return bytes
        case .array(let values):guard values.count<16 else{throw ProtocolError.invalid("EQ array too large.")};var bytes=Data([0x90|UInt8(values.count)]);for value in values {bytes.append(try nativeEncode(value))};return bytes
        default:return try MessagePack.encode(value)
        }
    }
}

/// Observed native property broadcasts; no guessed OSC writes are generated here.
public enum GlobalEQUpdate:Sendable {
    case sync(Value),output(EQOutput,GlobalEQOperation)
    public static func decode(_ message:OSCMessage)->GlobalEQUpdate? {
        guard message.address=="/setPropertyValue",message.values.count==3,let bytes=message.values[2].data,let envelope=try? MessagePack.decode(bytes),envelope["type"].text=="v",let key=envelope["key_"].text else{return nil}
        let value=envelope["val_"]
        if key=="global.eq.sync",(try? GlobalEQState(value:value)) != nil {return .sync(value)}
        for output in EQOutput.allCases {
            let prefix="dsp.globaleq."+output.wire
            if key==prefix,(try? GlobalEQState.validateOutput(value,output:output)) != nil{return .output(output,.replace(value))}
            if key==prefix+".enable",let enabled=value.boolean{return .output(output,.enabled(enabled))}
            if key==prefix+".level",(try? EQParameter.level.validated(value)) != nil{return .output(output,.parameter(.mid,.level,value))}
            for band in EQBand.allCases {
                let wire=band.wire
                for parameter in band.parameters {
                    let name:[EQParameter:String] = [.enable:"enable",.frequency:"freq",.gain:"gain",.q:"q",.slope:"slope"]
                    if key==prefix+"."+wire+"."+name[parameter]!,value["parm"].integer==parameter.rawValue,(try? parameter.validated(value["valu"])) != nil {return .output(output,.parameter(band,parameter,value["valu"]))}
                }
            }
        }
        return nil
    }
    public var pendingKey:String {
        switch self {
        case .sync:return "sync"
        case .output(let output,let operation):
            let suffix:String
            switch operation {case .parameter(let band,let parameter,_):suffix="\(band.rawValue)-\(parameter.rawValue)";case .enabled:suffix="enable";default:suffix="all"}
            return output.wire+"-"+suffix
        }
    }
    public func applying(to state:GlobalEQState)throws->GlobalEQState {
        switch self {case .sync(let value):return try GlobalEQState(value:value,origin:state.origin);case .output(let output,let operation):return try operation.applying(to:state,output:output)}
    }
}

/// Constructed only by validated GlobalEQOperation; callers cannot supply arbitrary keys.
public struct EQDSPUpdate:Sendable {
    public let key:String;public let value:Value
    fileprivate init(key:String,value:Value){self.key=key;self.value=value}
    public func message(id:Int32)throws->OSCMessage {try GlobalEQOperation.encodeProperty(key:key,value:value,id:id)}
}
