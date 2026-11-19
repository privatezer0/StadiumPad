import Foundation
import StadiumProtocol

public actor StadiumSession {
    private var commands:WireSocket?;private var updates:WireSocket?;private var nextID:Int32=1
    private var occupied=false;private var waiters:[CheckedContinuation<Void,Never>]=[]
    private var allocated:Set<Int>=[]
    private var connectionID=UUID()
    private var selectionReceipts:[Int32:StadiumBlockFocus]=[:]
    public init() {}
    private func acquire()async {if !occupied {occupied=true;return};await withCheckedContinuation{waiters.append($0)}}
    private func release() {if waiters.isEmpty {occupied=false}else{waiters.removeFirst().resume()}}
    public func connect(host:String,port:UInt16=2001,trace:TraceRecorder?=nil)async throws {
        guard port>0,port<65535,!host.isEmpty else{throw ProtocolError.invalid("Enter a valid Stadium address.")}
        await disconnect();connectionID=UUID();await acquire();defer{release()};try Task.checkCancellation()
        let sub=WireSocket(host:host,port:port,trace:trace),command=WireSocket(host:host,port:port+1,trace:trace)
        do {
            try await sub.start();try await command.start();try await sub.handshake(type:"SUB");try await command.handshake(type:"DEALER")
            updates=sub;commands=command
        } catch {await sub.close();await command.close();throw error}
    }
    public func disconnect()async {await commands?.close();await updates?.close();commands=nil;updates=nil;allocated=[];selectionReceipts=[:]}
    private func exchange(_ make:(Int32)throws->OSCMessage,reply:String)async throws->OSCMessage {
        try Task.checkCancellation();guard let socket=commands else{throw ProtocolError.closed}
        let id=nextID;nextID = nextID==Int32.max ? 1:nextID+1
        try await socket.send(Frame(payload:try make(id).encode()).encode())
        let deadline=Date().addingTimeInterval(5)
        while deadline.timeIntervalSinceNow>0 {
            let frame=try await socket.frame(timeout:deadline.timeIntervalSinceNow)
            if frame.flags&4 != 0 || frame.more || frame.payload.isEmpty {continue}
            let message=try OSCMessage.decode(frame.payload)
            guard message.values.first?.integer==Int(id) else{continue}
            if message.address=="/error" {throw ProtocolError.invalid("The Stadium rejected the request. No success was confirmed.")}
            if message.address==reply {return message}
        };throw ProtocolError.timeout
    }
    private func readUnlocked(_ command:ReadCommand)async throws->Value {try command.decode(await exchange(command.message,reply:command.replyAddress))}
    private func editUnlocked(_ command:EditCommand)async throws->OSCMessage {try await exchange(command.message,reply:"/status")}
    public func read(_ command:ReadCommand)async throws->Value {await acquire();defer{release()};return try await readUnlocked(command)}
    public func event(timeout:Double=5)async throws->OSCMessage {
        guard let socket=updates else{throw ProtocolError.closed};let origin=connectionID;let deadline=Date().addingTimeInterval(timeout)
        while deadline.timeIntervalSinceNow>0 {
            let frame=try await socket.frame(timeout:deadline.timeIntervalSinceNow)
            if frame.flags&4 != 0 || frame.more || frame.payload.isEmpty {continue}
            guard origin==connectionID else{throw ProtocolError.closed}
            let message=try OSCMessage.decode(frame.payload)
            if case .selection(let path,let position)=StadiumLiveUpdate.decode(message),let id=message.values[1].integer,let key=Int32(exactly:id) {
                if selectionReceipts.count>=64 {selectionReceipts.removeAll()}
                selectionReceipts[key]=StadiumBlockFocus(path:path,position:position)
            }
            return message
        };throw ProtocolError.timeout
    }
    /// Selection is transient UI state. Firmware emits /setSelectedBlock instead of /status.
    /// The live event reader remains active while this FIFO transaction awaits its echo.
    public func selectBlock(context:EditContext)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let origin=connectionID,before=try await snapshotUnlocked();_ = try verify(context,in:before)
        guard let socket=commands else{throw ProtocolError.closed}
        let id=nextID;nextID = nextID==Int32.max ? 1:nextID+1;selectionReceipts[id]=nil
        try await socket.send(Frame(payload:try EditCommand.selection(context).message(id:id).encode()).encode())
        let deadline=Date().addingTimeInterval(3)
        while Date()<deadline {
            try Task.checkCancellation();guard connectionID==origin,commands != nil else{throw ProtocolError.closed}
            if let receipt=selectionReceipts.removeValue(forKey:id),receipt.path==context.path,receipt.position==context.position {
                let after=try await snapshotUnlocked(product:before.product);_ = try verify(context,in:after);return after
            }
            try await Task.sleep(for:.milliseconds(20))
        }
        throw ProtocolError.invalid("Block selection was not confirmed. Nothing was retried or saved.")
    }
    public func snapshot(product:Value?=nil)async throws->DeviceSnapshot {await acquire();defer{release()};return try await snapshotUnlocked(product:product)}
    private func snapshotUnlocked(product:Value?=nil)async throws->DeviceSnapshot {
        let productValue:Value
        if let product {productValue=product}else{productValue=try await readUnlocked(.product)}
        for _ in 0..<3 {
            let before=try await readUnlocked(.activePreset),beforeSnapshot=try await readUnlocked(.activeSnapshot)
            guard let id=before["val_"].integer else{throw ProtocolError.invalid("Missing active preset reference.")}
            guard let raw=try await readUnlocked(.editBufferBytes).data else{throw ProtocolError.invalid("Missing edit buffer.")}
            let edit=try MessagePack.decode(raw),preset=try await readUnlocked(.contentRef(id)),index=try await readUnlocked(.activeSnapshot),dirty=try await readUnlocked(.dirty)
            let after=try await readUnlocked(.activePreset)
            guard let edited=dirty["val_"].boolean else{throw ProtocolError.invalid("Could not verify unsaved changes.")}
            if after["val_"].integer==id,index==beforeSnapshot {return DeviceSnapshot(product:productValue,editBuffer:edit,preset:preset,activeSnapshot:index.integer ?? 0,rawEditBuffer:raw,dirty:edited,origin:connectionID)}
        };throw ProtocolError.invalid("The preset changed during reading. Try again.")
    }
    private func verify(_ context:EditContext,in state:DeviceSnapshot)throws->SignalBlock {
        try context.validate()
        guard context.origin==connectionID,state.presetID==context.presetID,state.activeSnapshot==context.snapshot,let block=state.blocks.first(where:{$0.path-1==context.path && $0.blockID==context.blockID && $0.position==context.position && $0.slot==context.slot}),block.model==context.modelID else{throw ProtocolError.invalid("The preset, snapshot or block changed. Close and reopen this editor.")};return block
    }
    private func confirmIdentity(_ state:DeviceSnapshot)async throws {
        guard let id=state.presetID,try await readUnlocked(.activePreset)["val_"].integer==id,try await readUnlocked(.activeSnapshot).integer==state.activeSnapshot else{throw ProtocolError.invalid("The active preset or snapshot changed. Nothing further was sent.")}
    }
    private func backup(_ state:DeviceSnapshot,to backups:PresetBackupStore)async throws {
        let id=state.preset["rcid"].integer ?? state.presetID
        guard let id,let bytes=try await readUnlocked(.contentData(id)).data else{throw ProtocolError.invalid("The saved preset could not be backed up.")}
        try await backups.retain(contentID:id,name:state.presetName,data:bytes)
        try await backups.retain(contentID:id,name:state.presetName+" (live)",data:state.rawEditBuffer)
    }
    public func setParameter(context:EditContext,definition:ParameterDefinition,value:Value,expected:Value,backups:PresetBackupStore)async throws->DeviceSnapshot {
        let wire=try definition.validated(value);await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked(),block=try verify(context,in:before)
        guard let old=block.value(definition),sameParameterValue(old,expected) else{throw ProtocolError.invalid("This parameter changed elsewhere. Refresh before editing it.")}
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledge(await editUnlocked(.parameter(context,definition,wire)))
        let after=try await snapshotUnlocked(product:before.product),changed=try verify(context,in:after)
        guard let received=changed.value(definition),sameParameterValue(received,wire) else{throw ProtocolError.invalid("The Stadium did not confirm the requested value. Check the current value before retrying.")}
        return after
    }
    /// One FIFO transaction for a Focus gesture. Validate the whole batch before
    /// any write, preserve starting bytes, apply discrete switches first, and
    /// stop on any uncertainty. No automatic save or retry.
    public func setParameters(context:EditContext,changes:[ParameterChange],backups:PresetBackupStore)async throws->DeviceSnapshot {
        guard !changes.isEmpty,changes.count<=128,Set(changes.map{$0.definition.identity}).count==changes.count else{throw ProtocolError.invalid("Invalid parameter batch.")}
        let wires=try changes.map{try $0.definition.validated($0.value)}
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked(),block=try verify(context,in:before)
        for change in changes {
            guard let old=block.value(change.definition),sameParameterValue(old,change.expected) else{throw ProtocolError.invalid("The tone changed elsewhere. Reopen Focus View before adjusting it.")}
        }
        let indices=changes.indices.filter{!sameParameterValue(changes[$0].expected,wires[$0])}.sorted {a,b in
            let af=changes[a].definition.type=="f",bf=changes[b].definition.type=="f"
            return af==bf ? a<b:!af
        }
        if indices.isEmpty {return before}
        try await backup(before,to:backups)
        for (offset,index) in indices.enumerated() {
            try Task.checkCancellation()
            if offset%4==0 {_ = try verify(context,in:await snapshotUnlocked(product:before.product))}
            try await confirmIdentity(before)
            try EditCommand.acknowledge(await editUnlocked(.parameter(context,changes[index].definition,wires[index])))
        }
        let after=try await snapshotUnlocked(product:before.product),actual=try verify(context,in:after)
        guard changes.indices.allSatisfy({index in actual.value(changes[index].definition).map{sameParameterValue($0,wires[index])}==true}) else{throw ProtocolError.invalid("Not every Focus value was confirmed. Check the current tone before retrying.")}
        return after
    }
    public func savePreset(expectedID:Int,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked()
        guard before.presetID==expectedID,before.location.writable else{throw ProtocolError.invalid("Save is available only for the current User preset. Save a copy for Factory presets.")}
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledge(await editUnlocked(.save(expectedID)))
        for attempt in 0..<8 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==expectedID,after.activeSnapshot==before.activeSnapshot else{throw ProtocolError.invalid("The active preset changed before saving was confirmed.")}
            if !after.dirty {
                guard let bytes=try await readUnlocked(.contentData(expectedID)).data else{throw ProtocolError.invalid("The saved preset could not be read back.")}
                let stored=DeviceSnapshot(product:before.product,editBuffer:try MessagePack.decode(bytes),preset:before.preset,activeSnapshot:before.activeSnapshot)
                guard stored.blocks.count==after.blocks.count,stored.snapshots==after.snapshots else{throw ProtocolError.invalid("The saved signal chain has not been verified.")}
                for block in after.blocks {
                    guard let saved=stored.blocks.first(where:{$0.id==block.id && $0.blockID==block.blockID && $0.model==block.model}),saved.enabled==block.enabled,saved.values.count==block.values.count,saved.harnessValues.count==block.harnessValues.count,block.values.allSatisfy({sameParameterValue($0.value,saved.values[$0.key] ?? .null)}),block.harnessValues.allSatisfy({sameParameterValue($0.value,saved.harnessValues[$0.key] ?? .null)}) else{throw ProtocolError.invalid("Some saved parameter values have not been confirmed. Check the device before leaving this preset.")}
                }
                try await confirmIdentity(after);return after
            }
            if attempt<7 {try await Task.sleep(for:.milliseconds(250))}
        };throw ProtocolError.invalid("The Stadium still reports unsaved changes. Saving was not confirmed.")
    }
    public func replaceModel(context:EditContext,source:ModelDefinition,destination:ModelDefinition,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked();_ = try verify(context,in:before)
        guard source.id==context.modelID else{throw ProtocolError.invalid("The selected model changed.")}
        let output=context.position%14==13
        if output {
            guard source.ioRole=="outputs",destination.ioRole=="outputs",!(context.path==1 && [779,784,788].contains(destination.id)) else{throw ProtocolError.invalid("Choose an output destination for this block.")}
        } else {
            guard (1...12).contains(context.position%14),source.ioRole==nil,!["split","join"].contains(source.category ?? ""),destination.replaceable,source.isCab==destination.isCab else{throw ProtocolError.invalid("This model cannot replace the selected block. Cab models stay in cab slots; input and routing blocks are separate.")}
        }
        if destination.id==source.id {return before}
        if destination.category=="amp" {
            guard let auto=try await readUnlocked(.autoCab)["val_"].boolean,!auto else{throw ProtocolError.invalid("Turn off Auto Cab on the Stadium before changing to an amp, so another block cannot be added automatically.")}
        }
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledge(await editUnlocked(.model(context,destination.id)))
        for attempt in 0..<8 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==before.presetID,after.activeSnapshot==before.activeSnapshot else{throw ProtocolError.invalid("The preset or snapshot changed before replacement was confirmed.")}
            if after.blocks.contains(where:{$0.path-1==context.path && $0.position==context.position && $0.slot==context.slot && $0.model==destination.id}) {
                let unchanged=before.blocks.filter{!($0.path-1==context.path && $0.position==context.position && $0.slot==context.slot)}
                guard after.blocks.count==before.blocks.count,unchanged.allSatisfy({old in after.blocks.contains(where:{$0.id==old.id && $0.model==old.model && $0.values==old.values && $0.harnessValues==old.harnessValues && $0.enabled==old.enabled})}) else{throw ProtocolError.invalid("The model changed, but other block changes were detected. Inspect the signal chain before saving.")}
                return after
            }
            if attempt<7 {try await Task.sleep(for:.milliseconds(150))}
        }
        throw ProtocolError.invalid("The requested model was not confirmed. No retry was sent.")
    }
    private func sendOnly(_ command:EditCommand)async throws {
        guard let socket=commands else{throw ProtocolError.closed}
        let id=nextID;nextID = nextID==Int32.max ? 1:nextID+1
        try await socket.send(Frame(payload:try command.message(id:id).encode()).encode())
    }
    public func activateSnapshot(_ index:Int,expectedID:Int,expectedSnapshot:Int,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked()
        guard before.presetID==expectedID,before.activeSnapshot==expectedSnapshot,before.snapshots.contains(where:{$0.id==index && $0.defined}) else{throw ProtocolError.invalid("The preset or snapshot changed, or this snapshot is empty.")}
        if index==before.activeSnapshot {return before}
        try await backup(before,to:backups);try await confirmIdentity(before)
        try await sendOnly(.snapshot(index))
        for _ in 0..<12 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==expectedID else{throw ProtocolError.invalid("The preset changed during snapshot selection.")}
            if after.activeSnapshot==index {return after}
            try await Task.sleep(for:.milliseconds(150))
        }
        throw ProtocolError.invalid("Snapshot selection was not confirmed. No retry was sent.")
    }
    public func createSnapshot(_ target:Int,expectedID:Int,expectedSnapshot:Int,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};let before=try await snapshotUnlocked()
        guard before.presetID==expectedID,before.activeSnapshot==expectedSnapshot,before.snapshots.contains(where:{$0.id==expectedSnapshot && $0.defined}),before.snapshots.contains(where:{$0.id==target && !$0.defined}) else{throw ProtocolError.invalid("Only an empty scene can be created. Refresh before trying again.")}
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledge(await editUnlocked(.copySnapshot(expectedSnapshot,target)))
        for _ in 0..<8 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==expectedID,after.activeSnapshot==expectedSnapshot else{throw ProtocolError.invalid("The preset or scene changed during creation.")}
            if after.snapshots.contains(where:{$0.id==target && $0.defined}) {return after}
            try await Task.sleep(for:.milliseconds(150))
        }
        throw ProtocolError.invalid("Scene creation was not confirmed. No retry was sent.")
    }
    public func reorderBlock(context:EditContext,to:Int,models:[Int:ModelDefinition],backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let before=try await snapshotUnlocked();_ = try verify(context,in:before)
        let plan=try BlockReorderPlan(state:before,context:context,to:to,models:models)
        try await backup(before,to:backups);try await confirmIdentity(before)
        try EditCommand.acknowledgeAgenda(await editUnlocked(.reorder(flow:plan.flow,from:plan.from,to:plan.to)))
        for _ in 0..<8 {
            let after=try await snapshotUnlocked(product:before.product)
            guard after.presetID==before.presetID,after.activeSnapshot==before.activeSnapshot else{throw ProtocolError.invalid("The preset or scene changed during the move. Nothing was retried.")}
            if plan.matches(after) {return after}
            try await Task.sleep(for:.milliseconds(150))
        }
        throw ProtocolError.invalid("The reordered blocks or their settings were not confirmed. Check the chain before retrying; no automatic retry or save was sent.")
    }
    /// Explicit tuner open/exit events only. An ACK confirms command acceptance;
    /// this firmware does not expose live note/cents through the known protocol.
    public func setTuner(_ enabled:Bool)async throws {
        await acquire();defer{release()};try Task.checkCancellation()
        try EditCommand.acknowledge(await editUnlocked(.tuner(enabled)))
    }
    public func pressStomp(_ plan:StompPlan,backups:PresetBackupStore)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        func validate(_ state:DeviceSnapshot)throws->StompPlan {
            guard plan.origin==connectionID,state.presetID==plan.presetID,state.activeSnapshot==plan.snapshot,let current=StompAssignment.read(state,bank:plan.bank,number:plan.number).plan,current.sourceID==plan.sourceID,current.fingerprint==plan.fingerprint else{throw ProtocolError.invalid("The preset, scene or footswitch assignments changed. Refresh before pressing it.")}
            return current
        }
        let before=try await snapshotUnlocked(),current=try validate(before)
        guard current.input==plan.input,current.controllers==plan.controllers else{throw ProtocolError.invalid("The switch values changed elsewhere. Check the current state before pressing it.")}
        try await backup(before,to:backups);var confirmed=0;var after=before
        do {
            for controller in plan.controllers {
                let fresh=try await snapshotUnlocked(product:before.product);_ = try validate(fresh)
                guard let old=controller.target.value(in:fresh),sameParameterValue(old,controller.current) else{throw ProtocolError.invalid("An assigned value changed elsewhere.")}
                try await confirmIdentity(fresh)
                try EditCommand.acknowledge(await editUnlocked(.controller(controller.id,plan.input)))
                after=try await snapshotUnlocked(product:before.product);_ = try validate(after)
                let wanted=plan.input==1 ? controller.high:controller.low
                guard let actual=controller.target.value(in:after),sameParameterValue(actual,wanted) else{throw ProtocolError.invalid("An assigned effect did not confirm its new value.")}
                confirmed+=1
            }
            for controller in plan.controllers {
                guard let actual=controller.target.value(in:after),sameParameterValue(actual,plan.input==1 ? controller.high:controller.low) else{throw ProtocolError.invalid("An assigned effect changed before the switch completed.")}
            }
            return after
        } catch {throw ProtocolError.invalid("\(confirmed) of \(plan.controllers.count) assigned actions confirmed. \(error.localizedDescription) Nothing was retried.")}
    }
    public func presetLibrary(container:Int)async throws->[PresetSlot] {await acquire();defer{release()};return try await readUnlocked(.container(container)).items.map(PresetSlot.init)}
    public func userPresets()async throws->[PresetSlot] {await acquire();defer{release()};return try await readUnlocked(.container(-2)).items.map(PresetSlot.init)}
    public func copyCurrent(name:String,expectedID:Int,backups:PresetBackupStore)async throws->PreservedPreset {
        let name=try EditCommand.validName(name);await acquire();defer{release()};try Task.checkCancellation()
        let state=try await snapshotUnlocked()
        guard state.presetID==expectedID else{throw ProtocolError.invalid("The preset changed before copying.")}
        try await backup(state,to:backups)
        let slots=try await readUnlocked(.container(-2)).items.map(PresetSlot.init)
        guard let position=slots.filter(\.empty).compactMap(\.position).min() else{throw ProtocolError.invalid("No empty User preset locations are available.")}
        let fresh=try await readUnlocked(.container(-2)).items.map(PresetSlot.init)
        guard fresh.contains(where:{$0.position==position && $0.empty}) else{throw ProtocolError.invalid("The chosen location is no longer empty.")}
        try await confirmIdentity(state)
        let id=try EditCommand.allocatedID(await editUnlocked(.createUser(position:position,name:name)))
        guard id != expectedID,id != state.preset["rcid"].integer else{throw ProtocolError.invalid("The Stadium did not allocate an independent preset.")}
        let reference=try await readUnlocked(.contentRef(id)),slot=PresetSlot(reference)
        guard slot.writable,slot.position==position,slot.contentID==id,slot.name==name else{throw ProtocolError.invalid("The new preset location was not verified. Check the User library before retrying.")}
        allocated.insert(id)
        try await storeNew(id,bytes:state.rawEditBuffer)
        return PreservedPreset(preset:slot,sourceID:expectedID,sourceSnapshot:state.activeSnapshot,sourceHash:PresetBackupStore.hash(state.rawEditBuffer))
    }
    private func storeNew(_ id:Int,bytes:Data)async throws {
        guard allocated.contains(id) else{throw ProtocolError.invalid("Only a newly allocated preset can receive copied data.")}
        try EditCommand.acknowledge(await editUnlocked(.storeNewPreset(id,bytes)))
        guard try await readUnlocked(.contentData(id)).data==bytes else{throw ProtocolError.invalid("The new copy's stored contents were not verified. Check the User library before retrying.")}
    }
    public func openPreservedCopy(_ copy:PreservedPreset)async throws->DeviceSnapshot {
        await acquire();defer{release()}
        let current=try await snapshotUnlocked()
        guard current.presetID==copy.sourceID,current.activeSnapshot==copy.sourceSnapshot,PresetBackupStore.hash(current.rawEditBuffer)==copy.sourceHash,let id=copy.preset.contentID,try await readUnlocked(.contentData(id)).data.map(PresetBackupStore.hash)==copy.sourceHash else{throw ProtocolError.invalid("The source changed after copying. The copy is saved, but your current preset was left open.")}
        try await loadUnlocked(id);return try await snapshotUnlocked(product:current.product)
    }
    public func loadPreset(_ id:Int,expectedID:Int,discardingChangesWith backups:PresetBackupStore?=nil)async throws->DeviceSnapshot {
        await acquire();defer{release()};try Task.checkCancellation()
        let current=try await snapshotUnlocked()
        guard current.presetID==expectedID else{throw ProtocolError.invalid("The active preset changed. Select the preset again.")}
        if let backups {
            // Explicit user selection means discard. Keep both saved and live
            // bytes locally, including edits the device dirty flag may omit.
            try await backup(current,to:backups)
        } else {
            guard !current.dirty else{throw ProtocolError.invalid("Save the current changes or save a copy before opening another preset.")}
        }
        try await confirmIdentity(current)
        try await loadUnlocked(id)
        let after=try await snapshotUnlocked(product:current.product)
        guard after.presetID==id else{throw ProtocolError.invalid("The selected preset was not confirmed as active.")}
        return after
    }
    private func loadUnlocked(_ id:Int)async throws {
        let ref=PresetSlot(try await readUnlocked(.contentRef(id)))
        guard ref.contentID==id,ref.type==2 else{throw ProtocolError.invalid("This preset is unavailable.")}
        try EditCommand.acknowledge(await editUnlocked(.load(id)))
        for _ in 0..<12 {if try await readUnlocked(.activePreset)["val_"].integer==id {return};try await Task.sleep(for:.milliseconds(150))}
        throw ProtocolError.invalid("The new preset was not confirmed as active.")
    }
}

