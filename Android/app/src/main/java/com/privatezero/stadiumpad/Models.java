package com.privatezero.stadiumpad;
import java.util.*;import java.io.*;import java.util.regex.*;import static com.privatezero.stadiumpad.Data.*;
final class Models {
 static final class Param {
  final Map<String,Object> raw;final int id;final String key,name,type,unit;final double min,max;final boolean harness,focusOnly;final List<Object> options;
  Param(Object o){raw=obj(o);id=n(raw.get("id"));key=s(raw.get("key"));name=s(raw.get("name"));type=s(raw.get("type"));unit=s(raw.get("unit"));min=d(raw.get("minimum"));max=d(raw.get("maximum"));harness=b(raw.get("harness"));focusOnly=b(raw.get("focusOnly"));options=arr(raw.get("options"));}
  String identity(){return (harness?"h":"m")+id;}
  Object valid(Object value)throws Exception{require(id>=0&&Double.isFinite(min)&&Double.isFinite(max)&&min<=max,"Invalid parameter metadata");if(type.equals("b")){require(value instanceof Boolean&&((Boolean)value?1:0)>=min&&((Boolean)value?1:0)<=max,"Invalid switch value");return value;}double v=d(value);require(Double.isFinite(v)&&v>=Math.min(min,(double)(float)min)&&v<=Math.max(max,(double)(float)max),name+" is outside its supported range");if(type.equals("i")){require(v==Math.rint(v)&&v>=Integer.MIN_VALUE&&v<=Integer.MAX_VALUE,"Choose a valid option");return (int)v;}require(type.equals("f")&&Float.isFinite((float)v),"Read-only parameter");return (double)(float)v;}
  String display(Object value){if(type.equals("b")){if(options.size()>=2)return s(options.get(b(value)?1:0));return b(value)?"On":"Off";}double v=d(value);if(!Double.isFinite(v))return "—";if(type.equals("i")&&!options.isEmpty()){int index=(int)(v-min);if(index>=0&&index<options.size())return s(options.get(index));}double lo=d(raw.get("displayMinimum")),hi=d(raw.get("displayMaximum"));if(Double.isFinite(lo)&&Double.isFinite(hi)&&max>min)v=lo+(v-min)/(max-min)*(hi-lo);
   for(Object f:arr(raw.get("displayFormats"))){Object lower=get(f,"lowerBound"),upper=get(f,"upperBound");if(lower!=null&&v<d(lower)||upper!=null&&v>=d(upper))continue;String format=s(get(f,"format"));Matcher m=Pattern.compile("%[-+]?[0-9]{0,2}(?:[.][0-9]{1,2})?[fFeEgG]").matcher(format);try{String out=format;if(m.find()){String token=m.group();String rest=format.substring(0,m.start())+format.substring(m.end());if(rest.replace("%%","").contains("%")||m.find())continue;out=String.format(Locale.US,format,v*d(get(f,"multiplier")));}else if(format.replace("%%","").contains("%"))continue;return out.replace("%%","%");}catch(Exception ignored){}}
   return String.format(Locale.US,type.equals("i")?"%.0f":"%.3g",v)+(unit.isEmpty()||unit.equals("unitless")?"":" "+unit);
  }
 }
 static final class Model {
  final int id;final String name,category,key,basedOn,io;final List<Param> params=new ArrayList<>();
  Model(Object o){id=n(get(o,"id"));name=s(get(o,"name"));category=s(get(o,"category"));key=s(get(o,"modelKey"));basedOn=s(get(o,"basedOn"));io=s(get(o,"ioRole"));for(Object p:arr(get(o,"parameters")))params.add(new Param(p));}
  boolean cab(){return category.equals("cab")||category.equals("cab_ir_interp");}
  boolean external(){return Arrays.asList(836,838,839,840).contains(id)||category.equals("ir");}
  boolean replaceable(){return id>=0&&!category.isEmpty()&&!category.equals("split")&&!category.equals("join")&&!external();}
  String group(){if(io.equals("outputs"))return "Output";if(io.equals("inputs"))return "Input";switch(category){case "amp":return "Amp";case "preamp":return "Preamp";case "cab":case "cab_ir_interp":case "ir":return "Cab / IR";case "distortion":return "Distortion";case "delay":return "Delay";case "reverb":return "Reverb";case "modulation":return "Modulation";case "dynamics":return "Dynamics";case "eq":return "EQ";case "pitch":case "synth":return "Pitch / Synth";case "wah":case "filter":return "Wah / Filter";case "volume":return "Volume / Pan";case "looper":return "Looper";case "send":case "return":case "fxloop":return "FX Loop";default:return "Utility";}}
  Param hype(){for(Param p:params)if(!p.harness&&p.type.equals("f")&&p.key.equalsIgnoreCase("Hype")&&p.min<p.max)return p;return null;}
 }
 static final class Block {
  final int path,pos,id,slot,model;final boolean enabled;final Map<Integer,Object> values=new LinkedHashMap<>(),harness=new LinkedHashMap<>();final Map<String,Object> raw;
  Block(int path,int pos,Object o,int slot,Object mdl){this.path=path;this.pos=pos;raw=obj(o);id=n(get(o,"id__"));this.slot=slot;model=n(get(mdl,"id__"));enabled=n(get(o,"enbl"))==1;for(Object p:arr(get(mdl,"parm")))values.put(n(get(p,"pid_")),get(p,"valu"));for(Object p:arr(get(o,"hrns","parm")))harness.put(n(get(p,"pid_")),get(p,"valu"));}
  Object value(Param p){return (p.harness?harness:values).get(p.id);}
  boolean settings(Block other){return other!=null&&id==other.id&&model==other.model&&enabled==other.enabled&&deep(values,other.values)&&deep(harness,other.harness);}
  String identity(){return path+"/"+pos+"/"+slot+"/"+id+"/"+model;}
 }
 static final class State {
  final UUID origin;final Object product,edit,preset;final int scene,id;final byte[] bytes;final boolean dirty;final List<Block> blocks=new ArrayList<>();
  State(UUID origin,Object product,byte[] bytes,Object preset,int scene,boolean dirty)throws Exception{this.origin=origin;this.product=product;this.bytes=bytes;edit=MP.decode(bytes);this.preset=preset;this.scene=scene;this.dirty=dirty;id=n(get(preset,"cid_"));int path=0;for(Object flow:arr(get(edit,"sfg_","flow"))){List<Object> b=arr(get(flow,"blks"));for(int i=0;i+1<b.size();i+=2){int pos=n(b.get(i));Object block=b.get(i+1);List<Object> models=arr(get(block,"mdls"));for(int slot=0;slot<models.size();slot++)if(n(get(models.get(slot),"id__"))>=0)blocks.add(new Block(path,pos,block,slot,models.get(slot)));}path++;}}
  String name(){return s(get(preset,"name"));}String location(){return label(n(get(preset,"posi")));}
  Block block(int path,int pos,int slot){for(Block b:blocks)if(b.path==path&&b.pos==pos&&b.slot==slot)return b;return null;}
  Object scene(int index){for(Object s:arr(get(edit,"cg__","entt","snps")))if(n(get(s,"si__"))==index)return s;return null;}
  boolean writable(){return n(get(preset,"ccid"))==-2&&n(get(preset,"type"))==2&&get(preset,"rcid")==null&&n(get(preset,"posi"))>=0&&n(get(preset,"posi"))<512;}
 }
 static final class Context {
  final UUID origin;final int preset,scene,path,pos,block,slot,model;
  Context(State s,Block b){origin=s.origin;preset=s.id;scene=s.scene;path=b.path;pos=b.pos;block=b.id;slot=b.slot;model=b.model;}
  Block verify(State state)throws Exception{require(preset>0&&scene>=0&&scene<=127&&path>=0&&path<=1&&pos>=0&&pos<28&&block>=0&&block<=255&&slot>=0&&slot<=1&&model>=0,"Invalid block context");Block b=state.block(path,pos,slot);require(origin.equals(state.origin)&&preset==state.id&&scene==state.scene&&b!=null&&b.id==block&&b.model==model,"The preset, scene or block changed. Reopen its controls.");return b;}
  String identity(){return origin+"/"+preset+"/"+scene+"/"+path+"/"+pos+"/"+block+"/"+slot+"/"+model;}
 }
 static String label(int p){return p>=0&&p<512?(p/4+1)+"ABCD".substring(p%4,p%4+1):"—";}
 static final class Change {final Param p;final Object value,expected;Change(Param p,Object v,Object e){this.p=p;value=v;expected=e;}}
 static List<Change> focus(Object def,double x,double y,Model model,Block block)throws Exception{
  require(Double.isFinite(x)&&Double.isFinite(y),"Invalid Focus point");x=normalize(x);y=normalize(y);float r=(float)(1/Math.sqrt(2)),sx=(float)x*r,sy=(float)y*r,major,minor;int first,second;
  if(x>=0&&x> -y&&x>=y){major=sx;minor=sy;first=4;second=3;}else if(y>Math.abs(x)){major=sy;minor=-sx;first=2;second=4;}else if(-x>=Math.abs(y)&&x<0){major=-sx;minor=-sy;first=1;second=2;}else{major=-sy;minor=sx;first=3;second=1;}
  float part=minor*r,a=(float)((double)major*r+part),b=(float)((double)major*r-part),centre=(1f-a)-b;int[] indices={0,first,second};double[] weights={clamp(centre,0,1),clamp(a,0,1),clamp(b,0,1)};int best=0;for(int i=1;i<3;i++)if(weights[i]>weights[best])best=i;
  List<Object> params=arr(get(def,"params"));require(arr(get(def,"names")).size()==5&&!params.isEmpty()&&params.size()<=128,"Invalid Focus map");Set<Integer> ids=new HashSet<>();List<Change> out=new ArrayList<>();
  for(Object f:params){int id=n(get(f,"id"));Param p=null;for(Param candidate:model.params)if(!candidate.harness&&candidate.id==id)p=candidate;require(p!=null&&ids.add(id)&&p.key.equals(s(get(f,"key")))&&p.type.equals(s(get(f,"type")))&&p.min==d(get(f,"min"))&&p.max==d(get(f,"max")),"Focus metadata mismatch");List<Object> values=arr(get(f,"values"));String behavior=s(get(f,"behavior"));require(values.size()==5&&(behavior.equals("quantize")||behavior.equals("interpolate")),"Invalid Focus values");for(Object v:values)require(Double.isFinite(d(v)),"Invalid Focus value");float mixed=0;for(int i=0;i<3;i++)mixed=(float)((double)mixed+(double)(float)d(values.get(indices[i]))*weights[i]);double v=clamp(behavior.equals("quantize")?d(values.get(indices[best])):mixed,p.min,p.max);Object desired=p.type.equals("b")?(Object)(v>=.5):p.type.equals("i")?(Object)(int)Math.floor(v+.5):(Object)v;require(block.value(p)!=null,"Focus control unavailable");out.add(new Change(p,p.valid(desired),block.value(p)));}return out;
 }
 static double clamp(double x,double lo,double hi){return Math.max(lo,Math.min(hi,x));}
 static double normalize(double v){v=clamp(v,-1,1);return Math.floor(Math.abs(v)*100+.5)/100*(v<0?-1:1);}
}
