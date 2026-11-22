import Foundation

public enum MatrixField:String,CaseIterable,Sendable {case level="vol_",pan="pan_",mute="mute",solo="solo"
    public var address:String {switch self {case .level:return "/syncMixChannelVolume";case .pan:return "/syncMixChannelPan";case .mute:return "/syncMixChannelMute";case .solo:return "/syncMixChannelSolo"}}
}
public struct MatrixStrip:Equatable,Sendable,Identifiable {
    public let id:Int
    public let name:String
    public let enabled:Bool
    public let raw:Value
    public var level:Double {raw["vol_"].numeric!}
    public var pan:Double {raw["pan_"].numeric!}
    public var muted:Bool {raw["mute"].boolean!}
    public var solo:Bool {raw["solo"].boolean!}
    public static let order=[5,1,2,3,4,14,6,7,8,9,10,11,12,13,15,16,17,18,19]
    public static func levelCC(_ source:Int)->Int? {order.firstIndex(of:source).map{11+$0}}
    public static func controlCC(source:Int,field:MatrixField)->Int? {
        guard let level=levelCC(source) else{return nil}
        switch field {case .level:return level;case .pan:return level+23;case .mute:return level+46;case .solo:return level+69}
    }
    public static func rows(in layer:Value)->[Value] {
        [layer["home"]["mix_"]]+layer["home"]["chan"].items+[layer["song"]["mix_"]]+layer["song"]["chan"].items+["clik","cntn","usbn","bt__","auxn"].map{layer[$0]}
    }
    public init(_ value:Value)throws {
        guard let id=value["src_"].integer,Self.order.contains(id),let name=value["name"].text,
              let level=value["vol_"].numeric,level.isFinite,(-120...12).contains(level),
              let pan=value["pan_"].numeric,pan.isFinite,(-1...1).contains(pan),
              value["mute"].boolean != nil,value["solo"].boolean != nil,let enabled=value["enbl"].integer else{throw ProtocolError.invalid("A Matrix channel is unavailable.")}
        self.id=id;self.name=name;self.enabled=enabled != 0 && id != 16;raw=value
    }
}
public struct MatrixConsoleState:Equatable,Sendable {
    public let property:Value
    public let origin:UUID?
    public var linked:Int {property["val_"]["lom_"].integer!}
    public init(property:Value,origin:UUID?=nil)throws {
        _ = try MatrixGuitarLevels(value:property)
        for output in 1...3 {let layer=property["val_"]["lyrs"].items.first{$0["out_"]["dst_"].integer==output}!
            let rows=MatrixStrip.rows(in:layer);let strips=try rows.map{try MatrixStrip($0)}
            guard strips.count==19,Set(strips.map(\.id))==Set(MatrixStrip.order) else{throw ProtocolError.invalid("The complete Matrix channel list is unavailable.")}
        }
        self.property=property;self.origin=origin
    }
    public func layer(_ output:Int)->Value {property["val_"]["lyrs"].items.first{$0["out_"]["dst_"].integer==output} ?? .null}
    public func strips(_ output:Int)->[MatrixStrip] {MatrixStrip.rows(in:layer(output)).compactMap{try? MatrixStrip($0)}}
    public func strip(output:Int,source:Int)->MatrixStrip? {strips(output).first{$0.id==source}}
}
public struct MatrixConsoleUpdate:Equatable,Sendable {
    public let output:Int,source:Int
    public let field:MatrixField
    public let value:Value
    public var key:String {"\(output):\(source):\(field.rawValue)"}
    public static func decode(_ message:OSCMessage)->Self? {
        guard message.values.count==5,let field=MatrixField.allCases.first(where:{$0.address==message.address}),message.values[0].integer != nil,message.values[1].integer != nil,
              let output=message.values[2].integer,(1...3).contains(output),let source=message.values[3].integer,MatrixStrip.order.contains(source) else{return nil}
        let raw=message.values[4];let value:Value
        if field == .mute || field == .solo {guard let n=raw.integer,(0...1).contains(n) else{return nil};value = .bool(n==1)}
        else {guard let n=raw.numeric,n.isFinite,(field == .pan ? -1...1 : -120...12).contains(n) else{return nil};value = .number(n)}
        return Self(output:output,source:source,field:field,value:value)
    }
    public func applying(to property:Value)->Value {
        func strip(_ row:Value)->Value {guard row["src_"].integer==source else{return row};var v=row.object;v[field.rawValue]=value;return .object(v)}
        var wrapper=property.object,root=property["val_"].object
        root["lyrs"] = .array((root["lyrs"] ?? .null).items.map{layer in
            guard layer["out_"]["dst_"].integer==output else{return layer}
            var row=layer.object
            for group in ["home","song"] {if let original=row[group] {var g=original.object;if let mix=g["mix_"] {g["mix_"]=strip(mix)};if let channels=g["chan"] {g["chan"] = .array(channels.items.map{strip($0)})};row[group] = .object(g)}}
            for key in ["clik","cntn","usbn","bt__","auxn"] {if let v=row[key] {row[key]=strip(v)}}
            return .object(row)
        });wrapper["val_"] = .object(root);return .object(wrapper)
    }
}
public struct MatrixConsoleCommand:Equatable,Sendable {
    public let output:Int,source:Int,field:MatrixField,value:Int
    public init(output:Int,source:Int,field:MatrixField,value:Int)throws {
        guard (1...3).contains(output),MatrixStrip.order.contains(source),source != 16,(0...127).contains(value),(!(field == .mute || field == .solo) || value==127) else{throw ProtocolError.invalid("Invalid Matrix control.")}
        self.output=output;self.source=source;self.field=field;self.value=value
    }
    public var key:String {"\(output):\(source):\(field.rawValue)"}
    public var cc:Int {MatrixStrip.controlCC(source:source,field:field)!}
    /// End the Solo switch gesture with a low-value release. Device qualification
    /// remains separate; Line 6 documents toggle activation only at >=64.
    public func midiWords(channel:Int)throws->[UInt32] {
        let press=try midiWord(channel:channel)
        return field == .solo ? [press,press & 0xFFFFFF00]:[press]
    }
    public func midiWord(channel:Int)throws->UInt32 {
        guard (1...16).contains(channel) else{throw ProtocolError.invalid("Invalid Matrix MIDI channel.")}
        return UInt32(0x2)<<28 | UInt32(0xB0+channel-1)<<16 | UInt32(cc)<<8 | UInt32(value)
    }
}