extension StadiumSession {
    /// Ascend the real folder records; a positive number alone never grants access.
    @discardableResult private func verifyUserCloneFolder(_ id:Int)async throws->Int {
        var current=id;var visited:Set<Int>=[]
        for _ in 0..<8 {
            if [-22,-23,-24,-25].contains(current) {return current}
            guard current>0,visited.insert(current).inserted else{break}
            let row=try await readUnlocked(.contentRef(current))
            guard row["type"].integer==1002,CloneLibraryCommand.userEditable(row),let parent=row["ccid"].integer else{break}
            current=parent
        }
        throw ProtocolError.invalid("Choose a folder inside User Clones.")
    }
    public func createCloneFolder(parent:Int,name:String)async throws->Value {
        await acquire();defer{release()};try await verifyUserCloneFolder(parent)
        let clean=try CloneLibraryCommand.name(name),before=try await readUnlocked(.container(parent))
        guard !before.items.contains(where:{$0["name"].text?.localizedCaseInsensitiveCompare(clean) == .orderedSame}) else{throw ProtocolError.invalid("This clone folder already contains that name.")}
        let position=(before.items.compactMap{$0["posi"].integer}.max() ?? -1)+1
        let response=try await exchange(CloneLibraryCommand.createFolder(parent:parent,position:position,name:clean).message,reply:"/status")
        let id=try EditCommand.allocatedID(response)
        let after=try await readUnlocked(.container(parent))
        guard let created=after.items.first(where:{$0["cid_"].integer==id}),created["type"].integer==1002,created["ownr"].integer==1,created["name"].text==clean,created["ccid"].integer==parent else{throw ProtocolError.invalid("Folder creation was not confirmed. Refresh before trying again.")}
        return created
    }
    public func changeClone(id:Int,parent:Int,uuid:String?,expectedName:String,newName:String?=nil,remove:Bool=false)async throws->Value {
        guard id>0 else{throw ProtocolError.invalid("Built-in clone folders cannot be modified.")}
        await acquire();defer{release()};try await verifyUserCloneFolder(parent)
        let before=try await readUnlocked(.contentRef(id))
        guard before["ccid"].integer==parent,CloneLibraryCommand.userEditable(before),before["name"].text==expectedName,let type=before["type"].integer,[11,1002].contains(type),type != 11 || before["cluid"].text==uuid else{throw ProtocolError.invalid("The selected clone or folder changed. Refresh before continuing.")}
        if remove {
            if type==1002 {guard try await readUnlocked(.container(id)).items.isEmpty else{throw ProtocolError.invalid("Only empty clone folders can be deleted.")}}
            try EditCommand.acknowledge(await exchange(CloneLibraryCommand.remove(parent:parent,id:id).message,reply:"/status"))
            let after=try await readUnlocked(.container(parent))
            guard !after.items.contains(where:{$0["cid_"].integer==id}) else{throw ProtocolError.invalid("Deletion was not confirmed. Nothing was retried.")}
            return .object(["removed":.int(Int64(id))])
        }
        guard let newName else{throw ProtocolError.invalid("Enter the clone name.")}
        let clean=try CloneLibraryCommand.name(newName),siblings=try await readUnlocked(.container(parent))
        guard !siblings.items.contains(where:{$0["cid_"].integer != id && $0["name"].text?.localizedCaseInsensitiveCompare(clean) == .orderedSame}) else{throw ProtocolError.invalid("This folder already contains that name.")}
        try EditCommand.acknowledge(await exchange(CloneLibraryCommand.rename(id:id,attributes:before,name:clean).message,reply:"/status"))
        let after=try await readUnlocked(.contentRef(id))
        var intended=before.object;intended["name"] = .string(clean)
        guard after == .object(intended) else{throw ProtocolError.invalid("The renamed clone/folder was not fully confirmed. Check the library before continuing.")}
        return after
    }
}

