import Foundation
import CoreBluetooth
import Combine
import Compression

public struct BluetoothHelper:Identifiable,Equatable,Sendable {
    public let id:UUID
    public var name:String
}
public struct BluetoothHelperInfo:Decodable,Sendable {
    public let `protocol`:Int,psm:UInt16,pin:String,name:String
}
private func bluetoothError(_ message:String)->NSError {NSError(domain:"PedalBridge.Bluetooth",code:1,userInfo:[NSLocalizedDescriptionKey:message])}

/// BLE discovery is independent of the tablet's Wi-Fi. No OS pairing/link entry.
@MainActor public final class BluetoothEditorHub:NSObject,ObservableObject,@preconcurrency CBCentralManagerDelegate,@preconcurrency CBPeripheralDelegate {
    public static let shared=BluetoothEditorHub()
    public static let service=CBUUID(string:"8DFB7000-24EA-4C52-B28C-684E04572AD1")
    private static let info=CBUUID(string:"8DFB7001-24EA-4C52-B28C-684E04572AD1")
    @Published public private(set) var helpers:[BluetoothHelper]=[]
    @Published public private(set) var message="Find nearby PedalBridge"
    private var central:CBCentralManager!
    private var scanning=false
    private var lastSeen:[UUID:Date]=[:]
    private var peripherals:[UUID:CBPeripheral]=[:],details:[UUID:BluetoothHelperInfo]=[:]
    private var connecting:[UUID:[CheckedContinuation<BluetoothHelperInfo,Error>]]=[:]
    private var opening:[UUID:[(UUID,UInt16,CheckedContinuation<BluetoothEditorStream,Error>)]]=[:]
    private var multiplexers:[UUID:BluetoothMultiplexer]=[:]
    public func search() {scanning=true;if central==nil {central=CBCentralManager(delegate:self,queue:.main)}else{centralManagerDidUpdateState(central)}}
    public func stopSearch(){scanning=false;central?.stopScan()}
    public func centralManagerDidUpdateState(_ central:CBCentralManager) {
        if central.state == .poweredOn {message="Choose a nearby PedalBridge";if scanning {central.scanForPeripherals(withServices:[Self.service],options:[CBCentralManagerScanOptionAllowDuplicatesKey:true])}}
        else {message=central.state == .unauthorized ? "Allow Bluetooth access in Settings.":"Turn on Bluetooth to find PedalBridge.";for p in peripherals.values {fail(p,error:bluetoothError(message))}}
    }
    public func centralManager(_ central:CBCentralManager,didDiscover peripheral:CBPeripheral,advertisementData:[String:Any],rssi RSSI:NSNumber) {
        peripherals[peripheral.identifier]=peripheral;lastSeen[peripheral.identifier]=Date()
        let name=advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? "PedalBridge"
        if !helpers.contains(where:{$0.id==peripheral.identifier}) {helpers.append(.init(id:peripheral.identifier,name:name))}
    }
    public func information(_ id:UUID)async throws->BluetoothHelperInfo {
        if central==nil {search()}
        guard central.state == .poweredOn else{throw bluetoothError(message)}
        if peripherals[id]==nil,let p=central.retrievePeripherals(withIdentifiers:[id]).first {peripherals[id]=p}
        guard let p=peripherals[id] else{throw bluetoothError("PedalBridge is not nearby. Refresh the helper list.")}
        if p.state == .connected,let value=details[id] {return value}
        return try await withCheckedThrowingContinuation {continuation in
            let first=connecting[id]==nil;connecting[id,default:[]].append(continuation)
            if first {p.delegate=self;if p.state == .connected {p.discoverServices([Self.service])}else{central.connect(p)}
                Task {try? await Task.sleep(nanoseconds:12_000_000_000);if self.connecting[id] != nil {self.fail(p,error:bluetoothError("Bluetooth connection timed out."));self.central.cancelPeripheralConnection(p)}}}
        }
    }
    public func centralManager(_ central:CBCentralManager,didConnect peripheral:CBPeripheral){peripheral.delegate=self;peripheral.discoverServices([Self.service])}
    public func centralManager(_ central:CBCentralManager,didFailToConnect peripheral:CBPeripheral,error:Error?){fail(peripheral,error:error ?? bluetoothError("Could not connect to PedalBridge."))}
    public func centralManager(_ central:CBCentralManager,didDisconnectPeripheral peripheral:CBPeripheral,error:Error?){details[peripheral.identifier]=nil;multiplexers.removeValue(forKey:peripheral.identifier)?.close();fail(peripheral,error:error ?? bluetoothError("Bluetooth disconnected. Reconnect before editing."))}
    private func fail(_ p:CBPeripheral,error:Error) {
        connecting.removeValue(forKey:p.identifier)?.forEach{$0.resume(throwing:error)}
        opening.removeValue(forKey:p.identifier)?.forEach{$0.2.resume(throwing:error)}
    }
    public func peripheral(_ peripheral:CBPeripheral,didDiscoverServices error:Error?) {
        guard error==nil,let service=peripheral.services?.first(where:{$0.uuid==Self.service}) else{fail(peripheral,error:error ?? bluetoothError("PedalBridge service unavailable."));return}
        peripheral.discoverCharacteristics([Self.info],for:service)
    }
    public func peripheral(_ peripheral:CBPeripheral,didDiscoverCharacteristicsFor service:CBService,error:Error?) {
        guard error==nil,let c=service.characteristics?.first(where:{$0.uuid==Self.info}) else{fail(peripheral,error:error ?? bluetoothError("PedalBridge information unavailable."));return};peripheral.readValue(for:c)
    }
    public func peripheral(_ peripheral:CBPeripheral,didUpdateValueFor characteristic:CBCharacteristic,error:Error?) {
        guard characteristic.uuid==Self.info else{return}
        do {if let error {throw error};guard let data=characteristic.value else{throw bluetoothError("Missing Bluetooth information.")}
            let info=try JSONDecoder().decode(BluetoothHelperInfo.self,from:data)
            guard info.protocol==2,info.psm>0,info.pin.range(of:"^[a-f0-9]{64}$",options:.regularExpression) != nil else{throw bluetoothError("Unsupported PedalBridge Bluetooth service.")}
            details[peripheral.identifier]=info
            if let index=helpers.firstIndex(where:{$0.id==peripheral.identifier}) {helpers[index].name=info.name}
            connecting.removeValue(forKey:peripheral.identifier)?.forEach{$0.resume(returning:info)}
        }catch{fail(peripheral,error:error)}
    }
    private func resolve(_ requested:UUID,pin:String)async throws->UUID {
        if let value=details.first(where:{$0.value.pin==pin && peripherals[$0.key]?.state == .connected}) {return value.key}
        let started=Date();search()
        for _ in 0..<24 {
            for helper in helpers where (lastSeen[helper.id] ?? .distantPast)>=started {
                if let info=try? await information(helper.id),info.pin==pin {stopSearch();return helper.id}
                if multiplexers[helper.id]==nil,let p=peripherals[helper.id]{central.cancelPeripheralConnection(p)}
            }
            try await Task.sleep(nanoseconds:250_000_000)
        }
        stopSearch();throw bluetoothError("Selected PedalBridge is not nearby. Reconnecting…")
    }
    func open(_ requested:UUID,psm:UInt16,pin:String)async throws->BluetoothEditorStream {
        let id=try await resolve(requested,pin:pin)
        if let old=multiplexers[id],old.closed,let p=peripherals[id] {
            multiplexers[id]=nil;details[id]=nil;central.cancelPeripheralConnection(p)
            for _ in 0..<30 {if p.state == .disconnected{break};try? await Task.sleep(nanoseconds:100_000_000)}
        }
        let information=try await information(id)
        let effectivePSM=information.psm
        if let mux=multiplexers[id],!mux.closed {return mux.open()}
        guard let p=peripherals[id] else{throw bluetoothError("PedalBridge disconnected.")}
        return try await withCheckedThrowingContinuation {continuation in
            let key=UUID(),first=opening[id,default:[]].isEmpty
            opening[id,default:[]].append((key,effectivePSM,continuation));if first {p.openL2CAPChannel(effectivePSM)}
            Task {try? await Task.sleep(nanoseconds:10_000_000_000);if self.opening[id]?.contains(where:{$0.0==key})==true {self.fail(p,error:bluetoothError("Bluetooth editor channel timed out."));self.central.cancelPeripheralConnection(p)}}
        }
    }
    public func peripheral(_ peripheral:CBPeripheral,didOpen channel:CBL2CAPChannel?,error:Error?) {
        let id=peripheral.identifier
        guard let requests=opening[id],!requests.isEmpty else{channel?.inputStream.close();channel?.outputStream.close();return}
        opening[id]=nil
        if let channel,error==nil {
            let mux=BluetoothMultiplexer(BluetoothPhysicalStream(channel));multiplexers[id]=mux
            for request in requests {request.2.resume(returning:mux.open())}
        }else{for request in requests {request.2.resume(throwing:error ?? bluetoothError("Cannot open Bluetooth editor channel."))}}

    }
}

