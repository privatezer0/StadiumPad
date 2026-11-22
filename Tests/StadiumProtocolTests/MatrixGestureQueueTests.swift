import XCTest
@testable import StadiumProtocol
final class MatrixGestureQueueTests:XCTestCase {
    func pan(_ value:Int,output:Int=3)throws->MatrixConsoleCommand {try MatrixConsoleCommand(output:output,source:5,field:.pan,value:value)}
    func testOlderReceiptCannotRewindTheNewestThumbPosition()throws {
        var queue=MatrixGestureQueue();let first=try pan(30),middle=try pan(40),last=try pan(50)
        queue.enqueue(first);let ticket=try XCTUnwrap(queue.takeNext())
        queue.enqueue(middle);queue.enqueue(last)
        XCTAssertEqual(queue.positions[first.key],50)
        queue.confirmed(ticket)
        XCTAssertEqual(queue.positions[first.key],50)
        let next=try XCTUnwrap(queue.takeNext());XCTAssertEqual(next.command,last)
        queue.confirmed(next);XCTAssertTrue(queue.isEmpty);XCTAssertEqual(queue.positions[first.key],50)
    }
    func testDifferentOutputsKeepFIFOOrderAndIndependentThumbs()throws {
        var queue=MatrixGestureQueue();let a=try pan(20,output:1),b=try pan(60,output:2),c=try pan(40,output:1)
        queue.enqueue(a);let ticket=try XCTUnwrap(queue.takeNext());queue.enqueue(b);queue.enqueue(c)
        queue.confirmed(ticket);XCTAssertEqual(queue.positions[a.key],40);XCTAssertEqual(queue.positions[b.key],60)
        let next=try XCTUnwrap(queue.takeNext());XCTAssertEqual(next.command,b)
        queue.confirmed(next);XCTAssertEqual(queue.takeNext()?.command,c)
    }
    func testToggleCommandsAreNeverMergedOrOptimisticallyShownAsConfirmed()throws {
        var queue=MatrixGestureQueue();let command=try MatrixConsoleCommand(output:3,source:5,field:.solo,value:127)
        queue.enqueue(command);queue.enqueue(command);XCTAssertTrue(queue.positions.isEmpty)
        let first=try XCTUnwrap(queue.takeNext());queue.confirmed(first)
        XCTAssertEqual(queue.takeNext()?.command,command)
    }
    func testExternalUpdatesDoNotErasePendingInputButInvalidateConfirmedPosition()throws {
        var queue=MatrixGestureQueue();let command=try pan(80);queue.enqueue(command)
        let ticket=try XCTUnwrap(queue.takeNext());queue.externalChange(command.key);XCTAssertEqual(queue.positions[command.key],80)
        queue.confirmed(ticket);queue.externalChange(command.key);XCTAssertNil(queue.positions[command.key])
    }
    func testResetRejectsLateAcknowledgmentEvenForAnIdenticalNewCommand()throws {
        var queue=MatrixGestureQueue();let command=try pan(80);queue.enqueue(command)
        let old=try XCTUnwrap(queue.takeNext());queue.reset();queue.enqueue(command);let fresh=try XCTUnwrap(queue.takeNext())
        queue.confirmed(old);XCTAssertNil(queue.takeNext())
        queue.confirmed(fresh);XCTAssertEqual(queue.positions[command.key],80)
    }
    func testCancelDropsQueuedGesturesWithoutAbandoningTheInFlightReceipt()throws {
        var queue=MatrixGestureQueue();let first=try pan(30),last=try pan(70)
        queue.enqueue(first);let ticket=try XCTUnwrap(queue.takeNext());queue.enqueue(last);queue.cancelPending()
        XCTAssertTrue(queue.isEmpty);XCTAssertNil(queue.positions[first.key])
        queue.confirmed(ticket);XCTAssertEqual(queue.positions[first.key],30)
    }
    func testPanConversionMatchesNativeObservedValuesAndRoundTripsAllPositions()throws {
        XCTAssertEqual(try MatrixPan.value(forMIDI:62),-0.0317460335791111,accuracy:0.000001)
        XCTAssertEqual(try MatrixPan.value(forMIDI:70),0.095238097012043,accuracy:0.000001)
        XCTAssertEqual(try MatrixPan.value(forMIDI:64),0)
        XCTAssertEqual(try MatrixPan.value(forMIDI:0),-1)
        for value in 1...127 {XCTAssertEqual(try MatrixPan.midi(forValue:MatrixPan.value(forMIDI:value)),value)}
        XCTAssertThrowsError(try MatrixPan.midi(forValue:.nan))
        XCTAssertThrowsError(try MatrixPan.value(forMIDI:128))
    }
}
