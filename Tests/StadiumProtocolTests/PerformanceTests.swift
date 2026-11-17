import XCTest
@testable import StadiumProtocol

final class PerformanceTests:XCTestCase {
    func fixture(command:Bool=false,timed:Bool=false,second:Bool=false,reversed:Bool=false)->DeviceSnapshot {
        func block(_ id:Int,_ model:Int,_ enabled:Bool)->Value {.object(["id__":.int(Int64(id)),"enbl":.int(enabled ? 1:0),"mdls":.array([.object(["id__":.int(Int64(model)),"parm":.array([])])])])}
        func controller(_ id:Int,_ target:Int,_ low:Bool,_ high:Bool)->Value {.object(["cid_":.int(Int64(id)),"trig":.int(3),"tid_":.int(Int64(target)),"type":.int(1),"min_":.bool(low),"max_":.bool(high),"behv":.int(0),"dlay":.number(0),"thrs":.number(0),"goid":.int(0),"togl":.bool(false)])}
        func target(_ id:Int,_ block:Int,_ model:Int)->Value {.object(["id__":.int(Int64(id)),"eID_":.int(Int64(block)),"mmid":.int(Int64(model)),"slot":.int(0),"type":.int(1)])}
        let source:Value = .object(["id__":.int(3),"type":.int(1),"ctxt":.int(1),"locl":.int(25),"mtyp":.int(timed ? 1:0),"mtms":.int(0),"cnt1":.int(0),"cnt2":.int(0),"cnt3":.int(0),"cmds":.array(command ? [.int(2),.int(-1)]:[.int(-1),.int(-1)]),"byps":.bool(false)])
        var controllers=[controller(5,7,false,true)],targets=[target(7,8,42)],blocks:[Value]=[.int(2),block(8,42,true)],ids:[Value]=[.int(5)]
        if second {controllers.append(controller(6,9,reversed,!reversed));targets.append(target(9,10,43));blocks += [.int(4),block(10,43,!reversed)];ids.append(.int(6))}
        let entities:Value = .object(["srcs":.array([source]),"ctrl":.array(controllers),"trgs":.array(targets),"cmnd":.array([]),"sm__":.object(["scid":.array([.int(3),.array(ids)])]),"snps":.array([.object(["si__":.int(0),"name":.string("Clean"),"colr":.int(8),"vald":.bool(true)])])])
        return DeviceSnapshot(product:.null,editBuffer:.object(["cg__":.object(["asnp":.int(0),"entt":entities]),"sfg_":.object(["flow":.array([.object(["blks":.array(blocks)])])])]),preset:.object(["cid_":.int(11)]),activeSnapshot:0,origin:UUID())
    }
    func testBypassPolarityAndContextOrigin()throws {
        let state=fixture(),plan=try XCTUnwrap(StompAssignment.read(state,bank:"a",number:1).plan)
        XCTAssertEqual(plan.input,1);XCTAssertEqual(plan.active,true);XCTAssertEqual(plan.controllers[0].low,.bool(true));XCTAssertEqual(plan.controllers[0].high,.bool(false))
        XCTAssertEqual(plan.origin,state.origin);XCTAssertEqual(try state.context(for:state.blocks[0]).origin,state.origin)
        XCTAssertEqual(plan.controllers[0].target.position,2);XCTAssertEqual(plan.controllers[0].target.blockID,8)
    }
    func testMultipleInverseAssignmentsAreKeptTogether()throws {
        let plan=try XCTUnwrap(StompAssignment.read(fixture(second:true,reversed:true),bank:"a",number:1).plan)
        XCTAssertEqual(plan.controllers.count,2);XCTAssertNil(plan.active);XCTAssertEqual(plan.input,1)
        XCTAssertEqual(plan.controllers[1].high,.bool(true))
    }
    func testCommandsTimedAndUnassignedSwitchesUnavailable() {
        XCTAssertNil(StompAssignment.read(fixture(command:true),bank:"a",number:1).plan)
        XCTAssertNil(StompAssignment.read(fixture(timed:true),bank:"a",number:1).plan)
        XCTAssertNil(StompAssignment.read(fixture(),bank:"b",number:1).plan)
        XCTAssertNil(StompAssignment.read(fixture(),bank:"a",number:6).plan)
    }
    func testChangedAssignmentRejectedInsteadOfGuessing() {
        var state=fixture();var graph=state.editBuffer["cg__"].object,entities=graph["entt"]!.object
        entities["trgs"] = .array([]);graph["entt"] = .object(entities);var edit=state.editBuffer.object;edit["cg__"] = .object(graph);state.editBuffer = .object(edit)
        XCTAssertNil(StompAssignment.read(state,bank:"a",number:1).plan)
    }
    func testControllerWireValueIsBoundedAndFloat()throws {
        let message=try EditCommand.controller(5,1).message(id:9)
        XCTAssertEqual(message.address,"/ControllerValueSet");XCTAssertEqual(message.values,[.int(9),.int(5),.number(1)])
        XCTAssertThrowsError(try EditCommand.controller(5,2).message(id:9));XCTAssertThrowsError(try EditCommand.controller(0,0).message(id:9))
    }
}

final class LibraryAndTunerTests:XCTestCase {
    func testSetlistReferencesResolveBackingPresetAndRemainNonWritable()throws {
        let reference:Value = .object(["cid_":.int(100),"type":.int(1003),"name":.string("Test folder")])
        let contents:Value = .array([.object(["cid_":.int(300),"rcid":.int(200),"type":.int(1),"ccid":.int(100),"posi":.int(0),"name":.string("Test preset")]),.object(["cid_":.int(301),"type":.int(1)])])
        let folder=try XCTUnwrap(PresetFolder(reference:reference,contents:contents))
        XCTAssertEqual(folder.presets.count,1);XCTAssertEqual(folder.presets[0].contentID,200);XCTAssertFalse(folder.presets[0].writable)
    }
    func testTunerHasExplicitOpenAndExitEventsOnly()throws {
        for enabled in [true,false] {
            let command=try EditCommand.tuner(enabled).message(id:5)
            XCTAssertEqual(command.address,"/PropertyValueSet");XCTAssertEqual(command.values[1],.int(0))
            let blob=try XCTUnwrap(command.values[2].data),property=try MessagePack.decode(blob)
            XCTAssertTrue(blob.starts(with:Data("lavppgsm".utf8)))
            XCTAssertEqual(property["key_"].text,enabled ? "volatile.held.taptempo":"volatile.press.exittuner")
            XCTAssertEqual(property["type"].text,"i");XCTAssertEqual(property["val_"],.int(11))
        }
    }
}
