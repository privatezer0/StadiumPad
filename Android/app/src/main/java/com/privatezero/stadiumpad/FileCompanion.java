package com.privatezero.stadiumpad;

import android.content.*;
import android.net.Uri;
import android.security.keystore.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.security.cert.*;
import java.util.*;
import java.util.concurrent.*;
import javax.crypto.*;
import javax.crypto.spec.GCMParameterSpec;
import javax.net.ssl.*;
import org.json.*;
import static com.privatezero.stadiumpad.Data.*;
import static com.privatezero.stadiumpad.Models.*;

/** TLS-pinned, paired file transfers. Editor credentials never leave the Mac. */
final class FileCompanion {
 final MainActivity activity;
 final SharedPreferences preferences;
 final ExecutorService worker=Executors.newSingleThreadExecutor();
 volatile boolean busy=false;
 String status="Pair with your Mac to import or export clone files.";
 volatile double progress=0;
 private Pair pair;
 static final String KEY="StadiumPad.FileCompanion.Pair";
 static final class Pair {
  final String host,pin,token;final int port;
  Pair(String link)throws Exception{
   Uri value=Uri.parse(link.trim());if(!"stadiumpad".equals(value.getScheme())||!"companion".equals(value.getHost()))throw new Exception("Paste the pairing link from StadiumPad Companion.");
   for(String name:new String[]{"host","port","pin","token"})if(value.getQueryParameters(name).size()!=1)throw new Exception("The pairing link is incomplete.");
   host=value.getQueryParameter("host")==null?null:value.getQueryParameter("host").toLowerCase(Locale.ROOT);pin=value.getQueryParameter("pin");token=value.getQueryParameter("token");port=Integer.parseInt(value.getQueryParameter("port"));
   if(host==null||host.length()>253||!host.matches("[A-Za-z0-9.:-]+")||port<1||port>65535||pin==null||!pin.matches("[0-9a-f]{64}")||token==null||!token.matches("[A-Za-z0-9_-]{40,128}"))throw new Exception("The pairing link is invalid.");
  }
 }
 FileCompanion(MainActivity owner){activity=owner;preferences=owner.getSharedPreferences("Companion",0);try{String saved=preferences.getString("pair","");if(!saved.isEmpty()){pair=new Pair(decrypt(saved));status="Mac companion paired";}}catch(Exception e){status="Pair with your Mac again to enable file transfers.";}}
 boolean paired(){return pair!=null;}
 static String deviceID(Monitor monitor){if(!monitor.connected||monitor.state==null)return null;String serial=s(get(monitor.state.product,"host","snum")).trim();if(serial.isEmpty())return null;try{return hash(serial.getBytes(StandardCharsets.UTF_8));}catch(Exception e){return null;}}
 private SecretKey key()throws Exception {KeyStore store=KeyStore.getInstance("AndroidKeyStore");store.load(null);if(store.containsAlias(KEY))return (SecretKey)store.getKey(KEY,null);KeyGenerator generator=KeyGenerator.getInstance("AES","AndroidKeyStore");generator.init(new KeyGenParameterSpec.Builder(KEY,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());return generator.generateKey();}
 private String encrypt(String value)throws Exception{Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,key());byte[] iv=c.getIV(),body=c.doFinal(value.getBytes(StandardCharsets.UTF_8));byte[] result=new byte[iv.length+body.length];System.arraycopy(iv,0,result,0,iv.length);System.arraycopy(body,0,result,iv.length,body.length);return Base64.getEncoder().encodeToString(result);}
 private String decrypt(String value)throws Exception{byte[] data=Base64.getDecoder().decode(value);if(data.length<29)throw new Exception();Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,Arrays.copyOf(data,12)));return new String(c.doFinal(Arrays.copyOfRange(data,12,data.length)),StandardCharsets.UTF_8);}
 void configure(String link)throws Exception{Pair candidate=new Pair(link);preferences.edit().putString("pair",encrypt(link.trim())).apply();pair=candidate;status="Mac companion paired";}
 void update(String value){activity.runOnUiThread(()->{status=value;activity.editor.invalidate();});}
 byte[] request(String path,String device,byte[] upload)throws Exception{return request(path,device,upload,null);}
 private HttpsURLConnection open(String path,String device)throws Exception {
  Pair p=pair;if(p==null)throw new Exception("Pair with StadiumPad Companion on your Mac first.");
  URL url=new URI("https",null,p.host,p.port,path,null,null).toURL();HttpsURLConnection connection=(HttpsURLConnection)url.openConnection();
  X509TrustManager trust=new X509TrustManager(){public X509Certificate[] getAcceptedIssuers(){return new X509Certificate[0];}public void checkClientTrusted(X509Certificate[] c,String a)throws CertificateException{throw new CertificateException();}public void checkServerTrusted(X509Certificate[] chain,String auth)throws CertificateException{try{if(chain.length==0||!hash(chain[0].getEncoded()).equals(p.pin))throw new CertificateException("Mac companion identity changed. Pair again from the Mac.");}catch(CertificateException e){throw e;}catch(Exception e){throw new CertificateException("Invalid companion identity.");}}};
  SSLContext ssl=SSLContext.getInstance("TLS");ssl.init(null,new TrustManager[]{trust},null);connection.setSSLSocketFactory(ssl.getSocketFactory());connection.setHostnameVerifier((host,session)->host.equals(p.host));connection.setInstanceFollowRedirects(false);connection.setConnectTimeout(8000);connection.setReadTimeout(100000);connection.setRequestProperty("Authorization","Bearer "+p.token);connection.setRequestProperty("X-Stadium-ID",device);connection.setUseCaches(false);
  return connection;
 }
 byte[] request(String path,String device,byte[] upload,Integer folder)throws Exception{
  HttpsURLConnection connection=open(path,device);if(folder!=null)connection.setRequestProperty("X-Clone-Folder",String.valueOf(folder));
  try{
   if(upload!=null){connection.setRequestMethod("POST");connection.setDoOutput(true);connection.setFixedLengthStreamingMode(upload.length);connection.setRequestProperty("Content-Type","application/octet-stream");try(OutputStream out=connection.getOutputStream()){for(int i=0;i<upload.length;i+=32768){int count=Math.min(32768,upload.length-i);out.write(upload,i,count);progress=(double)(i+count)/upload.length;activity.runOnUiThread(()->activity.editor.invalidate());}}}
   int code=connection.getResponseCode();byte[] result=readBounded(code==200?connection.getInputStream():connection.getErrorStream());
   if(code!=200){String message="The file operation was not confirmed. Check Last Transfer before retrying.";try{JSONObject object=new JSONObject(new String(result,StandardCharsets.UTF_8));message=object.optString("error",object.optString("message",message));}catch(Exception ignored){}throw new Exception(message);}
   if(path.startsWith("/v1/export/")&&!hash(result).equals(connection.getHeaderField("X-Content-SHA256")))throw new Exception("Exported file checksum did not match.");
   return result;
  }finally{connection.disconnect();}
 }
 static byte[] readBounded(InputStream input)throws Exception{if(input==null)return new byte[0];try(InputStream in=input;ByteArrayOutputStream out=new ByteArrayOutputStream()){byte[] buffer=new byte[32768];int count;while((count=in.read(buffer))!=-1){if(out.size()+count>8*1024*1024)throw new Exception("The file or response exceeds 8 MB.");out.write(buffer,0,count);}return out.toByteArray();}}
 void check(String device){if(device==null)return;worker.execute(()->{try{request("/v1/status",device,null);update("Mac connected to this Stadium");}catch(Exception e){update(e.getMessage());activity.runOnUiThread(()->activity.problem(e.getMessage()));}});}
 void checkLast(String device){String job=preferences.getString("lastJob","");if(job.isEmpty()||device==null)return;worker.execute(()->{try{JSONObject object=new JSONObject(new String(request("/v1/jobs/"+job,device,null),StandardCharsets.UTF_8));update(object.optString("message","Transfer status unavailable"));activity.monitor.refreshClones();}catch(Exception e){update(e.getMessage());}});}
 void importFiles(List<Uri> files,String device,int generation,int folder){
  if(busy||device==null)return;if(files.isEmpty()||files.size()>50){activity.problem("Choose between 1 and 50 clone files.");return;}busy=true;
  worker.execute(()->{try{for(int index=0;index<files.size();index++){
   if(activity.monitor.generation!=generation)throw new Exception("The connected Stadium changed. No further files were sent.");
   byte[] data=readBounded(activity.getContentResolver().openInputStream(files.get(index)));
   if(data.length<=24)throw new Exception("Choose a .clone file exported by Helix Stadium.");
   String job=UUID.randomUUID().toString();preferences.edit().putString("lastJob",job).commit();update("Importing "+(index+1)+" of "+files.size()+"…");progress=0;
   JSONObject result=new JSONObject(new String(request("/v1/import/"+job,device,data,folder),StandardCharsets.UTF_8));if(!result.optBoolean("confirmed"))throw new Exception("Import was not confirmed. Check Last Transfer before retrying.");
  }update(files.size()+" clone files imported and verified");activity.monitor.refreshClones();activity.monitor.readLibraryFolder(folder);
  }catch(Exception e){update("Import was not confirmed. Use Check Last Transfer before trying again.");activity.runOnUiThread(()->activity.problem(e.getMessage()));}
  finally{busy=false;activity.runOnUiThread(()->activity.editor.invalidate());}});
 }
 File latestBackup(){String name=preferences.getString("lastBackup","");if(name.isEmpty()||!new File(name).getName().equals(name))return null;File file=new File(new File(activity.getFilesDir(),"Library Backups"),name);return file.isFile()?file:null;}
 void downloadLibrary(String device,int generation){if(busy||device==null)return;if(!paired()){activity.pairCompanion(null);return;}busy=true;progress=0;update("Copying your User Clones and IRs to this tablet…");worker.execute(()->{File partial=null;HttpsURLConnection connection=null;try{
  connection=open("/v1/backup/library",device);connection.setReadTimeout(240000);int code=connection.getResponseCode();if(code!=200){byte[] data=readBounded(connection.getErrorStream());throw new Exception(new JSONObject(new String(data,StandardCharsets.UTF_8)).optString("error","Library backup was not confirmed."));}
  long expected=connection.getContentLengthLong();if(expected<1||expected>256L*1024*1024)throw new Exception("Backup is empty or exceeds this version's 256 MB limit.");String checksum=connection.getHeaderField("X-Content-SHA256");String clones=connection.getHeaderField("X-Clone-Count"),irs=connection.getHeaderField("X-IR-Count");
  File folder=new File(activity.getFilesDir(),"Library Backups");if(!folder.isDirectory()&&!folder.mkdirs())throw new IOException("Could not create the tablet backup folder.");String name="StadiumPad Library "+new java.text.SimpleDateFormat("yyyy-MM-dd HH-mm-ss",Locale.US).format(new Date())+" "+UUID.randomUUID().toString().substring(0,8)+".zip";File destination=new File(folder,name);partial=new File(folder,name+".part");MessageDigest digest=MessageDigest.getInstance("SHA-256");long total=0;
  try(InputStream in=connection.getInputStream();OutputStream out=new FileOutputStream(partial)){byte[] buffer=new byte[65536];int count;while((count=in.read(buffer))!=-1){total+=count;if(total>256L*1024*1024)throw new IOException("Backup exceeds the supported size.");digest.update(buffer,0,count);out.write(buffer,0,count);progress=(double)total/expected;activity.runOnUiThread(()->activity.editor.invalidate());}}
  StringBuilder actual=new StringBuilder();for(byte value:digest.digest())actual.append(String.format(Locale.ROOT,"%02x",value&255));if(total!=expected||!actual.toString().equals(checksum))throw new IOException("Library backup checksum did not match. No partial backup was kept.");if(destination.exists()||!partial.renameTo(destination))throw new IOException("Could not retain the tablet backup.");partial=null;preferences.edit().putString("lastBackup",name).commit();update("Saved "+clones+" clones and "+irs+" IRs on this tablet");
 }catch(Exception e){update("Library backup was not completed; Stadium originals are unchanged.");activity.runOnUiThread(()->activity.problem(e.getMessage()));}finally{if(connection!=null)connection.disconnect();if(partial!=null)partial.delete();busy=false;activity.runOnUiThread(()->activity.editor.invalidate());}});}
 void manage(String operation,Object entry,int parent,String name,String device,int generation){if(busy||device==null)return;busy=true;update("Updating clone library…");worker.execute(()->{try{
  JSONObject value=new JSONObject();value.put("op",operation);value.put("parent",parent);if(entry!=null){value.put("id",n(get(entry,"cid_")));value.put("expectedName",s(get(entry,"name")));String uuid=s(get(entry,"cluid"));if(!uuid.isEmpty())value.put("uuid",uuid);}if(name!=null)value.put("name",name);
  String job=UUID.randomUUID().toString();preferences.edit().putString("lastJob",job).commit();JSONObject result=new JSONObject(new String(request("/v1/manage/"+job,device,value.toString().getBytes(StandardCharsets.UTF_8)),StandardCharsets.UTF_8));if(!result.optBoolean("confirmed"))throw new Exception("Library change was not confirmed. Check Last Transfer before trying again.");
  update("Clone library change verified");activity.runOnUiThread(()->{if(activity.monitor.generation!=generation)return;LibrarianView library=activity.editor.librarian;if(operation.equals("delete")&&entry!=null&&library.cloneFolder==n(get(entry,"cid_"))){library.cloneFolder=parent;library.cloneTrail.removeIf(r->n(get(r,"cid_"))==n(get(entry,"cid_")));}library.selected=-1;activity.monitor.refreshClones();activity.monitor.readLibraryFolder(parent);activity.monitor.readLibraryFolder(library.cloneFolder);activity.editor.invalidate();});
 }catch(Exception e){update("Library change not confirmed. Check Last Transfer before retrying.");activity.runOnUiThread(()->activity.problem(e.getMessage()));}finally{busy=false;activity.runOnUiThread(()->activity.editor.invalidate());}});}
 void exportClone(Object entry,String device,int generation){if(busy||device==null)return;busy=true;update("Exporting "+s(get(entry,"name"))+"…");worker.execute(()->{try{
  int id=n(get(entry,"cid_"));String uuid=s(get(entry,"cluid"));if(id<=0||!uuid.matches("[0-9a-f-]{36}"))throw new Exception("Choose a clone file.");
  byte[] data=request("/v1/export/"+id+"/"+uuid,device,null);
  activity.runOnUiThread(()->{if(activity.monitor.generation!=generation){activity.problem("The connected Stadium changed. No exported file was saved.");return;}activity.saveClone(data,s(get(entry,"name")));update("Clone exported and verified");});
 }catch(Exception e){activity.runOnUiThread(()->activity.problem(e.getMessage()));update("Export was not confirmed");}finally{busy=false;activity.runOnUiThread(()->activity.editor.invalidate());}});}
}
