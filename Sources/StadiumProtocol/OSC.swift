import Foundation

public struct OSCMessage:Equatable,Sendable {
    public var address:String;public var values:[Value]
    public init(_ address:String,_ values:[Value]=[]) {self.address=address;self.values=values}
    public func encode()throws->Data {
        guard address.hasPrefix("/"),!address.contains("\0") else{throw ProtocolError.invalid("Invalid OSC address.")}
        var tags=",";var arguments=Data()
        for value in values {
            switch value {
            case .int(let n):guard let n=Int32(exactly:n) else{throw ProtocolError.invalid("OSC int out of range.")};tags+="i";arguments.appendBE(UInt32(bitPattern:n))
            case .number(let n):guard n.isFinite,Float(n).isFinite else{throw ProtocolError.invalid("Nonfinite OSC value.")};tags+="f";arguments.appendBE(Float(n).bitPattern)
            case .string(let s):tags+="s";arguments.append(try Self.padded(s))
            case .binary(let data):tags+="b";arguments.appendBE(UInt32(data.count));arguments.append(data);while arguments.count%4 != 0 {arguments.append(0)}
            case .bool(let b):tags+=b ? "T":"F"
            case .null:tags+="N"
            default:throw ProtocolError.invalid("Unsupported OSC argument.")
            }
        }
        var data=try Self.padded(address);data.append(try Self.padded(tags));data.append(arguments);return data
    }
    static func padded(_ s:String)throws->Data {guard !s.contains("\0") else{throw ProtocolError.invalid("Embedded OSC null.")};var d=Data(s.utf8);d.append(0);while d.count%4 != 0 {d.append(0)};return d}
    public static func decode(_ data:Data)throws->OSCMessage {
        var r=Cursor(data);let address=try r.oscString(),tags=try r.oscString()
        guard address.hasPrefix("/"),tags.first=="," else{throw ProtocolError.invalid("Invalid OSC message.")}
        var values:[Value]=[]
        for tag in tags.dropFirst() {
            switch tag {
            case "i":values.append(.int(Int64(Int32(bitPattern:UInt32(try r.uint(4))))))
            case "h":values.append(.int(Int64(bitPattern:try r.uint(8))))
            case "f":values.append(.number(Double(Float(bitPattern:UInt32(try r.uint(4))))))
            case "d":values.append(.number(Double(bitPattern:try r.uint(8))))
            case "s":values.append(.string(try r.oscString()))
            case "b":let n=try r.uint(4);guard n<=16*1024*1024 else{throw ProtocolError.invalid("OSC blob too large.")};values.append(.binary(Data(try r.take(Int(n)))));while r.offset%4 != 0 {_ = try r.byte()}
            case "T":values.append(.bool(true))
            case "F":values.append(.bool(false))
            case "N":values.append(.null)
            default:throw ProtocolError.invalid("Unsupported OSC type \(tag).")
            }
        }
        guard r.offset==r.bytes.count else{throw ProtocolError.invalid("Trailing OSC bytes.")}
        return OSCMessage(address,values)
    }
}
extension Data {
    mutating func appendBE<T:FixedWidthInteger>(_ value:T) {var big=value.bigEndian;Swift.withUnsafeBytes(of:&big){append(contentsOf:$0)}}
}
