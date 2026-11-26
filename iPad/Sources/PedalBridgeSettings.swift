import Foundation
import Combine
import Security
import StadiumProtocol

@MainActor final class PedalBridgeSettings:ObservableObject {
    @Published private(set) var pair:PedalBridgePair?
    private let service=(Bundle.main.bundleIdentifier ?? "StadiumPad")+".PedalBridge"
    init(){reload()}
    func reload(){
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"pair",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var value:CFTypeRef?
        let status=SecItemCopyMatching(query as CFDictionary,&value)
        if status==errSecSuccess,let data=value as? Data {pair=try? JSONDecoder().decode(PedalBridgePair.self,from:data)}
        else if status==errSecItemNotFound {pair=nil}
        // A locked/background launch must not erase or replace remembered settings.
        // Retry on didBecomeActive when protected Keychain data is available.
    }

    func configure(_ link:String)throws {
        try configure(PedalBridgePair(link:link))
    }
    func configure(_ next:PedalBridgePair)throws {
        let data=try JSONEncoder().encode(next)
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"pair"]
        var status=SecItemUpdate(query as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status==errSecItemNotFound {var add=query;add[kSecValueData as String]=data;add[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly;status=SecItemAdd(add as CFDictionary,nil)}
        guard status==errSecSuccess else{throw ProtocolError.invalid("Could not save PedalBridge pairing securely.")};pair=next
    }
    func forget(){let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"pair"];SecItemDelete(query as CFDictionary);pair=nil}
}
