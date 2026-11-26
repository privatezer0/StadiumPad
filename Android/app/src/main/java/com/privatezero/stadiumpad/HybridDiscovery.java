package com.privatezero.stadiumpad;
import android.content.Context;import android.net.nsd.*;import android.net.wifi.WifiManager;import java.util.*;import java.util.concurrent.*;
/** Bounded read-only discovery. Identity is verified by Session before use. */
final class HybridDiscovery {
 static final class Endpoint {final String host;final int port;Endpoint(String h,int p){host=h;port=p;}}
 static List<Endpoint> find(Context context)throws Exception {
  NsdManager manager=(NsdManager)context.getSystemService(Context.NSD_SERVICE);CountDownLatch ready=new CountDownLatch(1);List<Endpoint> results=Collections.synchronizedList(new ArrayList<>());
  WifiManager wifi=(WifiManager)context.getApplicationContext().getSystemService(Context.WIFI_SERVICE);WifiManager.MulticastLock lock=wifi==null?null:wifi.createMulticastLock("StadiumPad hybrid discovery");if(lock!=null)lock.acquire();
  NsdManager.DiscoveryListener listener=new NsdManager.DiscoveryListener(){public void onDiscoveryStarted(String t){}public void onDiscoveryStopped(String t){}public void onStartDiscoveryFailed(String t,int e){ready.countDown();}public void onStopDiscoveryFailed(String t,int e){}public void onServiceLost(NsdServiceInfo s){}public void onServiceFound(NsdServiceInfo s){if(results.size()>=4)return;manager.resolveService(s,new NsdManager.ResolveListener(){public void onResolveFailed(NsdServiceInfo i,int e){}public void onServiceResolved(NsdServiceInfo i){if(i.getHost()!=null&&i.getPort()>0&&i.getPort()<65535){results.add(new Endpoint(i.getHost().getHostAddress(),i.getPort()));ready.countDown();}}});}};
  try{manager.discoverServices("_stadiumserver._tcp.",NsdManager.PROTOCOL_DNS_SD,listener);ready.await(1800,TimeUnit.MILLISECONDS);synchronized(results){return new ArrayList<>(results.subList(0,Math.min(4,results.size())));}}
  finally{try{manager.stopServiceDiscovery(listener);}catch(Exception ignored){}if(lock!=null&&lock.isHeld())lock.release();}
 }
}
