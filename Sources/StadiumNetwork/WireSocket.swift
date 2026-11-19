import Foundation
import Darwin
import Network
import StadiumProtocol

/// Completion gates are necessary because a timeout and NWConnection callback can race.
private final class Gate<T>:@unchecked Sendable {
    private let lock=NSLock();private var complete=false
    func finish(_ body:()->Void) {lock.lock();guard !complete else{lock.unlock();return};complete=true;lock.unlock();body()}
}
public final class TraceRecorder:@unchecked Sendable {
    private let handle:FileHandle;private let lock=NSLock();private let maximumBytes:Int?;private var capturedBytes=0
    public init(path:String,maximumBytes:Int?=nil)throws {
        guard maximumBytes.map({$0>0}) ?? true else{throw ProtocolError.invalid("Choose a positive trace size limit.")}
        self.maximumBytes=maximumBytes
        let descriptor=Darwin.open(path,O_WRONLY|O_CREAT|O_EXCL,0o600)
        guard descriptor>=0 else{throw ProtocolError.invalid("Could not create a new private trace. Choose an unused filename.")}
        handle=FileHandle(fileDescriptor:descriptor,closeOnDealloc:true)
    }

    public func record(channel:Int,direction:String,data:Data) {
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
    let connection:NWConnection;let channel:Int;let trace:TraceRecorder?;let queue=DispatchQueue(label:"stadium.wire",qos:.utility)
    var decoder=FrameDecoder()
    init(host:String,port:UInt16,trace:TraceRecorder?) {connection=NWConnection(host:NWEndpoint.Host(host),port:NWEndpoint.Port(rawValue:port)!,using:.tcp);channel=Int(port);self.trace=trace}
    func start()async throws {
        let gate=Gate<Void>(),c=connection
        try await withCheckedThrowingContinuation {(continuation:CheckedContinuation<Void,Error>) in
            c.stateUpdateHandler={state in
                switch state {case .ready:gate.finish{continuation.resume()};case .failed(let e):gate.finish{continuation.resume(throwing:e)};case .cancelled:gate.finish{continuation.resume(throwing:ProtocolError.closed)};default:break}
            }
            c.start(queue:queue)
            queue.asyncAfter(deadline:.now()+5){gate.finish{c.cancel();continuation.resume(throwing:ProtocolError.timeout)}}
        }
    }
    func close() {connection.cancel()}
    func send(_ data:Data)async throws {
        let gate=Gate<Void>(),c=connection
        try await withCheckedThrowingContinuation {(continuation:CheckedContinuation<Void,Error>) in
            c.send(content:data,completion:.contentProcessed {error in gate.finish{if let error {continuation.resume(throwing:error)}else{continuation.resume()}}})
            queue.asyncAfter(deadline:.now()+5){gate.finish{c.cancel();continuation.resume(throwing:ProtocolError.timeout)}}
        }
        trace?.record(channel:channel,direction:"sent",data:data)
    }
    func receive(maximum:Int=65536,timeout:Double=5)async throws->Data {
        let gate=Gate<Data>(),c=connection
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
