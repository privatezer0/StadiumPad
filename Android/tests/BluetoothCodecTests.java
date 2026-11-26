package com.privatezero.stadiumpad;
import java.util.*;import java.io.*;
public final class BluetoothCodecTests {
 public static void main(String[] args)throws Exception{
  byte[] data=new byte[16384];for(int i=0;i<data.length;i++)data[i]=(byte)i;
  byte[] packed=BluetoothBridge.packed(data,0,data.length);
  if(packed==null||packed.length>1024||!Arrays.equals(data,BluetoothBridge.unpack(4,packed)))throw new AssertionError("Large native payload changed");
  if(BluetoothBridge.packed(new byte[]{1,2,3},0,3)!=null)throw new AssertionError("Small controls should be plain");
  for(byte[] invalid:new byte[][]{new byte[]{0,1,0,0,1},Arrays.copyOf(packed,packed.length-1),Arrays.copyOf(packed,packed.length+1)}){
   try{BluetoothBridge.unpack(4,invalid);throw new AssertionError("Invalid compressed frame accepted");}catch(IOException expected){}
  }
  System.out.println("Bluetooth codec: lossless native bytes, small controls, bounds and malformed payload checks passed");
 }
}