extension StadiumSession {
    public func prepareCloneExport(id:Int,uuid:String,expectedName:String)async throws->Value {
        guard id>0,UUID(uuidString:uuid)?.uuidString.lowercased()==uuid else{throw ProtocolError.invalid("Invalid clone export identity.")}
        await acquire();defer{release()};let origin=connectionID
        let before=try await readUnlocked(.contentRef(id))
        guard before["type"].integer==11,CloneLibraryCommand.userEditable(before),before["cluid"].text==uuid,before["name"].text==expectedName,let parent=before["ccid"].integer else{throw ProtocolError.invalid("The clone changed before export.")}
        try await verifyUserCloneFolder(parent)
        guard let socket=commands else{throw ProtocolError.closed}
        let commandID=nextID;nextID = nextID==Int32.max ? 1:nextID+1
        try await socket.send(Frame(payload:try OSCMessage("/ExportCloneArchive",[.int(Int64(commandID)),.int(Int64(id))]).encode()).encode())
        let deadline=Date().addingTimeInterval(15)
        while Date()<deadline {
            let event=try await self.event(timeout:max(0.1,deadline.timeIntervalSinceNow))
            guard origin==connectionID else{throw ProtocolError.closed}
            guard event.address=="/cloneArchiveExportReady",event.values.count==6,event.values[2].integer==id else{continue}
            let path="/data/stadium-family-fw/proxy/exports/"+uuid+".clone"
            guard event.values[3].text==path,event.values[4].text==uuid+".clone",let size=event.values[5].integer,size>24,size<=8*1024*1024,try await readUnlocked(.contentRef(id))==before else{throw ProtocolError.invalid("The Stadium did not confirm the requested clone archive.")}
            return .object(["path":.string(path),"size":.int(Int64(size))])
        }
        throw ProtocolError.invalid("Clone export was not confirmed. Nothing was retried.")
    }
}


