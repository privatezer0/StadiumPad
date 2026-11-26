package com.privatezero.stadiumpad;
import java.util.*;import static com.privatezero.stadiumpad.Models.*;import static com.privatezero.stadiumpad.Data.*;
/** Unsent explicit gestures coalesce. A failure discards this entire edit run. */
final class ParameterIntents {
 static final class Intent {final Context context;final Param definition;final Object value,expected;final String key;Intent(Context c,Param p,Object v,Object e){context=c;definition=p;value=v;expected=e;key=c.identity()+"/"+p.identity();}}
 final LinkedHashMap<String,Intent> pending=new LinkedHashMap<>();final Map<String,Object> acknowledged=new HashMap<>();
 void append(Context c,Param p,Object v,Object e)throws Exception{Intent next=new Intent(c,p,p.valid(v),e);require(pending.containsKey(next.key)||pending.size()<32,"Wait for the current controls to finish");Intent prior=pending.get(next.key);pending.put(next.key,prior==null?next:new Intent(c,p,next.value,prior.expected));}
 Intent take(){if(pending.isEmpty())return null;Intent item=pending.remove(pending.keySet().iterator().next());return new Intent(item.context,item.definition,item.value,acknowledged.containsKey(item.key)?acknowledged.get(item.key):item.expected);}
 void confirmed(Intent item){acknowledged.put(item.key,item.value);}
 void clear(){pending.clear();acknowledged.clear();}
}
