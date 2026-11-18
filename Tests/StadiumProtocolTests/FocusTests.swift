import XCTest
@testable import StadiumProtocol

final class FocusTests:XCTestCase {
    func testNativeArithmeticVectors()throws {
        // Synthetic numeric fixtures from the MIT helix-stadium-tools reference.
        let vectors:[(Int,Int,[Double],Double,Double,Double)] = [
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],0,0,10.0),
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],-1,-1,7.22926984053629e-07),
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],-1,1,20.0),
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],1,-1,29.999998092651367),
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],1,1,39.999996185302734),
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],0.6,0.2,26.0),
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],0.5,0,22.499998092651367),
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],-0.4,0.7,20.0),
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],0.2,-0.9,17.5),
            (0,0,[10.0, 0.0, 20.0, 30.0, 40.0],-0.8,0.1,11.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],0,0,2.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],-1,-1,0.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],-1,1,1.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],1,-1,4.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],1,1,3.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],0.6,0.2,3.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],0.5,0,3.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],-0.4,0.7,2.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],0.2,-0.9,2.0),
            (0,1,[2.0, 0.0, 1.0, 4.0, 3.0],-0.8,0.1,1.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],0,0,0.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],-1,-1,1.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],-1,1,0.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],1,-1,1.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],1,1,1.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],0.6,0.2,1.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],0.5,0,0.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],-0.4,0.7,0.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],0.2,-0.9,1.0),
            (0,2,[0.0, 1.0, 0.0, 1.0, 1.0],-0.8,0.1,0.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],0,0,10.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],-1,-1,0.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],-1,1,20.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],1,-1,30.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],1,1,40.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],0.6,0.2,10.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],0.5,0,10.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],-0.4,0.7,20.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],0.2,-0.9,30.0),
            (1,0,[10.0, 0.0, 20.0, 30.0, 40.0],-0.8,0.1,20.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],0,0,2.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],-1,-1,0.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],-1,1,1.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],1,-1,4.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],1,1,3.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],0.6,0.2,2.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],0.5,0,2.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],-0.4,0.7,1.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],0.2,-0.9,4.0),
            (1,1,[2.0, 0.0, 1.0, 4.0, 3.0],-0.8,0.1,1.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],0,0,0.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],-1,-1,1.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],-1,1,0.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],1,-1,1.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],1,1,1.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],0.6,0.2,0.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],0.5,0,0.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],-0.4,0.7,0.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],0.2,-0.9,1.0),
            (1,2,[0.0, 1.0, 0.0, 1.0, 1.0],-0.8,0.1,0.0)
        ]
        for (behavior,type,values,x,y,expected) in vectors {
            let kind=["f","i","b"][type]
            let model=try JSONDecoder().decode(ModelDefinition.self,from:JSONSerialization.data(withJSONObject:["id":42,"name":"Synthetic","parameters":[["id":1,"key":"Value","name":"Value","type":kind,"minimum":0,"maximum":100,"unit":"","harness":false]]]))
            let map=try JSONDecoder().decode(FocusDefinition.self,from:JSONSerialization.data(withJSONObject:["key":"synthetic","names":["C","BL","TL","BR","TR"],"params":[["id":1,"key":"Value","behavior":behavior==0 ? "interpolate":"quantize","type":kind,"min":0,"max":100,"values":values]]]))
            let result=try XCTUnwrap(map.changes(x:x,y:y,model:model).first?.value)
            if kind=="b" {XCTAssertEqual(result.boolean,expected>=0.5)}else {XCTAssertEqual(try XCTUnwrap(result.numeric),expected,accuracy:0.00001)}
        }
    }
    func testCoordinateBoundsAndInvalidInput()throws {
        XCTAssertEqual(try FocusDefinition.normalized(-3),-1)
        XCTAssertEqual(try FocusDefinition.normalized(0.125),0.13)
        XCTAssertEqual(try FocusDefinition.normalized(-0.125),-0.13)
        XCTAssertThrowsError(try FocusDefinition.weights(x:.nan,y:0))
        for x in stride(from:-1.0,through:1.0,by:0.05) {for y in stride(from:-1.0,through:1.0,by:0.05) {
            let w=try FocusDefinition.weights(x:x,y:y);XCTAssertEqual(w.reduce(0){$0+$1.1},1,accuracy:0.000001)
            XCTAssertTrue(w.allSatisfy{$0.1>=0 && $0.1<=1})
        }}
    }
    func testMismatchedAndIncompleteMetadataRefused()throws {
        let m=try JSONDecoder().decode(ModelDefinition.self,from:Data(#"{"id":42,"name":"Synthetic","parameters":[]}"#.utf8))
        let d=try JSONDecoder().decode(FocusDefinition.self,from:Data(#"{"key":"test","names":["a","b","c","d","e"],"params":[{"id":1,"key":"Value","behavior":"quantize","type":"f","min":0,"max":1,"values":[0,1,0,1,0]}]}"#.utf8))
        XCTAssertThrowsError(try d.changes(x:0,y:0,model:m))
    }
}
