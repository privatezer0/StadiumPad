import Foundation

public enum ProtocolError:Error,LocalizedError {
    case invalid(String), closed, timeout
    public var errorDescription:String? {switch self {case .invalid(let s):return s;case .closed:return "The Stadium connection closed.";case .timeout:return "The Stadium did not respond in time."}}
}
public indirect enum Value:Equatable,Sendable {
    case null,bool(Bool),int(Int64),number(Double),string(String),binary(Data),array([Value]),object([String:Value])
    public subscript(_ key:String)->Value {if case .object(let o)=self{return o[key] ?? .null};return .null}
    public var text:String? {if case .string(let s)=self{return s};return nil}
    public var integer:Int? {if case .int(let n)=self{return Int(exactly:n)};return nil}
    public var items:[Value] {if case .array(let a)=self{return a};return []}
    public var object:[String:Value] {if case .object(let o)=self{return o};return [:]}
    public var scalar:String {switch self {case .string(let s):return s;case .int(let n):return String(n);case .number(let n):return String(format:"%.4g",n);case .bool(let b):return b ? "On":"Off";default:return "—"}}
    public var json:Any {switch self {case .null:return NSNull();case .bool(let b):return b;case .int(let n):return n;case .number(let n):return n.isFinite ? n:NSNull();case .string(let s):return s;case .binary(let d):return ["bytes":d.base64EncodedString()];case .array(let a):return a.map(\.json);case .object(let o):return o.mapValues(\.json)}}
}
struct Cursor {
    var bytes:[UInt8];var offset=0
    init(_ data:Data) {bytes=Array(data)}
    mutating func take(_ n:Int)throws->[UInt8] {guard n>=0,n<=bytes.count-offset else{throw ProtocolError.invalid("Truncated protocol data.")};defer{offset+=n};return Array(bytes[offset..<offset+n])}
    mutating func byte()throws->UInt8 {try take(1)[0]}
    mutating func uint(_ n:Int)throws->UInt64 {try take(n).reduce(0){($0<<8)|UInt64($1)}}
    mutating func string(_ n:Int)throws->String {guard let s=String(bytes:try take(n),encoding:.utf8) else{throw ProtocolError.invalid("Invalid UTF-8.")};return s}
    mutating func oscString()throws->String {guard let end=bytes[offset...].firstIndex(of:0) else{throw ProtocolError.invalid("Unterminated OSC string.")};let s=try string(end-offset);_ = try byte();while offset%4 != 0 {_ = try byte()};return s}
}
