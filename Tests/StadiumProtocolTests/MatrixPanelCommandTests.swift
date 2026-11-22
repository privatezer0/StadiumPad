import XCTest
@testable import StadiumProtocol
final class MatrixPanelCommandTests:XCTestCase {
    func properties(_ global:Int=1,usb:Int=1,quarter:Int=3)->Value {
        .object(["vals":.array([("global.midi.channel",global),("global.midi.over.usb.c",usb),("global.midi.bcchannel",2),("global.midi.matrix.ch.qtr",quarter),("global.midi.matrix.ch.xlr",4),("global.midi.matrix.ch.phones",5)].map{.object(["key_":.string($0.0),"val_":.int(Int64($0.1))])})])
    }
    func testDifferentOutputThenTargetLeavesEveryStartingPanelStateOpen()throws {
        for target in 1...3 {for initial in 1...3 {for initiallyOpen in [false,true] {
            let plan=try MatrixPanelCommand(output:target)
            var selected=initial,open=initiallyOpen
            for step in plan.outputs {
                XCTAssertEqual(try MatrixPanelCommand.midiWord(output:step,channel:6),0x20B50900 | UInt32(step+6))
                if step==selected {open.toggle()}else{selected=step;open=true}
            }
            XCTAssertEqual(selected,target);XCTAssertTrue(open)
            XCTAssertEqual(plan.outputs.count,2);XCTAssertNotEqual(plan.outputs[0],target)
        }}}
    }
    func testCloseEndsHiddenForEveryStartingOutputAndVisibility()throws {
        for target in 1...3 {for initial in 1...3 {for initiallyOpen in [false,true] {
            let command=try MatrixPanelCommand(output:target,closing:true)
            var selected=initial,open=initiallyOpen
            for step in command.outputs {if step==selected {open.toggle()}else{selected=step;open=true}}
            XCTAssertEqual(command.outputs,[target%3+1,target,target]);XCTAssertEqual(selected,target);XCTAssertFalse(open)
        }}}
    }
    func testInvalidOutputsAndChannelsNeverProducePackets()throws {
        for output in [0,4] {XCTAssertThrowsError(try MatrixPanelCommand(output:output));XCTAssertThrowsError(try MatrixPanelCommand.midiWord(output:output,channel:1))}
        for channel in [0,17] {XCTAssertThrowsError(try MatrixPanelCommand.midiWord(output:1,channel:channel))}
    }
    func testAttachedOutputDecoderDoesNotInventVisibilityOrAcceptMalformedEvents() {
        XCTAssertEqual(MatrixAttachedOutput.decode(OSCMessage("/syncMixAttachedOut",[.int(8),.int(-1),.int(2)]))?.output,2)
        XCTAssertNil(MatrixAttachedOutput.decode(OSCMessage("/syncMixAttachedOut",[.int(8),.int(-1)])))
        XCTAssertNil(MatrixAttachedOutput.decode(OSCMessage("/syncMixAttachedOut",[.int(8),.int(-1),.int(4)])))
        XCTAssertNil(MatrixAttachedOutput.decode(OSCMessage("/syncMixAttachedOut",[.int(8),.int(-1),.string("2")])))
    }
    func testReadsConfiguredGlobalChannelAndRejectsDisabledAmbiguousOrCollidingRoutes()throws {
        XCTAssertEqual(try MatrixPanelCommand.globalChannel(properties:properties(6)),6)
        XCTAssertThrowsError(try MatrixPanelCommand.globalChannel(properties:properties(1,usb:0)))
        XCTAssertThrowsError(try MatrixPanelCommand.globalChannel(properties:properties(3)))
        XCTAssertThrowsError(try MatrixPanelCommand.globalChannel(properties:properties(2)))
        XCTAssertThrowsError(try MatrixPanelCommand.globalChannel(properties:.null))
    }
}
