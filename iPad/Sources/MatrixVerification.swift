#if DEBUG
import Foundation
import SwiftUI
import UIKit
import Network
import Darwin
import StadiumProtocol
import StadiumNetwork

@MainActor func nativeMatrixTestsDisarmed()->Bool {
    let path=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("matrix-tests-gate.json")
    guard FileManager.default.fileExists(atPath:path.path) else{return false}
    guard let data=try? Data(contentsOf:path),let value=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let disabled=value["disabled"] as? Bool else{return true}
    return disabled
}

@MainActor func inspectUSBConnections(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    let midi=MatrixUSBMIDI()
    var report=midi.diagnostic()
    var interfaces:[[String:Any]]=[]
    var first:UnsafeMutablePointer<ifaddrs>?
    if getifaddrs(&first)==0,let first {
        defer{freeifaddrs(first)}
        var pointer:UnsafeMutablePointer<ifaddrs>?=first
        while let item=pointer {
            defer{pointer=item.pointee.ifa_next}
            guard let address=item.pointee.ifa_addr,Int32(address.pointee.sa_family)==AF_INET || Int32(address.pointee.sa_family)==AF_INET6 else{continue}
            var buffer=[CChar](repeating:0,count:Int(NI_MAXHOST))
            if getnameinfo(address,socklen_t(address.pointee.sa_len),&buffer,socklen_t(buffer.count),nil,0,NI_NUMERICHOST)==0 {interfaces.append(["name":String(cString:item.pointee.ifa_name),"address":String(cString:buffer)])}
        }
    }
    report["interfaces"]=interfaces
    let pathMonitor=NWPathMonitor();let pathQueue=DispatchQueue(label:"matrix.usb.inspect")
    pathMonitor.start(queue:pathQueue)
    try? await Task.sleep(for:.milliseconds(400))
    report["networkInterfaces"]=pathMonitor.currentPath.availableInterfaces.map{["name":$0.name,"type":String(describing:$0.type),"index":String($0.index)]}
    pathMonitor.cancel()
    let wiredMonitor=NWPathMonitor(requiredInterfaceType:.wiredEthernet);wiredMonitor.start(queue:pathQueue)
    try? await Task.sleep(for:.milliseconds(400))
    report["wiredStatus"]=String(describing:wiredMonitor.currentPath.status)
    report["wiredInterfaces"]=wiredMonitor.currentPath.availableInterfaces.map{["name":$0.name,"type":String(describing:$0.type),"index":String($0.index)]}
    wiredMonitor.cancel()
    report["usbHost"]=ProcessInfo.processInfo.environment["STADIUM_USB_HOST"] ?? ""
    let usbSearch=USBStadiumDiscovery();usbSearch.search()
    for _ in 0..<40 {if !usbSearch.devices.isEmpty {break};try? await Task.sleep(for:.milliseconds(150))}
    report["usbDiscoveries"]=usbSearch.devices.map{["host":$0.host,"port":String($0.port),"interface":$0.interface?.name ?? "unknown","type":$0.interface.map{String(describing:$0.type)} ?? "unknown"]}
    let discovered=usbSearch.devices.first;usbSearch.stop()
    let session=StadiumSession()
    do {
        guard let host=discovered?.host ?? ProcessInfo.processInfo.environment["STADIUM_USB_HOST"],!host.isEmpty else{throw ProtocolError.invalid("A reviewed USB hostname is required for this read-only check.")}
        let trace=try TraceRecorder(path:folder.appendingPathComponent("matrix-usb-connect-"+UUID().uuidString+".jsonl").path,maximumBytes:1024*1024)
        try await session.connect(host:host,trace:trace,route:.usb,interface:discovered?.interface)
        let state=try await session.snapshot()
        let matrix=try MatrixGuitarLevels(value:await session.read(.matrixMixer))
        let channels=try await session.matrixMIDIChannels()
        let eq=try await session.read(.globalEQ)
        report["usbEditorConnected"]=true;report["interface"]=await session.connectionInterface()
        report["matchesSelectedStadium"]=state.product["host"]["snum"]==monitor.snapshot?.product["host"]["snum"]
        report["presetID"]=state.presetID;report["matrixLevels"]=matrix.levels;report["matrixChannels"]=channels;report["eqRead"]=eq != .null
    }catch{report["usbEditorConnected"]=false;report["usbError"]=error.localizedDescription}
    await session.disconnect()
    try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("matrix-usb-inspection.json"),options:.atomic)
}
#endif
#if DEBUG
@MainActor func prepareUSBSpareChecks(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    var report:[String:Any]=["passed":false]
    do {
        let intent=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("usb-spare-intent.json"))) as? [String:Any]
        guard intent?["authorizeUSBSpareCopies"] as? Bool==true,let run=intent?["run"] as? String,UUID(uuidString:run) != nil,let expectedID=intent?["sourceID"] as? Int,monitor.connectionInterface=="USB/Ethernet" else{throw ProtocolError.invalid("A reviewed USB spare-copy intent is required.")}
        let marker=folder.appendingPathComponent("usb-spare-"+run+"-started")
        guard !FileManager.default.fileExists(atPath:marker.path) else{throw ProtocolError.invalid("Do not replay an interrupted allocation.")}
        let before=try await monitor.readUSBSource()
        guard before.presetID==expectedID else{throw ProtocolError.invalid("The active preset changed before USB qualification.")}
        let saved=try await monitor.readUSBSavedSource(expectedID)
        try before.rawEditBuffer.write(to:folder.appendingPathComponent("usb-source-live-original.bin"),options:.atomic)
        try saved.write(to:folder.appendingPathComponent("usb-source-saved-original.bin"),options:.atomic)
        try Data("started".utf8).write(to:marker,options:.withoutOverwriting)
        var copies:[PreservedPreset]=[]
        for name in ["USB Preserve 1121","USB Edit Test 1121"] {
            let copy=try await monitor.prepareUSBSpare(name:name,expectedID:expectedID)
            copies.append(copy)
            try JSONEncoder().encode(copies).write(to:folder.appendingPathComponent("usb-spare-copies.json"),options:.atomic)
        }
        let after=try await monitor.readUSBSource(),savedAfter=try await monitor.readUSBSavedSource(expectedID)
        guard copies.count==2,copies[0].preset.contentID != copies[1].preset.contentID,copies.allSatisfy({$0.sourceID==expectedID && $0.sourceHash==PresetBackupStore.hash(before.rawEditBuffer)}),before.rawEditBuffer==after.rawEditBuffer,before.presetID==after.presetID,before.activeSnapshot==after.activeSnapshot,before.dirty==after.dirty,saved==savedAfter else{throw ProtocolError.invalid("Original preset preservation differs after the USB copy check.")}
        report["passed"]=true;report["copies"]=copies.map{["name":$0.preset.name,"id":$0.preset.contentID ?? -1,"label":$0.preset.label]};report["sourceSavedUnchanged"]=true;report["sourceLiveUnchanged"]=true;report["sourcePresetID"]=expectedID;report["sourceHash"]=PresetBackupStore.hash(before.rawEditBuffer)
    }catch{report["error"]=error.localizedDescription}
    try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("usb-spare-verification.json"),options:.atomic)
}
#endif

