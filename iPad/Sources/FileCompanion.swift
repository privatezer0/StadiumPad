import SwiftUI
import StadiumProtocol
import Foundation
import CryptoKit
import Security
import UIKit

struct CompanionPair:Codable {
    let host:String;let port:Int;let pin:String;let token:String
    init(link:String)throws {
        guard let value=URLComponents(string:link.trimmingCharacters(in:.whitespacesAndNewlines)),value.scheme=="stadiumpad",value.host=="companion" else{throw ProtocolError.invalid("Paste the pairing link from StadiumPad Companion on your Mac.")}
        let items=value.queryItems ?? []
        func field(_ name:String)throws->String {let matches=items.filter{$0.name==name};guard matches.count==1,let text=matches[0].value,!text.isEmpty else{throw ProtocolError.invalid("The pairing link is incomplete.")};return text}
        host=try field("host").lowercased();pin=try field("pin");token=try field("token")
        guard let port=Int(try field("port")),(1...65535).contains(port),host.count<=253,host.range(of:"^[A-Za-z0-9.:-]+$",options:.regularExpression) != nil,pin.range(of:"^[0-9a-f]{64}$",options:.regularExpression) != nil,token.range(of:"^[A-Za-z0-9_-]{40,128}$",options:.regularExpression) != nil else{throw ProtocolError.invalid("The pairing link is invalid.")}
        self.port=port
    }
    func url(_ path:String)throws->URL {var c=URLComponents();c.scheme="https";c.host=host;c.port=port;c.path=path;guard let url=c.url else{throw ProtocolError.invalid("Invalid companion address.")};return url}
}

private final class PinnedCompanionSession:NSObject,URLSessionDelegate,URLSessionTaskDelegate,URLSessionDownloadDelegate {
    let pair:CompanionPair
    var progress:((Double)->Void)?
    private let trustLock=NSLock()
    private var trustMessage:String?
    var trustFailure:String? {trustLock.lock();defer{trustLock.unlock()};return trustMessage}
    private func reject(_ message:String,_ completion:@escaping (URLSession.AuthChallengeDisposition,URLCredential?)->Void){trustLock.lock();trustMessage=message;trustLock.unlock();completion(.cancelAuthenticationChallenge,nil)}
    init(_ pair:CompanionPair){self.pair=pair}
    func urlSession(_ session:URLSession,didReceive challenge:URLAuthenticationChallenge,completionHandler:@escaping (URLSession.AuthChallengeDisposition,URLCredential?)->Void) {
        guard challenge.protectionSpace.authenticationMethod==NSURLAuthenticationMethodServerTrust,challenge.protectionSpace.host.lowercased()==pair.host.lowercased(),let trust=challenge.protectionSpace.serverTrust,let chain=SecTrustCopyCertificateChain(trust) as? [SecCertificate],let cert=chain.first else{reject("The Mac companion did not provide a valid TLS identity.",completionHandler);return}
        let digest=SHA256.hash(data:SecCertificateCopyData(cert) as Data).map{String(format:"%02x",$0)}.joined()
        guard digest==pair.pin else{reject("The Mac companion identity changed. Copy a fresh pairing link from your Mac.",completionHandler);return}
        completionHandler(.useCredential,URLCredential(trust:trust))
    }
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void){completionHandler(nil)}
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didFinishDownloadingTo location:URL){}
    func urlSession(_ session:URLSession,downloadTask:URLSessionDownloadTask,didWriteData bytesWritten:Int64,totalBytesWritten:Int64,totalBytesExpectedToWrite:Int64){if totalBytesExpectedToWrite>0 {progress?(Double(totalBytesWritten)/Double(totalBytesExpectedToWrite))}}
    func urlSession(_ session:URLSession,task:URLSessionTask,didSendBodyData bytesSent:Int64,totalBytesSent:Int64,totalBytesExpectedToSend:Int64){if totalBytesExpectedToSend>0 {progress?(Double(totalBytesSent)/Double(totalBytesExpectedToSend))}}
}

