#if DEBUG
import SwiftUI
import UIKit
import StadiumProtocol

@MainActor func verifyGlobalEQ(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0],marker="global-eq-check-started"
    var checks=0
    do {
        let permission=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("global-eq-intent.json"))) as? [String:Bool]
        guard permission?["authorizeGlobalEQCheck"]==true,!FileManager.default.fileExists(atPath:folder.appendingPathComponent(marker).path),let preset=monitor.snapshot,preset.presetName=="StadiumPad Commands Test" else{throw ProtocolError.invalid("A fresh reviewed Global EQ intent and the existing spare are required.")}
        await monitor.refreshGlobalEQ()
        guard let initial=monitor.globalEQ else{throw ProtocolError.invalid("Global EQ unavailable.")}
        try initial.raw.write(to:folder.appendingPathComponent("global-eq-original.bin"),options:.atomic)
        try Data("started".utf8).write(to:folder.appendingPathComponent(marker),options:.atomic)
        func update(_ output:EQOutput,_ operation:GlobalEQOperation)async throws {
            guard let expected=monitor.globalEQ,await monitor.editGlobalEQ(expected,output,operation) else{throw ProtocolError.invalid(monitor.errorText ?? "EQ edit failed.")};checks+=1
        }
        for output in EQOutput.allCases {
            try await update(output,.parameters([GlobalEQChange(.mid,.frequency,.number(2050)),GlobalEQChange(.mid,.gain,.number(-0.125)),GlobalEQChange(.mid,.q,.number(0.8)),GlobalEQChange(.lowCut,.slope,.int(2)),GlobalEQChange(.highCut,.enable,.bool(false)),GlobalEQChange(.mid,.level,.number(-0.25))]))
            try await update(output,.enabled(true));try await update(output,.enabled(false))
            try await update(output,.reset);try await update(output,.replace(initial.output(output)))
        }
        try await update(.xlr,.replace(initial.output(.quarter)));try await update(.xlr,.replace(initial.output(.xlr)))
        await monitor.refreshGlobalEQ()
        guard monitor.globalEQ?.sameSettings(initial)==true,monitor.snapshot?.presetID==preset.presetID,monitor.snapshot?.dirty==preset.dirty,monitor.snapshot?.editBuffer==preset.editBuffer else{throw ProtocolError.invalid("EQ restoration or preset preservation failed.")}
        let result:[String:Any] = ["passed":true,"checks":checks,"restored":true,"presetUnchanged":true]
        try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:folder.appendingPathComponent("global-eq-verification.json"),options:.atomic)
    }catch {
        let result:[String:Any] = ["passed":false,"checks":checks,"error":error.localizedDescription]
        try? JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:folder.appendingPathComponent("global-eq-verification.json"),options:.atomic)
    }
}
@MainActor func captureGlobalEQLayouts(monitor:StadiumMonitor,discovery:StadiumDiscovery)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    for (name,size) in [("pro",CGSize(width:1366,height:980)),("regular",CGSize(width:1024,height:724)),("portrait",CGSize(width:768,height:980))] {
        for band in [EQBand.lowCut,.mid] {
            let view=GlobalEQView(preview:true,initialBand:band).environmentObject(monitor).preferredColorScheme(.dark)
            let host=UIHostingController(rootView:view);host.view.frame=CGRect(origin:.zero,size:CGSize(width:size.width,height:size.height-65));host.view.setNeedsLayout();host.view.layoutIfNeeded()
            try? await Task.sleep(for:.milliseconds(250))
            let image=UIGraphicsImageRenderer(size:host.view.bounds.size).image {_ in host.view.drawHierarchy(in:host.view.bounds,afterScreenUpdates:true)}
            try? image.pngData()?.write(to:folder.appendingPathComponent("layout-eq-\(name)-\(band.rawValue).png"),options:.atomic)
        }
    }
}
@MainActor func verifyGlobalEQStream(_ monitor:StadiumMonitor)async {
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    let marker=folder.appendingPathComponent("global-eq-stream-check-started")
    var checks=0,maxLatency=0.0
    do {
        let permission=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("global-eq-stream-intent.json"))) as? [String:Bool]
        guard permission?["authorizeGlobalEQCheck"]==true,!FileManager.default.fileExists(atPath:marker.path),let preset=monitor.snapshot,preset.presetName=="StadiumPad Commands Test" else{throw ProtocolError.invalid("A fresh reviewed stream-check intent and the spare preset are required.")}
        await monitor.refreshGlobalEQ()
        guard let initial=monitor.globalEQ,initial.output(.quarter)["enab"].boolean==false else{throw ProtocolError.invalid("The reviewed bypassed EQ is required for this small live test.")}
        try initial.raw.write(to:folder.appendingPathComponent("global-eq-stream-original.bin"),options:.atomic)
        try Data("started".utf8).write(to:marker,options:.atomic)
        let frequency=initial.parameter(.quarter,.mid,.frequency).numeric!,gain=initial.parameter(.quarter,.mid,.gain).numeric!
        for index in 0..<12 {
            if index==6 {monitor.finishGlobalEQGesture(output:.quarter);try await Task.sleep(for:.milliseconds(100))}
            guard let expected=monitor.globalEQ else{throw ProtocolError.invalid("Live EQ became unavailable.")}
            let changes=[GlobalEQChange(.mid,.frequency,.number(min(20000,max(20,frequency+Double(index+1)*2)))),GlobalEQChange(.mid,.gain,.number(min(24,max(-24,gain+Double(index+1)*0.01))))]
            let start=Date()
            guard await monitor.editGlobalEQ(expected,.quarter,.parameters(changes),live:true),monitor.errorText==nil else{throw ProtocolError.invalid(monitor.errorText ?? "Live EQ edit failed.")}
            maxLatency=max(maxLatency,Date().timeIntervalSince(start));checks+=1
            try await Task.sleep(for:.milliseconds(40))
        }
        monitor.finishGlobalEQGesture(output:.quarter);await monitor.waitForGlobalEQConfirmation()
        guard monitor.errorText==nil,let live=monitor.globalEQ else{throw ProtocolError.invalid(monitor.errorText ?? "Commit check failed.")}
        let stored=try GlobalEQState(value:MessagePack.decode(live.raw)["val_"])
        guard stored.sameSettings(live) else{throw ProtocolError.invalid("Final stored settings differ from live settings.")}
        guard await monitor.editGlobalEQ(live,.quarter,.replace(initial.output(.quarter))),monitor.globalEQ?.sameSettings(initial)==true else{throw ProtocolError.invalid(monitor.errorText ?? "Original EQ restoration was not confirmed.")}
        checks+=1
        guard monitor.snapshot?.presetID==preset.presetID,monitor.snapshot?.activeSnapshot==preset.activeSnapshot,monitor.snapshot?.editBuffer==preset.editBuffer,monitor.snapshot?.dirty==preset.dirty else{throw ProtocolError.invalid("Preset state changed during the stream check.")}
        let report:[String:Any] = ["passed":true,"checks":checks,"restored":true,"presetUnchanged":true,"maximumLiveLatencySeconds":maxLatency,"build":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "unknown"]
        try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("global-eq-stream-verification.json"),options:.atomic)
    }catch {
        let report:[String:Any] = ["passed":false,"checks":checks,"maximumLiveLatencySeconds":maxLatency,"error":error.localizedDescription]
        try? JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:folder.appendingPathComponent("global-eq-stream-verification.json"),options:.atomic)
    }
}
#endif
