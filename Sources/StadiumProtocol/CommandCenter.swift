import Foundation

public enum CommandFamily:Int,CaseIterable,Codable,Sendable {
    case none=0,presetSnapshot,song,looper,utility,extAmp,midi,hotKey
    public var name:String {switch self {case .none:return "None";case .presetSnapshot:return "Preset/Snapshot";case .song:return "Song";case .looper:return "Looper";case .utility:return "Utility";case .extAmp:return "ExtAmp";case .midi:return "MIDI";case .hotKey:return "HotKey"}}
    public var key:String {switch self {case .none:return "Undefined";case .presetSnapshot:return "PresetSnapshot";case .song:return "Song";case .looper:return "Looper";case .utility:return "Utility";case .extAmp:return "ExtAmp";case .midi:return "MIDI";case .hotKey:return "HotKey"}}
}
public struct CommandSource:Hashable,Identifiable,Codable,Sendable {
    public enum Kind:String,Codable,Sendable {case stomp,instant,axis,expression,toe,externalSwitch,trigger}
    public let kind:Kind;public let number:Int;public let bank:Int
    public init(_ kind:Kind,number:Int,bank:Int=0){self.kind=kind;self.number=number;self.bank=bank}
    public var id:String {"\(kind.rawValue)-\(bank)-\(number)"}
    public var name:String {switch kind {case .stomp:return "Stomp \(bank==1 ? "A":"B")\(number)";case .instant:return "Instant \(number+1)";case .axis:return "XY Pad: \(number==0 ? "X":"Y")";case .expression:return number==0 ? "EXP \(bank+1)":"EXP \(String(UnicodeScalar(64+number)!))";case .toe:return "Exp Toe";case .externalSwitch:return "Switch \(String(UnicodeScalar(65+number)!))";case .trigger:return "Trigger \(String(UnicodeScalar(65+number)!))"}}
    public var type:Int {switch kind {case .instant:return 4;case .axis:return 5;default:return 1}}
    public var location:Int {switch kind {case .stomp:return 24+number;case .instant,.axis:return 0;case .toe:return 37;case .externalSwitch,.trigger:return 38+number;case .expression:return 42+number}}
    public var context:Int {(kind == .stomp || (kind == .expression && number==0)) ? bank:kind == .instant || kind == .axis ? number:0}
    public var externalConfiguration:(key:String,value:Int)? {
        guard kind == .trigger || kind == .externalSwitch || (kind == .expression && number>0) else{return nil}
        let index=kind == .expression ? number-1:number
        guard (0..<4).contains(index) else{return nil}
        return ("global.assign.control."+String(UnicodeScalar(97+index)!),kind == .expression ? 0:kind == .externalSwitch ? 1:2)
    }
    public var continuous:Bool {kind == .axis || kind == .expression}
    public var slots:Int {continuous || kind == .instant ? 1:2}
    public func validate()throws {
        let valid:Bool
        switch kind {case .stomp:valid=[1,2].contains(bank) && StompAssignment.switchNumbers.contains(number);case .instant:valid=bank==0 && (0..<16).contains(number);case .axis:valid=bank==0 && (0..<2).contains(number);case .expression:valid=(number==0 && (0...1).contains(bank)) || (bank==0 && (1..<5).contains(number));case .toe:valid=bank==0 && number==0;case .externalSwitch,.trigger:valid=bank==0 && (0..<4).contains(number)}
        guard valid else{throw ProtocolError.invalid("This command source is unavailable.")}
    }
    public func supports(_ family:CommandFamily)->Bool {if family == .none {return true};if continuous {return family == .midi};if kind == .instant {return ![.presetSnapshot,.utility].contains(family)};return true}
    public func catalogueKey(_ family:CommandFamily)->String {
        if family == .midi {return continuous ? (kind == .axis ? "MIDI-XY":"MIDI-Exp"):kind == .instant ? "MIDI-Instant":kind == .trigger ? "MIDI-Drum":"MIDI-FS"}
        return family.key+(kind == .instant ? "-Instant":kind == .trigger ? "-Drum":"")
    }
    public func row(in state:DeviceSnapshot)throws->Value? {
        try validate();let graph=state.editBuffer["cg__"]
        guard graph["asnp"].integer==state.activeSnapshot,case .array=graph["entt"]["srcs"],case .array=graph["entt"]["cmnd"] else{throw ProtocolError.invalid("Command assignments are unavailable. Refresh this preset.")}
        let rows=graph["entt"]["srcs"].items.filter{$0["type"].integer==type && $0["locl"].integer==(kind == .axis ? -1:location) && $0["ctxt"].integer==context}
        guard rows.count<=1 else{throw ProtocolError.invalid("Command source is ambiguous.")};return rows.first
    }
}
public struct CommandParameter:Codable,Identifiable,Equatable,Sendable {
    public let id:Int;public let name:String;public let type:String;public let minimum:Double;public let maximum:Double;public let defaultValue:Double;public let options:[String]?
    public init(id:Int,name:String,type:String="i",minimum:Double,maximum:Double,defaultValue:Double=0,options:[String]?=nil){self.id=id;self.name=name;self.type=type;self.minimum=minimum;self.maximum=maximum;self.defaultValue=defaultValue;self.options=options}
    public var valueKey:String {"pvl"+String(UnicodeScalar(97+max(0,min(11,id)))!)}
    public var snapshotKey:String {"psp"+String(UnicodeScalar(97+max(0,min(11,id)))!)}
    public func validated(_ value:Value)throws->Value {
        guard (0..<12).contains(id),["i","f"].contains(type),minimum.isFinite,maximum.isFinite,minimum<=maximum,let n=value.numeric,n.isFinite,n>=minimum,n<=maximum else{throw ProtocolError.invalid("Invalid command parameter value.")}
        if type=="i" {guard let i=Int32(exactly:n) else{throw ProtocolError.invalid("Command parameter requires a whole number.")};return .int(Int64(i))};return .number(Double(Float(n)))
    }
    public func display(_ value:Value)->String {guard let n=value.numeric,n.isFinite,abs(n)<Double(Int32.max) else{return "—"};if let options,let i=Int(exactly:n-minimum),options.indices.contains(i){return options[i]};if n == -1 && ["MSB","LSB","PC"].contains(name){return "Off"};if name=="Wait" {return "\(Int(n)) ms"};return type=="f" ? String(format:"%.1f",n):String(Int(n))}
    public func visible(source:CommandSource,family:CommandFamily,command:Value)->Bool {
        let function=command[source.kind == .instant ? "pvla":"pvlb"].integer ?? 0
        if source.continuous {return !["Curve","Value"].contains(name)}
        if family == .presetSnapshot {if ["Setlist","Preset"].contains(name) {return function==4};if name=="Snapshot" {return function==7}}
        if family == .utility && name=="Level Trim" {return false}
        if family == .midi {
            if ["MSB","LSB","PC"].contains(name) {return function==0}
            if ["CC#","Value"].contains(name) {return function==1}
            if ["Note","Velocity","NoteOff"].contains(name) {return function==2}
            if name=="Message" {return function==3}
        };return true
    }
}
public struct CommandContext:Equatable,Sendable {
    public let origin:UUID?;public let presetID:Int;public let snapshot:Int;public let source:CommandSource;public let slot:Int;public let sourceRow:Value;public let command:Value
    public init(state:DeviceSnapshot,source:CommandSource,slot:Int)throws {
        try source.validate();guard let preset=state.presetID,(0..<source.slots).contains(slot) else{throw ProtocolError.invalid("Choose a valid command slot.")}
        let row=try source.row(in:state) ?? .null
        if row != .null {guard let id=row["id__"].integer,id>0,row["cmds"].items.count==2,row["cmds"].items.allSatisfy({$0.integer != nil}) else{throw ProtocolError.invalid("This source's command slots are incomplete.")}}
        let id=row["cmds"].items.indices.contains(slot) ? row["cmds"].items[slot].integer ?? -1:-1
        let matches=id>0 ? state.editBuffer["cg__"]["entt"]["cmnd"].items.filter{$0["cid_"].integer==id}:[]
        guard id == -1 || (matches.count==1 && matches[0]["trig"].integer==row["id__"].integer),id == -1 || state.editBuffer["cg__"]["entt"]["srcs"].items.filter({$0["cmds"].items.contains(.int(Int64(id)))}).count==1 else{throw ProtocolError.invalid("The command is missing or shared. Refresh before editing.")}
        self.origin=state.origin;self.presetID=preset;self.snapshot=state.activeSnapshot;self.source=source;self.slot=slot;self.sourceRow=row;self.command=matches.first ?? .null
    }
    public var commandID:Int? {command["cid_"].integer}
    public var family:CommandFamily {CommandFamily(rawValue:command["type"].integer ?? 0) ?? .none}
}
public enum CommandCenterOperation:Sendable {
    case family(CommandFamily),parameter(CommandParameter,Value),snapshot(CommandParameter,Bool),paste(CommandFamily,[CommandParameter],Value)
    public func message(context:CommandContext,id:Int32)throws->OSCMessage {
        var args:[Value]=[.int(Int64(id))];let address:String
        switch self {
        case .family(let family):
            guard context.source.supports(family) else{throw ProtocolError.invalid("This source does not support that command type.")}
            if family == .none {guard let cid=context.commandID else{throw ProtocolError.invalid("This slot is already empty.")};return OSCMessage("/removeCommand",args+[.int(Int64(cid))])}
            if let cid=context.commandID {return OSCMessage("/CommandTypeSet",args+[.int(Int64(cid)),.int(Int64(family.rawValue)),.int(context.source.continuous ? 1:0)])}
            return try Self.attach(context:context,id:id,family:family,values:[])
        case .paste(let family,let definitions,let copied):
            guard context.source.supports(family),family != .none,definitions.count<=12 else{throw ProtocolError.invalid("The copied command does not fit this source.")}
            let values=try definitions.map {p in Value.object(["pidx":.int(Int64(p.id)),"pval":try p.validated(copied[p.valueKey])])}
            return try Self.attach(context:context,id:id,family:family,values:values)
        case .parameter(let parameter,let value):
            guard let cid=context.commandID else{throw ProtocolError.invalid("Choose a command first.")};address="/setCommandParamVal";args += [.int(Int64(cid)),.int(Int64(parameter.id)),try parameter.validated(value)]
        case .snapshot(let parameter,let enabled):
            guard let cid=context.commandID,parameter.name != "Action",!(context.family == .midi && parameter.name=="Command") else{throw ProtocolError.invalid("This parameter does not support snapshot control.")}
            let _=try parameter.validated(context.command[parameter.valueKey]);address=enabled ? "/assignSnapshotCommandParam":"/removeSnapshotCommandParam";args += [.int(Int64(cid)),.int(Int64(parameter.id))];if enabled {args.append(.int(Int64(context.snapshot)))}
        };return OSCMessage(address,args)
    }
    public func permitsPairedToggle(old:Value,new:Value,context:CommandContext)->Bool {
        guard case .parameter(let p,let value)=self,p.name=="Action",p.id==0,(value.integer==3 || context.command["pvla"].integer==3),context.slot==0,context.source.slots==2,context.sourceRow["cmds"].items.count==2,let peer=context.sourceRow["cmds"].items[1].integer,peer>0,old["cid_"].integer==peer,new["pvla"].integer==(value.integer==3 ? 3:0) else{return false}
        return old.object.filter{$0.key != "pvla" && $0.key != "togl"}==new.object.filter{$0.key != "pvla" && $0.key != "togl"}
    }
    private static func attach(context:CommandContext,id:Int32,family:CommandFamily,values:[Value])throws->OSCMessage {
        try context.source.validate();let source=context.source
        return OSCMessage("/attachCommandWithType",[.int(Int64(id)),.int(Int64(source.type)),.int(Int64(source.location)),.int(Int64(source.context)),.int(Int64(context.slot)),.int(Int64(family.rawValue)),.int(source.continuous ? 1:0),.binary(try MessagePack.encode(.array(values)))])
    }
}