/// Bounded, backpressured stream. Losing a channel fails the session; never replay.
@MainActor final class BluetoothPhysicalStream:NSObject,@preconcurrency StreamDelegate {
    private let channel:CBL2CAPChannel
    private var buffer=Data(),closed:Error?
    private var reading:(UUID,Int,CheckedContinuation<Data,Error>)?
    private var writes:[(UUID,Data,Int,CheckedContinuation<Void,Error>)]=[]
    init(_ channel:CBL2CAPChannel) {
        self.channel=channel;super.init()
        for stream in [channel.inputStream,channel.outputStream] as [Stream] {stream.delegate=self;stream.schedule(in:.main,forMode:.common);stream.open()}
    }
    func close(_ error:Error=bluetoothError("Bluetooth editor disconnected.")) {
        guard closed==nil else{return};closed=error
        for stream in [channel.inputStream,channel.outputStream] as [Stream] {stream.close();stream.remove(from:.main,forMode:.common);stream.delegate=nil}
        reading?.2.resume(throwing:error);reading=nil
        let waiting=writes;writes=[];for item in waiting {item.3.resume(throwing:error)}
    }
    func send(_ data:Data)async throws {
        if let closed {throw closed};guard data.count<=4*1024*1024 else{throw bluetoothError("Bluetooth write is too large.")}
        try await withCheckedThrowingContinuation {(c:CheckedContinuation<Void,Error>) in
            let id=UUID();writes.append((id,data,0,c));flush()
            Task {try? await Task.sleep(nanoseconds:10_000_000_000);if self.writes.contains(where:{$0.0==id}) {self.close(bluetoothError("Bluetooth send timed out."))}}
        }
    }
    private func flush() {
        while !writes.isEmpty,channel.outputStream.hasSpaceAvailable {
            let item=writes[0],remaining=item.1.count-item.2
            if remaining==0 {writes.removeFirst().3.resume();continue}
            let sent=item.1.withUnsafeBytes {raw in channel.outputStream.write(raw.bindMemory(to:UInt8.self).baseAddress!.advanced(by:item.2),maxLength:remaining)}
            if sent<0 {close(channel.outputStream.streamError ?? bluetoothError("Bluetooth send failed."));return};if sent==0{return};writes[0].2+=sent
        }
        if let first=writes.first,first.2==first.1.count {writes.removeFirst().3.resume()}
    }
    func receive(maximum:Int,timeout:Double)async throws->Data {
        if let closed {throw closed}
        if !buffer.isEmpty {let data=Data(buffer.prefix(maximum));buffer.removeFirst(data.count);return data}
        guard reading==nil else{throw bluetoothError("Overlapping Bluetooth reads.")}
        return try await withCheckedThrowingContinuation {c in
            let id=UUID();reading=(id,maximum,c)
            Task {try? await Task.sleep(nanoseconds:UInt64(max(0.01,timeout)*1_000_000_000));if self.reading?.0==id {self.close(bluetoothError("Bluetooth receive timed out."))}}
        }
    }
    func stream(_ aStream:Stream,handle eventCode:Stream.Event) {
        if eventCode.contains(.errorOccurred) || eventCode.contains(.endEncountered) {close(aStream.streamError ?? bluetoothError("Bluetooth connection ended."));return}
        if eventCode.contains(.hasSpaceAvailable) || eventCode.contains(.openCompleted) {flush()}
        if eventCode.contains(.hasBytesAvailable) {
            var bytes=[UInt8](repeating:0,count:16384)
            while channel.inputStream.hasBytesAvailable {
                let count=channel.inputStream.read(&bytes,maxLength:bytes.count)
                if count<0 {close(channel.inputStream.streamError ?? bluetoothError("Bluetooth read failed."));return};if count==0{break}
                buffer.append(contentsOf:bytes.prefix(count))
                if buffer.count>4*1024*1024 {close(bluetoothError("Bluetooth receive buffer exceeded."));return}
            }
            if let request=reading,!buffer.isEmpty {reading=nil;let data=Data(buffer.prefix(request.1));buffer.removeFirst(data.count);request.2.resume(returning:data)}
        }
    }
}


