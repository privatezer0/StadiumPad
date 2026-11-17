import Foundation

public enum MessagePack {
    public static func decode(_ data:Data)throws->Value {
        guard data.count<=16*1024*1024 else{throw ProtocolError.invalid("MessagePack reply too large.")}
        // Only observed typed envelopes are accepted. Arbitrary offset probing can
        // turn a truncated/malformed object into an unrelated scalar at its tail.
        let envelopes=[Data("lavppgsm".utf8),Data("slvppgsm".utf8),Data("_sbepgsm".utf8)]
        let body=envelopes.contains(where:{data.starts(with:$0)}) ? Data(data.dropFirst(8)):data
        var reader=Cursor(body)
        let value=try read(&reader,depth:0)
        guard reader.offset==reader.bytes.count else{throw ProtocolError.invalid("Trailing MessagePack bytes.")}
        return value
    }
    static func read(_ r:inout Cursor,depth:Int)throws->Value {
        guard depth<64 else{throw ProtocolError.invalid("MessagePack nesting too deep.")}
        let tag=try r.byte()
        if tag<=0x7f{return .int(Int64(tag))}
        if tag>=0xe0{return .int(Int64(Int8(bitPattern:tag)))}
        if tag&0xe0==0xa0{return .string(try r.string(Int(tag&0x1f)))}
        if tag&0xf0==0x90{return try array(&r,count:Int(tag&0xf),depth:depth)}
        if tag&0xf0==0x80{return try map(&r,count:Int(tag&0xf),depth:depth)}
        switch tag {
        case 0xc0:return .null
        case 0xc2:return .bool(false)
        case 0xc3:return .bool(true)
        case 0xc4,0xc5,0xc6:let n=try length(&r,bytes:1<<Int(tag-0xc4));return .binary(Data(try r.take(n)))
        case 0xca:return .number(Double(Float(bitPattern:UInt32(try r.uint(4)))))
        case 0xcb:return .number(Double(bitPattern:try r.uint(8)))
        case 0xcc,0xcd,0xce,0xcf:
            let n=try r.uint(1<<Int(tag-0xcc));guard let signed=Int64(exactly:n) else{throw ProtocolError.invalid("Unsigned value exceeds supported range.")};return .int(signed)
        case 0xd0:return .int(Int64(Int8(bitPattern:try r.byte())))
        case 0xd1:return .int(Int64(Int16(bitPattern:UInt16(try r.uint(2)))))
        case 0xd2:return .int(Int64(Int32(bitPattern:UInt32(try r.uint(4)))))
        case 0xd3:return .int(Int64(bitPattern:try r.uint(8)))
        case 0xd9,0xda,0xdb:let n=try length(&r,bytes:1<<Int(tag-0xd9));return .string(try r.string(n))
        case 0xdc,0xdd:let n=try length(&r,bytes:tag==0xdc ? 2:4);return try array(&r,count:n,depth:depth)
        case 0xde,0xdf:let n=try length(&r,bytes:tag==0xde ? 2:4);return try map(&r,count:n,depth:depth)
        default:throw ProtocolError.invalid("Unsupported MessagePack type \(tag).")
        }
    }
    static func length(_ r:inout Cursor,bytes:Int)throws->Int {let n=try r.uint(bytes);guard n<=16*1024*1024 else{throw ProtocolError.invalid("MessagePack field too large.")};return Int(n)}
    static func array(_ r:inout Cursor,count:Int,depth:Int)throws->Value {
        guard count<=r.bytes.count-r.offset else{throw ProtocolError.invalid("Impossible array length.")}
        var values:[Value]=[];for _ in 0..<count {values.append(try read(&r,depth:depth+1))};return .array(values)
    }
    static func map(_ r:inout Cursor,count:Int,depth:Int)throws->Value {
        guard count<=(r.bytes.count-r.offset)/2 else{throw ProtocolError.invalid("Impossible map length.")}
        var values:[String:Value]=[:]
        for _ in 0..<count {
            let key=try read(&r,depth:depth+1);let name:String
            if case .int(let n)=key,let v=UInt32(exactly:n) {
                let b=(0..<4).reversed().map{UInt8(truncatingIfNeeded:v>>($0*8))}
                name=b.allSatisfy{(32...126).contains($0)} ? String(bytes:b,encoding:.ascii)!:String(n)
            } else if let text=key.text {name=text}else{throw ProtocolError.invalid("Unsupported map key.")}
            guard values[name]==nil else{throw ProtocolError.invalid("Duplicate decoded map key.")}
            values[name]=try read(&r,depth:depth+1)
        };return .object(values)
    }
}

extension MessagePack {
    /// Encoder is used for new-content attributes, never to rewrite an existing
    /// preset body. Raw preset bytes are retained for copying/backups.
    public static func encode(_ value:Value)throws->Data {
        var data=Data()
        func length(_ n:Int,_ small:UInt8,_ large:UInt8) throws {
            guard n>=0,n<=16*1024*1024 else{throw ProtocolError.invalid("MessagePack output too large.")}
            if n<=65535 {data.append(small);data.appendBE(UInt16(n))}else{data.append(large);data.appendBE(UInt32(n))}
        }
        switch value {
        case .null:data.append(0xc0)
        case .bool(let b):data.append(b ? 0xc3:0xc2)
        case .int(let n):
            if n>=0,n<=127 {data.append(UInt8(n))}
            else if n>=(-32),n<0 {data.append(UInt8(bitPattern:Int8(n)))}
            else if let n=Int32(exactly:n) {data.append(0xd2);data.appendBE(UInt32(bitPattern:n))}
            else {data.append(0xd3);data.appendBE(UInt64(bitPattern:n))}
        case .number(let n):guard n.isFinite else{throw ProtocolError.invalid("Invalid MessagePack number.")};data.append(0xcb);data.appendBE(n.bitPattern)
        case .string(let s):let utf8=Data(s.utf8);if utf8.count<32 {data.append(0xa0|UInt8(utf8.count))}else{try length(utf8.count,0xda,0xdb)};data.append(utf8)
        case .binary(let bytes):try length(bytes.count,0xc5,0xc6);data.append(bytes)
        case .array(let values):if values.count<16 {data.append(0x90|UInt8(values.count))}else{try length(values.count,0xdc,0xdd)};for value in values {data.append(try encode(value))}
        case .object(let values):if values.count<16 {data.append(0x80|UInt8(values.count))}else{try length(values.count,0xde,0xdf)};for key in values.keys.sorted(){data.append(try encode(.string(key)));data.append(try encode(values[key]!))}
        }
        guard data.count<=16*1024*1024 else{throw ProtocolError.invalid("MessagePack output too large.")};return data
    }
}
