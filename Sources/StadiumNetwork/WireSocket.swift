import Foundation
import Darwin
import Network
import Security
import CryptoKit
import StadiumProtocol

/// Completion gates are necessary because a timeout and NWConnection callback can race.
private final class Gate<T>:@unchecked Sendable {
    private let lock=NSLock();private var complete=false
    func finish(_ body:()->Void) {lock.lock();guard !complete else{lock.unlock();return};complete=true;lock.unlock();body()}
}
public final class TraceRecorder:@unchecked Sendable {
    private let handle:FileHandle;private let lock=NSLock();private let maximumBytes:Int?;private var capturedBytes=0;private let channels:Set<Int>?
    public init(path:String,maximumBytes:Int?=nil,channels:Set<Int>?=nil)throws {
        guard maximumBytes.map({$0>0}) ?? true else{throw ProtocolError.invalid("Choose a positive trace size limit.")}
        self.maximumBytes=maximumBytes;self.channels=channels
        let descriptor=Darwin.open(path,O_WRONLY|O_CREAT|O_EXCL,0o600)
        guard descriptor>=0 else{throw ProtocolError.invalid("Could not create a new private trace. Choose an unused filename.")}
        handle=FileHandle(fileDescriptor:descriptor,closeOnDealloc:true)
    }

