import Foundation

/// CC9 output commands toggle the selected panel. Visit a different output first
/// so the requested output opens from either visible or hidden starting state.
public struct MatrixPanelCommand:Equatable,Sendable {
    public let output:Int
    public let closing:Bool
    public var outputs:[Int] {[output%3+1,output]+(closing ? [output]:[])}
    public init(output:Int,closing:Bool=false)throws {
        guard (1...3).contains(output) else{throw ProtocolError.invalid("Invalid Matrix panel output.")}
        self.output=output;self.closing=closing
    }
    public static func midiWord(output:Int,channel:Int)throws->UInt32 {
        guard (1...3).contains(output),(1...16).contains(channel) else{throw ProtocolError.invalid("Invalid Matrix panel MIDI route.")}
        return UInt32(0x2)<<28 | UInt32(0xB0+channel-1)<<16 | UInt32(9)<<8 | UInt32(output+6)
    }
    public static func globalChannel(properties:Value)throws->Int {
        let rows=properties["vals"].items
        func number(_ key:String)throws->Int {
            let found=rows.filter{$0["key_"].text==key}
            guard found.count==1,let n=found[0]["val_"].integer else{throw ProtocolError.invalid("Stadium MIDI settings are unavailable.")}
            return n
        }
        let channel=try number("global.midi.channel")
        guard (1...16).contains(channel),try number("global.midi.over.usb.c") != 0 else{throw ProtocolError.invalid("Enable USB-C MIDI and a global MIDI channel on Stadium.")}
        for key in ["global.midi.bcchannel","global.midi.matrix.ch.qtr","global.midi.matrix.ch.xlr","global.midi.matrix.ch.phones"] {
            guard try number(key) != channel else{throw ProtocolError.invalid("Use a separate global MIDI channel for Stadium screen control.")}
        }
        return channel
    }
}

/// Attached output is useful for selection receipts, not panel visibility.
public struct MatrixAttachedOutput:Equatable,Sendable {
    public let output:Int
    public static func decode(_ message:OSCMessage)->Self? {
        guard message.address=="/syncMixAttachedOut",message.values.count==3,
              message.values[0].integer != nil,message.values[1].integer != nil,
              let output=message.values[2].integer,(1...3).contains(output) else{return nil}
        return Self(output:output)
    }
}
