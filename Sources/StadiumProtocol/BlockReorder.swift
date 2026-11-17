import Foundation

/// Reorder effects within one signal row using native adjacent swaps. Inputs,
/// outputs and split/merge nodes remain fixed; empty cells rotate with the row.
public struct BlockReorderPlan:Sendable {
    public let flow:Int;public let from:Int;public let to:Int
    public let expected:[SignalBlock]
    private let bindings:Value
    public init(state:DeviceSnapshot,context:EditContext,to:Int,models:[Int:ModelDefinition])throws {
        try context.validate()
        guard context.origin==state.origin,state.presetID==context.presetID,state.activeSnapshot==context.snapshot,
              context.slot==0,(1...12).contains(context.position%14),(1...12).contains(to%14),context.position/14==to/14,(0...27).contains(to),to != context.position,
              state.blocks.contains(where:{$0.path-1==context.path && $0.position==context.position && $0.blockID==context.blockID && $0.model==context.modelID && $0.slot==0}) else{throw ProtocolError.invalid("Drag an effect to a different position within the same signal row.")}
        flow=context.path;from=context.position;self.to=to;bindings=Self.bindingState(state)
        let lower=min(from,to),upper=max(from,to)
        for block in state.blocks where block.path-1==flow && (lower...upper).contains(block.position) {
            guard let model=models[block.model],model.ioRole==nil,!["split","join"].contains(model.category ?? "") else{throw ProtocolError.invalid("Reorder effects between routing nodes. Inputs, outputs, split and merge nodes stay fixed.")}
        }
        // A branch row can have multiple disjoint branches. Without establishing
        // their boundaries, rotating positions could move an effect across them.
        if from>=14 {
            let raw=state.editBuffer["sfg_"]["flow"].items.flatMap{$0["blks"].items}
            var links:[Int]=[]
            for i in stride(from:1,to:raw.count,by:2) {if raw[i]["bflw"].integer==flow,let p=raw[i]["bblk"].integer,p>=14 {links.append(p)}}
            guard links.count==1,lower>=max(15,links[0]) else{throw ProtocolError.invalid("This branch layout needs the desktop editor for rearranging blocks.")}
        }
        let sourcePosition=context.position,sourceFlow=context.path
        expected=state.blocks.map {original in
            var block=original
            guard block.path-1==sourceFlow,(lower...upper).contains(block.position) else{return block}
            if block.position==sourcePosition {block.position=to}
            else {block.position += sourcePosition<to ? -1:1}
            block.id="\(sourceFlow)-\(block.position)-\(block.slot)";return block
        }
    }
    private static func bindingState(_ state:DeviceSnapshot)->Value {
        var entities=state.editBuffer["cg__"]["entt"].object
        // Entity collections are native keyed sets; serialization order can
        // change after a read/load. Preserve each entity and all unknown fields.
        for (collection,key) in [("srcs","id__"),("ctrl","cid_"),("trgs","id__"),("snps","si__"),("cmnd","cid_"),("ctm_","id__")] {
            if case .array(let values)=entities[collection],values.allSatisfy({$0[key].integer != nil}) {entities[collection] = .array(values.sorted{($0[key].integer ?? -1)<($1[key].integer ?? -1)})}
        }
        for (collection,runtimeKey) in [("srcs","byps"),("ctrl","togl"),("cmnd","togl")] {
            if case .array(let values)=entities[collection] {entities[collection] = .array(values.map{value in if case .object(let fields)=value {return .object(fields.filter{$0.key != runtimeKey})};return value})}
        }
        var targetMap=entities["ctm_"]?.object ?? [:]
        if case .array(let ids)=targetMap["stid"],ids.allSatisfy({$0.integer != nil}) {targetMap["stid"] = .array(ids.sorted{($0.integer ?? -1)<($1.integer ?? -1)});entities["ctm_"] = .object(targetMap)}
        var map=entities["sm__"]?.object ?? [:]
        if case .array(let values)=map["scid"],values.count%2==0 {
            var pairs:[(Int,Value)]=[]
            for i in stride(from:0,to:values.count,by:2) {guard let id=values[i].integer else{return .object(entities)};pairs.append((id,values[i+1]))}
            map["scid"] = .array(pairs.sorted{$0.0<$1.0}.flatMap{[.int(Int64($0.0)),$0.1]});entities["sm__"] = .object(map)
        }
        return .object(entities)
    }
    public func matches(_ state:DeviceSnapshot)->Bool {
        guard Self.bindingState(state)==bindings,state.blocks.count==expected.count else{return false}
        return expected.allSatisfy {block in
            guard let actual=state.blocks.first(where:{$0.path==block.path && $0.position==block.position && $0.slot==block.slot}),actual.blockID==block.blockID,actual.model==block.model,actual.enabled==block.enabled,actual.values.count==block.values.count,actual.harnessValues.count==block.harnessValues.count else{return false}
            return block.values.allSatisfy{sameParameterValue($0.value,actual.values[$0.key] ?? .null)} && block.harnessValues.allSatisfy{sameParameterValue($0.value,actual.harnessValues[$0.key] ?? .null)}
        }
    }
}