extension StadiumSession {
    public func moveClone(id:Int,parent:Int,uuid:String,expectedName:String,destination:Int)async throws->Value {
        await acquire();defer{release()}
        guard id>0,parent != destination else{throw ProtocolError.invalid("Choose a different clone folder.")}
        let sourceCategory=try await verifyUserCloneFolder(parent),targetCategory=try await verifyUserCloneFolder(destination)
        guard sourceCategory==targetCategory else{throw ProtocolError.invalid("Clones can only move within their own Amp, Amp+Cab, Preamp or Distortion category.")}
        let before=try await readUnlocked(.contentRef(id)),contents=try await readUnlocked(.container(destination))
        guard before["type"].integer==11,CloneLibraryCommand.userEditable(before),before["ccid"].integer==parent,before["cluid"].text==uuid,before["name"].text==expectedName else{throw ProtocolError.invalid("The selected clone changed before moving.")}
        guard !contents.items.contains(where:{$0["name"].text?.localizedCaseInsensitiveCompare(expectedName) == .orderedSame}) else{throw ProtocolError.invalid("The destination already has a clone with this name.")}
        let position=(contents.items.compactMap{$0["posi"].integer}.max() ?? -1)+1
        try EditCommand.acknowledge(await exchange(CloneLibraryCommand.move(id:id,parent:destination,position:position).message,reply:"/status"))
        let after=try await readUnlocked(.contentRef(id)),remaining=try await readUnlocked(.container(parent))
        var intended=before.object;intended["ccid"] = .int(Int64(destination));intended["posi"] = .int(Int64(position))
        guard after == .object(intended),!remaining.items.contains(where:{$0["cid_"].integer==id}) else{throw ProtocolError.invalid("The clone move was not confirmed. Refresh before trying again.")}
        return after
    }
}
