import XCTest
@testable import StadiumProtocol
final class MatrixPanelCommandTests:XCTestCase {
    func properties(_ global:Int=1,usb:Int=1,quarter:Int=3)->Value {
        .object(["vals":.array([("global.midi.channel",global),("global.midi.over.usb.c",usb),("global.midi.bcchannel",2),("global.midi.matrix.ch.qtr",quarter),("global.midi.matrix.ch.xlr",4),("global.midi.matrix.ch.phones",5)].map{.object(["key_":.string($0.0),"val_":.int(Int64($0.1))])})])
    }
    func testOpeningAlwaysEstablishesHomeThenUsesOnlyTheChosenCC9Command()throws {
        for output in 1...3 {
            let words=try MatrixPanelCommand(output:output).midiWords(channel:6)
            XCTAssertEqual(words,[0x20B50900,0x20B50900 | UInt32(output+6)])
        }
        XCTAssertEqual(try MatrixPanelCommand(output:nil).midiWords(channel:6),[0x20B50900])
    }
    func testInvalidOutputsAndChannelsNeverProducePackets()throws {
        for output in [0,4] {XCTAssertThrowsError(try MatrixPanelCommand(output:output))}
        for channel in [0,17] {XCTAssertThrowsError(try MatrixPanelCommand(output:1).midiWords(channel:channel))}
    }
    func testReadsConfiguredGlobalChannelAndRejectsDisabledAmbiguousOrCollidingRoutes()throws {
        XCTAssertEqual(try MatrixPanelCommand.globalChannel(properties:properties(6)),6)
        XCTAssertThrowsError(try MatrixPanelCommand.globalChannel(properties:properties(1,usb:0)))
        XCTAssertThrowsError(try MatrixPanelCommand.globalChannel(properties:properties(3)))
        XCTAssertThrowsError(try MatrixPanelCommand.globalChannel(properties:properties(2)))
        XCTAssertThrowsError(try MatrixPanelCommand.globalChannel(properties:.null))
    }
}