@MainActor final class BluetoothMultiplexer {
    private let physical:BluetoothPhysicalStream
    private var channels:[UInt32:BluetoothEditorStream]=[:],nextID:UInt32=1
    private var reader:Task<Void,Never>?
    private(set) var closed=false
    init(_ physical:BluetoothPhysicalStream) {
        self.physical=physical
        reader=Task { [weak self] in
            var buffer=Data()
            do {while let self,!Task.isCancelled {
                buffer.append(try await physical.receive(maximum:65536,timeout:3600))
                while buffer.count>=9 {
                    let bytes=[UInt8](buffer.prefix(9)),kind=bytes[0]
                    let id=bytes[1...4].reduce(UInt32(0)){($0<<8)|UInt32($1)},size=bytes[5...8].reduce(UInt32(0)){($0<<8)|UInt32($1)}
                    guard [2,3,4].contains(kind),id>0,size<=16384,kind != 3 || size==0 else{throw bluetoothError("Invalid Bluetooth stream frame.")}
                    guard buffer.count>=9+Int(size) else{break}
                    let data=Data(buffer.dropFirst(9).prefix(Int(size)));buffer=Data(buffer.dropFirst(9+Int(size)))
                    if kind==2 || kind==4 {channels[id]?.append(try BluetoothFrameCodec.unpack(kind,data))}else{channels.removeValue(forKey:id)?.remoteClose()}
                }
            }}catch{self?.close(error)}
        }
    }
    func open()->BluetoothEditorStream {
        let id=nextID;nextID &+= 1
        let stream=BluetoothEditorStream(id:id,mux:self);channels[id]=stream;return stream
    }
    func write(_ kind:UInt8,_ id:UInt32,_ data:Data=Data())async throws {
        guard !closed else{throw bluetoothError("Bluetooth disconnected.")}
        for offset in stride(from:0,to:max(1,data.count),by:16384) {
            let raw=Data(data.dropFirst(offset).prefix(16384))
            let (wireKind,part)=BluetoothFrameCodec.pack(kind,raw);let size=UInt32(part.count)
            var header=Data([wireKind]);for value in [id,size]{header.append(contentsOf:[UInt8((value>>24)&255),UInt8((value>>16)&255),UInt8((value>>8)&255),UInt8(value&255)])};header.append(part)
            try await physical.send(header)
        }
    }
    func remove(_ id:UInt32){channels[id]=nil;Task{try? await write(3,id)}}
    func close(_ error:Error=bluetoothError("Bluetooth disconnected. Reconnect before editing.")) {
        guard !closed else{return};closed=true;reader?.cancel();physical.close(error)
        let streams=Array(channels.values);channels=[:];for stream in streams{stream.remoteClose(error)}
    }
}

