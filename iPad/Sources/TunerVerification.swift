#if DEBUG
import Foundation

/// Explicitly invoked on-device navigation check. Only tuner open/exit commands;
/// does not edit or save presets, change Matrix settings or claim live pitch.
@MainActor func verifyTunerNavigation(monitor:StadiumMonitor,chooseMode:(EditorMode)->Void,chooseSection:(EditorSection)->Void,currentMode:()->EditorMode,currentSection:()->EditorSection)async {
    var checks:[[String:Any]]=[]
    let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    func record(_ name:String,_ passed:Bool) {
        checks.append(["name":name,"passed":passed])
        let result:[String:Any]=["build":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "","checks":checks,"acknowledgments":monitor.tunerAcknowledgments,"error":monitor.errorText ?? "","mode":currentMode().rawValue,"section":currentSection().rawValue]
        try? JSONSerialization.data(withJSONObject:result).write(to:folder.appendingPathComponent("tuner-navigation-verification.json"),options:.atomic)
    }
    func waitFor(_ enabled:Bool,after count:Int)async->Bool {
        for _ in 0..<100 {
            if monitor.tunerAcknowledgments.count>count {return monitor.tunerAcknowledgments.last==enabled}
            if !monitor.connected || monitor.errorText != nil {return false}
            try? await Task.sleep(for:.milliseconds(100))
        }
        return false
    }
    guard monitor.connected,!monitor.busy else{record("Connected and idle",false);return}
    monitor.errorText=nil
    // Simulate an editor operation owning its UI busy flag. The real session FIFO
    // still serializes the tuner command; the monitor must not discard the intent.
    monitor.busy=true
    var count=monitor.tunerAcknowledgments.count
    chooseMode(.tuner)
    let opened=await waitFor(true,after:count)
    monitor.busy=false
    record("Toolbar entry activates tuner even while editor busy",opened)
    guard opened else{return}
    count=monitor.tunerAcknowledgments.count
    chooseSection(.home) // Same callback used by Turn Tuner Off and Home.
    let closed=await waitFor(false,after:count)
    record("Turn Off returns Home/Preset and exits pedal tuner",closed && currentMode() == .preset && currentSection() == .home)
    guard closed else{return}
    for destination in EditorSection.allCases {
        // Starting away from Home also covers entering Tuner from other pages.
        chooseSection(.librarian)
        try? await Task.sleep(for:.milliseconds(100))
        count=monitor.tunerAcknowledgments.count;chooseMode(.tuner)
        let entered=await waitFor(true,after:count)
        record("Tuner entry before \(destination.rawValue)",entered)
        guard entered else{return}
        count=monitor.tunerAcknowledgments.count;chooseSection(destination)
        let exited=await waitFor(false,after:count)
        record("\(destination.rawValue) exits tuner",exited && currentMode() == .preset && currentSection() == destination)
        guard exited else{return}
    }
    chooseSection(.home)
    record("Finished at Home with tuner off",!monitor.tunerRequested && currentMode() == .preset)
}
#endif
