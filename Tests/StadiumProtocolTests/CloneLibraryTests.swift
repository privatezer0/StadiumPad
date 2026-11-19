import XCTest
@testable import StadiumProtocol

final class CloneLibraryTests:XCTestCase {
    func testFolderCreationIsScopedToCloneRoots()throws {
        for invalid in [-1,-2,-3,-4,-14,0] {XCTAssertThrowsError(try CloneLibraryCommand.createFolder(parent:invalid,position:0,name:"Folder").message(id:7))}
        let message=try CloneLibraryCommand.createFolder(parent:-23,position:2,name:"Folder").message(id:7)
        XCTAssertEqual(message.address,"/CreateContent")
        XCTAssertEqual(Array(message.values.prefix(4)),[.int(7),.int(-23),.int(2),.int(1002)])
    }
    func testUnsafeAndEmptyNamesAreRejected() {
        for name in ["", "  ","..","a/b","a\\b","a\nB",String(repeating:"x",count:65)] {XCTAssertThrowsError(try CloneLibraryCommand.name(name))}
    }
    func testRenamePreservesUnknownFields()throws {
        let attrs:Value = .object(["cid_":.int(9),"type":.int(11),"ownr":.int(1),"name":.string("Before"),"unknown":.binary(Data([1,2,3]))])
        let message=try CloneLibraryCommand.rename(id:9,attributes:attrs,name:"After").message(id:2)
        guard case .binary(let data)=message.values[2] else{return XCTFail("Missing attributes")}
        let result=try MessagePack.decode(data)
        XCTAssertEqual(result["name"],.string("After"));XCTAssertEqual(result["unknown"],attrs["unknown"])
    }
    func testPresetAndFactoryRecordsCannotBecomeCloneWrites() {
        for (type,owner) in [(2,1),(11,0),(1003,1)] {
            let attrs:Value = .object(["cid_":.int(9),"type":.int(Int64(type)),"ownr":.int(Int64(owner))])
            XCTAssertThrowsError(try CloneLibraryCommand.rename(id:9,attributes:attrs,name:"Name").message(id:1))
        }
        XCTAssertThrowsError(try CloneLibraryCommand.remove(parent:-23,id:-23).message(id:1))
    }
    func testMoveUsesVerifiedMoveFlagInsteadOfCopy()throws {
        let message=try CloneLibraryCommand.move(id:23,parent:40,position:0).message(id:9)
        XCTAssertEqual(message.address,"/AddContentsToContainer")
        XCTAssertEqual(Array(message.values.suffix(3)),[.int(0),.int(0),.int(1)])
    }
    func testContentPathRequiresSuccessfulNativeStatus()throws {
        let command=ReadCommand.contentPath(12)
        XCTAssertEqual(try command.decode(OSCMessage("/GetContentPath",[.int(1),.string("/data/stadium-family-fw/ir/test.wav"),.int(0)])),.string("/data/stadium-family-fw/ir/test.wav"))
        for values:[Value] in [[.int(1),.string("path")],[.int(1),.string("path"),.int(-1)],[.int(1),.string(""),.int(0)]] {XCTAssertThrowsError(try command.decode(OSCMessage("/GetContentPath",values)))}
    }
    func testReadOnlyCloneAndIRContainersAreAccepted()throws {
        for id in [-10,-11,-13,-14,-22,-23,-24,-25] {XCTAssertEqual(try ReadCommand.container(id).message(id:1).values.last,.int(Int64(id)))}
        XCTAssertThrowsError(try ReadCommand.container(-26).message(id:1))
    }
}