public struct CommandCopy:Sendable {
    public let source:CommandSource;public let slot:Int;public let family:CommandFamily;public let parameters:[CommandParameter];public let command:Value
    public init(context:CommandContext,catalog:[String:[CommandParameter]])throws {
        guard context.commandID != nil,context.family != .none,let definitions=catalog[context.source.catalogueKey(context.family)],!definitions.isEmpty else{throw ProtocolError.invalid("The complete command metadata is unavailable. Nothing was copied.")}
        self.source=context.source;self.slot=context.slot;self.family=context.family;self.parameters=definitions.filter{!context.source.continuous || $0.name != "Value"};self.command=context.command
        for parameter in parameters {_ = try parameter.validated(command[parameter.valueKey])}
    }
    public static var sources:[CommandSource] {var result:[CommandSource]=[];for bank in [1,2]{for number in StompAssignment.switchNumbers {result.append(CommandSource(.stomp,number:number,bank:bank))}};result += (0..<16).map{CommandSource(.instant,number:$0)};result += (0..<2).map{CommandSource(.axis,number:$0)};result += (0..<5).map{CommandSource(.expression,number:$0)};result.append(CommandSource(.expression,number:0,bank:1));result.append(CommandSource(.toe,number:0));for i in 0..<4 {result += [CommandSource(.externalSwitch,number:i),CommandSource(.trigger,number:i)]};return result}
    public static func all(state:DeviceSnapshot,catalog:[String:[CommandParameter]],properties:[String:Value])throws->[CommandCopy] {
        var result:[CommandCopy]=[],seen:Set<Int>=[]
        for source in sources {
            if source.kind == .externalSwitch || source.kind == .trigger {let letter=String(UnicodeScalar(97+source.number)!);guard properties["global.assign.control."+letter]?.integer==(source.kind == .externalSwitch ? 1:2) else{continue}}
            for slot in 0..<source.slots {
                let context=try CommandContext(state:state,source:source,slot:slot)
                if let id=context.commandID {guard seen.insert(id).inserted else{continue};result.append(try CommandCopy(context:context,catalog:catalog))}
            }
        }
        guard seen.count==state.editBuffer["cg__"]["entt"]["cmnd"].items.count else{throw ProtocolError.invalid("Some command sources are not recognized. The layout was not partially copied.")}
        return result
    }
}

