import Foundation

/// Screen navigation only. CC9 values are commands, not press/release pairs:
/// sending value0 as a release would navigate Home.
public struct MatrixPanelCommand:Equatable,Sendable {
    public let output:Int?
    public init(output:Int?)throws {
        guard output==nil || (1...3).contains(output!) else{throw ProtocolError.invalid("Invalid Matrix panel output.")}
        self.output=output
    }
    public func midiWords(channel:Int)throws->[UInt32] {
        guard (1...16).contains(channel) else{throw ProtocolError.invalid("Invalid global MIDI channel.")}
        let home=UInt32(0x2)<<28 | UInt32(0xB0+channel-1)<<16 | UInt32(9)<<8
        // Home establishes a known closed baseline before the output's toggle.
        return output.map{[home,home | UInt32($0+6)]} ?? [home]
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
