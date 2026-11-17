import XCTest
@testable import StadiumProtocol

final class EditingTests:XCTestCase {
    func definition(_ type:String="f",harness:Bool=false,minimum:Double=0,maximum:Double=1)throws->ParameterDefinition {
        let object:[String:Any]=["id":1,"key":"Test","name":"Test depth","type":type,"minimum":minimum,"maximum":maximum,"displayMinimum":0,"displayMaximum":10,"unit":"unitless","harness":harness]
        return try JSONDecoder().decode(ParameterDefinition.self,from:JSONSerialization.data(withJSONObject:object))
    }
    func context(slot:Int=1)->EditContext {EditContext(presetID:11,snapshot:0,path:1,blockID:2,slot:slot,modelID:42,position:11)}
    func testWireUsesPositionAndDualSlotWhileContextRetainsRawIdentity()throws {
        let message=try EditCommand.parameter(context(),definition(),.number(0.5)).message(id:6)
        XCTAssertEqual(message.address,"/ParamValueSet")
        XCTAssertEqual(message.values,[.int(6),.int(1),.int(11),.int(1),.int(1),.number(0.5),.int(-1)])
        XCTAssertEqual(try OSCMessage.decode(message.encode()),message)
    }
    func testHarnessAndBooleanHaveDifferentWireShape()throws {
        let message=try EditCommand.parameter(context(),definition("b",harness:true),.bool(true)).message(id:6)
        XCTAssertEqual(message.address,"/HarnessParamValueSet");XCTAssertEqual(message.values.count,6)
        XCTAssertEqual(try OSCMessage.decode(message.encode()).values[4],.bool(true))
        let model=try EditCommand.parameter(context(),definition("b"),.bool(true)).message(id:6)
        XCTAssertEqual(try OSCMessage.decode(model.encode()).values[5],.bool(true))
    }
    func testRejectOutOfRangeFractionalNonfiniteAndUnknownValues()throws {
        for value in [Value.number(1.01),.number(-1),.number(.nan),.number(.infinity),.string("invalid")] {XCTAssertThrowsError(try EditCommand.parameter(context(),definition(),value).message(id:1))}
        XCTAssertThrowsError(try EditCommand.parameter(context(),definition("i"),.number(0.5)).message(id:1))
        XCTAssertThrowsError(try EditCommand.parameter(context(slot:2),definition(),.number(0.5)).message(id:1))
        XCTAssertThrowsError(try EditCommand.parameter(context(),definition("b"),.int(1)).message(id:1))
        let boundary=try definition("f",minimum:19.9,maximum:500)
        XCTAssertTrue(boundary.containsWireValue(Double(Float(19.9))))
        XCTAssertNoThrow(try boundary.validated(.number(Double(Float(19.9)))))
        XCTAssertFalse(boundary.containsWireValue(19.899))
    }
    func testWholePresetSaveIncludesBothSelectorsAndValidatesAck()throws {
        XCTAssertEqual(try EditCommand.save(21).message(id:9).values,[.int(9),.int(21),.int(-1),.int(-1)])
        for result in [0,1] {try EditCommand.acknowledge(OSCMessage("/status",[.int(9),.int(0),.int(Int64(result))]))}
        for values in [[Value.int(9)],[.int(9),.int(-1),.int(1)],[.int(9),.int(0),.string("yes")]] {XCTAssertThrowsError(try EditCommand.acknowledge(OSCMessage("/status",values)))}
        XCTAssertThrowsError(try EditCommand.save(0).message(id:1))
    }
    func testCopyOnlyUsesUserContainerAndBoundedNames()throws {
        let message=try EditCommand.createUser(position:267,name:"Spare").message(id:1)
        XCTAssertEqual(message.address,"/CreateContent");XCTAssertEqual(Array(message.values.prefix(4)),[.int(1),.int(-2),.int(267),.int(2)])
        XCTAssertEqual(try MessagePack.decode(message.values[4].data!)["name"],.string("Spare"))
        XCTAssertThrowsError(try EditCommand.createUser(position:512,name:"Spare").message(id:1))
        for name in ["",String(repeating:"x",count:33),"Bad\0name"] {XCTAssertThrowsError(try EditCommand.createUser(position:1,name:name).message(id:1))}
        XCTAssertEqual(try EditCommand.allocatedID(OSCMessage("/status",[.int(1),.int(52),.int(1)])),52)
        XCTAssertThrowsError(try EditCommand.allocatedID(OSCMessage("/status",[.int(1),.int(0),.int(1)])))
    }
    func testEmptySlotAndStorageChecksRejectAmbiguousLocations() {
        XCTAssertTrue(PresetSlot(.object(["ccid":.int(-2),"posi":.int(0),"cid_":.int(0)])).empty)
        for value:Value in [.object(["ccid":.int(-2),"posi":.int(0),"cid_":.int(2)]),.object(["ccid":.int(-1),"posi":.int(0)]),.object(["ccid":.int(-2)])] {XCTAssertFalse(PresetSlot(value).empty)}
        XCTAssertFalse(PresetSlot(.object(["cid_":.int(2),"ccid":.int(-1),"type":.int(2)])).writable)
        XCTAssertFalse(PresetSlot(.object(["cid_":.int(2),"ccid":.int(-2),"type":.int(1),"rcid":.int(8)])).writable)
    }
    func testModelAndHarnessWithSameParameterIDStaySeparateAndDualModelsSurvive()throws {
        let model:Value = .object(["id__":.int(42),"parm":.array([.object(["pid_":.int(1),"valu":.number(0.4)])])])
        let block:Value = .object(["id__":.int(2),"enbl":.int(1),"mdls":.array([model,model]),"hrns":.object(["parm":.array([.object(["pid_":.int(1),"valu":.int(3)])])])])
        let state=DeviceSnapshot(product:.null,editBuffer:.object(["sfg_":.object(["flow":.array([.object(["blks":.array([.int(11),block])])])])]),preset:.object(["cid_":.int(11)]),activeSnapshot:0)
        XCTAssertEqual(state.blocks.count,2);XCTAssertEqual(state.blocks[1].blockID,2);XCTAssertEqual(state.blocks[1].position,11);XCTAssertEqual(state.blocks[1].slot,1)
        XCTAssertEqual(state.blocks[0].value(try definition()),.number(0.4));XCTAssertEqual(state.blocks[0].value(try definition("i",harness:true,maximum:5)),.int(3))
    }
    func testConditionalDisplayFormatsDoNotMislabelOffOrUnits()throws {
        func parameter(_ formats:[[String:Any]])throws->ParameterDefinition {
            let data:[String:Any] = ["id":1,"key":"Cut","name":"Cut","type":"f","minimum":0,"maximum":30000,"unit":"Hz","harness":false,"displayFormats":formats]
            return try JSONDecoder().decode(ParameterDefinition.self,from:JSONSerialization.data(withJSONObject:data))
        }
        let p=try parameter([["lowerBound":0,"upperBound":20,"multiplier":1,"format":"Off"],["lowerBound":20,"upperBound":1000,"multiplier":1,"format":"%.0f Hz"],["lowerBound":1000,"upperBound":30001,"multiplier":0.001,"format":"%.1f kHz"]])
        XCTAssertEqual(p.display(.number(19.9)),"Off")
        XCTAssertEqual(p.display(.number(500)),"500 Hz")
        XCTAssertEqual(p.display(.number(3720)),"3.7 kHz")
        let unsupported=try parameter([["multiplier":1,"format":"%s"]])
        XCTAssertEqual(unsupported.display(.number(5)),"5 Hz")
        let excessive=try parameter([["multiplier":1,"format":"%999999999f"]])
        XCTAssertEqual(excessive.display(.number(5)),"5 Hz")
    }
    func testModelAndSnapshotCommandsUseVisiblePositionsAndBoundedIndices()throws {
        XCTAssertEqual(try EditCommand.model(context(),77).message(id:3).values,[.int(3),.int(1),.int(11),.int(1),.int(77)])
        XCTAssertEqual(try EditCommand.snapshot(7).message(id:4),OSCMessage("/activateSnapshot",[.int(4),.int(7),.int(0)]))
        for index in [-1,8] {XCTAssertThrowsError(try EditCommand.snapshot(index).message(id:1))}
        let input=EditContext(presetID:11,snapshot:0,path:0,blockID:0,slot:0,modelID:42,position:0)
        XCTAssertThrowsError(try EditCommand.model(input,77).message(id:1))
        XCTAssertEqual(try ReadCommand.cloneHierarchy.decode(OSCMessage("/GetCloneHierarchy",[.int(1),.binary(try MessagePack.encode(.array([])))])),.array([]))
        XCTAssertEqual(try ReadCommand.container(-7).message(id:1).values,[.int(1),.int(-7)])
        XCTAssertThrowsError(try ReadCommand.container(0).message(id:1))
    }
    func testSnapshotsExposeNamedDefinedScenesOnlyAsDefined() {
        let state=DeviceSnapshot(product:.null,editBuffer:.object(["cg__":.object(["entt":.object(["snps":.array([.object(["si__":.int(1),"vald":.bool(false)]),.object(["si__":.int(0),"vald":.bool(true),"name":.string("Clean")])])])])]),preset:.null,activeSnapshot:0)
        XCTAssertEqual(state.snapshots.map(\.id),[0,1]);XCTAssertEqual(state.snapshots[0].name,"Clean");XCTAssertFalse(state.snapshots[1].defined)
    }
    func testLiveSelectionUsesVisiblePositionAndRejectsMalformedEvents() {
        XCTAssertEqual(StadiumLiveUpdate.decode(OSCMessage("/setSelectedBlock",[.int(2),.int(17),.int(0),.int(6)])),.selection(path:0,position:6))
        XCTAssertEqual(StadiumLiveUpdate.decode(OSCMessage("/setSelectedBlock",[.int(2),.int(18),.int(1),.int(27)])),.selection(path:1,position:27))
        for values:[Value] in [[.int(0),.int(6)],[.int(2),.int(17),.int(2),.int(6)],[.int(2),.int(17),.int(0),.int(28)],[.int(2),.int(17),.number(0),.int(6)]] {XCTAssertNil(StadiumLiveUpdate.decode(OSCMessage("/setSelectedBlock",values)))}
        XCTAssertEqual(StadiumLiveUpdate.decode(OSCMessage("/setModelWithMID",[])),.stateChanged)
        XCTAssertNil(StadiumLiveUpdate.decode(OSCMessage("/heartbeat",[])))
    }
    func testMessagePackAttributesRoundTrip()throws {
        let value:Value = .object(["s":.string(String(repeating:"a",count:40)),"i":.int(-100),"b":.bool(true),"array":.array([.null,.number(0.25)]),"data":.binary(Data([1,2,3]))])
        XCTAssertEqual(try MessagePack.decode(MessagePack.encode(value)),value)
        XCTAssertThrowsError(try EditCommand.storeNewPreset(3,Data([1,2,3])).message(id:1))
    }
}