public enum StompAppearance:Sendable {
    case label(String),color(Int)
    public func property(source:CommandSource)throws->(String,Value) {
        try source.validate();guard source.kind == .stomp else{throw ProtocolError.invalid("Choose a stomp switch for Label/Color.")}
        let prefix="preset.floorboard.stomp.\(source.bank==1 ? "a":"b").\(source.number)."
        switch self {
        case .label(let text):guard text.count<=24,!text.unicodeScalars.contains(where:{$0.value<32 || $0.value==127}) else{throw ProtocolError.invalid("Use a label of up to 24 characters.")};return (prefix+"label",.string(text))
        case .color(let color):guard (0...11).contains(color) else{throw ProtocolError.invalid("Invalid stomp color.")};return (prefix+"color",.int(Int64(color)))
        }
    }
    public func message(source:CommandSource,id:Int32)throws->OSCMessage {
        let (key,value)=try property(source:source)
        var blob=Data("lavppgsm".utf8);blob.append(0x83)
        for (field,value) in [(Int64(0x6b65795f),Value.string(key)),(Int64(0x74797065),Value.string(value.text==nil ? "i":"s")),(Int64(0x76616c5f),value)] {blob.append(try MessagePack.encode(.int(field)));blob.append(try MessagePack.encode(value))}
        return OSCMessage("/PropertyValueSet",[.int(Int64(id)),.int(0),.binary(blob)])
    }
}
