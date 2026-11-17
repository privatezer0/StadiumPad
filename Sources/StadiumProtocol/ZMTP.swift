import Foundation

public struct Frame:Equatable,Sendable {
    public let flags:UInt8;public let payload:Data
    public init(flags:UInt8=0,payload:Data) {self.flags=flags;self.payload=payload}
    public var more:Bool {flags&1 != 0}
    public func encode()->Data {var data=Data();if payload.count<256 {data.append(flags);data.append(UInt8(payload.count))}else{data.append(flags|2);data.appendBE(UInt64(payload.count))};data.append(payload);return data}
}
public struct FrameDecoder {
    private var buffer=Data()
    public static let limit=16*1024*1024
    public init() {}
    public mutating func append(_ data:Data)throws {guard data.count<=Self.limit+9-buffer.count else{throw ProtocolError.invalid("Receive buffer exceeded limit.")};buffer.append(data)}
    public mutating func next()throws->Frame? {
        guard buffer.count>=2 else{return nil};let b=Array(buffer.prefix(9));let flags=b[0]
        guard flags&0xf8==0 else{throw ProtocolError.invalid("Unknown ZMTP flags.")}
        let header=flags&2 != 0 ? 9:2;guard buffer.count>=header else{return nil}
        let count=header==2 ? UInt64(b[1]):b[1..<9].reduce(0){($0<<8)|UInt64($1)}
        guard count<=Self.limit else{throw ProtocolError.invalid("ZMTP frame exceeded limit.")}
        guard buffer.count>=header+Int(count) else{return nil}
        let payload=Data(buffer.dropFirst(header).prefix(Int(count)));buffer=Data(buffer.dropFirst(header+Int(count)))
        return Frame(flags:flags,payload:payload)
    }
}
public enum ZMTP {
    public static let greeting:Data = {
        var d=Data([0xff,0,0,0,0,0,0,0,1,0x7f,3,0]);d.append(Data("NULL".utf8));d.append(Data(repeating:0,count:64-d.count));return d
    }()
    public static func validateGreeting(_ data:Data)throws {
        let b=Array(data);guard b.count==64,b[0]==0xff,b[9]==0x7f,b[10]==3,Array(b[12..<32])==Array(greeting[12..<32]) else{throw ProtocolError.invalid("Unsupported Stadium handshake or authentication mechanism.")}
    }
    public static func ready(_ socketType:String)->Frame {
        var d=Data([5]);d.append(Data("READY".utf8));d.append(11);d.append(Data("Socket-Type".utf8));d.appendBE(UInt32(socketType.utf8.count));d.append(Data(socketType.utf8))
        if socketType=="DEALER" {d.append(8);d.append(Data("Identity".utf8));d.appendBE(UInt32(0))}
        return Frame(flags:4,payload:d)
    }
    public static func validateReady(_ frame:Frame,peerTypes:Set<String>=["ROUTER"])throws {
        var r=Cursor(frame.payload)
        let count=Int(try r.byte());guard frame.flags&4 != 0,try r.string(count)=="READY" else{throw ProtocolError.invalid("Stadium did not accept the session.")}
        var socketType:String?
        while r.offset<r.bytes.count {let count=Int(try r.byte()),key=try r.string(count),length=try r.uint(4);guard length<=65536 else{throw ProtocolError.invalid("Handshake metadata too long.")};let value=try r.string(Int(length));if key=="Socket-Type" {socketType=value}}
        guard let socketType,peerTypes.contains(socketType) else{throw ProtocolError.invalid("Unexpected Stadium socket type.")}
    }
}
