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
    public static func open(_ storedPair:PedalBridgePair)async throws->PedalBridgeConnection {
        let pair=try await refreshed(storedPair)
        let socket=WireSocket(host:pair.host,port:pair.port,trace:nil,bridgePair:pair,bridgeRequest:["protocol":1,"token":pair.token,"channel":"status"])
        do {try await socket.start();let status=await socket.bridgeReply;await socket.close();return try PedalBridgeConnection(pair:pair,status:status)}catch{await socket.close();throw error}
    }
    public static func automaticBluetooth(_ id:UUID)async throws->PedalBridgePair {
        let info=try await BluetoothEditorHub.shared.information(id)
        let temporary=try PedalBridgePair(host:id.uuidString,port:info.psm,pin:info.pin,token:String(repeating:"0",count:40))
        return try await refreshed(temporary)
    }
    private static func refreshed(_ stored:PedalBridgePair)async throws->PedalBridgePair {
        guard stored.bluetooth else{return stored}
        let socket=WireSocket(host:stored.host,port:stored.port,trace:nil,bridgePair:stored,bridgeRequest:["protocol":1,"channel":"pair"])
        do {try await socket.start();let reply=await socket.bridgeReply;await socket.close()
            guard let token=reply["token"] as? String,reply["pin"] as? String==stored.pin else{throw ProtocolError.invalid("The selected PedalBridge identity changed. Choose the helper again.")}
            return try PedalBridgePair(host:stored.host,port:stored.port,pin:stored.pin,token:token)
        }catch{await socket.close();throw error}
    }

    public static func settings(_ storedPair:PedalBridgePair,action:String="status",ssid:String?=nil,password:String?=nil,enabled:Bool?=nil)async throws->[String:Any] {
        let pair=try await refreshed(storedPair)
        guard ["status","scan","connect","restart","dashboard"].contains(action) else{throw ProtocolError.invalid("Unsupported PedalBridge setting.")}
        var request:[String:Any]=["protocol":1,"token":pair.token,"channel":"settings","action":action]
        if let ssid {request["ssid"]=ssid};if let password {request["password"]=password};if let enabled {request["enabled"]=enabled}
        let socket=WireSocket(host:pair.host,port:pair.port,trace:nil,bridgePair:pair,bridgeRequest:request)
        do {try await socket.start();let result=await socket.bridgeReply;await socket.close();return result}catch{await socket.close();throw error}
    }
    func request(_ channel:String)->[String:Any] {["protocol":1,"token":pair.token,"channel":channel,"session":sessionID,"device":deviceID,"generation":generation]}
    public func matrixSession(identity:String)async throws->PedalBridgeMatrixSession {
        guard matrixAvailable,identity==deviceID else{throw ProtocolError.invalid("Matrix requires the same Stadium connected to PedalBridge by USB.")}
        let socket=WireSocket(host:pair.host,port:pair.port,trace:nil,bridgePair:pair,bridgeRequest:request("matrix-session"))
        do {try await socket.start();return PedalBridgeMatrixSession(socket:socket)}catch{await socket.close();throw error}
    }
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

public actor PedalBridgeMatrixSession {
    private let socket:WireSocket
    fileprivate init(socket:WireSocket){self.socket=socket}
    public func close()async {await socket.close()}
    public func waitForDisconnect()async throws {
        while true {let data=try await socket.receive(maximum:1,timeout:12);guard data==Data([0]) else{throw ProtocolError.closed}}
    }
}