@MainActor final class BluetoothEditorStream {
    private let id:UInt32
    private weak var mux:BluetoothMultiplexer?
    private var buffer=Data(),failure:Error?
    private var pending:(UUID,Int,CheckedContinuation<Data,Error>)?
    private let opening:Task<Void,Error>
    init(id:UInt32,mux:BluetoothMultiplexer){self.id=id;self.mux=mux;opening=Task{try await mux.write(1,id)}}
    func send(_ data:Data)async throws {try await opening.value;if let failure{throw failure};guard let mux else{throw bluetoothError("Bluetooth disconnected.")};try await mux.write(2,id,data)}
    func receive(maximum:Int,timeout:Double)async throws->Data {
        try await opening.value
        if !buffer.isEmpty{let data=Data(buffer.prefix(maximum));buffer.removeFirst(data.count);return data}
        if let failure{throw failure}
        guard pending==nil else{throw bluetoothError("Overlapping Bluetooth stream reads.")}
        return try await withCheckedThrowingContinuation {continuation in
            let key=UUID();pending=(key,maximum,continuation)
            Task{try? await Task.sleep(nanoseconds:UInt64(max(0.01,timeout)*1_000_000_000));if self.pending?.0==key{self.close(bluetoothError("Bluetooth response timed out. Nothing was retried."))}}
        }
    }
    func append(_ data:Data) {
        buffer.append(data);if buffer.count>4*1024*1024{close(bluetoothError("Bluetooth stream receive buffer exceeded."));return}
        if let request=pending,!buffer.isEmpty{pending=nil;let result=Data(buffer.prefix(request.1));buffer.removeFirst(result.count);request.2.resume(returning:result)}
    }
    func remoteClose(_ error:Error=bluetoothError("Bluetooth editor channel closed.")){guard failure==nil else{return};failure=error;pending?.2.resume(throwing:error);pending=nil}
    func close(_ error:Error=bluetoothError("Bluetooth editor channel closed.")){remoteClose(error);buffer=Data();let parent=mux;mux=nil;Task{_ = try? await opening.value;parent?.remove(id)}}
}