    public func record(channel:Int,direction:String,data:Data) {
        guard channels?.contains(channel) ?? true else{return}
        lock.lock();defer{lock.unlock()}
        if let maximumBytes,capturedBytes>=maximumBytes {return}
        let object:[String:Any]=["at":Date().timeIntervalSince1970,"channel":channel,"direction":direction,"hex":data.map{String(format:"%02x",$0)}.joined()]
        guard var line=try? JSONSerialization.data(withJSONObject:object,options:.sortedKeys) else{return};line.append(10)
        if let maximumBytes,line.count>maximumBytes-capturedBytes {capturedBytes=maximumBytes;return}
        do {try handle.write(contentsOf:line);capturedBytes+=line.count}catch {}
    }
    deinit {try? handle.close()}
}
actor WireSocket {
    let connection:NWConnection?;private let bluetoothPair:PedalBridgePair?;private var bluetoothStream:BluetoothEditorStream?;let channel:Int;let trace:TraceRecorder?;let queue=DispatchQueue(label:"stadium.wire",qos:.userInitiated)
    var decoder=FrameDecoder()
    private var pending=Data()
    private let bridgeRequest:[String:Any]?
    private(set) var bridgeReply:[String:Any]=[:]
    init(host:String,port:UInt16,trace:TraceRecorder?,route:StadiumConnectionRoute = .automatic,interface:NWInterface?=nil,bridgePair:PedalBridgePair?=nil,bridgeRequest:[String:Any]?=nil) {
        bluetoothPair=bridgePair?.bluetooth==true ? bridgePair:nil
        if bridgePair?.bluetooth==true {connection=nil;channel=Int(port);self.trace=trace;self.bridgeRequest=bridgeRequest;return}
        // Interactive request/reply frames must not wait behind Nagle buffering.
        let tcp=NWProtocolTCP.Options();tcp.noDelay=true
        let tls:NWProtocolTLS.Options?
        if let pair=bridgePair {
            let options=NWProtocolTLS.Options()
            sec_protocol_options_set_verify_block(options.securityProtocolOptions,{_,trust,complete in
                let value=sec_trust_copy_ref(trust).takeRetainedValue()
                guard let chain=SecTrustCopyCertificateChain(value) as? [SecCertificate],let certificate=chain.first else{complete(false);return}
                let hash=SHA256.hash(data:SecCertificateCopyData(certificate) as Data).map{String(format:"%02x",$0)}.joined()
                complete(hash==pair.pin)
            },DispatchQueue(label:"pedalbridge.trust"))
            tls=options
        }else{tls=nil}
        let parameters=NWParameters(tls:tls,tcp:tcp)
        if let interface {parameters.requiredInterface=interface}
        if route == .usb {parameters.requiredInterfaceType = .wiredEthernet}
        if route == .wifi {parameters.requiredInterfaceType = .wifi}
        connection=NWConnection(host:NWEndpoint.Host(host),port:NWEndpoint.Port(rawValue:port)!,using:parameters);channel=Int(port);self.trace=trace;self.bridgeRequest=bridgeRequest
    }
    func interfaceName()->String {
        if bluetoothPair != nil {return "Bluetooth LE"}
        guard let path=connection?.currentPath else{return "Unknown"}
        if path.usesInterfaceType(.wiredEthernet) {return "USB/Ethernet"}
        if path.usesInterfaceType(.wifi) {return "Wi-Fi"}
        return "Network"
    }
    func start()async throws {
        if let pair=bluetoothPair,let id=UUID(uuidString:pair.host) {
            bluetoothStream=try await BluetoothEditorHub.shared.open(id,psm:pair.port,pin:pair.pin)
            try await authenticate();return
        }
        guard let c=connection else{throw ProtocolError.closed};let gate=Gate<Void>()
        try await withCheckedThrowingContinuation {(continuation:CheckedContinuation<Void,Error>) in
            c.stateUpdateHandler={state in
                switch state {case .ready:gate.finish{continuation.resume()};case .failed(let e):gate.finish{continuation.resume(throwing:e)};case .cancelled:gate.finish{continuation.resume(throwing:ProtocolError.closed)};default:break}
            }
            c.start(queue:queue)
            queue.asyncAfter(deadline:.now()+5){gate.finish{c.cancel();continuation.resume(throwing:ProtocolError.timeout)}}
        }
        try await authenticate()
    }
    private func authenticate()async throws {
        guard let request=bridgeRequest else{return}
        var data=try JSONSerialization.data(withJSONObject:request);guard data.count<8192 else{throw ProtocolError.invalid("PedalBridge request is too large.")};data.append(10)
        try await send(data,record:false)
        var response=Data()
        while response.count<8192 {
            response.append(try await receive(maximum:8192-response.count,timeout:request["channel"] as? String == "settings" ? 110:10))
            if let index=response.firstIndex(of:10) {
                pending=Data(response.suffix(from:response.index(after:index)))
                guard let reply=try JSONSerialization.jsonObject(with:response.prefix(upTo:index)) as? [String:Any],reply["ok"] as? Bool==true else {
                    let reply=(try? JSONSerialization.jsonObject(with:response.prefix(upTo:index))) as? [String:Any]
                    throw ProtocolError.invalid(reply?["error"] as? String ?? "PedalBridge refused the connection.")
                }
                bridgeReply=reply;return
            }
        };throw ProtocolError.invalid("PedalBridge reply is too large.")
    }
    func close()async {connection?.cancel();await bluetoothStream?.close();bluetoothStream=nil}
    func send(_ data:Data,record:Bool=true)async throws {
        if let bluetoothStream {try await bluetoothStream.send(data);if record {trace?.record(channel:channel,direction:"sent",data:data)};return}
        guard let c=connection else{throw ProtocolError.closed};let gate=Gate<Void>()
        try await withCheckedThrowingContinuation {(continuation:CheckedContinuation<Void,Error>) in
            c.send(content:data,completion:.contentProcessed {error in gate.finish{if let error {continuation.resume(throwing:error)}else{continuation.resume()}}})
            queue.asyncAfter(deadline:.now()+5){gate.finish{c.cancel();continuation.resume(throwing:ProtocolError.timeout)}}
        }
        if record {trace?.record(channel:channel,direction:"sent",data:data)}
    }
    func receive(maximum:Int=65536,timeout:Double=5)async throws->Data {
        if !pending.isEmpty {let data=Data(pending.prefix(maximum));pending.removeFirst(data.count);return data}
        if let bluetoothStream {return try await bluetoothStream.receive(maximum:maximum,timeout:timeout)}
        guard let c=connection else{throw ProtocolError.closed};let gate=Gate<Data>()
        return try await withCheckedThrowingContinuation {(continuation:CheckedContinuation<Data,Error>) in
            c.receive(minimumIncompleteLength:1,maximumLength:maximum){data,_,closed,error in
                gate.finish{if let data,!data.isEmpty {continuation.resume(returning:data)}else if let error {continuation.resume(throwing:error)}else{continuation.resume(throwing:ProtocolError.closed)}}
            }
            queue.asyncAfter(deadline:.now()+timeout){gate.finish{c.cancel();continuation.resume(throwing:ProtocolError.timeout)}}
        }
    }
    func raw(_ count:Int)async throws->Data {
        var result=Data();while result.count<count {let data=try await receive(maximum:count-result.count);trace?.record(channel:channel,direction:"received",data:data);result.append(data)};return result
    }
    func frame(timeout:Double=5)async throws->Frame {
        let deadline=Date().addingTimeInterval(timeout)
        while true {
            if let frame=try decoder.next(){return frame}
            let remaining=deadline.timeIntervalSinceNow;guard remaining>0 else{throw ProtocolError.timeout}
            let data=try await receive(timeout:remaining);trace?.record(channel:channel,direction:"received",data:data);try decoder.append(data)
        }
    }
    func handshake(type:String)async throws {
        try await send(ZMTP.greeting);try ZMTP.validateGreeting(await raw(64));try await send(ZMTP.ready(type).encode());try ZMTP.validateReady(await frame(),peerTypes:type=="SUB" ? ["PUB","XPUB","ROUTER"]:["ROUTER"])
        if type=="SUB" {try await send(Frame(payload:Data([1])).encode())}
    }
}
