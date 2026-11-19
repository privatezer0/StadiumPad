import Foundation

/// Calculated editor response, not an audio measurement or substitute for Stadium DSP.
public enum EQResponse {
    public static func gain(output:Value,frequency:Double,only:EQBand?=nil)->Double {
        guard frequency.isFinite,frequency>0 else{return 0}
        var result=only==nil ? output["olvl"]["valu"].numeric ?? 0:0
        for band in EQBand.allCases where only==nil || only==band {
            func p(_ parameter:EQParameter)->Value {GlobalEQState.parameter(in:output,band:band,parameter:parameter)}
            guard p(.enable).boolean==true else{continue}
            let center=p(.frequency).numeric ?? 1000,gain=p(.gain).numeric ?? 0,q=p(.q).numeric ?? 0.707
            if band == .lowCut || band == .highCut {
                let order=Double((p(.slope).integer ?? 1)+1),ratio=band == .lowCut ? center/frequency:frequency/center
                // Butterworth cut magnitude, with the same displayed 6...24 dB/oct slopes.
                result += -10*log10(1+pow(ratio,2*order));continue
            }
            let rate=48000.0,w=2*Double.pi*min(center,20000)/rate,c=cos(w),sn=sin(w),a=pow(10,gain/40)
            var b:[Double],den:[Double]
            if band == .lowShelf || band == .highShelf {
                let alpha=sn/sqrt(2),t=2*sqrt(a)*alpha
                if band == .lowShelf {b=[a*((a+1)-(a-1)*c+t),2*a*((a-1)-(a+1)*c),a*((a+1)-(a-1)*c-t)];den=[(a+1)+(a-1)*c+t,-2*((a-1)+(a+1)*c),(a+1)+(a-1)*c-t]}
                else {b=[a*((a+1)+(a-1)*c+t),-2*a*((a-1)+(a+1)*c),a*((a+1)+(a-1)*c-t)];den=[(a+1)-(a-1)*c+t,2*((a-1)-(a+1)*c),(a+1)-(a-1)*c-t]}
            } else {let alpha=sn/(2*max(0.1,q));b=[1+alpha*a,-2*c,1-alpha*a];den=[1+alpha/a,-2*c,1-alpha/a]}
            let f=2*Double.pi*min(frequency,20000)/rate
            func magnitude(_ coefficients:[Double])->Double {let real=coefficients[0]+coefficients[1]*cos(f)+coefficients[2]*cos(2*f),imag = -coefficients[1]*sin(f)-coefficients[2]*sin(2*f);return real*real+imag*imag}
            result += 10*log10(max(1e-20,magnitude(b))/max(1e-20,magnitude(den)))
        }
        return min(120,max(-120,result.isFinite ? result:0))
    }
}
