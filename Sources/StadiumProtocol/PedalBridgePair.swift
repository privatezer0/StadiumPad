import Foundation

/// A private, pinned helper pairing. Never include it in traces or diagnostics.
public struct PedalBridgePair:Codable,Equatable,Sendable,CustomStringConvertible {
    public let host:String,token:String,pin:String
    public let port:UInt16
    public var description:String {"PedalBridge pairing (private)"}
    public init(link:String)throws {
        guard let url=URLComponents(string:link.trimmingCharacters(in:.whitespacesAndNewlines)),url.scheme=="pedalbridge",url.host=="pair" else{throw ProtocolError.invalid("Paste the pairing link shown by PedalBridge.")}
        let items=url.queryItems ?? []
        func field(_ key:String)throws->String {let values=items.filter{$0.name==key};guard values.count==1,let value=values[0].value,!value.isEmpty else{throw ProtocolError.invalid("The PedalBridge pairing link is incomplete.")};return value}
        let h=try field("host"),p=try field("pin"),t=try field("token")
        guard let port=UInt16(try field("port")),port>0,h.count<=253,h.range(of:"^[A-Za-z0-9.:-]+$",options:.regularExpression) != nil,p.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil,t.range(of:"^[A-Za-z0-9_-]{40,128}$",options:.regularExpression) != nil else{throw ProtocolError.invalid("The PedalBridge pairing link is invalid.")}
        host=h;pin=p;token=t;self.port=port
    }
}