#if DEBUG
@MainActor func captureMatrixLayouts(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    do {
        let state=try await monitor.readMatrixConsole()
        let report:[String:Any]=["readSucceeded":true,"channels":state.strips(3).count,"linked":state.linked,"interface":monitor.connectionInterface]
        try JSONSerialization.data(withJSONObject:report).write(to:folder.appendingPathComponent("matrix-console-inspection.json"),options:.atomic)
        for (name,size,expanded) in [("pro",CGSize(width:1200,height:760),false),("regular",CGSize(width:960,height:620),false),("portrait",CGSize(width:700,height:820),false),("expanded",CGSize(width:960,height:620),true)] {
            let host=UIHostingController(rootView:MatrixMixerView(initialOutput:3,preview:true,previewState:state,expanded:expanded).environmentObject(monitor))
            host.view.bounds=CGRect(origin:.zero,size:size);host.view.backgroundColor = .black;host.view.setNeedsLayout();host.view.layoutIfNeeded()
            try? await Task.sleep(for:.milliseconds(100))
            let image=UIGraphicsImageRenderer(size:size).image{_ in host.view.drawHierarchy(in:host.view.bounds,afterScreenUpdates:true)}
            try image.pngData()?.write(to:folder.appendingPathComponent("matrix-layout-"+name+".png"),options:.atomic)
        }
    }catch {try? JSONSerialization.data(withJSONObject:["readSucceeded":false,"error":error.localizedDescription]).write(to:folder.appendingPathComponent("matrix-console-inspection.json"),options:.atomic)}
}
#endif

