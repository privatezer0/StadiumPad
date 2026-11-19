#if DEBUG
import Foundation
import CryptoKit
import StadiumProtocol

/// Explicit, private-plan-only verification. Never called by a Release build.
@MainActor func verifyCloneLibrary(_ monitor:StadiumMonitor)async {
    let documents=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    let planURL=documents.appendingPathComponent("clone-verification-plan.json")
    var report:[String:Any]=[:]
    do {
        guard var plan=try JSONSerialization.jsonObject(with:Data(contentsOf:planURL)) as? [String:Any],plan["authorizedSpareClone"] as? Bool==true,plan["phase"] as? String=="prepared",let link=plan["pairingLink"] as? String,let folder=plan["importFolder"] as? Int,folder>0,let parent=plan["exportFolder"] as? Int,let exportID=plan["exportID"] as? Int,let expectedExport=plan["exportSHA256"] as? String,let cloneUUID=plan["importUUID"] as? String,let filename=plan["importFile"] as? String,filename==URL(fileURLWithPath:filename).lastPathComponent,let deviceID=monitor.snapshot.flatMap({FileCompanion.deviceID($0.product)}),let before=monitor.snapshot else{throw ProtocolError.invalid("A fresh, authorized spare-clone test plan is required.")}
        let companion=FileCompanion();try companion.configure(link);try await companion.check(deviceID:deviceID);report["pairingConfirmed"]=true
        do {try await companion.check(deviceID:String(repeating:"0",count:64));throw ProtocolError.invalid("Wrong Stadium identity was accepted.")}catch {guard error.localizedDescription.contains("different Stadium") else{throw error};report["wrongStadiumRefused"]=true}
        var bad=URLComponents(string:link)!;bad.queryItems=bad.queryItems?.map{$0.name=="pin" ? URLQueryItem(name:"pin",value:String(repeating:"0",count:64)):$0}
        try companion.configure(bad.string!)
        var refused=false
        do {try await companion.check(deviceID:deviceID)}catch{refused=true}
        try companion.configure(link)
        guard refused else{throw ProtocolError.invalid("Wrong companion TLS pin was accepted.")};report["wrongTLSPinRefused"]=true
        try await monitor.readLibraryFolder(parent)
        guard let entry=monitor.libraryEntries[parent]?.first(where:{$0.id==exportID && $0.type==11}) else{throw ProtocolError.invalid("The test export clone is unavailable.")}
        let url=try await companion.exportClone(entry,deviceID:deviceID)
        let digest=SHA256.hash(data:try Data(contentsOf:url)).map{String(format:"%02x",$0)}.joined()
        guard digest==expectedExport else{throw ProtocolError.invalid("Native iPad clone export differs from its source.")};report["exportExactBytes"]=true
        try await monitor.readLibraryFolder(folder)
        guard !(monitor.libraryEntries[folder] ?? []).contains(where:{$0.cloneUUID==cloneUUID}) else{throw ProtocolError.invalid("The spare clone has already been imported; do not repeat.")}
        plan["phase"]="import-requested";try JSONSerialization.data(withJSONObject:plan).write(to:planURL,options:.atomic)
        try await companion.importFiles([documents.appendingPathComponent(filename)],deviceID:deviceID,folder:folder)
        try await monitor.readLibraryFolder(folder)
        guard let imported=monitor.libraryEntries[folder]?.first(where:{$0.cloneUUID==cloneUUID && $0.type==11}),imported.parent==folder else{throw ProtocolError.invalid("The iPad import was not independently found in its destination.")}
        report["importInCustomFolder"]=true;report["importedContentID"]=imported.id
        try await companion.checkLast(deviceID:deviceID);report["lastTransferReadback"]=true
        if let after=monitor.snapshot {report["samePresetAndTone"]=before.presetID==after.presetID && before.activeSnapshot==after.activeSnapshot && before.blocks==after.blocks && before.dirty==after.dirty}
        plan["phase"]="verified";try JSONSerialization.data(withJSONObject:plan).write(to:planURL,options:.atomic)
    }catch{report["error"]=error.localizedDescription}
    if var plan=(try? JSONSerialization.jsonObject(with:Data(contentsOf:planURL))) as? [String:Any] {plan.removeValue(forKey:"pairingLink");try? JSONSerialization.data(withJSONObject:plan).write(to:planURL,options:.atomic)}
    try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:documents.appendingPathComponent("clone-verification-result.json"),options:.atomic)
}
@MainActor func verifyLibraryBackup(_ monitor:StadiumMonitor)async {
    let documents=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    var report:[String:Any]=[:]
    do {
        guard let before=monitor.snapshot,let deviceID=FileCompanion.deviceID(before.product) else{throw ProtocolError.invalid("Connect to Stadium before downloading its library.")}
        let companion=FileCompanion()
        let url=try await companion.downloadLibrary(deviceID:deviceID)
        report["file"]=url.lastPathComponent
        report["bytes"]=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize
        if let after=monitor.snapshot {report["samePresetAndTone"]=before.presetID==after.presetID && before.activeSnapshot==after.activeSnapshot && before.blocks==after.blocks && before.dirty==after.dirty}
    }catch{report["error"]=error.localizedDescription}
    try? JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:documents.appendingPathComponent("library-backup-result.json"),options:.atomic)
}
#endif
