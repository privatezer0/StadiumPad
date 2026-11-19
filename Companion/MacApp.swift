import SwiftUI
import AppKit
import Foundation
import Network
import SystemConfiguration
import CoreImage.CIFilterBuiltins

@MainActor final class CompanionModel:NSObject,ObservableObject,@preconcurrency NetServiceBrowserDelegate,@preconcurrency NetServiceDelegate {
    @Published var address=UserDefaults.standard.string(forKey:"StadiumAddress") ?? ""
    @Published var devices:[NetService]=[]
    @Published var status="Choose your Stadium, then connect."
    @Published var link:String?
    @Published var working=false
    @Published var trustPrompt=false
    @Published var fingerprint=""
    private var probeAddress=""
    private let browser=NetServiceBrowser()
    private var nativeBrowser:NWBrowser?
    private var browseGeneration=UUID()
    private var pending:[NetService]=[]
    private var process:Process?
    private var buffer=Data()
    override init(){super.init();browser.delegate=self}
    var resources:URL {Bundle.main.resourceURL!}
    var state:URL {FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("StadiumPad Companion",isDirectory:true)}
    func search(){
        browser.stop();nativeBrowser?.cancel();devices=[];pending=[];let generation=UUID();browseGeneration=generation
        let finder=NWBrowser(for:.bonjour(type:"_stadiumserver._tcp",domain:"local."),using:.tcp)
        finder.stateUpdateHandler={state in Task{@MainActor in
            guard self.browseGeneration==generation else{return}
            if case .waiting=state {self.status="Allow StadiumPad Companion to use the local network when macOS asks. If access was denied, enable it in System Settings → Privacy & Security → Local Network."}
        }}
        finder.browseResultsChangedHandler={results,_ in Task{@MainActor in
            guard self.browseGeneration==generation else{return}
            for result in results {if case .service(let name,let type,let domain,_)=result.endpoint,!self.pending.contains(where:{$0.name==name}) {
                let service=NetService(domain:domain,type:type,name:name);self.pending.append(service);service.delegate=self;service.resolve(withTimeout:5)
            }}
        }}
        nativeBrowser=finder;finder.start(queue:.main)
    }
    func netServiceBrowser(_ browser:NetServiceBrowser,didFind service:NetService,moreComing:Bool){pending.append(service);service.delegate=self;service.resolve(withTimeout:5)}
    func netServiceDidResolveAddress(_ service:NetService){if service.hostName != nil,!devices.contains(where:{$0.name==service.name}){devices.append(service)}}
    func choose(_ service:NetService){guard !working,link==nil,let host=service.hostName else{return};address=host}
    private func executable()->URL {resources.appendingPathComponent("Backend/stadiumpad-companion/stadiumpad-companion")}
    func connect(){
        NSApp.activate(ignoringOtherApps:true)
        guard !working,link==nil else{return};let host=address.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !host.isEmpty,host.count<=253,host.range(of:"^[A-Za-z0-9.:-]+$",options:.regularExpression) != nil else{status="Enter a Stadium hostname or address.";return}
        working=true;status="Checking Stadium file connection…";probeAddress=host
        let tool=executable()
        Task {
            do {
                let data=try await Task.detached {let task=Process(),out=Pipe();task.executableURL=tool;task.environment=ProcessInfo.processInfo.environment.filter{!$0.key.hasPrefix("_PYI") && !["PYTHONHOME","PYTHONPATH","DYLD_LIBRARY_PATH","DYLD_FRAMEWORK_PATH","LD_LIBRARY_PATH"].contains($0.key)};task.arguments=["--host",host,"--probe"];task.standardOutput=out;task.standardError=FileHandle.nullDevice;try task.run();let data=out.fileHandleForReading.readDataToEndOfFile();task.waitUntilExit();guard task.terminationStatus==0 else{throw NSError(domain:"Companion",code:Int(task.terminationStatus),userInfo:[NSLocalizedDescriptionKey:(try? JSONSerialization.jsonObject(with:data) as? [String:Any])?["error"] as? String ?? "File helper exited with code \(task.terminationStatus)."] )};return data}.value
                guard let object=try JSONSerialization.jsonObject(with:data) as? [String:Any],let pin=object["fingerprint"] as? String,pin.count==64 else{throw NSError(domain:"Companion",code:2,userInfo:[NSLocalizedDescriptionKey:"File helper returned an invalid identity response."])}
                fingerprint=pin;working=false
                let saved=UserDefaults.standard.string(forKey:"SSHIdentity."+host)
                if saved==pin {start()}else{status=saved==nil ? "Verify this is your Stadium, then trust its file connection.":"The Stadium file identity changed. Verify the device before trusting it.";trustPrompt=true}
            }catch{working=false;status="Could not reach Stadium: \(error.localizedDescription)"}
        }
    }
    func start(){
        guard process==nil,!fingerprint.isEmpty,probeAddress==address.trimmingCharacters(in:.whitespacesAndNewlines) else{return}
        UserDefaults.standard.set(fingerprint,forKey:"SSHIdentity."+probeAddress);UserDefaults.standard.set(probeAddress,forKey:"StadiumAddress")
        let hostname=((SCDynamicStoreCopyLocalHostName(nil) as String?) ?? ProcessInfo.processInfo.hostName.components(separatedBy:".")[0]).lowercased()+".local"
        let task=Process(),output=Pipe();task.executableURL=executable()
        task.arguments=["--host",probeAddress,"--agent",resources.appendingPathComponent("stadium-library").path,"--state",state.path,"--trusted-ssh",fingerprint,"--advertise",hostname,"--listen","45935"]
        task.standardOutput=output;task.standardError=FileHandle.nullDevice;buffer=Data();working=true;status="Connecting through your installed Helix Stadium editor…"
        output.fileHandleForReading.readabilityHandler={handle in let data=handle.availableData;guard !data.isEmpty else{return};Task{@MainActor in self.consume(data)}}
        task.terminationHandler={_ in Task{@MainActor in output.fileHandleForReading.readabilityHandler=nil;self.process=nil;self.link=nil;self.working=false;if !self.status.hasPrefix("Could not") {self.status="Companion stopped. Connect to start it again."}}}
        do{try task.run();process=task}catch{working=false;status="Could not start the file companion."}
    }
    private func consume(_ data:Data){
        buffer.append(data)
        while let end=buffer.firstIndex(of:10) {
            let line=buffer.prefix(upTo:end);buffer.removeSubrange(...end)
            guard let object=try? JSONSerialization.jsonObject(with:line) as? [String:Any] else{continue}
            if let link=object["link"] as? String {self.link=link;working=false;status="Ready. Scan this QR code with the tablet camera, or copy its pairing link. Keep this Mac app open for file transfers."}
            if let error=object["error"] as? String {status=error;working=false}
        }
    }
    func stop(){process?.terminate();link=nil;working=false}
    func copy(){guard let link else{return};NSPasteboard.general.clearContents();NSPasteboard.general.setString(link,forType:.string)}
    var qr:NSImage? {
        guard let link else{return nil};let filter=CIFilter.qrCodeGenerator();filter.message=Data(link.utf8);filter.correctionLevel="M"
        guard let image=filter.outputImage?.transformed(by:CGAffineTransform(scaleX:6,y:6)),let bitmap=CIContext().createCGImage(image,from:image.extent) else{return nil}
        return NSImage(cgImage:bitmap,size:NSSize(width:280,height:280))
    }
}
@main struct StadiumPadCompanionApp:App {
    @StateObject private var model=CompanionModel()
    var body:some Scene {
        WindowGroup("StadiumPad Companion") {
            VStack(alignment:.leading,spacing:18) {
                HStack{Image(systemName:"ipad.and.arrow.forward").font(.system(size:30,weight:.light));VStack(alignment:.leading){Text("StadiumPad Companion").font(.title2.bold());Text("Clone file transfers through your Mac").foregroundStyle(.secondary)};Spacer()}
                HStack{TextField("Stadium hostname or IP address",text:$model.address).textFieldStyle(.roundedBorder).disabled(model.link != nil || model.working);Button("Search",action:model.search).disabled(model.link != nil || model.working)}
                if !model.devices.isEmpty,model.link==nil {HStack{ForEach(model.devices,id:\.name){device in Button(device.name){model.choose(device)}}}}
                HStack{Button(model.link==nil ? "Connect":"Disconnect"){if model.link==nil {model.connect()}else{model.stop()}}.disabled(model.working);if model.working {ProgressView().controlSize(.small)}}
                Text(model.status).font(.callout).fixedSize(horizontal:false,vertical:true)
                if let image=model.qr {
                    HStack{Spacer();Image(nsImage:image).interpolation(.none).resizable().frame(width:280,height:280).padding(12).background(.white);Spacer()}.privacySensitive()
                    HStack{Spacer();Button("Copy Pairing Link",action:model.copy);Spacer()}
                    Text("Only pair your own tablets. The pairing link grants access to clone transfers for the Stadium connected here. Editor authentication stays on this Mac.").font(.caption).foregroundStyle(.secondary)
                }else{
                    Text("Install the official Helix Stadium editor on this Mac. Put the Mac, tablet and Stadium on the same local network. Preset editing and clone browsing remain direct from the tablet; only file transfers use this companion.").foregroundStyle(.secondary).font(.callout)
                }
            }.padding(24).frame(width:560).frame(minHeight:350).onAppear{NSApp.activate(ignoringOtherApps:true);model.search()}
            .alert("Trust this Stadium file connection?",isPresented:$model.trustPrompt){Button("Cancel",role:.cancel){};Button("Trust and Connect"){model.start()}}message:{Text("Stadium: \(model.address)\nSSH SHA-256 identity:\n\(model.fingerprint)\n\nTrust only the Stadium you intend to connect to.")}
        }.windowResizability(.contentSize)
    }
}
