import Foundation

/// Factory Focus tone maps are prepared locally, never embedded in public source.
public struct FocusDefinition:Codable,Sendable {
    public let key:String
    public let names:[String]
    public let params:[FocusParameter]
    public func changes(x:Double,y:Double,model:ModelDefinition)throws->[FocusChange] {
        let weights=try Self.weights(x:x,y:y)
        let strongest=weights.dropFirst().reduce(weights[0]){$1.1>$0.1 ? $1:$0}
        guard names.count==5,!params.isEmpty,params.count<=128,Set(params.map(\.id)).count==params.count else{throw ProtocolError.invalid("Invalid Focus map.")}
        return try params.map {p in
            guard p.values.count==5,p.values.allSatisfy(\.isFinite),["interpolate","quantize"].contains(p.behavior),
                  let native=model.parameters.first(where:{!$0.harness && $0.id==p.id && $0.key==p.key && $0.type==p.type}),
                  p.min==native.minimum,p.max==native.maximum else{throw ProtocolError.invalid("Focus metadata does not match this model.")}
            let mixed:Double
            if p.behavior=="quantize" {mixed=p.values[strongest.0]}
            else {mixed=Double(weights.reduce(Float(0)){Float(Double($0)+Double(Float(p.values[$1.0]))*$1.1)})}
            let limited=max(p.min,min(p.max,mixed))
            let value:Value=p.type=="b" ? .bool(limited>=0.5):p.type=="i" ? .int(Int64(floor(limited+0.5))):.number(limited)
            return FocusChange(definition:native,value:try native.validated(value))
        }
    }
    public static func normalized(_ value:Double)throws->Double {
        guard value.isFinite else{throw ProtocolError.invalid("Choose a valid Focus position.")}
        let v=max(-1,min(1,value));return (abs(v)*100).rounded(.toNearestOrAwayFromZero)/100*(v<0 ? -1:1)
    }
    /// Float32 rotations and strongest-point tie order follow the native routine,
    /// as documented by the MIT-licensed helix-stadium-tools reference.
    public static func weights(x:Double,y:Double)throws->[(Int,Double)] {
        let x=try normalized(x),y=try normalized(y),d=Float(1/sqrt(2.0))
        let sx=Float(x)*d,sy=Float(y)*d
        let major:Float,minor:Float,first:Int,second:Int
        if x>=0 && x > -y && x>=y {(major,minor,first,second)=(sx,sy,4,3)}
        else if y>abs(x) {(major,minor,first,second)=(sy,-sx,2,4)}
        else if -x>=abs(y) && x<0 {(major,minor,first,second)=(-sx,-sy,1,2)}
        else {(major,minor,first,second)=(-sy,sx,3,1)}
        let part=minor*d,a=Float(Double(major)*Double(d)+Double(part)),b=Float(Double(major)*Double(d)-Double(part)),centre=(Float(1)-a)-b
        return [(0,Double(max(0,min(1,centre)))),(first,Double(max(0,min(1,a)))),(second,Double(max(0,min(1,b))))]
    }
}
public struct FocusParameter:Codable,Sendable {
    public let id:Int;public let key:String;public let behavior:String;public let type:String
    public let min:Double;public let max:Double;public let values:[Double]
}
public struct FocusChange:Sendable {
    public let definition:ParameterDefinition;public let value:Value
    public init(definition:ParameterDefinition,value:Value) {self.definition=definition;self.value=value}
}
public struct ParameterChange:Sendable {
    public let definition:ParameterDefinition;public let value:Value;public let expected:Value
    public init(definition:ParameterDefinition,value:Value,expected:Value) {self.definition=definition;self.value=value;self.expected=expected}
}