/// Raw DEFLATE is interoperable with Python zlib(wbits:-15) and Android nowrap.
/// Every expanded frame is bounded before allocating its output buffer.
enum BluetoothFrameCodec {
    static func pack(_ kind:UInt8,_ data:Data)->(UInt8,Data) {
        guard kind==2,data.count>=512 else{return(kind,data)}
        var destination=Data(count:data.count)
        let count=destination.withUnsafeMutableBytes {out in data.withUnsafeBytes {input in
            compression_encode_buffer(out.bindMemory(to:UInt8.self).baseAddress!,data.count,input.bindMemory(to:UInt8.self).baseAddress!,data.count,nil,COMPRESSION_ZLIB)
        }}
        guard count>0,count+20<data.count else{return(kind,data)}
        let size=UInt32(data.count);var result=Data([UInt8((size>>24)&255),UInt8((size>>16)&255),UInt8((size>>8)&255),UInt8(size&255)])
        result.append(destination.prefix(count));return(4,result)
    }
    static func unpack(_ kind:UInt8,_ data:Data)throws->Data {
        guard kind==4 else{return data}
        guard data.count>=5 else{throw bluetoothError("Invalid compressed Bluetooth frame.")}
        let expected=data.prefix(4).reduce(UInt32(0)){($0<<8)|UInt32($1)}
        guard expected>0,expected<=16384 else{throw bluetoothError("Invalid Bluetooth expanded size.")}
        var stream=compression_stream(dst_ptr:UnsafeMutablePointer<UInt8>(bitPattern:1)!,dst_size:0,src_ptr:UnsafePointer<UInt8>(bitPattern:1)!,src_size:0,state:nil)
        guard compression_stream_init(&stream,COMPRESSION_STREAM_DECODE,COMPRESSION_ZLIB)==COMPRESSION_STATUS_OK else{throw bluetoothError("Bluetooth decompressor unavailable.")}
        defer{compression_stream_destroy(&stream)}
        var output=Data(count:Int(expected)+1);let payload=Data(data.dropFirst(4))
        let valid=output.withUnsafeMutableBytes {out in payload.withUnsafeBytes {input in
            stream.dst_ptr=out.bindMemory(to:UInt8.self).baseAddress!;stream.dst_size=out.count
            stream.src_ptr=input.bindMemory(to:UInt8.self).baseAddress!;stream.src_size=input.count
            let status=compression_stream_process(&stream,Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
            return status==COMPRESSION_STATUS_END && stream.src_size==0 && out.count-stream.dst_size==Int(expected)
        }}
        guard valid else{throw bluetoothError("Invalid compressed Bluetooth payload.")};return Data(output.prefix(Int(expected)))
    }
}
