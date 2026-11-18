import Foundation

public struct ParameterDefinition:Codable,Identifiable,Equatable,Sendable {
    public let id:Int
    public let key:String
    public let name:String
    public let type:String
    public let minimum:Double
    public let maximum:Double
    public let displayMinimum:Double?
    public let displayMaximum:Double?
    public let unit:String
    public let displayFormats:[ParameterDisplayFormat]?
    public let options:[String]?
    public let harness:Bool
    public let focusOnly:Bool?
    public var identity:String {"\(harness ? "h":"m")-\(id)"}
    public var range:ClosedRange<Double> {minimum...max(minimum,maximum)}
    public func containsWireValue(_ n:Double)->Bool {
        guard n.isFinite else{return false}
        if type=="f" {return Float(n).isFinite && n>=min(minimum,Double(Float(minimum))) && n<=max(maximum,Double(Float(maximum)))}
        return n>=minimum && n<=maximum
    }
    public func validated(_ value:Value)throws->Value {
        guard id>=0,id<=Int(Int32.max),minimum.isFinite,maximum.isFinite,minimum<=maximum else{throw ProtocolError.invalid("This control has invalid metadata.")}
        switch type {
        case "b":guard case .bool(let flag)=value else{throw ProtocolError.invalid("Choose an on/off value.")};let n=flag ? 1.0:0.0;guard n>=minimum,n<=maximum else{throw ProtocolError.invalid("This switch value is outside the supported range.")};return value
        case "i","f":
            guard let n=value.numeric,containsWireValue(n) else{throw ProtocolError.invalid("\(name) must be within its supported range.")}
            if type=="i" {guard n.rounded()==n,let int=Int32(exactly:n) else{throw ProtocolError.invalid("Choose a valid option for \(name).")};return .int(Int64(int))}
            guard Float(n).isFinite else{throw ProtocolError.invalid("Invalid numeric value.")};return .number(Double(Float(n)))
        default:throw ProtocolError.invalid("This parameter is read-only.")
        }
    }
    public func display(_ value:Value)->String {
        if type=="b" {guard let enabled=value.boolean else{return "—"};if let options,options.count>=2 {return options[enabled ? 1:0]};return enabled ? "On":"Off"}
        guard let raw=value.numeric,raw.isFinite else{return "—"}
        if let options,type=="i" {let index=Int(raw-minimum);if options.indices.contains(index){return options[index]}}
        let shown:Double
        if let lo=displayMinimum,let hi=displayMaximum,maximum>minimum {shown=lo+(raw-minimum)/(maximum-minimum)*(hi-lo)}else{shown=raw}
        if let displayFormats,let format=displayFormats.first(where:{$0.contains(shown)}),let formatted=format.render(shown) {return formatted}
        let suffix=unit=="unitless" || unit.isEmpty ? "":" \(unit)"
        return String(format:type=="i" ? "%.0f":"%.3g",shown)+suffix
    }
}
public struct ModelDefinition:Codable,Sendable {public let id:Int;public let name:String;public let category:String?;public let modelKey:String?;public let basedOn:String?;public let ioRole:String?;public let parameters:[ParameterDefinition]}
extension Value {
    public var numeric:Double? {switch self {case .int(let n):return Double(n);case .number(let n):return n;default:return nil}}
    public var boolean:Bool? {switch self {case .bool(let b):return b;case .int(let n) where n==0 || n==1:return n==1;default:return nil}}
    public var data:Data? {if case .binary(let data)=self{return data};return nil}
}
public struct EditContext:Equatable,Sendable {
    public let origin:UUID?
    public let presetID:Int;public let snapshot:Int;public let path:Int;public let blockID:Int;public let position:Int;public let slot:Int;public let modelID:Int
    public init(presetID:Int,snapshot:Int,path:Int,blockID:Int,slot:Int,modelID:Int,position:Int,origin:UUID?=nil) {self.origin=origin;self.presetID=presetID;self.snapshot=snapshot;self.path=path;self.blockID=blockID;self.position=position;self.slot=slot;self.modelID=modelID}
    public func validate()throws {guard presetID>0,presetID<=Int(Int32.max),(0...127).contains(snapshot),(0...1).contains(path),(0...255).contains(blockID),(0...27).contains(position),(0...1).contains(slot),modelID>=0 else{throw ProtocolError.invalid("Invalid block context.")}}
}
public struct PresetSlot:Identifiable,Equatable,Codable,Sendable {
    public let contentID:Int?;public let container:Int?;public let position:Int?;public let name:String;public let type:Int?;public let backingID:Int?
    public init(_ value:Value) {contentID=value["cid_"].integer;container=value["ccid"].integer;position=value["posi"].integer;name=value["name"].text ?? "Empty";type=value["type"].integer;backingID=value["rcid"].integer}
    public var id:Int {position ?? contentID ?? -1}
    public var empty:Bool {container == -2 && position.map{(0..<512).contains($0)} == true && (contentID==nil || contentID==0)}
    public var label:String {guard let position,(0..<512).contains(position) else{return "—"};return "\(position/4+1)\(["A","B","C","D"][position%4])"}
    public var writable:Bool {container == -2 && type==2 && (contentID ?? 0)>0 && (contentID ?? 0)<=Int(Int32.max) && position.map{(0..<512).contains($0)}==true && backingID==nil}
}

