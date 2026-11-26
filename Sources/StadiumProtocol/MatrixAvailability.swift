/// The current editor transport must have physical USB MIDI access before opening Matrix.
public enum MatrixAvailability {
    public static let usbRequiredMessage = "Stadium must be connected via USB to either PedalBridge or your tablet to use Matrix Mixer."
    public static func canOpen(connected:Bool,bridgeUSB:Bool?,tabletUSB:Bool)->Bool {
        connected && (bridgeUSB ?? tabletUSB)
    }
}
