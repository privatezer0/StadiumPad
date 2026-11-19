package com.privatezero.stadiumpad;
import android.app.AlertDialog;
import android.widget.EditText;
import java.util.*;
import static com.privatezero.stadiumpad.Data.*;
import static com.privatezero.stadiumpad.Models.*;
/** Full-width librarian; editor preset navigation is not part of this screen. */
final class LibrarianView {
 final EditorView v;
 String tab="Presets",search="",cloneCategory="Amp";
 int folder=-2,selected=-1,cloneFolder=-23,seenGeneration=-1;long lastCloneRefresh=0;final List<Object> cloneTrail=new ArrayList<>();
 float folderOffset=0,rowOffset=0,rail,middle,top=265;
 final String[] tabs={"Presets","Cab IRs","Favorites","Templates","Songs","Clones"};
 LibrarianView(EditorView view){v=view;}
 int color(){return tab.equals("Clones")?0xffff3737:tab.equals("Cab IRs")?0xffff3594:tab.equals("Songs")?0xff20ad99:tab.equals("Favorites")?v.GREY:v.GOLD;}
 List<Object> rows(){
  List<Object> source=null;
  if(tab.equals("Presets"))for(Monitor.Folder f:v.m.folders)if(f.id==folder)source=f.presets;
  int cid=tab.equals("Presets")?folder:tab.equals("Cab IRs")?-11:tab.equals("Favorites")?-8:tab.equals("Templates")?-3:-7;
  if(source==null)source=v.m.inventory.getOrDefault(cid,Collections.emptyList());
  List<Object> result=new ArrayList<>();
  for(Object row:source)if(n(get(row,"cid_"))>0&&(!tab.equals("Presets")||n(get(row,"type"))==2)&&(search.isEmpty()||s(get(row,"name")).toLowerCase(Locale.ROOT).contains(search.toLowerCase(Locale.ROOT))))result.add(row);
  return result;
 }
 void draw(){
  if(seenGeneration!=v.m.generation){seenGeneration=v.m.generation;selected=-1;cloneFolder=-23;cloneTrail.clear();lastCloneRefresh=0;}
  rail=v.W<1150?168:205;middle=rail+(v.W<1150?270:330);int color=color();
  v.rect(0,154,rail,v.H-178,0xff141416);
  for(int i=0;i<tabs.length;i++){String name=tabs[i];int c=i==1?0xffff3594:i==2?v.GREY:i==4?0xff20ad99:i==5?0xffff3737:v.GOLD;float y=163+i*66;v.box(6,y,rail-12,64,v.alpha(c,tab.equals(name)?80:22),0,8);v.text(name,22,y+40,24,c,rail-35);v.hit(6,y,rail-12,64,name,"library",()->{tab=name;search="";selected=-1;folderOffset=rowOffset=0;v.invalidate();});}
  if(!v.activity.files.busy&&v.m.connected)v.button(8,v.H-143,rail-16,44,"Download Library",v.GOLD,false,()->v.activity.files.downloadLibrary(FileCompanion.deviceID(v.m),v.m.generation));
  if(v.activity.files.latestBackup()!=null)v.button(8,v.H-90,rail-16,44,"Open Tablet Backup",v.GOLD,false,()->v.activity.saveLibraryBackup(v.activity.files.latestBackup()));
  v.rect(rail,154,v.W-rail,v.H-178,v.alpha(color,13));
  if(tab.equals("Clones")){clones();return;}
  boolean presets=tab.equals("Presets");float listX=presets?middle:rail;
  if(presets){v.text("Setlists",rail+10,176,14,color,260);tools(rail+8,187,new String[]{"New","Delete","Duplicate","Import","Export"},v.W<1150?48:52);v.text("⌕  "+(search.isEmpty()?"Search Presets":search),rail+12,277,18,color,middle-rail-24);v.hit(rail,252,middle-rail,39,"Search Presets","library",this::search);float y=301-folderOffset;v.canvas.save();v.canvas.clipRect(rail,293,middle,v.H-25);folderRow("FACTORY PRESETS  ▣",-1,y);folderRow("USER PRESETS",-2,y+44);int i=2;for(Monitor.Folder f:v.m.folders)folderRow((i-1)+"   "+f.name,f.id,y+44*i++);v.canvas.restore();v.line(middle,154,middle,v.H-24,v.BORDER,1);}
  v.text(tab.equals("Presets")?"Presets":tab,listX+10,176,14,color,400);
  tools(listX+8,187,presets?new String[]{"Delete","Create Setlist"}:new String[]{"Delete"},80);tools(v.W-170,187,new String[]{"Import","Export"},80);
  if(!presets){v.text("⌕  "+(search.isEmpty()?"Search "+tab:search),listX+12,277,18,color,v.W-listX-24);v.hit(listX,252,v.W-listX,39,"Search "+tab,"library",this::search);}
  top=presets?252:293;List<Object> rows=rows();rowOffset=Math.max(0,Math.min(rowOffset,Math.max(0,rows.size()*44-(v.H-66-top))));v.canvas.save();v.canvas.clipRect(listX,top,v.W,v.H-66);
  for(int i=0;i<rows.size();i++){Object row=rows.get(i);float yy=top+i*44-rowOffset;if(yy+44<top||yy>v.H-66)continue;int id=n(get(row,"cid_"));if(selected==id)v.rect(listX,yy,v.W-listX,44,v.alpha(color,60));v.text("▱",listX+12,yy+29,24,color,30);float tx=listX+48;if(presets){v.text(label(n(get(row,"posi"))),tx,yy+29,19,v.WHITE,48);tx+=58;}v.text(s(get(row,"name")),tx,yy+29,20,v.WHITE,v.W-tx-16);v.line(listX,yy+43,v.W,yy+43,v.alpha(color,35),1);v.hit(listX,Math.max(top,yy),v.W-listX,Math.min(44,v.H-66-Math.max(top,yy)),s(get(row,"name")),"library",()->{selected=id;v.invalidate();});}
  v.canvas.restore();v.text(rows.size()+" items",listX+12,v.H-41,12,color,200);
  Object choice=rows.stream().filter(r->n(get(r,"cid_"))==selected).findFirst().orElse(null);
  if(presets&&choice!=null)v.button(v.W-160,v.H-61,148,32,"Open Preset",color,false,()->{v.activity.load(choice);});
 }
 void folderRow(String name,int id,float y){if(y+44<293||y>v.H-25)return;if(folder==id)v.rect(rail,y,middle-rail,44,v.alpha(v.GOLD,60));v.text("▱  "+name,rail+12,y+29,18,v.GOLD,middle-rail-24);v.hit(rail,Math.max(293,y),middle-rail,Math.min(44,v.H-25-Math.max(293,y)),name,"library",()->{folder=id;selected=-1;rowOffset=0;v.invalidate();});}
 void tools(float x,float y,String[] names,float width){for(int i=0;i<names.length;i++){v.box(x+i*(width+3),y,width,58,v.alpha(color(),17),0,5);v.center(names[i],x+i*(width+3)+width/2,y+38,11,v.alpha(color(),85));}}
 List<Object> cloneRows(){List<Object> result=new ArrayList<>();for(Object row:v.m.inventory.getOrDefault(cloneFolder,Collections.emptyList()))if(search.isEmpty()||s(get(row,"name")).toLowerCase(Locale.ROOT).contains(search.toLowerCase(Locale.ROOT)))result.add(row);result.sort(Comparator.comparing(r->s(get(r,"name")),String.CASE_INSENSITIVE_ORDER));return result;}
 void cloneAction(float x,String name,boolean enabled,Runnable action){if(enabled)v.button(x,167,82,58,name,color(),false,action);else tools(x,167,new String[]{name},82);}
 void clones(){
  if(v.m.connected&&android.os.SystemClock.uptimeMillis()-lastCloneRefresh>3000){lastCloneRefresh=android.os.SystemClock.uptimeMillis();v.m.readLibraryFolder(-14);v.m.readLibraryFolder(cloneFolder);}
  FileCompanion files=v.activity.files;String device=FileCompanion.deviceID(v.m);List<Object> rows=cloneRows();Object choice=rows.stream().filter(r->n(get(r,"cid_"))==selected&&n(get(r,"type"))==11).findFirst().orElse(null);
  Object manage=choice;if(manage==null&&!cloneTrail.isEmpty()){Object candidate=cloneTrail.get(cloneTrail.size()-1);if(n(get(candidate,"cid_"))>0)manage=candidate;}final Object target=manage;
  cloneAction(rail+10,"New Folder",device!=null&&!files.busy,()->v.activity.cloneManage("mkdir",null,cloneFolder));
  cloneAction(rail+97,"Delete",target!=null&&device!=null&&!files.busy,()->v.activity.cloneManage("delete",target,n(get(target,"ccid"))));
  cloneAction(rail+184,"Rename",target!=null&&device!=null&&!files.busy,()->v.activity.cloneManage("rename",target,n(get(target,"ccid"))));
  cloneAction(rail+265,"Export",choice!=null&&files.paired()&&device!=null&&!files.busy,()->files.exportClone(choice,device,v.m.generation));
  cloneAction(rail+352,"Import",device!=null&&!files.busy,v.activity::importClones);
  if(!files.busy)v.button(v.W-142,175,130,42,files.paired()?"Mac Paired":"Pair Mac",color(),false,()->v.activity.pairCompanion(null));
  v.text("⌕  "+(search.isEmpty()?"Search Clones":search),rail+14,257,17,color(),v.W-rail-28);v.hit(rail,232,v.W-rail,40,"Search Clones","library",this::search);
  float split=rail+(v.W-rail)*.42f;top=276;List<Object> roots=new ArrayList<>(v.m.inventory.getOrDefault(-14,Collections.emptyList()));roots.sort(Comparator.comparing(r->s(get(r,"name")),String.CASE_INSENSITIVE_ORDER));int i=0;
  for(Object row:roots){int id=n(get(row,"cid_"));float y=top+i++*46;if(cloneFolder==id||!cloneTrail.isEmpty()&&n(get(cloneTrail.get(0),"cid_"))==id)v.rect(rail,y,split-rail,46,v.alpha(color(),40));v.text("▱  "+s(get(row,"name")),rail+14,y+29,21,color(),split-rail-28);v.hit(rail,y,split-rail,46,s(get(row,"name")),"library",()->{cloneFolder=id;selected=-1;rowOffset=0;cloneTrail.clear();cloneTrail.add(row);lastCloneRefresh=0;v.invalidate();});if(cloneTrail.isEmpty()&&id==cloneFolder)cloneTrail.add(row);}
  v.line(split,top,split,v.H-100,v.BORDER,1);float listTop=top;
  if(cloneTrail.size()>1){v.text("‹ Back",split+14,top+29,17,color(),160);v.hit(split,top,v.W-split,40,"Back to parent clone folder","library",()->{cloneTrail.remove(cloneTrail.size()-1);cloneFolder=cloneTrail.isEmpty()?-23:n(get(cloneTrail.get(cloneTrail.size()-1),"cid_"));selected=-1;rowOffset=0;lastCloneRefresh=0;v.invalidate();});listTop+=40;}
  rowOffset=Math.max(0,Math.min(rowOffset,Math.max(0,rows.size()*44-(v.H-100-listTop))));v.canvas.save();v.canvas.clipRect(split,listTop,v.W,v.H-100);
  for(i=0;i<rows.size();i++){Object row=rows.get(i);int id=n(get(row,"cid_"));boolean folder=n(get(row,"type"))==1002;float y=listTop+i*44-rowOffset;if(y+44<listTop||y>v.H-100)continue;if(selected==id)v.rect(split,y,v.W-split,44,v.alpha(color(),70));v.text((folder?"▱  ":"▧  ")+s(get(row,"name")),split+14,y+29,19,color(),v.W-split-28);v.hit(split,Math.max(y,listTop),v.W-split,Math.min(44,v.H-100-Math.max(y,listTop)),s(get(row,"name")),"library",()->{if(folder){cloneFolder=id;cloneTrail.add(row);rowOffset=0;lastCloneRefresh=0;selected=-1;}else selected=id;v.invalidate();});}
  if(rows.isEmpty())v.text(v.m.connected?"No clones in this folder":"Connect to Stadium to browse clones",split+18,listTop+34,16,v.GREY,v.W-split-36);v.canvas.restore();
  String breadcrumb="User Clones";for(Object row:cloneTrail)breadcrumb+="  ›  "+s(get(row,"name"));v.text(breadcrumb,rail+16,v.H-73,14,color(),v.W-rail-30);
  if(files.busy){v.rect(rail+12,v.H-61,v.W-rail-24,4,0xff222225);v.rect(rail+12,v.H-61,(float)((v.W-rail-24)*files.progress),4,color());}
  v.text(files.status,rail+14,v.H-39,12,v.GREY,v.W-rail-220);
  if(!files.busy&&files.preferences.contains("lastJob")&&device!=null)v.button(v.W-195,v.H-59,184,29,"Check Last Transfer",color(),false,()->files.checkLast(device));
 }
 void search(){EditText field=new EditText(v.activity);field.setSingleLine(true);field.setText(search);new AlertDialog.Builder(v.activity).setTitle("Search "+tab).setView(field).setNegativeButton("Cancel",null).setNeutralButton("Clear",(d,w)->{search="";rowOffset=0;v.invalidate();}).setPositiveButton("Search",(d,w)->{search=field.getText().toString();rowOffset=0;v.invalidate();}).show();}
 int region(float x,float y){if(tab.equals("Clones"))return y>top&&y<v.H-100&&x>rail+(v.W-rail)*.42f?5:0;return y>293&&y<v.H-66&&x>rail?(tab.equals("Presets")&&x<middle?4:5):0;}
 float offset(int region){return region==4?folderOffset:rowOffset;}
 int limit(int region){if(tab.equals("Clones"))return (int)Math.max(0,cloneRows().size()*44-(v.H-140-top));return (int)Math.max(0,region==4?(v.m.folders.size()+2)*44-(v.H-318):rows().size()*44-(v.H-66-top));}
 void scroll(int region,float value){if(region==4)folderOffset=Math.max(0,Math.min(value,limit(region)));else rowOffset=Math.max(0,Math.min(value,limit(region)));}
}
