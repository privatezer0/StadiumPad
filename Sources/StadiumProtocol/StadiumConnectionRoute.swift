import Foundation
/// USB uses Stadium's CDC-NCM Ethernet interface, never a Wi-Fi fallback.
public enum StadiumConnectionRoute:String,CaseIterable,Sendable {
    case automatic="Automatic",wifi="Wi-Fi",usb="USB"
}
