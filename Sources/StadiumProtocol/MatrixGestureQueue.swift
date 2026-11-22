import Foundation

/// The control thumb follows the newest request; labels still use device readback.
public struct MatrixGestureQueue:Sendable {
    public struct Ticket:Equatable,Sendable {
        public let sequence:UInt64
        public let command:MatrixConsoleCommand
    }
    public private(set) var positions:[String:Int]=[:]
    private var pending:[MatrixConsoleCommand]=[]
    private var latest:[String:Int]=[:]
    private var sequence:UInt64=0
    private var inFlight:Ticket?
    public init(){}
    public var isEmpty:Bool {pending.isEmpty}
    public mutating func enqueue(_ command:MatrixConsoleCommand) {
        if command.field == .level || command.field == .pan {
            pending.removeAll{$0.key==command.key}
            latest[command.key]=command.value;positions[command.key]=command.value
        }
        pending.append(command)
    }
    public mutating func takeNext()->Ticket? {
        guard inFlight==nil,!pending.isEmpty else{return nil}
        sequence &+= 1
        let ticket=Ticket(sequence:sequence,command:pending.removeFirst());inFlight=ticket;return ticket
    }
    public mutating func confirmed(_ ticket:Ticket) {
        guard inFlight==ticket else{return};inFlight=nil
        let command=ticket.command
        guard command.field == .level || command.field == .pan else{return}
        if latest[command.key]==nil || latest[command.key]==command.value {
            latest[command.key]=nil;positions[command.key]=command.value
        }
    }
    public mutating func externalChange(_ key:String) {
        if latest[key]==nil {positions[key]=nil}
    }
    public mutating func cancelPending() {
        for command in pending where command.field == .level || command.field == .pan {
            latest[command.key]=nil;positions[command.key]=nil
        }
        pending=[]
    }
    public mutating func reset() {pending=[];latest=[:];positions=[:];inFlight=nil}
}

/// Observed Stadium 1.4 pan conversion, including its clamped left endpoint.
public enum MatrixPan {
    public static func value(forMIDI value:Int)throws->Double {
        guard (0...127).contains(value) else{throw ProtocolError.invalid("Invalid pan MIDI value.")}
        return max(-1,Double(value-64)/63)
    }
    public static func midi(forValue value:Double)throws->Int {
        guard value.isFinite,(-1...1).contains(value) else{throw ProtocolError.invalid("Invalid Matrix pan.")}
        return min(127,max(0,Int((64+value*63).rounded())))
    }
}
