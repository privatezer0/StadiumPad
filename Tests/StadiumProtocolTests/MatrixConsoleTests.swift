import XCTest
@testable import StadiumProtocol
final class MatrixConsoleTests:XCTestCase {
    func row(_ id:Int)->Value {.object(["src_":.int(Int64(id)),"name":.string("Channel \(id)"),"enbl":.int(-1),"vol_":.number(-6),"pan_":.number(0),"mute":.bool(false),"solo":.bool(false),"future":.string("keep")])}
    func fixture()->Value {
        let layers=(1...3).map{output in Value.object(["out_":.object(["dst_":.int(Int64(output)),"vol_":.number(-18)]),"home":.object(["mix_":row(5),"chan":.array((1...4).map(row))]),"song":.object(["mix_":row(14),"chan":.array((6...13).map(row))]),"clik":row(15),"cntn":row(16),"usbn":row(17),"bt__":row(18),"auxn":row(19)])}
        return .object(["key_":.string("server.mixer.state"),"val_":.object(["lom_":.int(0),"lyrs":.array(layers)])])
    }
    func testSourceIDsUseDocumentedCCOrderRatherThanNumericSourceID()throws {
        let cases=[(5,11),(1,12),(4,15),(14,16),(6,17),(13,24),(15,25),(16,26),(17,27),(18,28),(19,29)]
        for (source,cc) in cases {XCTAssertEqual(MatrixStrip.controlCC(source:source,field:.level),cc);XCTAssertEqual(MatrixStrip.controlCC(source:source,field:.pan),cc+23);XCTAssertEqual(MatrixStrip.controlCC(source:source,field:.mute),cc+46);XCTAssertEqual(MatrixStrip.controlCC(source:source,field:.solo),cc+69)}
        XCTAssertEqual(try MatrixConsoleCommand(output:3,source:14,field:.mute,value:127).midiWord(channel:5),0x20B43E7F)
        XCTAssertThrowsError(try MatrixConsoleCommand(output:1,source:16,field:.level,value:20))
        XCTAssertThrowsError(try MatrixConsoleCommand(output:1,source:20,field:.level,value:20))
        XCTAssertThrowsError(try MatrixConsoleCommand(output:1,source:5,field:.mute,value:0))
    }
    func testCompleteStateRejectsMissingOrDuplicateRows()throws {
        let before=fixture(),state=try MatrixConsoleState(property:before)
        XCTAssertEqual(state.strips(3).count,19);XCTAssertFalse(state.strip(output:1,source:16)!.enabled)
        var root=before["val_"].object,layers=root["lyrs"]!.items,layer=layers[0].object,home=layer["home"]!.object
        home["chan"] = .array([row(1),row(1),row(3),row(4)]);layer["home"] = .object(home);layers[0] = .object(layer);root["lyrs"] = .array(layers)
        XCTAssertThrowsError(try MatrixConsoleState(property:.object(["key_":.string("server.mixer.state"),"val_":.object(root)])))
    }
    func testLivePanAndToggleChangeOnlyTheAddressedStripAndPreserveUnknownFields()throws {
        let before=fixture()
        let message=OSCMessage("/syncMixChannelPan",[.int(7),.int(-1),.int(2),.int(14),.number(-0.5)])
        let update=try XCTUnwrap(MatrixConsoleUpdate.decode(message)),after=try MatrixConsoleState(property:update.applying(to:before))
        XCTAssertEqual(after.strip(output:2,source:14)!.pan,-0.5)
        XCTAssertEqual(after.strip(output:2,source:14)!.raw["future"],.string("keep"))
        XCTAssertEqual(after.layer(1),try MatrixConsoleState(property:before).layer(1))
        XCTAssertEqual(after.strip(output:2,source:5)!.pan,0)
        let mute=try XCTUnwrap(MatrixConsoleUpdate.decode(OSCMessage("/syncMixChannelMute",[.int(7),.int(-1),.int(3),.int(1),.int(1)])))
        XCTAssertTrue(try MatrixConsoleState(property:mute.applying(to:before)).strip(output:3,source:1)!.muted)
        XCTAssertNil(MatrixConsoleUpdate.decode(OSCMessage(message.address,[.int(7),.int(-1),.int(2),.int(14),.number(2)])))
        XCTAssertNil(MatrixConsoleUpdate.decode(OSCMessage(message.address,[.int(7),.int(-1),.int(0),.int(14),.number(0)])))
    }
    func testSoloPressReleaseDoesNotLeaveASustainedHighCC()throws {
        XCTAssertEqual(try MatrixConsoleCommand(output:3,source:5,field:.solo,value:127).midiWords(channel:5),[0x20B4507F,0x20B45000])
        XCTAssertEqual(try MatrixConsoleCommand(output:3,source:5,field:.mute,value:127).midiWords(channel:5),[0x20B4397F])
        XCTAssertEqual(try MatrixConsoleCommand(output:3,source:5,field:.pan,value:64).midiWords(channel:5),[0x20B42240])
    }

    func testClearSoloIsAnAbsoluteSeparateCCAndNotAToggleLoop()throws {
        XCTAssertEqual(try MatrixClearSolosCommand(output:3).midiWords(channel:5),[0x20B4677F,0x20B46700])
        XCTAssertThrowsError(try MatrixClearSolosCommand(output:0))
        XCTAssertThrowsError(try MatrixClearSolosCommand(output:1).midiWords(channel:17))
    }

}
