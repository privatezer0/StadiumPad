package com.privatezero.stadiumpad;
import java.util.*;
import static com.privatezero.stadiumpad.Data.*;
import static com.privatezero.stadiumpad.Models.*;
public final class LiveSelectionTests {
 static State state(int preset,int scene,int model)throws Exception {
  Object one=map("id__",80,"enbl",1,"mdls",Arrays.asList(map("id__",42,"parm",Collections.emptyList())));
  Object two=map("id__",91,"enbl",1,"mdls",Arrays.asList(map("id__",model,"parm",Collections.emptyList())));
  return new State(new UUID(0,1),null,MP.encode(map("sfg_",map("flow",Arrays.asList(map("blks",Arrays.asList(1,one,6,two)))))),map("cid_",preset),scene,false);
 }
 public static int verify()throws Exception {
  int checks=0;State before=state(10,0,43),after=state(10,0,44);
  require(LiveSelection.resolve(before,after,-1,-1,true).pos==6,"External replacement follows changed model");checks++;
  require(LiveSelection.resolve(before,after,0,1,true).pos==1,"Explicit selection wins over replacement fallback");checks++;
  require(LiveSelection.resolve(before,after,-1,-1,false)==null,"Follow off ignores external model changes");checks++;
  require(LiveSelection.resolve(before,after,0,1,false)==null,"Follow off ignores selection events");checks++;
  require(LiveSelection.resolve(before,before,-1,-1,true)==null,"Ordinary refresh preserves browsing");checks++;
  require(LiveSelection.resolve(before,state(11,0,44),-1,-1,true)==null,"Preset change cannot reuse old model selection");checks++;
  require(LiveSelection.resolve(before,state(10,1,44),-1,-1,true)==null,"Scene change cannot reuse old model selection");checks++;
  require(LiveSelection.resolve(before,after,0,25,true).pos==6,"Unavailable selection still follows known replacement");checks++;
  int[] decoded=LiveSelection.decode(new OSC("/setSelectedBlock",2,17,1,27));
  require(decoded!=null&&decoded[0]==1&&decoded[1]==27,"Event uses flow and visible position");checks++;
  for(OSC invalid:Arrays.asList(new OSC("/setSelectedBlock",0,6),new OSC("/setSelectedBlock",2,17,0.0,6),new OSC("/setSelectedBlock",2,17,2,6),new OSC("/setSelectedBlock",2,17,0,28),new OSC("/setSelectedBlock",2,17,0,4294967296L),new OSC("/heartbeat",2,17,0,6))){require(LiveSelection.decode(invalid)==null,"Malformed/unrelated selection rejected");checks++;}
  return checks;
 }
 public static void main(String[] args)throws Exception {System.out.println(verify()+" live selection checks passed");}
}
