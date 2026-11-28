// Shared with QCPad under the MIT license.
package com.privatezero.stadiumpad;
import android.Manifest;import android.app.Activity;import android.bluetooth.*;import android.bluetooth.le.*;import android.content.pm.PackageManager;import android.os.*;import android.os.ParcelUuid;import org.json.*;import java.io.*;import java.net.*;import java.util.*;import java.util.concurrent.*;import java.util.zip.*;

/** BLE helper selection and credit-based streams, independent of Wi-Fi. */
final class BluetoothBridge {
 static final UUID SERVICE=UUID.fromString("8dfb7000-24ea-4c52-b28c-684e04572ad1"),INFO=UUID.fromString("8dfb7001-24ea-4c52-b28c-684e04572ad1");
 interface Found {void found(BluetoothDevice device,String name);void error(String message);}
 static java.lang.ref.WeakReference<BluetoothBridge> instance=new java.lang.ref.WeakReference<>(null);
 final Activity activity;BluetoothLeScanner scanner;ScanCallback callback;
 BluetoothBridge(Activity a){activity=a;instance=new java.lang.ref.WeakReference<>(this);}
 static boolean granted(Activity a){return Build.VERSION.SDK_INT>=31 ? a.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)==PackageManager.PERMISSION_GRANTED&&a.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)==PackageManager.PERMISSION_GRANTED:a.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)==PackageManager.PERMISSION_GRANTED;}
 boolean permissions(){if(Build.VERSION.SDK_INT>=31){if(activity.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN)!=PackageManager.PERMISSION_GRANTED||activity.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT)!=PackageManager.PERMISSION_GRANTED){activity.requestPermissions(new String[]{Manifest.permission.BLUETOOTH_SCAN,Manifest.permission.BLUETOOTH_CONNECT},73);return false;}}else if(activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)!=PackageManager.PERMISSION_GRANTED){activity.requestPermissions(new String[]{Manifest.permission.ACCESS_FINE_LOCATION},73);return false;}return true;}
 void scan(Found found){stop();if(Build.VERSION.SDK_INT<29){found.error("Bluetooth editor requires Android 10 or later.");return;}if(!permissions())return;
  BluetoothAdapter adapter=BluetoothAdapter.getDefaultAdapter();if(adapter==null||!adapter.isEnabled()){found.error("Turn on Bluetooth to find PedalBridge.");if(adapter!=null)activity.startActivityForResult(new android.content.Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE),74);return;}scanner=adapter.getBluetoothLeScanner();callback=new ScanCallback(){public void onScanResult(int type,ScanResult result){String name=result.getScanRecord()==null?null:result.getScanRecord().getDeviceName();found.found(result.getDevice(),name==null?"PedalBridge":name);}public void onScanFailed(int code){found.error("Bluetooth discovery failed. Refresh to try again.");}};
  scanner.startScan(Collections.singletonList(new ScanFilter.Builder().setServiceUuid(new ParcelUuid(SERVICE)).build()),new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),callback);
 }
 void stop(){if(scanner!=null&&callback!=null)try{scanner.stopScan(callback);}catch(Exception ignored){}scanner=null;callback=null;}
 static final class Information {final JSONObject value;final BluetoothGatt gatt;Information(JSONObject v,BluetoothGatt g){value=v;gatt=g;}}
 static Information informationLink(android.content.Context context,BluetoothDevice device)throws Exception {
  CompletableFuture<JSONObject> result=new CompletableFuture<>();BluetoothGatt gatt=device.connectGatt(context.getApplicationContext(),false,new BluetoothGattCallback(){
   public void onConnectionStateChange(BluetoothGatt g,int status,int state){if(status!=BluetoothGatt.GATT_SUCCESS){result.completeExceptionally(new IOException("Bluetooth connection failed"));return;}if(state==BluetoothProfile.STATE_CONNECTED){g.requestConnectionPriority(BluetoothGatt.CONNECTION_PRIORITY_HIGH);g.discoverServices();}else if(state==BluetoothProfile.STATE_DISCONNECTED)result.completeExceptionally(new IOException("Bluetooth disconnected"));}
   public void onServicesDiscovered(BluetoothGatt g,int status){BluetoothGattService service=g.getService(SERVICE);BluetoothGattCharacteristic info=service==null?null:service.getCharacteristic(INFO);if(status!=BluetoothGatt.GATT_SUCCESS||info==null||!g.readCharacteristic(info))result.completeExceptionally(new IOException("PedalBridge service unavailable"));}
   public void onCharacteristicRead(BluetoothGatt g,BluetoothGattCharacteristic c,int status){if(status==BluetoothGatt.GATT_SUCCESS)try{result.complete(new JSONObject(new String(c.getValue(),"UTF-8")));}catch(Exception e){result.completeExceptionally(new IOException("Invalid Bluetooth helper information"));}else result.completeExceptionally(new IOException("Cannot read Bluetooth helper information"));}
  },BluetoothDevice.TRANSPORT_LE);
  boolean transferred=false;try{Information info=new Information(result.get(15,TimeUnit.SECONDS),gatt);transferred=true;return info;}finally{if(!transferred&&gatt!=null)gatt.close();}
 }
 JSONObject information(BluetoothDevice device)throws Exception {Information info=informationLink(activity,device);try{return info.value;}finally{info.gatt.close();}}
 String choose(BluetoothDevice device)throws Exception {
  JSONObject info=information(device);int psm=info.getInt("psm");String pin=info.getString("pin");PedalBridge.require(info.getInt("protocol")==2&&psm>0&&psm<256&&pin.matches("[a-f0-9]{64}"),"Unsupported Bluetooth helper");
  String provisional=link(device.getAddress(),psm,pin,String.join("",Collections.nCopies(40,"0")));JSONObject reply;
  try(Socket s=socket(new PedalBridge.Pair(provisional))){reply=PedalBridge.authenticate(s,new JSONObject().put("protocol",1).put("channel","pair"));}
  PedalBridge.require(pin.equals(reply.getString("pin")),"PedalBridge identity changed. Refresh helper list.");return link(device.getAddress(),psm,pin,reply.getString("token"));
 }
 static String link(String host,int port,String pin,String token)throws Exception {return "pedalbridge://pair?host="+URLEncoder.encode(host,"UTF-8")+"&port="+port+"&pin="+pin+"&token="+token;}
 static boolean bluetooth(PedalBridge.Pair pair){return pair.port>=128&&pair.port<=255&&pair.host.matches("(?i)([0-9a-f]{2}:){5}[0-9a-f]{2}");}
 static byte[] unpack(int kind,byte[] data)throws IOException {
  if(kind!=4)return data;if(data.length<5)throw new IOException("Invalid compressed Bluetooth frame");int expected=((data[0]&255)<<24)|((data[1]&255)<<16)|((data[2]&255)<<8)|(data[3]&255);if(expected<=0||expected>16384)throw new IOException("Invalid Bluetooth expanded size");
  Inflater inflater=new Inflater(true);try{inflater.setInput(data,4,data.length-4);byte[] out=new byte[expected+1];int count=inflater.inflate(out);if(count!=expected||!inflater.finished()||inflater.getRemaining()!=0)throw new IOException("Invalid compressed Bluetooth payload");return Arrays.copyOf(out,expected);}catch(DataFormatException e){throw new IOException("Invalid compressed Bluetooth payload");}finally{inflater.end();}
 }
 static byte[] packed(byte[] data,int offset,int count){
  if(count<512)return null;Deflater compressor=new Deflater(1,true);try{compressor.setInput(data,offset,count);compressor.finish();byte[] out=new byte[count+4];int length=compressor.deflate(out,4,count);if(!compressor.finished()||length+20>=count)return null;out[0]=(byte)(count>>24);out[1]=(byte)(count>>16);out[2]=(byte)(count>>8);out[3]=(byte)count;return Arrays.copyOf(out,length+4);}finally{compressor.end();}
 }
 static final class Endpoint {final BluetoothDevice device;final int psm;final BluetoothGatt gatt;Endpoint(BluetoothDevice d,int p,BluetoothGatt g){device=d;psm=p;gatt=g;}}
 Endpoint resolve(PedalBridge.Pair pair)throws Exception {
  BluetoothAdapter adapter=BluetoothAdapter.getDefaultAdapter();if(adapter==null||!adapter.isEnabled())throw new IOException("Turn on Bluetooth to reconnect PedalBridge");
  BluetoothLeScanner scanning=adapter.getBluetoothLeScanner();BlockingQueue<BluetoothDevice> candidates=new ArrayBlockingQueue<>(16);Set<String> seen=ConcurrentHashMap.newKeySet();
  ScanCallback scan=new ScanCallback(){public void onScanResult(int type,ScanResult result){String name=result.getScanRecord()==null?"":result.getScanRecord().getDeviceName();if(name!=null&&name.endsWith(pair.pin.substring(0,4))&&seen.add(result.getDevice().getAddress()))candidates.offer(result.getDevice());}};
  scanning.startScan(Collections.singletonList(new ScanFilter.Builder().setServiceUuid(new ParcelUuid(SERVICE)).build()),new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),scan);
  try{long deadline=System.nanoTime()+8_000_000_000L;while(System.nanoTime()<deadline){BluetoothDevice device=candidates.poll(500,TimeUnit.MILLISECONDS);if(device==null)continue;Information link=informationLink(activity,device);boolean transferred=false;try{JSONObject info=link.value;if(info.getInt("protocol")==2&&pair.pin.equals(info.getString("pin"))){int psm=info.getInt("psm");if(psm>=128&&psm<=255){transferred=true;return new Endpoint(device,psm,link.gatt);}}}finally{if(!transferred)link.gatt.close();}}throw new IOException("Selected PedalBridge is not nearby. Reconnecting…");}finally{scanning.stopScan(scan);}
 }
 static final Map<String,Mux> links=new HashMap<>();
 static synchronized Socket socket(PedalBridge.Pair pair)throws Exception {
  if(Build.VERSION.SDK_INT<29)throw new IOException("Bluetooth editor requires Android 10 or later");
  String key=pair.pin;Mux mux=links.get(key);
  if(mux==null||mux.closed){BluetoothBridge owner=instance.get();if(owner==null)throw new IOException("Open the editor to connect PedalBridge");Endpoint endpoint=owner.resolve(pair);BluetoothSocket b;try{b=endpoint.device.createInsecureL2capChannel(endpoint.psm);}catch(Exception e){endpoint.gatt.close();throw e;}
   ScheduledExecutorService timer=Executors.newSingleThreadScheduledExecutor(r->{Thread t=new Thread(r,"Bluetooth connect timeout");t.setDaemon(true);return t;});ScheduledFuture<?> timeout=timer.schedule(()->{try{b.close();}catch(IOException ignored){}},10,TimeUnit.SECONDS);
   try{b.connect();mux=new Mux(b,endpoint.gatt);links.put(key,mux);}catch(Exception e){try{b.close();}catch(IOException ignored){}finally{endpoint.gatt.close();}throw e;}finally{timeout.cancel(false);timer.shutdown();}
  }
  return mux.open();
 }
 static final class Mux {
  final BluetoothSocket bluetooth;final BluetoothGatt priorityLink;final DataOutputStream out;final Map<Integer,Adapter> channels=new ConcurrentHashMap<>();volatile boolean closed;int next=1;
  final ScheduledThreadPoolExecutor timer=new ScheduledThreadPoolExecutor(1,r->{Thread t=new Thread(r,"Bluetooth send timeout");t.setDaemon(true);return t;});
  Mux(BluetoothSocket b,BluetoothGatt gatt)throws IOException {bluetooth=b;priorityLink=gatt;out=new DataOutputStream(new BufferedOutputStream(b.getOutputStream(),16400));timer.setRemoveOnCancelPolicy(true);
   Thread pump=new Thread(()->{try{DataInputStream in=new DataInputStream(new BufferedInputStream(bluetooth.getInputStream(),16384));while(!closed){int kind=in.readUnsignedByte(),id=in.readInt(),length=in.readInt();if((kind!=2&&kind!=3&&kind!=4)||id<=0||length<0||length>16384||(kind==3&&length!=0))throw new IOException("Invalid Bluetooth stream frame");byte[] data=new byte[length];in.readFully(data);Adapter channel=channels.get(id);if(channel==null)continue;if(kind==3){channels.remove(id);channel.end();}else if(!channel.received.offer(unpack(kind,data))){channel.close();}}}catch(Exception ignored){}finally{close();}},"PedalBridge BLE streams");pump.setDaemon(true);pump.start();
  }
  synchronized Adapter open()throws IOException {if(closed||channels.size()>=12)throw new IOException("Bluetooth editor channels unavailable");int id=next++;Adapter a=new Adapter(this,id);channels.put(id,a);try{frame(1,id,new byte[0],0,0);return a;}catch(IOException e){channels.remove(id);throw e;}}
  synchronized void frame(int kind,int id,byte[] data,int offset,int length)throws IOException {if(closed)throw new IOException("Bluetooth disconnected; reconnect before editing");ScheduledFuture<?> expiry=timer.schedule(this::close,10,TimeUnit.SECONDS);try{int end=offset+length;do{int count=Math.min(16384,end-offset);byte[] compressed=kind==2?packed(data,offset,count):null;out.writeByte(compressed==null?kind:4);out.writeInt(id);out.writeInt(compressed==null?count:compressed.length);if(compressed==null)out.write(data,offset,count);else out.write(compressed);out.flush();offset+=count;}while(offset<end);}catch(IOException e){close();throw e;}finally{expiry.cancel(false);}}
  void close(){if(closed)return;closed=true;try{priorityLink.close();}catch(SecurityException ignored){}try{bluetooth.close();}catch(IOException ignored){}for(Adapter a:channels.values())a.end();channels.clear();timer.shutdownNow();}
 }
 /** Logical socket facade preserves the native decoder and independent SUB/DEALER. */
 static final class Adapter extends Socket {
  final Mux mux;final int id;final BlockingQueue<byte[]> received=new ArrayBlockingQueue<>(256);final InputStream in;final OutputStream out;volatile boolean closed;volatile int timeout=5000;byte[] current=new byte[0];int position;
  Adapter(Mux mux,int id){this.mux=mux;this.id=id;
   out=new OutputStream(){public void write(int b)throws IOException{write(new byte[]{(byte)b});}public void write(byte[] b,int offset,int length)throws IOException{if(closed)throw new IOException("Bluetooth channel closed");mux.frame(2,id,b,offset,length);}};
   in=new InputStream(){public int read()throws IOException{byte[] one=new byte[1];int n=read(one,0,1);return n<0?-1:one[0]&255;}public synchronized int read(byte[] target,int offset,int length)throws IOException{if(length==0)return 0;
    if(position==current.length){if(closed&&received.isEmpty())return -1;try{current=timeout==0?received.take():received.poll(timeout,TimeUnit.MILLISECONDS);position=0;}catch(InterruptedException e){Thread.currentThread().interrupt();throw new IOException("Bluetooth receive interrupted");}if(current==null){Adapter.this.close();throw new SocketTimeoutException("Bluetooth receive timed out; nothing was retried");}if(current.length==0)return -1;}
    int n=Math.min(length,current.length-position);System.arraycopy(current,position,target,offset,n);position+=n;return n;}
   };
  }
  public InputStream getInputStream(){return in;}public OutputStream getOutputStream(){return out;}
  public void setSoTimeout(int value){timeout=Math.max(0,value);}public void setTcpNoDelay(boolean value){}
  void end(){closed=true;received.offer(new byte[0]);}
  public synchronized void close()throws IOException {if(closed)return;end();received.clear();received.offer(new byte[0]);mux.channels.remove(id);if(!mux.closed)mux.frame(3,id,new byte[0],0,0);}
  public boolean isClosed(){return closed;}
 }
}
