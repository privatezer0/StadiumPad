import Foundation
import Network
import StadiumProtocol

/// Resolve the service on a wired interface, avoiding cached Wi-Fi hostname addresses.
@MainActor final class USBStadiumDiscovery:ObservableObject {
    @Published var devices:[StadiumDevice]=[]
    @Published var message="Search for a USB-connected Stadium"
    private var browser:NWBrowser?
    private var connections:[String:NWConnection]=[:]
    private var epoch=UUID()
    func stop(){epoch=UUID();browser?.cancel();browser=nil;for connection in connections.values {connection.cancel()};connections=[:]}
    func search(){
        stop();devices=[];message="Searching USB…";let token=epoch
        let parameters=NWParameters.tcp;parameters.requiredInterfaceType = .wiredEthernet
        let finder=NWBrowser(for:.bonjour(type:"_stadiumserver._tcp",domain:"local."),using:parameters)
        finder.browseResultsChangedHandler={[weak self] results,_ in Task{@MainActor in
            guard let self,self.epoch==token else{return}
            for result in results {
                guard case .service(let name,_,_,_)=result.endpoint,self.connections[name]==nil else{continue}
                let link=NWParameters.tcp;link.requiredInterfaceType = .wiredEthernet
                if let interface=result.interfaces.first(where:{$0.type == .wiredEthernet}) {link.requiredInterface=interface}
                let connection=NWConnection(to:result.endpoint,using:link);self.connections[name]=connection
                connection.stateUpdateHandler={[weak self,weak connection] state in Task{@MainActor in
                    guard let self,self.epoch==token,let connection else{return}
                    if case .ready=state,let path=connection.currentPath,path.usesInterfaceType(.wiredEthernet),case .hostPort(let host,let port)=path.remoteEndpoint {
                        let device=StadiumDevice(id:name+" · USB",host:String(describing:host),port:port.rawValue,interface:result.interfaces.first(where:{$0.type == .wiredEthernet}) ?? path.availableInterfaces.first(where:{$0.type == .wiredEthernet}))
                        if !self.devices.contains(where:{$0.host==device.host}) {self.devices.append(device)}
                        self.message="USB Stadium found";connection.cancel()
                    }
                }}
                connection.start(queue:.global(qos:.userInitiated))
            }
        }}
        finder.stateUpdateHandler={[weak self] state in Task{@MainActor in if case .failed=state,self?.epoch==token {self?.message="USB discovery unavailable. Check the cable and Local Network permission."}}}
        browser=finder;finder.start(queue:.global(qos:.userInitiated))
    }
}
