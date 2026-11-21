import Foundation
import Combine
import CoreMIDI
import CryptoKit
import StadiumProtocol

/// Device notifications invalidate availability immediately; sends re-enumerate the port.
@MainActor final class MatrixUSBMIDI:ObservableObject {
    @Published private(set) var online=false
    @Published private(set) var deviceName="No Stadium USB MIDI connection"
    private var endpoint:MIDIEndpointRef=0
    private var usbIdentity:String?
    private var client:MIDIClientRef=0
    private var port:MIDIPortRef=0
    init() {
        if MIDIClientCreateWithBlock("StadiumPad Guitar Volume" as CFString,&client,{[weak self] _ in Task{@MainActor in self?.refresh()}})==0 {
            _ = MIDIOutputPortCreate(client,"StadiumPad Guitar Volume" as CFString,&port)
        }
        refresh()
    }
    deinit {if port != 0 {MIDIPortDispose(port)};if client != 0 {MIDIClientDispose(client)}}
    static func hash(_ text:String)->String {SHA256.hash(data:Data(text.utf8)).map{String(format:"%02x",$0)}.joined()}
    func refresh() {
        var matches:[(MIDIEndpointRef,String,String)]=[]
        for index in 0..<MIDIGetNumberOfDevices() {
            let device=MIDIGetDevice(index);var properties:Unmanaged<CFPropertyList>?
            guard MIDIObjectGetProperties(device,&properties,true)==0,let properties,let value=properties.takeRetainedValue() as? [String:Any],
                  (value["offline"] as? Int ?? 1)==0,let name=value["name"] as? String,name.localizedCaseInsensitiveContains("Helix Stadium"),
                  let serial=value["SerialNumber"] as? String,!serial.isEmpty,
                  (value["driver"] as? String ?? "").localizedCaseInsensitiveContains("USB") || value["USBVendorProduct"] != nil else{continue}
            for entityIndex in 0..<MIDIDeviceGetNumberOfEntities(device) {
                let entity=MIDIDeviceGetEntity(device,entityIndex)
                for destinationIndex in 0..<MIDIEntityGetNumberOfDestinations(entity) {matches.append((MIDIEntityGetDestination(entity,destinationIndex),name,Self.hash(serial)))}
            }
        }
        if matches.count==1,port != 0 {endpoint=matches[0].0;deviceName=matches[0].1;usbIdentity=matches[0].2;online=true}
        else {endpoint=0;usbIdentity=nil;online=false;deviceName=matches.isEmpty ? "Connect Stadium directly to iPad by USB-C":"Connect only one Stadium by USB"}
    }
    func bound(to networkIdentity:String)->Bool {online && usbIdentity != nil && UserDefaults.standard.string(forKey:"MatrixUSBPair."+networkIdentity)==usbIdentity}
    func bind(to networkIdentity:String)throws {
        refresh();guard online,let usbIdentity else{throw ProtocolError.invalid("A single Stadium USB MIDI connection is required.")}
        UserDefaults.standard.set(usbIdentity,forKey:"MatrixUSBPair."+networkIdentity)
        objectWillChange.send()
    }
    func send(channel:Int,value:Int,networkIdentity:String)throws {
        refresh();guard bound(to:networkIdentity),(1...16).contains(channel),(0...127).contains(value),port != 0 else{throw ProtocolError.invalid("Stadium USB MIDI disconnected or changed. Nothing was sent.")}
        try sendHome(channel:channel,value:value)
    }
    private func sendHome(channel:Int,value:Int)throws {
        // MIDI 1.0 Channel Voice in a Universal MIDI Packet, translated by CoreMIDI
        // to the connected USB device's negotiated protocol.
        var word=try MatrixGuitarLevels.midiWord(channel:channel,value:value)
        var list=MIDIEventList()
        let status=withUnsafeMutablePointer(to:&list){pointer -> OSStatus in
            let packet=MIDIEventListInit(pointer,._1_0)
            return withUnsafePointer(to:&word){data in
                _ = MIDIEventListAdd(pointer,MemoryLayout<MIDIEventList>.size,packet,0,1,data)
                return MIDISendEventList(port,endpoint,pointer)
            }
        }
        #if DEBUG
        let record:[String:Any]=["at":Date().timeIntervalSince1970,"channel":channel,"cc":11,"value":value,"word":String(word,radix:16),"packets":list.numPackets,"status":status]
        if let data=try? JSONSerialization.data(withJSONObject:record) {try? data.write(to:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("matrix-last-midi.json"),options:.atomic)}
        #endif
        guard status==0 else{throw ProtocolError.invalid("USB MIDI send failed. Nothing was retried.")}
    }

    #if DEBUG
    func diagnostic()->[String:Any] {
        refresh()
        var rows:[[String:Any]]=[]
        for i in 0..<MIDIGetNumberOfDevices() {
            var p:Unmanaged<CFPropertyList>?
            if MIDIObjectGetProperties(MIDIGetDevice(i),&p,true)==0,let p,let v=p.takeRetainedValue() as? [String:Any] {
                rows.append(["name":v["name"] as? String ?? "","offline":v["offline"] as? Int ?? -1,"driver":v["driver"] as? String ?? "","serialPresent":v["SerialNumber"] != nil,"usbVendorProductPresent":v["USBVendorProduct"] != nil])
            }
        }
        return ["online":online,"devices":rows,"destinations":MIDIGetNumberOfDestinations()]
    }
    #endif
}