#if DEBUG
/// Explicit one-shot Phones/Home pan check; no preset, level, mute or solo writes.
@MainActor func verifyMatrixPanTiming(_ monitor:StadiumMonitor)async {
    guard !nativeMatrixTestsDisarmed() else{return}
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    var report:[String:Any]=["passed":false,"restored":false]
    var needsRestore=false
    var steps:[[String:Any]]=[]
    let midi=MatrixUSBMIDI()
    var identity:String?
    func apply(_ value:Int)async throws {
        let state=try await monitor.readMatrixConsole(),channels=try await monitor.matrixChannels()
        guard monitor.connected,monitor.connectionRoute == .usb,monitor.connectionInterface=="USB/Ethernet",state.linked==0,let id=identity,midi.bound(to:id) else{throw ProtocolError.invalid("USB Matrix test context changed.")}
        let command=try MatrixConsoleCommand(output:3,source:5,field:.pan,value:value),connection=monitor.connectionID,started=Date()
        let after=try await monitor.setMatrixConsole(command,expected:state,channel:channels[2]) {
            try await MainActor.run {
                guard monitor.connected,monitor.connectionID==connection else{throw CancellationError()}
                try midi.send(command,channel:channels[2],networkIdentity:id)
            }
        }
        guard let pan=after.strip(output:3,source:5)?.pan else{throw ProtocolError.invalid("Pan readback unavailable.")}
        steps.append(["midi":value,"pan":pan,"transactionMilliseconds":Date().timeIntervalSince(started)*1000])
        if value==64 {guard abs(pan)<0.00001 else{throw ProtocolError.invalid("Center was not confirmed.")}}
    }
    do {
        let intent=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("matrix-pan-intent.json"))) as? [String:Any]
        guard intent?["authorizePhonesHomePanTimingAndCenter"] as? Bool==true,let run=intent?["run"] as? String,UUID(uuidString:run) != nil,
              monitor.connected,monitor.connectionRoute == .usb,let product=monitor.snapshot?.product,let id=FileCompanion.deviceID(product) else{throw ProtocolError.invalid("A reviewed one-shot USB pan intent is required.")}
        let marker=folder.appendingPathComponent("matrix-pan-"+run+"-started")
        guard !FileManager.default.fileExists(atPath:marker.path) else{throw ProtocolError.invalid("Do not replay an interrupted pan test.")}
        identity=id;midi.refresh();guard midi.bound(to:id) else{throw ProtocolError.invalid("The attached USB Stadium is not confirmed.")}
        let before=try await monitor.readMatrixConsole()
        try MessagePack.encode(before.property).write(to:folder.appendingPathComponent("matrix-pan-before.bin"),options:.atomic)
        try Data("started".utf8).write(to:marker,options:.withoutOverwriting)
        needsRestore=true
        try await apply(62)
        try await apply(64);needsRestore=false
        report["passed"]=true;report["restored"]=true
    }catch {
        report["error"]=error.localizedDescription
        if needsRestore {
            // Separate explicit baseline restoration, never a replay of the failed edit.
            do {try await apply(64);report["restored"]=true}catch{report["restoreError"]=error.localizedDescription}
        }
    }
    report["steps"]=steps
    try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("matrix-pan-timing.json"),options:.atomic)
}
#endif

