import SwiftUI
import StadiumProtocol
import StadiumNetwork

@MainActor final class StadiumMonitor:ObservableObject {
    @Published var connectionID=UUID()
    @Published var currentHost=""
    @Published var tunerRequested=false
    @Published var tunerReference:Double?
    @Published var status="Connect to your Stadium to view its current preset."
    @Published var snapshot:DeviceSnapshot?
    @Published var connected=false
    @Published var connecting=false
    @Published var lastEvent:Date?
    @Published var focusedBlock:StadiumBlockFocus?
    @Published var presets:[PresetSlot]=[]
    @Published var presetFolders:[PresetFolder]=[]
    @Published var factoryPresets:[PresetSlot]=[]
    @Published var cloneHierarchy:Value = .null
    @Published var libraryEntries:[Int:[LibraryEntry]]=[:]
    @Published var presetContainer = -2
    @Published var stompProperties:[String:Value]=[:]
    @Published var busy=false
    @Published var errorText:String?
    @Published var lastAction:String?
    @Published var lastCopy:PreservedPreset?
    let backups=PresetBackupStore(root:FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Preset Backups"))
    let catalog:[String:ModelDefinition] = {
        guard let url=Bundle.main.url(forResource:"ParameterCatalog",withExtension:"json"),let data=try? Data(contentsOf:url),let catalog=try? JSONDecoder().decode([String:ModelDefinition].self,from:data) else{return [:]};return catalog
    }()
    private var worker:Task<Void,Never>?
    private var subscriber:Task<Void,Never>?
    private var refreshTask:Task<Void,Never>?
    private var pendingFocus:StadiumBlockFocus?
    private var liveRevision=0
    private var session:StadiumSession?
    private var generation=UUID()
    let names:[String:String] = {
        guard let url=Bundle.main.url(forResource:"ModelNames",withExtension:"json"),let data=try? Data(contentsOf:url),let names=try? JSONDecoder().decode([String:String].self,from:data) else{return [:]};return names
    }()
    func blockName(_ block:SignalBlock)->String {catalog[String(block.model)]?.name ?? names[String(block.model)] ?? "Effect block \(block.position)"}
    func connect(host:String,port:UInt16=2001) {
        guard !busy else{return}
        stop();connectionID=UUID();currentHost=host;snapshot=nil;presets=[];presetFolders=[];factoryPresets=[];libraryEntries=[:];stompProperties=[:];lastCopy=nil;lastAction=nil
        let token=UUID();generation=token
        lastEvent=nil;let current=StadiumSession();session=current;connecting=true;status="Connecting…"
        worker=Task {
            do {
                try await current.connect(host:host,port:port)
                let state=try await current.snapshot()
                guard generation==token,!Task.isCancelled else{await current.disconnect();return}
                snapshot=state;connecting=false;connected=true;status="Connected · live view";report()
                subscriber=Task {
                    do {
                        while !Task.isCancelled {
                            let event=try await current.event(timeout:8)
                            guard generation==token,!Task.isCancelled else{return}
                            lastEvent=Date()
                            if let update=StadiumLiveUpdate.decode(event) {
                                liveRevision+=1
                                if case .selection(let path,let position)=update {pendingFocus=StadiumBlockFocus(path:path,position:position)}
                                refreshFromEvent(current,token:token)
                            }
                            report()
                        }
                    } catch {if generation==token,!Task.isCancelled {fail(error)}}
                }
                while !Task.isCancelled {
                    try await Task.sleep(for:.milliseconds(750))
                    if busy {continue}
                    let state=try await current.snapshot(product:state.product)
                    guard generation==token,!Task.isCancelled else{return}
                    snapshot=state
                    if refreshTask==nil,let focus=pendingFocus,state.blocks.contains(where:{$0.path-1==focus.path && $0.position==focus.position}) {focusedBlock=focus;pendingFocus=nil}
                    report()
                }
            } catch {if generation==token,!Task.isCancelled {fail(error)}}
        }
    }
    private func refreshFromEvent(_ current:StadiumSession,token:UUID) {
        guard refreshTask==nil else{return}
        refreshTask=Task {
            do {
                try await Task.sleep(for:.milliseconds(60))
                for _ in 0..<3 {
                    while busy && !Task.isCancelled {try await Task.sleep(for:.milliseconds(75))}
                    guard generation==token,!Task.isCancelled else{return}
                    let revision=liveRevision
                    let state=try await current.snapshot(product:snapshot?.product)
                    guard generation==token,!Task.isCancelled else{return}
                    snapshot=state
                    if revision==liveRevision,let focus=pendingFocus {
                        if state.blocks.contains(where:{$0.path-1==focus.path && $0.position==focus.position}) {focusedBlock=focus}
                        pendingFocus=nil
                    }
                    report()
                    if revision==liveRevision {break}
                }
            } catch {if generation==token,!Task.isCancelled {fail(error)}}
            if generation==token {refreshTask=nil}
        }
    }
    func stop() {
        generation=UUID();refreshTask?.cancel();refreshTask=nil;pendingFocus=nil;focusedBlock=nil;worker?.cancel();worker=nil;subscriber?.cancel();subscriber=nil
        let closeTuner=tunerRequested;tunerRequested=false
        if let old=session {Task {if closeTuner {try? await old.setTuner(false)};await old.disconnect()}}
        session=nil;connected=false;connecting=false;status="Disconnected. Last received values remain visible.";report()
    }
    func definitions(_ block:SignalBlock)->[ParameterDefinition] {catalog[String(block.model)]?.parameters.filter{block.value($0) != nil} ?? []}
    func edit(context:EditContext,definition:ParameterDefinition,value:Value,expected:Value) async {
        guard !busy,connected,let current=session else{return};busy=true;defer{busy=false}
        let token=generation
        do {
            let state=try await current.setParameter(context:context,definition:definition,value:value,expected:expected,backups:backups)
            guard generation==token else{return};snapshot=state;lastAction="\(definition.name) updated · unsaved";report()
        } catch {if generation==token {errorText=error.localizedDescription;lastAction=nil;stop()}}
    }
    func save(expectedID:Int?=nil)async {
        guard !busy,connected,let current=session,let currentID=snapshot?.presetID else{return};let id=expectedID ?? currentID
        guard currentID==id else{errorText="The preset changed after you opened Save. Review the current preset before saving.";return}
        busy=true;defer{busy=false};let token=generation
        do {let state=try await current.savePreset(expectedID:id,backups:backups);guard generation==token else{return};snapshot=state;lastAction="Saved to \(state.location.label) · \(state.presetName)";report()}
        catch {if generation==token {errorText=error.localizedDescription;lastAction=nil;stop()}}
    }
    func copy(name:String,expectedID:Int?=nil)async {
        guard !busy,connected,let current=session,let id=snapshot?.presetID else{return}
        guard expectedID==nil || expectedID==id else{errorText="The preset changed. Reopen Save Copy before copying it.";return}
        busy=true;defer{busy=false};let token=generation
        do {
            let copy=try await current.copyCurrent(name:name,expectedID:id,backups:backups)
            lastCopy=copy
            guard generation==token else{return};lastAction="Copy saved in \(copy.preset.label) · \(copy.preset.name)"
            do {let state=try await current.openPreservedCopy(copy);guard generation==token else{return};snapshot=state;report()}
            catch {if generation==token {errorText=error.localizedDescription}}
        } catch {if generation==token {errorText=error.localizedDescription}}
    }
    func replace(context:EditContext,destination:ModelDefinition)async->SignalBlock? {
        guard !busy,connected,let current=session,let source=catalog[String(context.modelID)] else{return nil}
        busy=true;defer{busy=false};let token=generation
        do {
            let state=try await current.replaceModel(context:context,source:source,destination:destination,backups:backups)
            guard generation==token else{return nil};snapshot=state;lastAction="\(destination.name) selected · unsaved";report()
            return state.blocks.first{$0.path-1==context.path && $0.position==context.position && $0.slot==context.slot}
        } catch {if generation==token {errorText=error.localizedDescription;lastAction=nil;stop()};return nil}
    }
    func activate(_ index:Int,expectedID:Int?=nil,expectedSnapshot:Int?=nil)async {
        guard !busy,connected,let current=session,let state=snapshot,let id=state.presetID else{return}
        guard (expectedID==nil || expectedID==id),(expectedSnapshot==nil || expectedSnapshot==state.activeSnapshot) else{errorText="The preset or snapshot changed. Reopen the snapshot selector.";return}
        busy=true;defer{busy=false};let token=generation
        do {let after=try await current.activateSnapshot(index,expectedID:id,expectedSnapshot:state.activeSnapshot,backups:backups);guard generation==token else{return};snapshot=after;lastAction="Snapshot \(index+1) · \(after.snapshots.first{$0.id==index}?.name ?? "")";report()}
        catch {if generation==token {errorText=error.localizedDescription}}
    }
    func setTuner(_ enabled:Bool)async {
        guard !busy,connected,let current=session else{return};busy=true;defer{busy=false};let token=generation
        tunerRequested=enabled
        do {
            try await current.setTuner(enabled);guard generation==token else{return}
            lastAction=enabled ? "Tuner open command acknowledged · read pitch on Stadium":"Tuner exit acknowledged"
            if enabled {
                let values=try await current.read(.tunerProperties);guard generation==token else{return}
                tunerReference=values["vals"].items.first{$0["key_"].text=="global.tuner.reference.pitch"}?["val_"].numeric
            }
        } catch {if generation==token {errorText=error.localizedDescription}}
    }
    func refreshStompProperties()async {
        guard connected,let session,let id=snapshot?.presetID else{return};let token=generation
        do {let response=try await session.read(.stompProperties);guard generation==token,snapshot?.presetID==id else{return};var properties:[String:Value]=[:];for item in response["vals"].items {if let key=item["key_"].text {properties[key]=item["val_"]}};stompProperties=properties}
        catch {if generation==token {stompProperties=[:]}}
    }
    func createScene(_ index:Int,expectedID:Int,expectedSnapshot:Int)async->Bool {
        guard !busy,connected,let current=session else{return false};busy=true;defer{busy=false};let token=generation
        do {let state=try await current.createSnapshot(index,expectedID:expectedID,expectedSnapshot:expectedSnapshot,backups:backups);guard generation==token else{return false};snapshot=state;lastAction="Scene \(index+1) created · unsaved";report();return true}
        catch {if generation==token {errorText=error.localizedDescription};return false}
    }
    func press(_ plan:StompPlan)async->Bool {
        guard !busy,connected,let current=session else{return false};busy=true;defer{busy=false};let token=generation
        do {let state=try await current.pressStomp(plan,backups:backups);guard generation==token else{return false};snapshot=state;lastAction="Stomp \(plan.bank.uppercased())\(plan.number) · assigned effects updated";report();return true}
        catch {if generation==token {errorText=error.localizedDescription;lastAction=nil;stop()};return false}
    }
    func refreshInventory()async throws {
        guard let session else{throw ProtocolError.closed};let token=generation
        for container in [-1,-2,-3,-4,-5,-6,-7,-8] {
            let value=try await session.read(.container(container));guard generation==token else{throw ProtocolError.closed};libraryEntries[container]=value.items.compactMap(LibraryEntry.init)
            if container == -1 {factoryPresets=value.items.map(PresetSlot.init).filter{($0.contentID ?? 0)>0}}
        }
        var folders:[PresetFolder]=[]
        for entry in libraryEntries[-5] ?? [] {
            let contents=try await session.read(.container(entry.id));guard generation==token else{throw ProtocolError.closed}
            let reference:Value = .object(["cid_":.int(Int64(entry.id)),"type":.int(1003),"name":.string(entry.name)])
            if let folder=PresetFolder(reference:reference,contents:contents) {folders.append(folder)}
        }
        presetFolders=folders
        let clones=try await session.read(.cloneHierarchy);guard generation==token else{throw ProtocolError.closed};cloneHierarchy=clones
    }
    func library()async throws->[PresetSlot] {
        guard let session else{throw ProtocolError.closed}
        let token=generation;let container=presetContainer
        let fetched=try await session.presetLibrary(container:container)
        guard generation==token,presetContainer==container else{throw ProtocolError.closed}
        presets=fetched.filter{($0.contentID ?? 0)>0 && $0.type==2}.sorted{($0.position ?? 0)<($1.position ?? 0)}
        return fetched
    }
    func load(_ preset:PresetSlot)async->Bool {
        guard !busy,connected,let current=session,let id=preset.contentID,let expected=snapshot?.presetID else{return false}
        busy=true;defer{busy=false};let token=generation
        do {let state=try await current.loadPreset(id,expectedID:expected);guard generation==token else{return false};snapshot=state;lastAction="Opened \(preset.label) · \(preset.name)";report();return true}
        catch {if generation==token {errorText=error.localizedDescription};return false}
    }
    private func fail(_ error:Error) {stop();status=error.localizedDescription;report()}
    private func report() {
        guard ProcessInfo.processInfo.environment["STADIUM_VERIFY"]=="1" else{return}
        let object:[String:Any]=["connected":connected,"firmware":snapshot?.firmware ?? "","blocks":snapshot?.blocks.count ?? 0,"snapshot":snapshot?.activeSnapshot ?? -1,"receivedEvent":lastEvent != nil,"dirty":snapshot?.dirty ?? false,"focusPath":focusedBlock?.path ?? -1,"focusPosition":focusedBlock?.position ?? -1,"namedParameters":snapshot?.blocks.reduce(0){$0+definitions($1).count} ?? 0,"at":Date().timeIntervalSince1970,"status":status]
        do {
            let root=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("StadiumRemote")
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            try JSONSerialization.data(withJSONObject:object,options:.prettyPrinted).write(to:root.appendingPathComponent("verification.json"),options:.atomic)
        } catch {print("Could not write the local verification report.")}
    }
}
struct StadiumDevice:Identifiable {var id:String;var host:String;var port:UInt16}
@MainActor final class StadiumDiscovery:NSObject,ObservableObject,@preconcurrency NetServiceBrowserDelegate,@preconcurrency NetServiceDelegate {
    @Published var devices:[StadiumDevice]=[]
    @Published var searching=false
    @Published var error:String?
    private let browser=NetServiceBrowser()
    private var pending:[NetService]=[]
    private var timer:Task<Void,Never>?
    override init() {super.init();browser.delegate=self}
    func search() {stop();devices=[];error=nil;searching=true;browser.searchForServices(ofType:"_stadiumserver._tcp.",inDomain:"local.");timer=Task {try? await Task.sleep(for:.seconds(6));if !Task.isCancelled {stop()}}}
    func stop() {timer?.cancel();timer=nil;browser.stop();for service in pending {service.stop()};pending=[];searching=false}
    func netServiceBrowser(_ browser:NetServiceBrowser,didFind service:NetService,moreComing:Bool) {pending.append(service);service.delegate=self;service.resolve(withTimeout:4)}
    func netServiceDidResolveAddress(_ sender:NetService) {
        guard let host=sender.hostName,sender.port>0,sender.port<65535 else{return}
        let device=StadiumDevice(id:sender.name,host:host,port:UInt16(sender.port))
        if !devices.contains(where:{$0.id==device.id}) {devices.append(device)}
    }
    func netServiceBrowser(_ browser:NetServiceBrowser,didNotSearch errorDict:[String:NSNumber]) {error="Search was unavailable. Allow Local Network access in Settings or enter your Stadium's address.";stop()}
}
