import XCTest
@testable import StadiumProtocol
final class MatrixAvailabilityTests:XCTestCase {
    func testCurrentTransportRequiresUSBAndConnection() {
        for connected in [false,true] {for local in [false,true] {
            XCTAssertEqual(MatrixAvailability.canOpen(connected:connected,bridgeUSB:nil,tabletUSB:local),connected && local)
            for bridge in [false,true] {
                XCTAssertEqual(MatrixAvailability.canOpen(connected:connected,bridgeUSB:bridge,tabletUSB:local),connected && bridge)
            }
        }}
    }
}
