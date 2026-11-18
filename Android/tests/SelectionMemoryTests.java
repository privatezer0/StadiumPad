package com.privatezero.stadiumpad;
import java.util.*;import static com.privatezero.stadiumpad.Data.*;import static com.privatezero.stadiumpad.Models.*;
public final class SelectionMemoryTests {
 static State device(State state,String serial)throws Exception{return new State(state.origin,map("host",map("snum",serial)),state.bytes,state.preset,state.scene,false);}
 public static int verify()throws Exception {
  int checks=0;State a=device(LiveSelectionTests.state(10,0,43),"synthetic-a"),b=device(LiveSelectionTests.state(11,0,43),"synthetic-a"),other=device(a,"synthetic-b");
  String ka=SelectionMemory.key(a,"first:2001"),kb=SelectionMemory.key(b,"first:2001"),record=SelectionMemory.record(a.blocks.get(1));
  require(!ka.equals(kb)&&!ka.equals(SelectionMemory.key(other,"first:2001")),"Preset and device caches separated");checks++;
  require(ka.equals(SelectionMemory.key(a,"second:2001"))&&!ka.contains("synthetic-a"),"Stable private serial scope survives address change");checks++;
  Map<String,String> preferences=new HashMap<>();preferences.put(ka,record);preferences.put(kb,SelectionMemory.record(b.blocks.get(0)));
  require(SelectionMemory.restore(preferences.get(kb),b).pos==1,"Active preset restores its own block instead of last open preset");checks++;
  State moved=device(a,"synthetic-a");Block old=moved.blocks.remove(1);moved.blocks.add(new Block(old.path,9,old.raw,old.slot,arr(get(old.raw,"mdls")).get(0)));
  require(SelectionMemory.restore(record,moved).pos==9,"Moved block followed by identity");checks++;
  State removed=device(a,"synthetic-a");removed.blocks.remove(1);require(SelectionMemory.restore(record,removed)==null,"Removed block falls back");checks++;
  require(SelectionMemory.restore("broken",a)==null&&SelectionMemory.restore("",a)==null,"Invalid preference falls back");checks++;
  require(SelectionMemory.restore(Base64.getEncoder().encodeToString(MP.encode(Arrays.asList(0,6,91,-1))),a)==null,"Invalid slot rejected");checks++;
  State unknown=LiveSelectionTests.state(10,0,43);require(!SelectionMemory.key(unknown,"first:2001").equals(SelectionMemory.key(unknown,"second:2001")),"Missing serial uses endpoint isolation");checks++;
  require(SelectionMemory.key(unknown,"")==null&&SelectionMemory.key(LiveSelectionTests.state(-1,0,43),"host")==null,"Missing identity or preset does not persist");checks++;
  Block slot=new Block(0,6,old.raw,1,arr(get(old.raw,"mdls")).get(0));a.blocks.add(slot);require(SelectionMemory.restore(SelectionMemory.record(slot),a).slot==1,"Model slot retained");checks++;
  return checks;
 }
 public static void main(String[] args)throws Exception{System.out.println(verify()+" selection memory checks passed");}
}
