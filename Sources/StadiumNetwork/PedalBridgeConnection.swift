import Foundation
import StadiumProtocol

/// One helper lease shared by the native SUB/DEALER streams and Matrix requests.
public final class PedalBridgeConnection:@unchecked Sendable {
    let pair:PedalBridgePair
    public let sessionID:String,deviceID:String,generation:String,upstream:String,matrixAvailable:Bool
    private init(pair:PedalBridgePair,status:[String:Any])throws {
        guard status["connected"] as? Bool==true,let id=status["device"] as? String,id.count==64,let generation=status["generation"] as? String,!generation.isEmpty else{throw ProtocolError.invalid(status["message"] as? String ?? "PedalBridge is waiting for Stadium.")}
        self.pair=pair;sessionID=UUID().uuidString;deviceID=id;self.generation=generation;upstream=status["upstream"] as? String ?? "Network";matrixAvailable=status["matrix"] as? Bool ?? false
    }
    public static func open(_ pair:PedalBridgePair)async throws->PedalBridgeConnection {
        let socket=WireSocket(host:pair.host,port:pair.port,trace:nil,bridgePair:pair,bridgeRequest:["protocol":1,"token":pair.token,"channel":"status"])
        do {try await socket.start();let status=await socket.bridgeReply;await socket.close();return try PedalBridgeConnection(pair:pair,status:status)}catch{await socket.close();throw error}
    }
    func request(_ channel:String)->[String:Any] {["protocol":1,"token":pair.token,"channel":channel,"session":sessionID,"device":deviceID,"generation":generation]}
    private func matrix(_ command:[String:Any],identity:String)async throws {
        guard matrixAvailable,identity==deviceID else{throw ProtocolError.invalid("PedalBridge needs this Stadium connected by USB for Matrix control.")}
        var request=request("matrix");request["command"]=command
        let socket=WireSocket(host:pair.host,port:pair.port,trace:nil,bridgePair:pair,bridgeRequest:request)
        do {try await socket.start();await socket.close()}catch{await socket.close();throw error}
    }
    public func send(_ command:MatrixConsoleCommand,channel:Int,identity:String)async throws {try await matrix(["kind":"strip","output":command.output,"source":command.source,"field":command.field.rawValue,"value":command.value,"channel":channel],identity:identity)}
    public func clearSolos(_ command:MatrixClearSolosCommand,channel:Int,identity:String)async throws {try await matrix(["kind":"clearSolos","output":command.output,"channel":channel],identity:identity)}
    public func navigate(output:Int,channel:Int,identity:String)async throws {try await matrix(["kind":"panel","output":output,"channel":channel],identity:identity)}
}