@MainActor final class FileCompanion:ObservableObject {
    @Published var paired=false
    @Published var busy=false
    @Published var status="Pair with your Mac to import or export clone files."
    @Published var progress:Double=0
    private var pair:CompanionPair?
    private let service=(Bundle.main.bundleIdentifier ?? "StadiumPad")+".FileCompanion"
    private let jobKey="stadiumCloneTransferJob"
    var lastJob:String? {UserDefaults.standard.string(forKey:jobKey)}
    init(){
        let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"pair",kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result:CFTypeRef?
        if SecItemCopyMatching(q as CFDictionary,&result)==errSecSuccess,let data=result as? Data,let saved=try? JSONDecoder().decode(CompanionPair.self,from:data){pair=saved;paired=true;status="Mac companion paired"}
    }
    func configure(_ link:String)throws {
        let candidate=try CompanionPair(link:link),data=try JSONEncoder().encode(candidate)
        let q:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"pair"]
        var add=q;add[kSecValueData as String]=data;add[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let result=SecItemAdd(add as CFDictionary,nil)
        if result==errSecDuplicateItem {guard SecItemUpdate(q as CFDictionary,[kSecValueData as String:data] as CFDictionary)==errSecSuccess else{throw ProtocolError.invalid("Could not retain the companion pairing securely.")}}
        else if result != errSecSuccess {throw ProtocolError.invalid("Could not retain the companion pairing securely.")}
        pair=candidate;paired=true;status="Mac companion paired"
    }
    static func deviceID(_ product:Value)->String? {guard let serial=product["host"]["snum"].text?.trimmingCharacters(in:.whitespacesAndNewlines),!serial.isEmpty else{return nil};return SHA256.hash(data:Data(serial.utf8)).map{String(format:"%02x",$0)}.joined()}
    private func request(_ path:String,deviceID:String,data:Data?=nil,folder:Int?=nil)async throws->(Data,HTTPURLResponse) {
        guard let pair else{throw ProtocolError.invalid("Pair with StadiumPad Companion on your Mac first.")}
        let delegate=PinnedCompanionSession(pair)
        delegate.progress={value in Task{@MainActor in self.progress=value}}
        let config=URLSessionConfiguration.ephemeral;config.timeoutIntervalForRequest=90;config.timeoutIntervalForResource=110;config.httpCookieStorage=nil;config.urlCache=nil
        let session=URLSession(configuration:config,delegate:delegate,delegateQueue:nil);defer{session.finishTasksAndInvalidate()}
        var request=URLRequest(url:try pair.url(path));request.setValue("Bearer "+pair.token,forHTTPHeaderField:"Authorization");request.setValue(deviceID,forHTTPHeaderField:"X-Stadium-ID")
        if let folder {request.setValue(String(folder),forHTTPHeaderField:"X-Clone-Folder")}
        if let data {request.httpMethod="POST";request.httpBody=data;request.setValue("application/octet-stream",forHTTPHeaderField:"Content-Type")}
        let body:Data;let response:URLResponse
        do {(body,response)=try await session.data(for:request)}catch {if let failure=delegate.trustFailure {throw ProtocolError.invalid(failure)};throw error}
        guard body.count<=8*1024*1024,let http=response as? HTTPURLResponse else{throw ProtocolError.invalid("Invalid companion response.")}
        guard http.statusCode==200 else {
            let object=(try? JSONSerialization.jsonObject(with:body)) as? [String:Any]
            throw ProtocolError.invalid(object?["error"] as? String ?? object?["message"] as? String ?? "The file operation was not confirmed. Check the library before retrying.")
        }
        return (body,http)
    }
    func check(deviceID:String)async throws {let _=try await request("/v1/status",deviceID:deviceID);status="Mac connected to this Stadium"}
    func importFiles(_ urls:[URL],deviceID:String,folder:Int)async throws {
        guard !busy,!urls.isEmpty,urls.count<=50 else{throw ProtocolError.invalid("Choose between 1 and 50 clone files.")};busy=true;defer{busy=false}
        for (index,url) in urls.enumerated() {
            guard url.pathExtension.lowercased()=="clone" else{throw ProtocolError.invalid("Choose .clone files exported by Helix Stadium.")}
            let access=url.startAccessingSecurityScopedResource();defer{if access {url.stopAccessingSecurityScopedResource()}}
            let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            guard size>24,size<=8*1024*1024 else{throw ProtocolError.invalid("Clone files must be smaller than 8 MB.")}
            let data=try Data(contentsOf:url);guard data.count<=8*1024*1024 else{throw ProtocolError.invalid("The file changed or is too large.")}
            let job=UUID().uuidString.lowercased();UserDefaults.standard.set(job,forKey:jobKey)
            status="Importing \(index+1) of \(urls.count) · \(url.lastPathComponent)";progress=0
            do {
                let (body,_)=try await request("/v1/import/"+job,deviceID:deviceID,data:data,folder:folder)
                let result=try JSONSerialization.jsonObject(with:body) as? [String:Any]
                guard result?["confirmed"] as? Bool==true else{throw ProtocolError.invalid("Import was not confirmed. Check Last Transfer before retrying.")}
            } catch {status="Import was not confirmed. Use Check Last Transfer before trying again.";throw error}
        }
        status="\(urls.count) clone file\(urls.count==1 ? "":"s") imported and verified";progress=1
    }
    func checkLast(deviceID:String)async throws {
        guard let job=lastJob else{return};let (body,_)=try await request("/v1/jobs/"+job,deviceID:deviceID)
        let result=try JSONSerialization.jsonObject(with:body) as? [String:Any];status=result?["message"] as? String ?? "Transfer status unavailable"
    }
    var latestBackup:URL? {
        guard let name=UserDefaults.standard.string(forKey:"stadiumLibraryBackup"),name==URL(fileURLWithPath:name).lastPathComponent else{return nil}
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Library Backups").appendingPathComponent(name)
        return FileManager.default.fileExists(atPath:url.path) ? url:nil
    }
    func downloadLibrary(deviceID:String)async throws->URL {
        guard !busy,let pair else{throw ProtocolError.invalid("Pair with your Mac and wait for the current transfer to finish.")};busy=true;defer{busy=false};progress=0;status="Copying your User Clones and IRs to this tablet…"
        let delegate=PinnedCompanionSession(pair);delegate.progress={value in Task{@MainActor in self.progress=value}}
        let config=URLSessionConfiguration.ephemeral;config.timeoutIntervalForRequest=180;config.timeoutIntervalForResource=240;config.urlCache=nil;config.httpCookieStorage=nil
        let session=URLSession(configuration:config,delegate:delegate,delegateQueue:nil);defer{session.finishTasksAndInvalidate()}
        var request=URLRequest(url:try pair.url("/v1/backup/library"));request.setValue("Bearer "+pair.token,forHTTPHeaderField:"Authorization");request.setValue(deviceID,forHTTPHeaderField:"X-Stadium-ID")
        let temporary:URL;let response:URLResponse
        do {(temporary,response)=try await session.download(for:request)}catch {if let failure=delegate.trustFailure {throw ProtocolError.invalid(failure)};throw error}
        defer{try? FileManager.default.removeItem(at:temporary)}
        guard let http=response as? HTTPURLResponse else{throw ProtocolError.invalid("Invalid companion response.")}
        guard http.statusCode==200,http.mimeType=="application/zip" else {
            let data=try Data(contentsOf:temporary)
            let message=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any]
            throw ProtocolError.invalid(message?["error"] as? String ?? "Library backup was not confirmed. The Stadium originals are unchanged.")
        }
        let length=try temporary.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard length>0,length<=256*1024*1024 else{throw ProtocolError.invalid("The backup is empty or exceeds this version's 256 MB limit.")}
        let handle=try FileHandle(forReadingFrom:temporary);defer{try? handle.close()};var digest=SHA256()
        while let bytes=try handle.read(upToCount:65536),!bytes.isEmpty {digest.update(data:bytes)}
        let hash=digest.finalize().map{String(format:"%02x",$0)}.joined()
        guard hash==http.value(forHTTPHeaderField:"X-Content-SHA256") else{throw ProtocolError.invalid("The library backup checksum did not match. No partial backup was kept.")}
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Library Backups",isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let date=ISO8601DateFormatter().string(from:Date()).replacingOccurrences(of:":",with:"-")
        let name="StadiumPad Library "+date+" "+UUID().uuidString.prefix(8)+".zip",destination=folder.appendingPathComponent(name)
        try FileManager.default.moveItem(at:temporary,to:destination);UserDefaults.standard.set(name,forKey:"stadiumLibraryBackup")
        status="Saved \(http.value(forHTTPHeaderField:"X-Clone-Count") ?? "0") clones and \(http.value(forHTTPHeaderField:"X-IR-Count") ?? "0") IRs on this tablet";progress=1;return destination
    }
    func manage(_ operation:String,parent:Int,entry:LibraryEntry?,name:String?,deviceID:String)async throws {
        guard !busy else{throw ProtocolError.invalid("Wait for the current file transfer to finish.")};busy=true;defer{busy=false};progress=0
        let job=UUID().uuidString.lowercased();UserDefaults.standard.set(job,forKey:jobKey)
        var value:[String:Any]=["op":operation,"parent":parent]
        if let entry {value["id"]=entry.id;value["expectedName"]=entry.name;if let uuid=entry.cloneUUID {value["uuid"]=uuid}}
        if let name {value["name"]=name}
        status="Updating clone library…"
        do {let (body,_)=try await request("/v1/manage/"+job,deviceID:deviceID,data:JSONSerialization.data(withJSONObject:value));let result=try JSONSerialization.jsonObject(with:body) as? [String:Any];guard result?["confirmed"] as? Bool==true else{throw ProtocolError.invalid("The library change was not confirmed. Check Last Transfer before retrying.")};status="Clone library change verified";progress=1}
        catch {status="Library change not confirmed. Check Last Transfer before retrying.";throw error}
    }
    func exportClone(_ entry:LibraryEntry,deviceID:String)async throws->URL {
        guard !busy,entry.type==11,let uuid=entry.cloneUUID,UUID(uuidString:uuid) != nil else{throw ProtocolError.invalid("Select a clone file to export.")};busy=true;defer{busy=false};status="Exporting \(entry.name)…"
        let (data,response)=try await request("/v1/export/\(entry.id)/\(uuid)",deviceID:deviceID)
        let digest=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
        guard response.value(forHTTPHeaderField:"X-Content-SHA256")==digest else{throw ProtocolError.invalid("The exported file checksum did not match.")}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let name=entry.name.components(separatedBy:CharacterSet.alphanumerics.union(.init(charactersIn:" -_().")).inverted).joined(separator:"_")
        let url=folder.appendingPathComponent(String(name.prefix(100))+".clone");try data.write(to:url,options:.atomic);status="Clone exported and verified";return url
    }
}
struct CloneShareFile:Identifiable {let id=UUID();let url:URL}
struct CloneShareView:UIViewControllerRepresentable {
    let url:URL
    func makeUIViewController(context:Context)->UIActivityViewController {UIActivityViewController(activityItems:[url],applicationActivities:nil)}
    func updateUIViewController(_ controller:UIActivityViewController,context:Context){}
}
