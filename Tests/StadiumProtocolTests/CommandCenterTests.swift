import XCTest
@testable import StadiumProtocol

final class CommandCenterTests:XCTestCase {
    func state(commands:[Value]=[],sources:[Value]=[])->DeviceSnapshot {DeviceSnapshot(product:.null,editBuffer:.object(["cg__":.object(["asnp":.int(0),"entt":.object(["cmnd":.array(commands),"srcs":.array(sources)])])]),preset:.object(["cid_":.int(50)]),activeSnapshot:0)}
    func testSourcesUseObservedDescriptorsAndRejectReservedSwitches()throws {
        XCTAssertEqual(CommandSource(.stomp,number:1,bank:2).location,25)
        XCTAssertEqual(CommandSource(.instant,number:15).type,4)
        XCTAssertEqual(CommandSource(.axis,number:1).type,5)
        XCTAssertEqual(CommandSource(.toe,number:0).location,37)
        XCTAssertEqual(CommandSource(.expression,number:0).location,42)
        for number in [0,6,12,13] {XCTAssertThrowsError(try CommandSource(.stomp,number:number,bank:1).validate())}
        XCTAssertThrowsError(try CommandSource(.instant,number:16).validate())
    }
    func testSourceCategoryAndSlotRestrictions()throws {
        let instant=CommandSource(.instant,number:0),axis=CommandSource(.axis,number:0)
        XCTAssertFalse(instant.supports(.utility));XCTAssertFalse(instant.supports(.presetSnapshot));XCTAssertTrue(instant.supports(.song))
        XCTAssertTrue(axis.supports(.midi));XCTAssertFalse(axis.supports(.hotKey))
        XCTAssertThrowsError(try CommandContext(state:state(),source:axis,slot:1))
    }
    func testAttachmentIsTypedAndCarriesNoArbitraryGraph()throws {
        let source=CommandSource(.stomp,number:1,bank:1),context=try CommandContext(state:state(),source:source,slot:0)
        let request=try CommandCenterOperation.family(.midi).message(context:context,id:7)
        XCTAssertEqual(request.address,"/attachCommandWithType");XCTAssertEqual(Array(request.values.prefix(7)),[.int(7),.int(1),.int(25),.int(1),.int(0),.int(6),.int(0)])
        XCTAssertEqual(try MessagePack.decode(request.values.last!.data!),.array([]))
    }
    func testSharedAndMissingCommandIdentitiesAreRejected() {
        let command:Value = .object(["cid_":.int(3),"trig":.int(9),"type":.int(6)])
        let source:Value = .object(["id__":.int(9),"type":.int(1),"locl":.int(25),"ctxt":.int(1),"cmds":.array([.int(3),.int(-1)])])
        var second=source.object;second["id__"] = .int(10);second["locl"] = .int(26)
        XCTAssertThrowsError(try CommandContext(state:state(commands:[command],sources:[source,.object(second)]),source:CommandSource(.stomp,number:1,bank:1),slot:0))
        XCTAssertThrowsError(try CommandContext(state:state(sources:[source]),source:CommandSource(.stomp,number:1,bank:1),slot:0))
    }
    func testTypedValuesAndHiddenSubtypeFields()throws {
        let p=CommandParameter(id:7,name:"Value",minimum:0,maximum:127)
        XCTAssertThrowsError(try p.validated(.number(1.5)));XCTAssertThrowsError(try p.validated(.int(128)));XCTAssertThrowsError(try p.validated(.number(.nan)))
        XCTAssertEqual(p.valueKey,"pvlh");XCTAssertEqual(p.snapshotKey,"psph")
        let cc=CommandParameter(id:6,name:"CC#",minimum:0,maximum:127),source=CommandSource(.stomp,number:1,bank:1)
        XCTAssertTrue(cc.visible(source:source,family:.midi,command:.object(["pvlb":.int(1)])))
        XCTAssertFalse(cc.visible(source:source,family:.midi,command:.object(["pvlb":.int(2)])))
    }
    func testExternalRefreshNotifications() {
        XCTAssertEqual(StadiumLiveUpdate.decode(OSCMessage("/setCommandParamVal",[])),.stateChanged)
        XCTAssertEqual(StadiumLiveUpdate.decode(OSCMessage("/removeCommand",[])),.stateChanged)
    }
    func testStoredSourceDescriptorsDifferFromWireAxisLocal()throws {
        for source in [CommandSource(.axis,number:1),CommandSource(.instant,number:15),CommandSource(.expression,number:0,bank:1)] {
            let local=source.kind == .axis ? -1:source.location
            let row:Value = .object(["id__":.int(9),"type":.int(Int64(source.type)),"locl":.int(Int64(local)),"ctxt":.int(Int64(source.context)),"cmds":.array([.int(3),.int(-1)])])
            let command:Value = .object(["cid_":.int(3),"trig":.int(9),"type":.int(6)])
            let context=try CommandContext(state:state(commands:[command],sources:[row]),source:source,slot:0)
            XCTAssertEqual(context.commandID,3)
            XCTAssertEqual(source.location,source.kind == .expression ? 42:0)
        }
        XCTAssertEqual(CommandSource(.expression,number:0,bank:1).name,"EXP 2")
    }
    func testSubtypeUsesParameterRatherThanNativeContinuousFlag() {
        let p=CommandParameter(id:3,name:"Preset",minimum:0,maximum:1024)
        XCTAssertTrue(p.visible(source:CommandSource(.stomp,number:1,bank:1),family:.presetSnapshot,command:.object(["func":.int(0),"pvlb":.int(4)])))
        let cc=CommandParameter(id:5,name:"CC#",minimum:0,maximum:127)
        XCTAssertTrue(cc.visible(source:CommandSource(.instant,number:0),family:.midi,command:.object(["func":.int(0),"pvla":.int(1)])))
    }
    func testSnapshotRemovalUsesObservedLowercaseAddress()throws {
        let source=CommandSource(.stomp,number:1,bank:1)
        let row:Value = .object(["id__":.int(9),"type":.int(1),"locl":.int(25),"ctxt":.int(1),"cmds":.array([.int(3),.int(-1)])])
        let command:Value = .object(["cid_":.int(3),"trig":.int(9),"type":.int(6),"pvlh":.int(45)])
        let context=try CommandContext(state:state(commands:[command],sources:[row]),source:source,slot:0)
        let p=CommandParameter(id:7,name:"Value",minimum:0,maximum:127)
        let message=try CommandCenterOperation.snapshot(p,false).message(context:context,id:10)
        XCTAssertEqual(message.address,"/removeSnapshotCommandParam");XCTAssertEqual(message.values,[.int(10),.int(3),.int(7)])
    }
    func testAppearanceHasNarrowPropertyScope()throws {
        let source=CommandSource(.stomp,number:1,bank:2)
        XCTAssertEqual(try StompAppearance.color(8).property(source:source).0,"preset.floorboard.stomp.b.1.color")
        XCTAssertThrowsError(try StompAppearance.color(12).property(source:source))
        XCTAssertThrowsError(try StompAppearance.label(String(repeating:"a",count:25)).property(source:source))
        XCTAssertThrowsError(try StompAppearance.label("bad\nlabel").property(source:source))
        XCTAssertThrowsError(try StompAppearance.label("Name").property(source:CommandSource(.instant,number:0)))
    }