#if DEBUG
/// Bounded autonomous Solo qualification, with absolute CC103 recovery.
@MainActor func verifyMatrixSoloRoundTrip(_ monitor:StadiumMonitor,model:MatrixConsoleModel?=nil,close:(@MainActor ()->Void)?=nil)async->Bool {
    guard !nativeMatrixTestsDisarmed() else{return false}
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    var report:[String:Any]=["passed":false,"restored":false]
    var steps:[[String:Any]]=[],started=false,clearAttempted=false,soloMayBeActive=false
    let midi=MatrixUSBMIDI()
    var identity:String?
    func context()async throws->(MatrixConsoleState,Int,String,UUID) {
        let state=try await monitor.readMatrixConsole(),channels=try await monitor.matrixChannels()
        guard monitor.connected,monitor.connectionRoute == .usb,monitor.connectionInterface=="USB/Ethernet",state.linked==0,let id=identity,midi.bound(to:id) else{throw ProtocolError.invalid("USB Solo test context changed.")}
        return(state,channels[2],id,monitor.connectionID)
    }
    func toggle(_ name:String)async throws {
        let (before,channel,id,connection)=try await context(),time=Date()
        let command=try MatrixConsoleCommand(output:3,source:5,field:.solo,value:127)
        let after:MatrixConsoleState
        if let model {
            model.send(command,monitor:monitor)
            let deadline=Date().addingTimeInterval(5)
            while model.gestureWorkPending {guard model.ready,Date()<deadline else{throw ProtocolError.invalid(model.message)};try await Task.sleep(for:.milliseconds(10))}
            guard model.ready else{throw ProtocolError.invalid(model.message)}
            after=try await monitor.readMatrixConsole()
            guard after.strip(output:3,source:5)?.solo == !(before.strip(output:3,source:5)!.solo) else{throw ProtocolError.invalid("The UI Solo toggle was not confirmed.")}
        }else {
            after=try await monitor.setMatrixConsole(command,expected:before,channel:channel) {
                try await MainActor.run {
                    guard monitor.connected,monitor.connectionID==connection else{throw CancellationError()}
                    try midi.send(command,channel:channel,networkIdentity:id)
                }
            }
        }
        steps.append(["name":name,"solo":after.strip(output:3,source:5)!.solo,"milliseconds":Date().timeIntervalSince(time)*1000])
    }
    func clear()async throws {
        clearAttempted=true
        let (before,channel,id,connection)=try await context(),time=Date()
        let command=try MatrixClearSolosCommand(output:3)
        let after=try await monitor.clearMatrixSolos(command,expected:before,channel:channel) {
            try await MainActor.run {
                guard monitor.connected,monitor.connectionID==connection else{throw CancellationError()}
                try midi.clearSolos(command,channel:channel,networkIdentity:id)
            }
        }
        guard after.strips(3).allSatisfy({!$0.solo}) else{throw ProtocolError.invalid("Solo recovery is not confirmed.")}
        report["restored"]=true
        steps.append(["name":"Clear Solos","solo":false,"milliseconds":Date().timeIntervalSince(time)*1000])
    }
    do {
        if let model {
            let deadline=Date().addingTimeInterval(20)
            while !model.ready,Date()<deadline {try await Task.sleep(for:.milliseconds(100))}
            guard model.ready else{throw ProtocolError.invalid("The presented Matrix model is not ready.")}
            try await Task.sleep(for:.seconds(2))
        }
        let intent=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("matrix-solo-intent.json"))) as? [String:Any]
        guard intent?["authorizePhonesHomeSoloRoundTrip"] as? Bool==true,let run=intent?["run"] as? String,UUID(uuidString:run) != nil else{throw ProtocolError.invalid("A reviewed one-shot Solo intent is required.")}
        guard monitor.connected else{throw ProtocolError.invalid("The USB editor session is not connected. No Solo commands were sent.")}
        guard let product=monitor.snapshot?.product,let id=FileCompanion.deviceID(product) else{throw ProtocolError.invalid("The selected Stadium identity is unavailable.")}
        let marker=folder.appendingPathComponent("matrix-solo-"+run+"-started")
        guard !FileManager.default.fileExists(atPath:marker.path) else{throw ProtocolError.invalid("Do not replay an interrupted Solo test.")}
        identity=id;midi.refresh()
        let (baseline,_,_,_)=try await context()
        guard baseline.strips(3).allSatisfy({!$0.solo}) else{throw ProtocolError.invalid("Clear existing Phones solos before qualification.")}
        let source=try await monitor.readUSBSource()
        guard let sourceID=source.presetID else{throw ProtocolError.invalid("Current preset identity unavailable.")}
        let saved=try await monitor.readUSBSavedSource(sourceID)
        try MessagePack.encode(baseline.property).write(to:folder.appendingPathComponent("matrix-solo-before.bin"),options:.atomic)
        try Data("started".utf8).write(to:marker,options:.withoutOverwriting);started=true
        soloMayBeActive=true
        try await toggle("Solo on")
        try await toggle("Solo off")
        let final=try await monitor.readMatrixConsole()
        guard final.strips(3).allSatisfy({!$0.solo}) else{throw ProtocolError.invalid("Solo off is not confirmed.")}
        soloMayBeActive=false;report["restored"]=true
        let afterSource=try await monitor.readUSBSource(),afterSaved=try await monitor.readUSBSavedSource(sourceID)
        guard afterSource.rawEditBuffer==source.rawEditBuffer,afterSource.presetID==source.presetID,afterSource.activeSnapshot==source.activeSnapshot,afterSource.dirty==source.dirty,saved==afterSaved else{throw ProtocolError.invalid("Preset preservation differs after the Solo test.")}
        report["presetUnchanged"]=true;report["passed"]=true
    }catch {
        report["error"]=error.localizedDescription
        if started,soloMayBeActive,!clearAttempted {do{try await clear()}catch{report["restoreError"]=error.localizedDescription}}
    }
    report["steps"]=steps;report["started"]=started;report["at"]=Date().timeIntervalSince1970
    report["usesPresentedModel"]=model != nil
    try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("matrix-solo-result.json"),options:.atomic)
    if report["passed"] as? Bool==true,ProcessInfo.processInfo.arguments.contains("--verify-matrix-close") {close?()}
    return report["passed"] as? Bool==true
}
#endif

