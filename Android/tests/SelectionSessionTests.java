package com.privatezero.stadiumpad;
import java.io.File;
import static com.privatezero.stadiumpad.Models.*;
import static com.privatezero.stadiumpad.Data.*;
/** Loopback-only command/event-channel test; never accepts a LAN address. */
public final class SelectionSessionTests {
 public static void main(String[] args)throws Exception{
  Session session=new Session(new File(args[1]));session.connect("127.0.0.1",Integer.parseInt(args[0]));
  Thread events=new Thread(()->{try{while(!session.closed)session.event();}catch(Exception ignored){}},"synthetic selection events");events.setDaemon(true);events.start();
  try{State before=session.snapshot();State after=session.selectBlock(new Context(before,before.blocks.get(0)));require(java.util.Arrays.equals(before.bytes,after.bytes)&&before.id==after.id&&before.scene==after.scene&&before.dirty==after.dirty,"Selection changed preset state");System.out.println("PASS selection echo correlated; preset unchanged");}finally{session.close();}
 }
}
