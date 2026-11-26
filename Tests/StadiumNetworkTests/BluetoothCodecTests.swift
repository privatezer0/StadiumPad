import XCTest
@testable import StadiumNetwork
final class BluetoothCodecTests:XCTestCase {
    func testPythonDeflateFixtureRetainsEveryNativeByte()throws {
        let fixture=Data(base64Encoded:"AAAQAGNgZGJmYWVj5+Dk4ubh5eMXEBQSFhEVE5eQlJKWkZWTV1BUUlZRVVPX0NTS1tHV0zcwNDI2MTUzt7C0sraxtbN3cHRydnF1c/fw9PL28fXzDwgMCg4JDQuPiIyKjomNi09ITEpOSU1Lz8jMys7JzcsvKCwqLiktK6+orKquqa2rb2hsam5pbWvv6Ozq7unt658wcdLkKVOnTZ8xc9bsOXPnzV+wcNHiJUuXLV+xctXqNWvXrd+wcdPmLVu3bd+xc9fuPXv37T9w8NDhI0ePHT9x8tTpM2fPnb9w8dLlK1evXb9x89btO3fv3X/w8NHjJ0+fPX/x8tXrN2/fvf/w8dPnL1+/ff/x89fvP3///WcY9f9o/I+m/9H8P1r+jZb/o/XfaP0/2v4Zbf+Ntn9H2/+j/Z/R/t8I6P8CAA==")!
        XCTAssertEqual(try BluetoothFrameCodec.unpack(4,fixture),Data((0..<16).flatMap{_ in (0...255).map(UInt8.init)}))
    }
    func testLargePayloadRoundTripAndSmallControlBypassesCompression()throws {
        let data=Data(repeating:42,count:16384),packed=BluetoothFrameCodec.pack(2,data)
        XCTAssertEqual(packed.0,4);XCTAssertLessThan(packed.1.count,512)
        XCTAssertEqual(try BluetoothFrameCodec.unpack(packed.0,packed.1),data)
        XCTAssertEqual(BluetoothFrameCodec.pack(2,Data([1,2,3])).0,2)
    }
    func testBombAndTruncationAreRejected()throws {
        XCTAssertThrowsError(try BluetoothFrameCodec.unpack(4,Data([0,1,0,0,1])))
        let packed=BluetoothFrameCodec.pack(2,Data(repeating:42,count:4096)).1
        XCTAssertThrowsError(try BluetoothFrameCodec.unpack(4,Data(packed.dropLast())))
    }
}