/// Functional numeric formatting only; never evaluates a catalogue string as a
/// printf argument list. Unsupported placeholders fall back to plain display.
public struct ParameterDisplayFormat:Codable,Sendable,Equatable {
    public let lowerBound:Double?;public let upperBound:Double?;public let multiplier:Double;public let format:String
    func contains(_ number:Double)->Bool {number >= (lowerBound ?? -.infinity) && number < (upperBound ?? .infinity)}
    func render(_ number:Double)->String? {
        let scaled=number*multiplier
        guard scaled.isFinite,format.count<=80 else{return nil}
        let placeholder=try! NSRegularExpression(pattern:"%[-+]?[0-9]{0,2}(?:[.][0-9]{1,2})?[fFeEgG]")
        let range=NSRange(format.startIndex...,in:format),matches=placeholder.matches(in:format,range:range)
        guard matches.count<=1 else{return nil}
        var output=format
        if let match=matches.first,let tokenRange=Range(match.range,in:format) {
            let token=String(format[tokenRange])
            let rest=format.replacingCharacters(in:tokenRange,with:"").replacingOccurrences(of:"%%",with:"")
            guard !rest.contains("%") else{return nil}
            output=format.replacingCharacters(in:tokenRange,with:String(format:token,scaled))
        } else if format.replacingOccurrences(of:"%%",with:"").contains("%") {return nil}
        return output.replacingOccurrences(of:"%%",with:"%")
    }
}

extension ModelDefinition {
    public var browserCategory:String {
        if ioRole=="outputs" {return "Output"};if ioRole=="inputs" {return "Input"}
        switch category ?? "" {
        case "amp":return "Amp"
        case "preamp":return "Preamp"
        case "cab","cab_ir_interp","ir":return "Cab / IR"
        case "distortion":return "Distortion"
        case "delay":return "Delay"
        case "reverb":return "Reverb"
        case "modulation":return "Modulation"
        case "dynamics":return "Dynamics"
        case "eq":return "EQ"
        case "pitch","synth":return "Pitch / Synth"
        case "wah","filter":return "Wah / Filter"
        case "volume":return "Volume / Pan"
        case "looper":return "Looper"
        case "send","return","fxloop":return "FX Loop"
        default:return "Utility"
        }
    }
    public var variant:String {let key=modelKey ?? "";return key.contains("Stereo") ? "Stereo":key.contains("Mono") ? "Mono":""}
    public var needsLibraryFile:Bool {[836,838,839,840].contains(id) || category=="ir"}
    public var isCab:Bool {category=="cab" || category=="cab_ir_interp"}
    public var replaceable:Bool {id>=0 && id<=Int(Int32.max) && category != nil && !["split","join"].contains(category!) && !needsLibraryFile}
}
public struct SnapshotChoice:Identifiable,Equatable,Sendable {public let id:Int;public let name:String;public let color:Int;public let defined:Bool}
extension DeviceSnapshot {
    public var snapshots:[SnapshotChoice] {
        editBuffer["cg__"]["entt"]["snps"].items.compactMap {value in
            guard let id=value["si__"].integer,(0..<8).contains(id) else{return nil}
            return SnapshotChoice(id:id,name:value["name"].text ?? "Snapshot \(id+1)",color:value["colr"].integer ?? 0,defined:value["vald"].boolean ?? false)
        }.sorted{$0.id<$1.id}
    }
}
