package com.privatezero.stadiumpad;
import java.util.*;import java.nio.charset.StandardCharsets;
import static com.privatezero.stadiumpad.Data.*;import static com.privatezero.stadiumpad.Models.*;
/** Persistent local view preference, scoped to device and active preset, with no network writes. */
final class SelectionMemory {
 static String key(State state,String endpoint){
  if(state==null||state.id<=0)return null;
  String serial=s(get(state.product,"host","snum")).trim();
  String scope=serial.isEmpty()?"endpoint:"+endpoint.trim().toLowerCase(Locale.ROOT):"serial:"+serial;
  if(scope.equals("endpoint:"))return null;
  try{return "rememberedBlock.v1."+hash(scope.getBytes(StandardCharsets.UTF_8))+"."+state.id;}catch(Exception e){return null;}
 }
 static String record(Block block){try{return Base64.getEncoder().encodeToString(MP.encode(Arrays.asList(block.path,block.pos,block.id,block.slot)));}catch(Exception e){return "";}}
 static Block restore(String record,State state){
  if(record==null||record.length()>128)return null;
  try{
   List<Object> a=arr(MP.decode(Base64.getDecoder().decode(record)));if(a.size()!=4)return null;
   for(Object v:a)if(!(v instanceof Integer||v instanceof Long))return null;
   long path=((Number)a.get(0)).longValue(),pos=((Number)a.get(1)).longValue(),id=((Number)a.get(2)).longValue(),slot=((Number)a.get(3)).longValue();
   if(path<0||path>1||pos<0||pos>=28||id<0||id>255||slot<0||slot>1)return null;
   Block found=null;
   for(Block b:state.blocks)if(b.path==path&&b.id==id&&b.slot==slot){if(found!=null)return null;found=b;}
   return found;
  }catch(Exception e){return null;}
 }
}
