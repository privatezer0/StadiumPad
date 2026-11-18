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
 int folder=-2,selected=-1;
 float folderOffset=0,rowOffset=0,rail,middle,top=265;
 final String[] tabs={"Presets","Cab IRs","Favorites","Templates","Songs","Clones"};
 LibrarianView(EditorView view){v=view;}
 int color(){return tab.equals("Clones")?0xffff3737:tab.equals("Cab IRs")?0xffff3594:tab.equals("Songs")?0xff20ad99:tab.equals("Favorites")?v.GREY:v.GOLD;}
 List<Object> rows(){
  List<Object> source=null;
  if(tab.equals("Presets"))for(Monitor.Folder f:v.m.folders)if(f.id==folder)source=f.presets;
  int cid=tab.equals("Presets")?folder:tab.equals("Cab IRs")?-3:tab.equals("Favorites")?-8:tab.equals("Templates")?-4:-7;
  if(source==null)source=v.m.inventory.getOrDefault(cid,Collections.emptyList());
  List<Object> result=new ArrayList<>();
  for(Object row:source)if(n(get(row,"cid_"))>0&&(!tab.equals("Presets")||n(get(row,"type"))==2)&&(search.isEmpty()||s(get(row,"name")).toLowerCase(Locale.ROOT).contains(search.toLowerCase(Locale.ROOT))))result.add(row);
  return result;
 }
 void draw(){
  rail=v.W<1150?168:205;middle=rail+(v.W<1150?270:330);int color=color();
  v.rect(0,154,rail,v.H-178,0xff141416);
  for(int i=0;i<tabs.length;i++){String name=tabs[i];int c=i==1?0xffff3594:i==2?v.GREY:i==4?0xff20ad99:i==5?0xffff3737:v.GOLD;float y=163+i*66;v.box(6,y,rail-12,64,v.alpha(c,tab.equals(name)?80:22),0,8);v.text(name,22,y+40,24,c,rail-35);v.hit(6,y,rail-12,64,name,"library",()->{tab=name;search="";selected=-1;folderOffset=rowOffset=0;v.invalidate();});}
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
 void clones(){tools(rail+10,166,new String[]{"New Folder","Delete","Rename","Export","Import"},90);float split=rail+(v.W-rail)*.42f;String[] names={"Amp","Amp+Cab","Distortion","Preamp"};for(int i=0;i<names.length;i++){String name=names[i];float y=238+i*46;v.text("▱  "+name,rail+14,y+29,21,color(),split-rail-28);v.hit(rail,y,split-rail,46,name,"library",()->{cloneCategory=name;v.invalidate();});}v.line(split,233,split,v.H-66,v.BORDER,1);v.text(cloneCategory,split+20,273,24,color(),v.W-split-40);v.text("Clone transfers need an authenticated file connection.",split+20,313,15,v.GREY,v.W-split-40);v.text("Transfer setup is being implemented.",split+20,342,15,v.GREY,v.W-split-40);v.text("User Clones  ›  "+cloneCategory,rail+16,v.H-40,15,color(),v.W-rail-32);}
 void search(){EditText field=new EditText(v.activity);field.setSingleLine(true);field.setText(search);new AlertDialog.Builder(v.activity).setTitle("Search "+tab).setView(field).setNegativeButton("Cancel",null).setNeutralButton("Clear",(d,w)->{search="";rowOffset=0;v.invalidate();}).setPositiveButton("Search",(d,w)->{search=field.getText().toString();rowOffset=0;v.invalidate();}).show();}
 int region(float x,float y){return !tab.equals("Clones")&&y>293&&y<v.H-66&&x>rail?(tab.equals("Presets")&&x<middle?4:5):0;}
 float offset(int region){return region==4?folderOffset:rowOffset;}
 int limit(int region){return (int)Math.max(0,region==4?(v.m.folders.size()+2)*44-(v.H-318):rows().size()*44-(v.H-66-top));}
 void scroll(int region,float value){if(region==4)folderOffset=Math.max(0,Math.min(value,limit(region)));else rowOffset=Math.max(0,Math.min(value,limit(region)));}
}
