import Foundation
/// USB uses Stadium's CDC-NCM Ethernet interface, never a Wi-Fi fallback.
public enum StadiumConnectionRoute:String,CaseIterable,Sendable {
    case automatic="Automatic",wifi="Wi-Fi",usb="USB",bridge="PedalBridge",hybrid="Hybrid"
    public var usesHelper:Bool {self == .bridge || self == .hybrid}
    public var title:String {self == .bridge ? "Full PedalBridge":rawValue}
}
