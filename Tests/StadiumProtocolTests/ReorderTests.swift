import XCTest
@testable import StadiumProtocol

final class ReorderTests:XCTestCase {
    func state(_ first:Int=5,_ second:Int=6,route:Bool=false,alter:Bool=false)->DeviceSnapshot {
        func block(_ id:Int,_ model:Int,_ value:Double)->Value {.object(["id__":.int(Int64(id)),"enbl":.int(1),"mdls":.array([.object(["id__":.int(Int64(model)),"parm":.array([.object(["pid_":.int(1),"valu":.number(value)])])])]),"hrns":.object(["parm":.array([.object(["pid_":.int(1),"valu":.bool(true)])])])])}
        let blocks:[Value]=[.int(Int64(first)),block(3,42,alter ? 0.6:0.4),.int(Int64(second)),block(4,route ? 475:43,0.2)]
        return DeviceSnapshot(product:.null,editBuffer:.object(["sfg_":.object(["flow":.array([.object(["blks":.array(blocks)])])])]),preset:.object(["cid_":.int(11)]),activeSnapshot:0)
    }
    func models()throws->[Int:ModelDefinition] {
        let data=Data("[{\"id\":42,\"name\":\"Amp\",\"category\":\"amp\",\"parameters\":[]},{\"id\":43,\"name\":\"Delay\",\"category\":\"delay\",\"parameters\":[]},{\"id\":475,\"name\":\"Split\",\"category\":\"split\",\"parameters\":[]}]".utf8)
        return Dictionary(uniqueKeysWithValues:try JSONDecoder().decode([ModelDefinition].self,from:data).map{($0.id,$0)})
    }
    func testReorderRotatesOccupiedAndEmptyCellsAndRetainsSettings()throws {
        let before=state(),context=try before.context(for:before.blocks[0]),plan=try BlockReorderPlan(state:before,context:context,to:7,models:models())
        XCTAssertTrue(plan.matches(state(7,5)));XCTAssertFalse(plan.matches(state(7,5,alter:true)))
        XCTAssertEqual(plan.expected.first{$0.blockID==3}?.harnessValues[1],.bool(true))
    }
    func testRoutingBoundariesStaleOriginAndIOAreRejected()throws {
        let before=state(),context=try before.context(for:before.blocks[0])
        for destination in [0,13,14,15,-1,28,5] {XCTAssertThrowsError(try BlockReorderPlan(state:before,context:context,to:destination,models:models()))}
        let routed=state(route:true);XCTAssertThrowsError(try BlockReorderPlan(state:routed,context:routed.context(for:routed.blocks[0]),to:7,models:models()))
        var other=before;other.origin=UUID();XCTAssertThrowsError(try BlockReorderPlan(state:other,context:context,to:7,models:models()))
        XCTAssertThrowsError(try BlockReorderPlan(state:before,context:context,to:7,models:[:]))
    }
    func testRuntimeFlagsAndSetOrderAreNotAssignmentEdits()throws {
        func entities(reversed:Bool,changedRange:Bool=false)->Value {
            let sources:[Value]=[.object(["id__":.int(1),"locl":.int(25),"byps":.bool(reversed)]),.object(["id__":.int(2),"locl":.int(26),"byps":.bool(!reversed)])]
            return .object(["srcs":.array(reversed ? sources.reversed():sources),"ctrl":.array([.object(["cid_":.int(3),"min_":.bool(changedRange),"max_":.bool(true),"togl":.bool(reversed)])]),"ctm_":.object(["stid":.array(reversed ? [.int(2),.int(1)]:[.int(1),.int(2)])]),"sm__":.object(["scid":.array([.int(1),.array([.int(3)])])])])
        }
        func adding(_ ent:Value,to state:DeviceSnapshot)->DeviceSnapshot {var result=state,edit=state.editBuffer.object;edit["cg__"] = .object(["entt":ent]);result.editBuffer = .object(edit);return result}
        let before=adding(entities(reversed:false),to:state()),context=try before.context(for:before.blocks[0]),plan=try BlockReorderPlan(state:before,context:context,to:7,models:models())
        XCTAssertTrue(plan.matches(adding(entities(reversed:true),to:state(7,5))))
        XCTAssertFalse(plan.matches(adding(entities(reversed:true,changedRange:true),to:state(7,5))))
    }
    func testNativeAgendaWireAndAcknowledgementChangedFlag()throws {
        let message=try EditCommand.reorder(flow:0,from:5,to:7).message(id:3)
        XCTAssertEqual(message.address,"/doAgenda")
        let commands=try MessagePack.decode(XCTUnwrap(message.values[1].data)).items
        XCTAssertEqual(commands.count,2);XCTAssertEqual(commands[0]["cmnd"],.int(0x73776170));XCTAssertEqual(commands[1]["blk0"],.int(6));XCTAssertEqual(commands[1]["blk1"],.int(7))
        for flag in [0,1] {XCTAssertNoThrow(try EditCommand.acknowledgeAgenda(OSCMessage("/status",[.int(3),.int(Int64(flag)),.int(1)])))}
        for flag in [-1,2] {XCTAssertThrowsError(try EditCommand.acknowledgeAgenda(OSCMessage("/status",[.int(3),.int(Int64(flag)),.int(1)])))}
    }
}
