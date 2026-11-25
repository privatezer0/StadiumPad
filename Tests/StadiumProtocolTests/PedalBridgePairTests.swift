import XCTest
@testable import StadiumProtocol
final class PedalBridgePairTests:XCTestCase {
 let base="pedalbridge://pair?host=bridge.example&port=8765&pin="+String(repeating:"a",count:64)+"&token="+String(repeating:"b",count:43)
 func testPairingAndRedaction()throws {let p=try PedalBridgePair(link:base);XCTAssertEqual(p.host,"bridge.example");XCTAssertEqual(p.port,8765);XCTAssertFalse(p.description.contains(p.token));XCTAssertEqual(try JSONDecoder().decode(PedalBridgePair.self,from:JSONEncoder().encode(p)),p)}
 func testRejectsDuplicateFieldsAndMalformedPairs(){for link in [base+"&token=extra",base.replacingOccurrences(of:"8765",with:"0"),base.replacingOccurrences(of:"pedalbridge:",with:"http:"),base.replacingOccurrences(of:"bridge.example",with:"evil.example/path"),base.replacingOccurrences(of:String(repeating:"a",count:64),with:"not-a-fingerprint")] {XCTAssertThrowsError(try PedalBridgePair(link:link))}}
 func testBridgeIsSeparateFromDirectRoutes(){XCTAssertTrue(StadiumConnectionRoute.allCases.contains(.bridge));XCTAssertNotEqual(StadiumConnectionRoute.bridge,.usb)}
}
