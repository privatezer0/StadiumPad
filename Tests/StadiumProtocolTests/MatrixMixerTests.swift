import XCTest
@testable import StadiumProtocol
final class MatrixMixerTests:XCTestCase {
    func property(_ layers:[Value])->Value {.object(["key_":.string("server.mixer.state"),"val_":.object(["lom_":.int(0),"lyrs":.array(layers)])])}
    func layer(_ output:Int,_ db:Double)->Value {.object(["out_":.object(["dst_":.int(Int64(output)),"vol_":.number(-20)]),"home":.object(["mix_":.object(["src_":.int(5),"vol_":.number(db)])])])}
    func testResolvesOutputIdentityNotArrayOrder()throws {
        let s=try MatrixGuitarLevels(value:property([layer(3,-3),layer(1,-1),layer(2,-2)]))
        XCTAssertEqual(s.levels,[-1,-2,-3]);XCTAssertEqual(s.linked,0)
    }
    func testRefusesMissingAmbiguousOrNonfiniteState()throws {
        XCTAssertThrowsError(try MatrixGuitarLevels(value:property([layer(1,0),layer(1,0),layer(3,0)])))
        XCTAssertThrowsError(try MatrixGuitarLevels(value:property([layer(1,0),layer(2,0)])))
        XCTAssertThrowsError(try MatrixGuitarLevels(value:property([layer(1,.nan),layer(2,0),layer(3,0)])))
        XCTAssertThrowsError(try MatrixGuitarLevels(value:.object([:])))
    }
    func testReadOnlyWireAndReplyIdentity()throws {
        XCTAssertEqual(try ReadCommand.matrixMixer.message(id:7),OSCMessage("/PropertyValueGet",[.int(7),.string("server.mixer.state")]))
        XCTAssertThrowsError(try ReadCommand.matrixMixer.decode(OSCMessage("/getPropertyValue",[.int(7),.string("other"),.binary(Data()),.int(0)])))
    }
    func testMIDIEstimateIsBoundedAndActualLabelRemainsDB() {
        for value in stride(from:-120.0,through:12,by:0.1) {XCTAssertTrue((0...127).contains(MatrixGuitarLevels.estimatedMIDI(value)))}
        XCTAssertEqual(MatrixGuitarLevels.estimatedMIDI(.nan),0)
        XCTAssertEqual(MatrixGuitarLevels.label(-120),"−∞")
        XCTAssertEqual(MatrixGuitarLevels.label(-5.3),"-5.3 dB")
    }
    func testLiveHomeLevelOverridesOldBulkValueAndPreservesEverythingElse()throws {
        let before=property([layer(3,0),layer(1,0),layer(2,0)])
        let event=OSCMessage("/syncMixChannelVolume",[.int(44),.int(-1),.int(3),.int(5),.number(-8.0605)])
        let update=try XCTUnwrap(MatrixGuitarUpdate.decode(event))
        let after=try MatrixGuitarLevels(value:update.applying(to:before))
        XCTAssertEqual(after.levels,[0,0,-8.0605]);XCTAssertEqual(after.linked,0)
        XCTAssertNil(MatrixGuitarUpdate.decode(OSCMessage(event.address,[.int(44),.int(-1),.int(3),.int(1),.number(-4)])))
        XCTAssertNil(MatrixGuitarUpdate.decode(OSCMessage(event.address,[.int(44),.int(-1),.int(4),.int(5),.number(-4)])))
        XCTAssertNil(MatrixGuitarUpdate.decode(OSCMessage(event.address,[.int(44),.int(-1),.int(3),.int(5),.number(.nan)])))
    }

    func testMIDIOutputUsesDocumentedCC11AndOneBasedChannels()throws {
        XCTAssertEqual(try MatrixGuitarLevels.midiWord(channel:3,value:99),0x20B20B63)
        XCTAssertEqual(try MatrixGuitarLevels.midiWord(channel:4,value:0),0x20B30B00)
        XCTAssertEqual(try MatrixGuitarLevels.midiWord(channel:5,value:127),0x20B40B7F)
        for channel in [0,17] {XCTAssertThrowsError(try MatrixGuitarLevels.midiWord(channel:channel,value:50))}
        for value in [-1,128] {XCTAssertThrowsError(try MatrixGuitarLevels.midiWord(channel:5,value:value))}
    }

}