#if DEBUG
@MainActor private final class MatrixFrameProbe:NSObject {
    private var link:CADisplayLink?
    private var last:Double?
    private(set) var gaps:[Double]=[]
    func start(){let link=CADisplayLink(target:self,selector:#selector(tick(_:)));link.preferredFramesPerSecond=60;link.add(to:.main,forMode:.common);self.link=link}
    @objc private func tick(_ link:CADisplayLink){if let last {gaps.append((link.timestamp-last)*1000)};last=link.timestamp}
    func stop(){link?.invalidate();link=nil}
}

/// Exercises the actual presented view model and queue, with main-thread frame sampling.
@MainActor func verifyMatrixGestureTiming(_ model:MatrixConsoleModel,monitor:StadiumMonitor,close:(@MainActor ()->Void)?=nil)async->Bool {
    guard !nativeMatrixTestsDisarmed() else{return false}
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    var report:[String:Any]=["passed":false,"restored":false],started=false
    let probe=MatrixFrameProbe();defer{probe.stop()}
    func waitIdle()async throws {
        let deadline=Date().addingTimeInterval(5)
        while model.gestureWorkPending {
            guard Date()<deadline,model.ready else{throw ProtocolError.invalid(model.message)}
            try await Task.sleep(for:.milliseconds(10))
        }
        guard model.ready else{throw ProtocolError.invalid(model.message)}
    }
    func center()async throws {
        let before=try await monitor.readMatrixConsole(),channels=try await monitor.matrixChannels()
        guard monitor.connected,monitor.connectionRoute == .usb,before.linked==0,let product=monitor.snapshot?.product,let id=FileCompanion.deviceID(product) else{throw ProtocolError.invalid("USB gesture restoration context changed.")}
        let command=try MatrixConsoleCommand(output:3,source:5,field:.pan,value:64),connection=monitor.connectionID
        let after=try await monitor.setMatrixConsole(command,expected:before,channel:channels[2]) {
            try await MainActor.run {
                guard monitor.connected,monitor.connectionID==connection else{throw CancellationError()}
                try model.usb.send(command,channel:channels[2],networkIdentity:id)
            }
        }
        guard after.strip(output:3,source:5)?.pan==0 else{throw ProtocolError.invalid("Center restoration is unconfirmed.")};report["restored"]=true
    }
    do {
        let deadline=Date().addingTimeInterval(20)
        while !model.ready,Date()<deadline {try await Task.sleep(for:.milliseconds(100))}
        guard model.ready,monitor.connectionRoute == .usb,monitor.connectionInterface=="USB/Ethernet",!ProcessInfo.processInfo.arguments.contains("--verify-matrix-solo"),!ProcessInfo.processInfo.arguments.contains("--verify-matrix-pan") else{throw ProtocolError.invalid("A separate USB gesture test session is required.")}
        let intent=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("matrix-gesture-intent.json"))) as? [String:Any]
        guard intent?["authorizeSmallPhonesPanGestureAndCenter"] as? Bool==true,let run=intent?["run"] as? String,UUID(uuidString:run) != nil else{throw ProtocolError.invalid("A reviewed gesture intent is required.")}
        let marker=folder.appendingPathComponent("matrix-gesture-"+run+"-started")
        guard !FileManager.default.fileExists(atPath:marker.path) else{throw ProtocolError.invalid("Do not replay a marked gesture check.")}
        try await Task.sleep(for:.seconds(2))
        let before=try await monitor.readMatrixConsole(),source=try await monitor.readUSBSource()
        guard before.linked==0,before.strips(3).allSatisfy({!$0.solo}),let sourceID=source.presetID else{throw ProtocolError.invalid("Solo must be off before the gesture test.")}
        let saved=try await monitor.readUSBSavedSource(sourceID)
        try MessagePack.encode(before.property).write(to:folder.appendingPathComponent("matrix-gesture-before.bin"),options:.atomic)
        try Data("started".utf8).write(to:marker,options:.withoutOverwriting);started=true
        let values=Array(repeating:[62,63,64,65,66,65,64,63],count:6).flatMap{$0}+[62]
        var rewinds=0,inputMilliseconds:[Double]=[]
        probe.start()
        for value in values {
            guard model.ready else{throw ProtocolError.invalid(model.message)}
            let command=try MatrixConsoleCommand(output:3,source:5,field:.pan,value:value),time=Date()
            model.send(command,monitor:monitor)
            inputMilliseconds.append(Date().timeIntervalSince(time)*1000)
            if model.positions[command.key] != value {rewinds+=1}
            try await Task.sleep(for:.milliseconds(33))
            if model.positions[command.key] != value {rewinds+=1}
        }
        let drain=Date();try await waitIdle();let drainMS=Date().timeIntervalSince(drain)*1000
        guard let final=model.state?.strip(output:3,source:5),abs(final.pan-(try MatrixPan.value(forMIDI:62)))<0.00001 else{throw ProtocolError.invalid("The newest gesture was not confirmed.")}
        model.send(try MatrixConsoleCommand(output:3,source:5,field:.pan,value:64),monitor:monitor)
        try await waitIdle()
        guard model.state?.strip(output:3,source:5)?.pan==0 else{throw ProtocolError.invalid("Center restoration is unconfirmed.")}
        report["restored"]=true;probe.stop()
        if intent?["authorizePhonesPanEndpointAndCenter"] as? Bool==true {
            report["restored"]=false
            model.send(try MatrixConsoleCommand(output:3,source:5,field:.pan,value:0),monitor:monitor);try await waitIdle()
            guard model.state?.strip(output:3,source:5)?.pan == -1 else{throw ProtocolError.invalid("Left endpoint was not confirmed.")}
            let endpoint=Date()
            model.send(try MatrixConsoleCommand(output:3,source:5,field:.pan,value:1),monitor:monitor);try await waitIdle()
            guard model.state?.strip(output:3,source:5)?.pan == -1 else{throw ProtocolError.invalid("Equivalent endpoint changed the pan.")}
            report["leftEndpointNoOpMilliseconds"]=Date().timeIntervalSince(endpoint)*1000;report["leftEndpointPassed"]=true
            model.send(try MatrixConsoleCommand(output:3,source:5,field:.pan,value:64),monitor:monitor);try await waitIdle()
            guard model.state?.strip(output:3,source:5)?.pan==0 else{throw ProtocolError.invalid("Endpoint test did not restore Center.")};report["restored"]=true
        }
        let afterSource=try await monitor.readUSBSource(),afterSaved=try await monitor.readUSBSavedSource(sourceID)
        let untouched=source.rawEditBuffer==afterSource.rawEditBuffer && source.presetID==afterSource.presetID && source.activeSnapshot==afterSource.activeSnapshot && source.dirty==afterSource.dirty && saved==afterSaved
        let frames=probe.gaps.sorted(),p95=frames.isEmpty ? 999:frames[min(frames.count-1,Int(Double(frames.count)*0.95))]
        report["requestCount"]=values.count;report["thumbRewinds"]=rewinds;report["maxInputHandlingMilliseconds"]=inputMilliseconds.max() ?? 0
        report["finalBurstDrainMilliseconds"]=drainMS;report["p95MainThreadFrameGapMilliseconds"]=p95;report["maxMainThreadFrameGapMilliseconds"]=frames.max() ?? 0;report["sampledFrames"]=frames.count;report["presetUnchanged"]=untouched
        report["passed"]=rewinds==0 && (inputMilliseconds.max() ?? 999)<16 && drainMS<300 && p95<34 && untouched
        if let window=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow}) {
            let image=UIGraphicsImageRenderer(bounds:window.bounds).image{_ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)}
            try? image.pngData()?.write(to:folder.appendingPathComponent("matrix-gesture-screen.png"),options:.atomic)
        }
    }catch {
        report["error"]=error.localizedDescription
        if started {model.stop();let deadline=Date().addingTimeInterval(2);while monitor.busy,Date()<deadline {try? await Task.sleep(for:.milliseconds(20))};do{try await center()}catch{report["restoreError"]=error.localizedDescription}}
    }
    report["at"]=Date().timeIntervalSince1970;report["started"]=started
    try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("matrix-gesture-result.json"),options:.atomic)
    if report["passed"] as? Bool==true,ProcessInfo.processInfo.arguments.contains("--verify-matrix-close") {close?()}
    return report["passed"] as? Bool==true
}
#endif

