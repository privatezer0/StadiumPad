import XCTest
@testable import StadiumProtocol

final class SelectionMemoryTests:XCTestCase {
    func block(_ id:Int=80,position:Int=6,slot:Int=0,path:Int=1)->SignalBlock {
        SignalBlock(id:"\(path)-\(position)-\(slot)",path:path,position:position,blockID:id,slot:slot,model:42,enabled:true,values:[:],harnessValues:[:])
    }
    func product(_ serial:String)->Value {.object(["host":.object(["snum":.string(serial)])])}
    func testActivePresetAndDeviceHaveSeparateKeys()throws {
        let a=try XCTUnwrap(RememberedBlockSelection.storageKey(product:product("synthetic-a"),endpoint:"host:2001",presetID:10))
        let b=try XCTUnwrap(RememberedBlockSelection.storageKey(product:product("synthetic-a"),endpoint:"host:2001",presetID:11))
        let other=RememberedBlockSelection.storageKey(product:product("synthetic-b"),endpoint:"host:2001",presetID:10)
        XCTAssertNotEqual(a,b);XCTAssertNotEqual(a,other)
        let saved=[a:RememberedBlockSelection(block(80,position:6)),b:RememberedBlockSelection(block(91,position:9))]
        XCTAssertEqual(saved[b]?.resolve(in:[block(91,position:9)])?.position,9)
        XCTAssertNil(saved[b]?.resolve(in:[block(80,position:6)]))
    }
    func testSerialSurvivesAddressChangesAndDoesNotAppearInKey() {
        let first=RememberedBlockSelection.storageKey(product:product("synthetic-a"),endpoint:"first:2001",presetID:10)
        XCTAssertEqual(first,RememberedBlockSelection.storageKey(product:product("synthetic-a"),endpoint:"second:2001",presetID:10))
        XCTAssertFalse(first!.contains("synthetic-a"))
    }
    func testMissingSerialUsesEndpointAndRequiresActivePreset() {
        XCTAssertNotEqual(RememberedBlockSelection.storageKey(product:.null,endpoint:"first:2001",presetID:10),RememberedBlockSelection.storageKey(product:.null,endpoint:"second:2001",presetID:10))
        XCTAssertNil(RememberedBlockSelection.storageKey(product:.null,endpoint:"",presetID:10))
        XCTAssertNil(RememberedBlockSelection.storageKey(product:product("a"),endpoint:"host",presetID:nil))
    }
    func testPersistenceRoundTripAndMovedBlockIdentity()throws {
        let data=try JSONEncoder().encode(RememberedBlockSelection(block()))
        let restored=try JSONDecoder().decode(RememberedBlockSelection.self,from:data)
        XCTAssertEqual(restored.resolve(in:[block(position:9)])?.position,9)
    }
    func testRemovedBlockDoesNotSelectNewOccupantOrAnotherFlow() {
        let memory=RememberedBlockSelection(block())
        XCTAssertNil(memory.resolve(in:[block(91)]))
        XCTAssertNil(memory.resolve(in:[block(path:2)]))
        XCTAssertNil(memory.resolve(in:[block(),block(position:9)]))
    }
    func testModelSlotIsRetained() {
        let memory=RememberedBlockSelection(block(slot:1))
        XCTAssertEqual(memory.resolve(in:[block(),block(slot:1)])?.slot,1)
        XCTAssertNil(memory.resolve(in:[block()]))
    }
    func testCorruptOrInvalidRecordCannotRestore()throws {
        XCTAssertThrowsError(try JSONDecoder().decode(RememberedBlockSelection.self,from:Data("broken".utf8)))
        let record=try JSONDecoder().decode(RememberedBlockSelection.self,from:Data(#"{"path":0,"position":6,"blockID":80,"slot":-1}"#.utf8))
        XCTAssertNil(record.resolve(in:[block()]))
    }
}
