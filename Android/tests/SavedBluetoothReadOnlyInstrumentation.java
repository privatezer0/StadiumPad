package com.privatezero.stadiumpad;
import android.app.Instrumentation;import android.os.Bundle;import android.content.Intent;import java.io.File;import static com.privatezero.stadiumpad.Data.*;import static com.privatezero.stadiumpad.Models.*;
/** Explicit physical read test; no edits, preference changes or new helper guesses. */
public final class SavedBluetoothReadOnlyInstrumentation extends Instrumentation {
 boolean allowed,setupPermissions,useExpectedHelper;
 @Override public void onCreate(Bundle args){super.onCreate(args);allowed=args!=null&&"true".equals(args.getString("readOnlyBridge"));setupPermissions=args!=null&&"true".equals(args.getString("setupPermissions"));useExpectedHelper=args!=null&&"true".equals(args.getString("useExpectedHelper"));start();}
 @Override public void onStart(){Bundle report=new Bundle();Session session=null;MainActivity activity=null;int code=0;
  try{
   require(allowed,"Pass readOnlyBridge=true explicitly");
   activity=(MainActivity)startActivitySync(new Intent(getTargetContext(),MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK|Intent.FLAG_ACTIVITY_CLEAR_TASK));
   if(!BluetoothBridge.granted(activity)&&setupPermissions){
    final MainActivity permissionsActivity=activity;runOnMainSync(()->permissionsActivity.bluetoothBridge.permissions());
    long until=android.os.SystemClock.elapsedRealtime()+60000;
    while(!BluetoothBridge.granted(activity)&&android.os.SystemClock.elapsedRealtime()<until)Thread.sleep(100);
   }
   require(BluetoothBridge.granted(activity),"Bluetooth permission must already be granted");
   PedalBridge.Pair saved=activity.bridgeStore.pair;
   if(useExpectedHelper){
    // Test-only explicit public identity; never credentials or app preference changes.
    File pinFile=new File(getTargetContext().getExternalFilesDir(null),"pedalbridge-readonly-pin.txt");require(pinFile.length()==64,"Stage the intended helper public fingerprint first");
    byte[] bytes=new byte[64];try(java.io.DataInputStream in=new java.io.DataInputStream(new java.io.FileInputStream(pinFile))){in.readFully(bytes);}require(pinFile.delete(),"Remove the test identity after reading");String pin=new String(bytes,java.nio.charset.StandardCharsets.US_ASCII);require(pin.matches("[a-f0-9]{64}"),"Invalid public helper fingerprint");
    PedalBridge.Pair target=new PedalBridge.Pair(BluetoothBridge.link("00:00:00:00:00:00",129,pin,String.join("",java.util.Collections.nCopies(40,"0"))));BluetoothBridge.Endpoint endpoint=activity.bluetoothBridge.resolve(target);
    try{saved=new PedalBridge.Pair(activity.bluetoothBridge.choose(endpoint.device));require(saved.pin.equals(pin),"Helper identity changed");}finally{endpoint.gatt.close();}
   }
   require(saved!=null,"First choose the intended helper normally");PedalBridge.Pair pair=saved;
   if(!BluetoothBridge.bluetooth(saved)){
    // Convert a legacy LAN address only after the saved public identity matches
    // live Bluetooth discovery. Never select an unrelated nearby helper.
    BluetoothBridge.Endpoint endpoint=activity.bluetoothBridge.resolve(saved);
    try{pair=new PedalBridge.Pair(BluetoothBridge.link(endpoint.device.getAddress(),endpoint.psm,saved.pin,saved.token));}finally{endpoint.gatt.close();}
   }
   final MainActivity current=activity;runOnMainSync(()->current.monitor.stop());
   long began=android.os.SystemClock.elapsedRealtime();session=new Session(new File(getTargetContext().getCacheDir(),"bridge-read-only"));session.connect(pair.host,2001,pair,null);State state=session.snapshot();
   require(!state.blocks.isEmpty(),"Expected the actual live signal chain");require(session.bridge!=null&&PedalBridge.hash(s(get(state.product,"host","snum")).trim().getBytes(java.nio.charset.StandardCharsets.UTF_8)).equals(session.bridge.device),"Bridge target identity mismatch");
   Object matrix=session.property("server.mixer.state");require(get(matrix,"lyrs") instanceof java.util.List,"Expected actual USB Matrix state");
   report.putBoolean("connected",true);report.putBoolean("readOnly",true);report.putBoolean("matrixUSBAvailable",session.bridge.matrix);report.putInt("liveBlocks",state.blocks.size());report.putInt("matrixOutputs",arr(get(matrix,"lyrs")).size());report.putString("upstream",session.bridge.upstream);report.putLong("initialReadMillis",android.os.SystemClock.elapsedRealtime()-began);code=-1;
  }catch(Throwable error){report.putString("failure",error.getClass().getSimpleName()+": "+error.getMessage());}
  finally{if(session!=null)session.close();if(activity!=null){final MainActivity done=activity;runOnMainSync(done::finish);}finish(code,report);}
 }
}
