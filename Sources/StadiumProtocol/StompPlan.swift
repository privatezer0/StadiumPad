import Foundation

public struct StompTarget:Equatable,Sendable {
    public let path:Int;public let position:Int;public let blockID:Int;public let modelID:Int;public let slot:Int;public let parameter:Int?
    public func value(in state:DeviceSnapshot)->Value? {
        guard let block=state.blocks.first(where:{$0.path-1==path && $0.position==position && $0.blockID==blockID && $0.model==modelID && $0.slot==slot}) else{return nil}
        return parameter.map{block.values[$0] ?? .null} ?? .bool(block.enabled)
    }
}
public struct StompController:Equatable,Sendable {
    public let id:Int;public let target:StompTarget;public let low:Value;public let high:Value;public let current:Value
}
public struct StompPlan:Equatable,Sendable {
    public let origin:UUID?
    public let presetID:Int;public let snapshot:Int;public let bank:String;public let number:Int;public let sourceID:Int
    public let controllers:[StompController];public let input:Int;public let active:Bool?;public let fingerprint:Value
}
public struct StompAssignment:Identifiable,Sendable {
    public let bank:String;public let number:Int;public let plan:StompPlan?;public let reason:String?
    public var id:String {bank+String(number)}
    public static let switchNumbers=[1,2,3,4,5,7,8,9,10,11]
    public static func read(_ state:DeviceSnapshot,bank:String,number:Int)->StompAssignment {
        func unavailable(_ reason:String)->StompAssignment {.init(bank:bank,number:number,plan:nil,reason:reason)}
        guard ["a","b"].contains(bank),switchNumbers.contains(number),let presetID=state.presetID else{return unavailable("Unavailable switch")}
        let graph=state.editBuffer["cg__"],entities=graph["entt"]
        guard graph["asnp"].integer==state.activeSnapshot,case .array=entities["srcs"],case .array=entities["ctrl"],case .array=entities["trgs"],case .array=entities["cmnd"] else{return unavailable("Assignments unavailable")}
        let sources=entities["srcs"].items
        let matches=sources.filter{$0["type"].integer==1 && $0["ctxt"].integer==(bank=="a" ? 1:2) && $0["locl"].integer==24+number}
        guard !matches.isEmpty else{return unavailable("Unassigned")}
        guard matches.count==1,let sourceID=matches[0]["id__"].integer,sourceID>0,sources.filter({$0["id__"].integer==sourceID}).count==1 else{return unavailable("Ambiguous assignment")}
        let source=matches[0]
        guard ["mtyp","mtms","cnt1","cnt2","cnt3"].allSatisfy({source[$0].numeric==0}) else{return unavailable("Timed switch · use pedal")}
        guard source["cmds"].items.count==2,source["cmds"].items.allSatisfy({$0.integer == -1}) else{return unavailable("Command switch · use pedal")}
        let mapping=entities["sm__"]["scid"].items
        guard mapping.count%2==0 else{return unavailable("Assignments incomplete")}
        var idLists:[Value]=[]
        for i in stride(from:0,to:mapping.count,by:2) {if mapping[i].integer==sourceID {idLists.append(mapping[i+1])}}
        guard idLists.count==1,case .array=idLists[0] else{return unavailable("Unassigned")}
        let ids=idLists[0].items.compactMap(\.integer)
        guard !ids.isEmpty,ids.count==idLists[0].items.count,ids.allSatisfy({$0>0 && $0<=Int(Int32.max)}),Set(ids).count==ids.count else{return unavailable("Assignments incomplete")}
        let linked=entities["ctrl"].items.filter{$0["trig"].integer==sourceID}
        guard linked.count==ids.count else{return unavailable("Assignment map changed")}
        func config(_ value:Value,excluding:[String])->Value {.object(value.object.filter{!excluding.contains($0.key)})}
        var controllers:[StompController]=[],fingerprints:[Value]=[],states:[Bool?]=[],positions:[Int]=[],targetKeys:Set<String>=[]
        for id in ids.sorted() {
            let found=entities["ctrl"].items.filter{$0["cid_"].integer==id}
            guard found.count==1,found[0]["trig"].integer==sourceID else{return unavailable("Controller changed")}
            let controller=found[0]
            guard ["behv","dlay","thrs","goid"].allSatisfy({controller[$0].numeric==0}) else{return unavailable("Momentary/timed · use pedal")}
            guard let type=controller["type"].integer,(1...3).contains(type),let targetID=controller["tid_"].integer else{return unavailable("Controller unavailable")}
            let targets=entities["trgs"].items.filter{$0["id__"].integer==targetID}
            guard targets.count==1,let blockID=targets[0]["eID_"].integer,let model=targets[0]["mmid"].integer,let slot=targets[0]["slot"].integer,(0...1).contains(slot),let targetType=targets[0]["type"].integer,[1,2].contains(targetType) else{return unavailable("Target unavailable")}
            let blocks=state.blocks.filter{$0.blockID==blockID && $0.model==model && $0.slot==slot}
            guard blocks.count==1 else{return unavailable("Assigned block changed")}
            let block=blocks[0],parameter=targetType==1 ? nil:targets[0]["pid_"].integer
            guard targetType==1 || parameter != nil else{return unavailable("Parameter unavailable")}
            let target=StompTarget(path:block.path-1,position:block.position,blockID:blockID,modelID:model,slot:slot,parameter:parameter)
            let key="\(target.path)-\(target.position)-\(parameter.map(String.init) ?? "bypass")-\(parameter==nil ? 0:slot)"
            guard targetKeys.insert(key).inserted else{return unavailable("Overlapping assignments")}
            func endpoint(_ raw:Value)->Value? {
                if targetType==1 {return raw.boolean.map{.bool(!$0)}}
                if type==1 {return raw.boolean.map(Value.bool)}
                guard let n=raw.numeric,n.isFinite else{return nil}
                if type==2 {guard let value=Int32(exactly:n) else{return nil};return .int(Int64(value))}
                return .number(n)
            }
            guard let low=endpoint(controller["min_"]),let high=endpoint(controller["max_"]),let current=target.value(in:state),current != .null else{return unavailable("Values unavailable")}
            let atLow=sameParameterValue(current,low),atHigh=sameParameterValue(current,high)
            if atLow && atHigh {return unavailable("No switch range")}
            let position=atHigh ? 1:atLow ? 0:abs((current.numeric ?? 0)-(high.numeric ?? 0))<abs((current.numeric ?? 0)-(low.numeric ?? 0)) ? 1:0
            positions.append(position)
            if targetType==1 {states.append(current.boolean)}else{states.append(atHigh ? true:atLow ? false:nil)}
            controllers.append(.init(id:id,target:target,low:low,high:high,current:current))
            fingerprints.append(.object(["controller":config(controller,excluding:["togl"]),"target":targets[0]]))
        }
        let active:Bool? = states.allSatisfy{$0==true} ? true:states.allSatisfy{$0==false} ? false:nil
        let plan=StompPlan(origin:state.origin,presetID:presetID,snapshot:state.activeSnapshot,bank:bank,number:number,sourceID:sourceID,controllers:controllers,input:positions[0]==1 ? 0:1,active:active,fingerprint:.object(["source":config(source,excluding:["byps"]),"controllers":.array(fingerprints)]))
        return .init(bank:bank,number:number,plan:plan,reason:nil)
    }
}
