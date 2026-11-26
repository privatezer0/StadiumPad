import XCTest
@testable import StadiumProtocol
final class ParameterIntentBufferTests:XCTestCase {
    private func definition()throws->ParameterDefinition {try JSONDecoder().decode(ParameterDefinition.self,from:Data(#"{"id":1,"key":"gain","name":"Gain","type":"i","minimum":0,"maximum":10,"unit":"","harness":false}"#.utf8))}
    private func context(_ preset:Int=1)->EditContext {EditContext(presetID:preset,snapshot:0,path:0,blockID:3,slot:0,modelID:20,position:1)}
    func testRapidGesturesCoalesceAndUseOnlyConfirmedOwnExpectedValue()throws {
        var buffer=ParameterIntentBuffer();let p=try definition(),c=context()
        try buffer.append(context:c,definition:p,value:.int(3),expected:.int(1));let sent=try XCTUnwrap(buffer.take())
        try buffer.append(context:c,definition:p,value:.int(4),expected:.int(1))
        try buffer.append(context:c,definition:p,value:.int(8),expected:.int(1))
        buffer.confirmed(sent)
        let latest=try XCTUnwrap(buffer.take());XCTAssertEqual(latest.value,.int(8));XCTAssertEqual(latest.expected,.int(3));XCTAssertNil(buffer.take())
    }
    func testUnsentPreviewNeverBecomesTheExpectedNativeValue()throws {
        var buffer=ParameterIntentBuffer();let p=try definition(),c=context()
        try buffer.append(context:c,definition:p,value:.int(3),expected:.int(1))
        try buffer.append(context:c,definition:p,value:.int(7),expected:.int(3))
        let intent=try XCTUnwrap(buffer.take());XCTAssertEqual(intent.value,.int(7));XCTAssertEqual(intent.expected,.int(1))
    }
    func testDifferentPresetNeverInheritsAcknowledgmentAndFailureDropsPendingWork()throws {
        var buffer=ParameterIntentBuffer();let p=try definition()
        try buffer.append(context:context(),definition:p,value:.int(3),expected:.int(1));buffer.confirmed(try XCTUnwrap(buffer.take()))
        try buffer.append(context:context(2),definition:p,value:.int(5),expected:.int(2));XCTAssertEqual(buffer.take()?.expected,.int(2))
        try buffer.append(context:context(),definition:p,value:.int(7),expected:.int(3));buffer.clear();XCTAssertNil(buffer.take())
        try buffer.append(context:context(),definition:p,value:.int(9),expected:.int(6));XCTAssertEqual(buffer.take()?.expected,.int(6))
        XCTAssertThrowsError(try buffer.append(context:context(),definition:p,value:.int(11),expected:.int(6)))
    }
}
