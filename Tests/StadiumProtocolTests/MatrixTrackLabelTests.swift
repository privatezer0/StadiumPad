import XCTest
@testable import StadiumProtocol
final class MatrixTrackLabelTests:XCTestCase {
    func row(_ id:Int,_ name:String)throws->MatrixStrip {
        try MatrixStrip(.object(["src_":.int(Int64(id)),"name":.string(name),"enbl":.int(1),"vol_":.number(-6),"pan_":.number(0.25),"mute":.bool(false),"solo":.bool(false)]))
    }
    func testGenericStemLabelsDoNotChangeNativeMixerDataOrSourceIdentity()throws {
        for (index,label) in ["Drums","Bass","Guitar","Vocals","Other"].enumerated() {
            let native=try row(index+6,"Track \(index+1)")
            XCTAssertEqual(native.displayName,label)
            XCTAssertEqual(native.name,"Track \(index+1)")
            XCTAssertEqual(native.raw["name"].text,native.name)
            XCTAssertEqual(native.id,index+6);XCTAssertEqual(native.level,-6);XCTAssertEqual(native.pan,0.25)
        }
    }
    func testSpecificNativeLabelsAndOtherStripsArePreserved()throws {
        XCTAssertEqual(try row(6,"Percussion").displayName,"Percussion")
        XCTAssertEqual(try row(6,"Track 7").displayName,"Track 7")
        for id in 11...13 {XCTAssertEqual(try row(id,"Track \(id-5)").displayName,"Track \(id-5)")}
        XCTAssertEqual(try row(5,"Paths").displayName,"Paths")
        XCTAssertEqual(try row(15,"Click").displayName,"Click")
    }
}
