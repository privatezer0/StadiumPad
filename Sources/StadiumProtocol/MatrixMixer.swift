import Foundation

/// Home/all-paths mix levels, separate from the physical output gain and Global EQ.
public struct MatrixGuitarLevels:Equatable,Sendable {
    public var levels:[Double]
    public var linked:Int
    public var origin:UUID?
    public init(value:Value,origin:UUID?=nil)throws {
        let root=value["val_"],layers=root["lyrs"].items
        guard value["key_"].text=="server.mixer.state",layers.count==3,let linked=root["lom_"].integer else{throw ProtocolError.invalid("The complete Matrix mixer is unavailable.")}
        var result:[Double]=[]
        for output in 1...3 {
            let found=layers.filter{$0["out_"]["dst_"].integer==output}
            guard found.count==1,found[0]["home"]["mix_"]["src_"].integer==5,let db=found[0]["home"]["mix_"]["vol_"].numeric,db.isFinite,(-120...12).contains(db) else{throw ProtocolError.invalid("A Matrix guitar channel is unavailable.")}
            result.append(db)
        }
        self.levels=result;self.linked=linked;self.origin=origin
    }
    public static let labels=["¼-inch","XLR","Phones"]
    /// MIDI is discrete; dB labels always come from actual device readback.
    public static func estimatedMIDI(_ db:Double)->Int {
        guard db.isFinite else{return 0}
        if db<=(-119) {return 0}
        return min(127,max(1,Int((db>0 ? 100+db*27/6:100+db*100/48).rounded())))
    }
    public static func midiWord(channel:Int,value:Int)throws->UInt32 {
        guard (1...16).contains(channel),(0...127).contains(value) else{throw ProtocolError.invalid("Invalid guitar MIDI value.")}
        return UInt32(0x2)<<28 | UInt32(0xB0+channel-1)<<16 | UInt32(11)<<8 | UInt32(value)
    }
    public static func label(_ db:Double)->String {db<=(-119) ? "−∞":String(format:"%+.1f dB",db)}
}

/// Device-originated live Home/Paths level; this is separate from the older bulk property.
public struct MatrixGuitarUpdate:Equatable,Sendable {
    public let output:Int
    public let level:Double
    public static func decode(_ message:OSCMessage)->Self? {
        guard message.address=="/syncMixChannelVolume",message.values.count==5,
              message.values[0].integer != nil,message.values[1].integer != nil,
              let output=message.values[2].integer,(1...3).contains(output),message.values[3].integer==5,
              let level=message.values[4].numeric,level.isFinite,(-120...12).contains(level) else{return nil}
        return Self(output:output-1,level:level)
    }
    public func applying(to property:Value)throws->Value {
        _ = try MatrixGuitarLevels(value:property)
        var wrapper=property.object,root=wrapper["val_"]!.object
        root["lyrs"] = .array(root["lyrs"]!.items.map {layer in
            guard layer["out_"]["dst_"].integer==output+1 else{return layer}
            var row=layer.object,home=row["home"]!.object,mix=home["mix_"]!.object
            mix["vol_"] = .number(level);home["mix_"] = .object(mix);row["home"] = .object(home);return .object(row)
        });wrapper["val_"] = .object(root);return .object(wrapper)
    }
}