    func testOnlyExpectedSecondSlotToggleCouplingIsAccepted()throws {
        let source=CommandSource(.stomp,number:1,bank:1)
        let row:Value = .object(["id__":.int(9),"type":.int(1),"locl":.int(25),"ctxt":.int(1),"cmds":.array([.int(3),.int(4)])])
        let first:Value = .object(["cid_":.int(3),"trig":.int(9),"type":.int(6),"pvla":.int(0)])
        let second:Value = .object(["cid_":.int(4),"trig":.int(9),"type":.int(6),"pvla":.int(0),"pvlh":.int(45),"togl":.bool(false)])
        let context=try CommandContext(state:state(commands:[first,second],sources:[row]),source:source,slot:0)
        let operation=CommandCenterOperation.parameter(CommandParameter(id:0,name:"Action",minimum:0,maximum:3),.int(3))
        var changed=second.object;changed["pvla"] = .int(3);changed["togl"] = .bool(true)
        XCTAssertTrue(operation.permitsPairedToggle(old:second,new:.object(changed),context:context))
        var toggledFirst=first.object;toggledFirst["pvla"] = .int(3)
        let toggled=try CommandContext(state:state(commands:[.object(toggledFirst),.object(changed)],sources:[row]),source:source,slot:0)
        var released=changed;released["pvla"] = .int(0);released["togl"] = .bool(false)
        XCTAssertTrue(CommandCenterOperation.parameter(CommandParameter(id:0,name:"Action",minimum:0,maximum:3),.int(0)).permitsPairedToggle(old:.object(changed),new:.object(released),context:toggled))
        changed["pvlh"] = .int(46)
        XCTAssertFalse(operation.permitsPairedToggle(old:second,new:.object(changed),context:context))
        changed["pvlh"] = .int(45);changed["cid_"] = .int(5)
        XCTAssertFalse(operation.permitsPairedToggle(old:second,new:.object(changed),context:context))
    }

}