#if DEBUG
@MainActor func recordMatrixClose(_ monitor:StadiumMonitor,expectedIdle:Bool?) {
    guard ProcessInfo.processInfo.arguments.contains("--verify-matrix-close") else{return}
    Task {@MainActor in
        try? await Task.sleep(for:.milliseconds(600))
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        let report:[String:Any]=["leaseCount":monitor.debugMatrixPresentationCount,"idleTimerRestored":expectedIdle.map{$0==UIApplication.shared.isIdleTimerDisabled} ?? false,"connected":monitor.connected,"busy":monitor.busy]
        try? JSONSerialization.data(withJSONObject:report).write(to:folder.appendingPathComponent("matrix-close-result.json"),options:.atomic)
        if let window=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap({$0.windows}).first(where:{$0.isKeyWindow}) {
            let image=UIGraphicsImageRenderer(bounds:window.bounds).image{_ in window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)}
            try? image.pngData()?.write(to:folder.appendingPathComponent("matrix-close-screen.png"),options:.atomic)
        }
    }
}
#endif

#if DEBUG
/// Only explicit popup output taps send navigation; opening/closing never does.
@MainActor func verifyMatrixOutputIcons(_ monitor:StadiumMonitor,select:@escaping @MainActor (Int)async->Bool)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    var report:[String:Any]=["passed":false]
    do {
        let deadline=Date().addingTimeInterval(20)
        while !monitor.connected,Date()<deadline {try await Task.sleep(for:.milliseconds(100))}
        guard monitor.connected,monitor.connectionRoute == .usb else{throw ProtocolError.closed}
        let intent=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("matrix-output-icons-intent.json"))) as? [String:Any]
        guard intent?["authorizePopupOutputNavigation"] as? Bool==true,let run=intent?["run"] as? String,UUID(uuidString:run) != nil else{throw ProtocolError.invalid("A reviewed popup navigation intent is required.")}
        let source=try await monitor.readUSBSource()
        guard let id=source.presetID else{throw ProtocolError.closed}
        let saved=try await monitor.readUSBSavedSource(id),before=try await monitor.readMatrixConsole()
        try Data("started".utf8).write(to:folder.appendingPathComponent("matrix-output-icons-"+run+"-started"),options:.withoutOverwriting)
        var rows:[Int]=[]
        for output in [1,2,3,3] {
            guard await select(output) else{throw ProtocolError.invalid("Popup output navigation failed.")}
            try await Task.sleep(for:.milliseconds(500))
            let state=try await monitor.readMatrixConsole()
            guard state.property["val_"]["atto"].integer==output else{throw ProtocolError.invalid("The selected output was not confirmed.")}
            rows.append(output)
        }
        let after=try await monitor.readMatrixConsole(),afterSource=try await monitor.readUSBSource(),afterSaved=try await monitor.readUSBSavedSource(id)
        let untouched=source.rawEditBuffer==afterSource.rawEditBuffer && source.presetID==afterSource.presetID && source.activeSnapshot==afterSource.activeSnapshot && source.dirty==afterSource.dirty && saved==afterSaved
        let mixerUnchanged=(1...3).allSatisfy{before.strips($0)==after.strips($0) && before.layer($0)["out_"]==after.layer($0)["out_"]} && before.linked==after.linked
        report["outputs"]=rows;report["presetUnchanged"]=untouched;report["mixerUnchanged"]=mixerUnchanged;report["passed"]=untouched && mixerUnchanged
    }catch {report["error"]=error.localizedDescription}
    try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("matrix-output-icons-result.json"),options:.atomic)
}
#endif
