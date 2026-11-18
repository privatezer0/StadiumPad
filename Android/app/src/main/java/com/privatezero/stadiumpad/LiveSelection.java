package com.privatezero.stadiumpad;
import static com.privatezero.stadiumpad.Models.*;
import static com.privatezero.stadiumpad.Data.*;
/** Selection events use visible positions, never internal block IDs. No hardware writes. */
final class LiveSelection {
 static int[] decode(OSC event){
  if(!event.address.equals("/setSelectedBlock")||event.args.size()!=4)return null;
  for(Object value:event.args)if(!(value instanceof Integer||value instanceof Long))return null;
  long path=((Number)event.args.get(2)).longValue(),pos=((Number)event.args.get(3)).longValue();
  return path>=0&&path<=1&&pos>=0&&pos<28?new int[]{(int)path,(int)pos}:null;
 }
 static Block resolve(State old,State next,int path,int pos,boolean follow){
  if(!follow)return null;
  if(path>=0){Block selected=next.block(path,pos,0);if(selected!=null)return selected;}
  if(old==null||old.id!=next.id||old.scene!=next.scene)return null;
  for(Block block:next.blocks){Block previous=old.block(block.path,block.pos,block.slot);if(previous!=null&&previous.model!=block.model)return block;}
  return null;
 }
}
