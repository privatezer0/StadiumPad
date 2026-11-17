import XCTest
@testable import StadiumProtocol

final class ProtocolTests:XCTestCase {
    func testEveryFragmentBoundaryAndMultipleFrames()throws {
        let frame=Frame(flags:1,payload:Data([0,1,2,3,4,5,6,7])),next=Frame(payload:Data(repeating:42,count:512))
        let wire=frame.encode()+next.encode()
        for split in 0...wire.count {
            var decoder=FrameDecoder();try decoder.append(Data(wire.prefix(split)))
            var received:[Frame]=[];while let f=try decoder.next(){received.append(f)}
            try decoder.append(Data(wire.dropFirst(split)));while let f=try decoder.next(){received.append(f)}
            XCTAssertEqual(received,[frame,Frame(flags:2,payload:next.payload)])
        }
    }
    func testOversizedFrameAndUnknownFlagsRejected()throws {
        var decoder=FrameDecoder();try decoder.append(Data([2,0,0,0,0,2,0,0,0]));XCTAssertThrowsError(try decoder.next())
        var invalid=FrameDecoder();try invalid.append(Data([0x80,0]));XCTAssertThrowsError(try invalid.next())
    }
    func testGreetingAndObservedPublisherTypes()throws {
        try ZMTP.validateGreeting(ZMTP.greeting)
        var wrong=ZMTP.greeting;wrong[12]=65;XCTAssertThrowsError(try ZMTP.validateGreeting(wrong))
        try ZMTP.validateReady(ZMTP.ready("PUB"),peerTypes:["PUB","ROUTER"])
        XCTAssertThrowsError(try ZMTP.validateReady(ZMTP.ready("PUB")))
        XCTAssertThrowsError(try ZMTP.validateReady(Frame(payload:Data())))
    }
    func testOSCRoundTripAndPadding()throws {
        let original=OSCMessage("/Synthetic",[.int(-42),.number(0.5),.string("abc"),.binary(Data([1,2,3])),.bool(true),.null])
        let encoded=try original.encode();XCTAssertEqual(encoded.count%4,0);XCTAssertEqual(try OSCMessage.decode(encoded),original)
        XCTAssertThrowsError(try OSCMessage.decode(Data(encoded.dropLast())))
        XCTAssertThrowsError(try OSCMessage("/bad\0address").encode())
        XCTAssertThrowsError(try OSCMessage("/float",[.number(.infinity)]).encode())
    }
    func testMessagePackFourCCAndEnvelopedProperty()throws {
        // {fourcc('name'): 'Mock'}; the field name is normalized, not the value.
        let map=Data([0x81,0xce,0x6e,0x61,0x6d,0x65,0xa4,0x4d,0x6f,0x63,0x6b])
        XCTAssertEqual(try MessagePack.decode(map)["name"],.string("Mock"))
        XCTAssertEqual(try MessagePack.decode(Data("lavppgsm".utf8)+map)["name"],.string("Mock"))
        XCTAssertEqual(try MessagePack.decode(Data("slvppgsm".utf8)+map)["name"],.string("Mock"))
        XCTAssertEqual(try MessagePack.decode(Data("_sbepgsm".utf8)+map)["name"],.string("Mock"))
        XCTAssertEqual(try MessagePack.decode(Data([0x94,0xff,0xc3,0xc0,0xca,0x3f,0,0,0])),.array([.int(-1),.bool(true),.null,.number(0.5)]))
    }
    func testTruncationImpossibleLengthAndNesting()throws {
        for data in [Data([0xdf,0xff,0xff,0xff,0xff]),Data([0xd9,8,1]),Data(repeating:0x91,count:70)+Data([0])] {XCTAssertThrowsError(try MessagePack.decode(data))}
    }
    func testReadOnlyCommandSurface()throws {
        let commands:[ReadCommand]=[.product,.editBuffer,.activePreset,.activeSnapshot,.contentRef(4)]
        let addresses=try commands.map{try $0.message(id:7).address}
        XCTAssertEqual(Set(addresses),["/ProductInfoGet","/EditBufferStateGet","/PropertyValueGet","/ActiveSnapshotIndexGet","/GetContentRef"])
        XCTAssertEqual(try ReadCommand.activePreset.message(id:1).values,[.int(1),.string("server.active.preset.id")])
        XCTAssertThrowsError(try ReadCommand.contentRef(Int.max).message(id:1))
        XCTAssertThrowsError(try ReadCommand.editBuffer.decode(OSCMessage("/getEditBufferState",[.int(1)])))
    }
    func testCurrentStateSummaryTracksNewStateWithoutWriting() {
        let block:Value = .object(["enbl":.int(1),"mdls":.array([.object(["id__":.int(9),"parm":.array([.object(["pid_":.int(2),"valu":.number(0.25)])])])])])
        let edit:Value = .object(["sfg_":.object(["flow":.array([.object(["blks":.array([.int(3),block])])])])])
        let snapshot=DeviceSnapshot(product:.null,editBuffer:edit,preset:.object(["name":.string("Synthetic preset")]),activeSnapshot:2)
        XCTAssertEqual(snapshot.presetName,"Synthetic preset");XCTAssertEqual(snapshot.blocks.count,1)
        XCTAssertEqual(snapshot.blocks[0].parameters["2"],"0.25");XCTAssertTrue(snapshot.blocks[0].enabled)
    }
}
