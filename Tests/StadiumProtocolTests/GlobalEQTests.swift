import XCTest
@testable import StadiumProtocol

final class GlobalEQTests:XCTestCase {
    func initial()throws->GlobalEQState {try GlobalEQState(value:.object(Dictionary(uniqueKeysWithValues:EQOutput.allCases.map{($0.key,GlobalEQState.defaults($0))}+[("anyl",.int(0)),("post",.int(0))])))}
    func testIndependentOutputsAndBatchedDrag()throws {
        let before=try initial(),after=try GlobalEQOperation.parameters([GlobalEQChange(.mid,.frequency,.number(1234)),GlobalEQChange(.mid,.gain,.number(-2.25))]).applying(to:before,output:.xlr)
        XCTAssertEqual(after.parameter(.xlr,.mid,.frequency).numeric,1234);XCTAssertEqual(after.parameter(.xlr,.mid,.gain).numeric,-2.25)
        XCTAssertEqual(after.output(.quarter),before.output(.quarter));XCTAssertEqual(after.output(.phones),before.output(.phones));XCTAssertEqual(after.output(.xlr)["drty"],.bool(true))
        XCTAssertThrowsError(try GlobalEQOperation.parameters([]).applying(to:before,output:.quarter))
        XCTAssertThrowsError(try GlobalEQOperation.parameters([GlobalEQChange(.mid,.gain,.number(1)),GlobalEQChange(.mid,.gain,.number(2))]).applying(to:before,output:.quarter))
    }
    func testCopyIncludesBypassAndResetPreservesBypass()throws {
        let original=try initial(),enabled=try GlobalEQOperation.enabled(true).applying(to:original,output:.quarter),edited=try GlobalEQOperation.parameter(.low,.gain,.number(1)).applying(to:enabled,output:.quarter)
        let pasted=try GlobalEQOperation.replace(edited.output(.quarter)).applying(to:edited,output:.phones)
        XCTAssertTrue(pasted.output(.phones)["enab"].boolean==true);XCTAssertEqual(pasted.output(.phones)["out_"],.int(2));XCTAssertEqual(pasted.parameter(.phones,.low,.gain).numeric,1)
        let reset=try GlobalEQOperation.reset.applying(to:pasted,output:.phones)
        XCTAssertTrue(reset.output(.phones)["enab"].boolean==true);XCTAssertEqual(reset.output(.phones)["drty"],.bool(false));XCTAssertEqual(reset.parameter(.phones,.low,.gain).numeric,0)
    }
    func testNativeBoundsAndInvalidBandControls()throws {
        let s=try initial()
        for (p,bad) in [(EQParameter.frequency,19.9),(.gain,24.1),(.gain,-24.1),(.q,0.09),(.q,20.1),(.slope,1.5),(.level,12.1),(.level,-60.1),(.frequency,Double.nan)] {XCTAssertThrowsError(try p.validated(.number(bad)))}
        XCTAssertThrowsError(try EQParameter.enable.validated(.string("on")))
        XCTAssertThrowsError(try GlobalEQOperation.parameter(.lowCut,.gain,.number(1)).applying(to:s,output:.quarter))
        for p in EQParameter.allCases where p != .enable {_ = try p.validated(.number(p.range.lowerBound));_ = try p.validated(.number(p.range.upperBound))}
    }
    func testStrictSchemaRefusesUnknownOrMissingState()throws {
        let s=try initial();var root=s.value.object;root["new_"] = .int(1);XCTAssertThrowsError(try GlobalEQState(value:.object(root)))
        root=s.value.object;var out=root["_qtr"]!.object;out["eqbs"] = .array(Array(out["eqbs"]!.items.dropLast()));root["_qtr"] = .object(out);XCTAssertThrowsError(try GlobalEQState(value:.object(root)))
        root=s.value.object;out=root["_qtr"]!.object;out["out_"] = .int(2);root["_qtr"] = .object(out);XCTAssertThrowsError(try GlobalEQState(value:.object(root)))
    }
    func testOnlyValidatedEQUsesNativeFourCCWireKeys()throws {
        let s=try initial(),m=try GlobalEQOperation.propertyMessage(key:"global.eq.sync",value:s.value,id:11),bytes=try XCTUnwrap(m.values[2].data)
        XCTAssertEqual(m.address,"/PropertyValueSet");XCTAssertTrue(bytes.starts(with:Data("lavppgsm".utf8)));XCTAssertEqual(bytes[9],0xd2) // key_ integer FourCC, not a string
        let decoded=try MessagePack.decode(bytes);XCTAssertEqual(decoded["key_"],.string("global.eq.sync"));XCTAssertEqual(decoded["val_"],s.value)
        XCTAssertThrowsError(try GlobalEQOperation.propertyMessage(key:"globals.eq",value:s.value,id:1))
        XCTAssertThrowsError(try GlobalEQOperation.propertyMessage(key:"dsp.globaleq.xlr",value:s.output(.quarter),id:1))
    }
    func testComparisonIgnoresArrayOrderAndDirtyButChecksAllSettings()throws {
        let s=try initial();var root=s.value.object,o=root["_qtr"]!.object;o["drty"] = .int(1);o["eqbs"] = .array(o["eqbs"]!.items.reversed());root["_qtr"] = .object(o)
        XCTAssertTrue(s.sameSettings(try GlobalEQState(value:.object(root))))
        XCTAssertFalse(s.sameSettings(try GlobalEQOperation.enabled(true).applying(to:s,output:.quarter)))
    }
    func testResponseIsFiniteAndBandEnableControlsCurve()throws {
        let s=try initial(),boost=try GlobalEQOperation.parameter(.mid,.gain,.number(12)).applying(to:s,output:.quarter)
        XCTAssertEqual(EQResponse.gain(output:boost.output(.quarter),frequency:2000,only:.mid),12,accuracy:0.001)
        let off=try GlobalEQOperation.parameter(.mid,.enable,.bool(false)).applying(to:boost,output:.quarter)
        XCTAssertEqual(EQResponse.gain(output:off.output(.quarter),frequency:2000,only:.mid),0)
        for f in [20.0,40,200,1000,5000,20000] {XCTAssertTrue(EQResponse.gain(output:boost.output(.quarter),frequency:f).isFinite)}
    }
    func testLivePropertyUpdatesHaveExactOutputBandAndParameterIdentity()throws {
        let envelope:Value = .object(["key_":.string("dsp.globaleq.phones.mid.gain"),"type":.string("v"),"val_":.object(["parm":.int(3),"valu":.number(-0.125)])])
        let event=OSCMessage("/setPropertyValue",[.int(1),.int(2),.binary(try MessagePack.encode(envelope))])
        let update=try XCTUnwrap(GlobalEQUpdate.decode(event)),initial=try initial(),after=try update.applying(to:initial)
        XCTAssertEqual(after.parameter(.phones,.mid,.gain).numeric,-0.125);XCTAssertEqual(after.output(.quarter),initial.output(.quarter))
        var invalid=envelope.object;invalid["val_"] = .object(["parm":.int(4),"valu":.number(-0.125)])
        XCTAssertNil(GlobalEQUpdate.decode(OSCMessage("/setPropertyValue",[.int(1),.int(2),.binary(try MessagePack.encode(.object(invalid)))])))
    }

    func testPropertyReplyCarriesExactKeyAndTrailingStatus()throws {
        let bytes=try MessagePack.encode(.object(["key_":.string("global.eq.sync"),"type":.string("v"),"val_":initial().value]))
        let reply=OSCMessage("/getPropertyValue",[.int(1),.string("global.eq.sync"),.binary(bytes),.int(0)])
        XCTAssertEqual(try ReadCommand.globalEQBytes.decode(reply),.binary(bytes))
        XCTAssertEqual(try ReadCommand.globalEQ.decode(reply)["key_"],.string("global.eq.sync"))
    }

    func testPendingGestureIdentityIsBoundedAndCoalescible() {
        let a=GlobalEQUpdate.output(.quarter,.parameter(.mid,.gain,.number(1))),b=GlobalEQUpdate.output(.quarter,.parameter(.mid,.gain,.number(2)))
        XCTAssertEqual(a.pendingKey,b.pendingKey)
        XCTAssertNotEqual(a.pendingKey,GlobalEQUpdate.output(.phones,.parameter(.mid,.gain,.number(1))).pendingKey)
        XCTAssertNotEqual(a.pendingKey,GlobalEQUpdate.output(.quarter,.parameter(.mid,.frequency,.number(1000))).pendingKey)
    }

}
