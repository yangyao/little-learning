package com.family.littlelearning;
import android.app.Service;
import android.content.*;
import android.graphics.*;
import android.os.IBinder;
import android.view.*;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import static com.family.littlelearning.ExtraRules.*;

/** Renders and exercises the real native layouts without taking over the television screen. */
public class NativeVerificationService extends Service {
 static final class Harness extends MainActivity {
  Harness(Context c)throws Exception{attachBaseContext(c);content=new Content(this);store=new Store(this,content);store.profiles=new GameModel.Profile[]{new GameModel.Profile(),new GameModel.Profile()};extra=new ExtraGames(this);fun=new FunGames(this);child=0;}
  @Override public Object getSystemService(String name){return getBaseContext().getSystemService(name);}
  @Override public android.content.res.Resources.Theme getTheme(){return getBaseContext().getTheme();}
  @Override public File getFilesDir(){File f=new File(super.getFilesDir(),"native-verification");f.mkdirs();return f;}
  @Override public void setContentView(View view){}
  @Override void fatal(String title,Exception e){throw new IllegalStateException(title,e);}
 }
 Harness a;int actions;
 void click(String tag){View v=a.root.findViewWithTag(tag);if(v==null||!v.performClick())throw new AssertionError("Missing control "+tag);actions++;}
 void capture(String name)throws Exception{a.root.measure(View.MeasureSpec.makeMeasureSpec(1920,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(1080,View.MeasureSpec.EXACTLY));a.root.layout(0,0,1920,1080);Bitmap b=Bitmap.createBitmap(1920,1080,Bitmap.Config.ARGB_8888);a.root.draw(new Canvas(b));try(FileOutputStream out=new FileOutputStream(new File(a.getFilesDir(),name+".png"))){b.compress(Bitmap.CompressFormat.PNG,90,out);}b.recycle();}
 @Override public IBinder onBind(Intent i){return null;}
 @Override public int onStartCommand(Intent i,int flags,int id){String result;try{a=new Harness(this);a.screen="children";a.child=-1;a.render("child-0");capture("avatars");a.child=0;
  for(int g=0;g<a.content.catalog.length();g++){String key=a.content.catalog.getJSONObject(g).getString("key");a.extra.key=key;a.previousGame=key;int index=groups(key,a.content).getJSONObject(0).getJSONArray("indices").getInt(0);a.profile().games.put(key,fresh(key,0,index,a.content).toString());a.screen="extra";a.extra.editing=false;a.message="";a.render("check");JSONObject s=a.extra.state(),q=task(key,s,a.content);capture(key);
   switch(key){
    case "pinyin":case "characters":case "idioms":case "bakery":List<Integer> order=order(pool(q).size(),index+key.hashCode());for(int n=0;n<q.getJSONArray("answer").length();n++)click("tile-"+order.indexOf(n));click("check");if(q.getJSONArray("choices").length()>0){if(a.extra.state().optBoolean("solved"))throw new AssertionError("Premature reward");int choice=order(q.getJSONArray("choices").length(),index+key.hashCode()).indexOf(q.getInt("correctChoice"));click("choice-"+choice);}break;
    case "sharing":for(int bowl=0;bowl<q.getInt("bowls");bowl++)for(int n=0;n<q.getInt("total")/q.getInt("bowls");n++)click("bowl-"+bowl);click("check");break;
    case "clock":int turns=Math.floorMod(q.getInt("target")-q.getInt("start"),720)/60;for(int n=0;n<turns;n++)click("nudge-1");click("check");break;
    case "ruler":for(int n=0;n<q.getInt("objectStart");n++)click("ruler-1");click("answer-"+q.getInt("length"));click("check");break;
    case "matches":int from=Integer.numberOfTrailingZeros(q.getInt("initial")&~q.getInt("solution")),to=Integer.numberOfTrailingZeros(q.getInt("solution")&~q.getInt("initial"));click("edit-board");for(int n=0;n<from;n++)a.extra.boardKey(22);a.extra.boardKey(23);for(int n=0;n<Math.floorMod(to-from,23);n++)a.extra.boardKey(22);a.extra.boardKey(23);a.extra.boardKey(4);click("check");break;
    case "sorting":JSONArray moves=q.getJSONArray("solution");for(int n=0;n<moves.length();n++){JSONArray m=moves.getJSONArray(n);click("jar-"+m.getInt(0));click("jar-"+m.getInt(1));}click("check");break;
    case "tangram":JSONArray pieces=q.getJSONArray("solution");for(int n=0;n<7;n++){click("piece-"+n);click("edit-board");JSONArray p=pieces.getJSONArray(n);for(int x=0;x<p.getInt(0);x++)a.extra.boardKey(22);for(int y=0;y<p.getInt(1);y++)a.extra.boardKey(20);a.extra.boardKey(23);}click("check");break;
    case "beads":JSONArray blanks=q.getJSONArray("blanks"),options=q.getJSONArray("options"),seq=q.getJSONArray("sequence");for(int n=0;n<blanks.length();n++){click("blank-"+n);String expected=seq.getJSONArray(blanks.getInt(n)).toString();for(int o=0;o<options.length();o++)if(options.getJSONArray(o).toString().equals(expected)){click("bead-"+o);break;}}click("check");break;
   }if(!a.extra.state().optBoolean("solved"))throw new AssertionError("UI did not solve "+key+": "+a.message);capture(key+"-solved");android.util.Log.i("LittleLearningTest","Native controls passed: "+key);
  }
  new Store(a,a.content);result="PASS: 11 real native game layouts, "+actions+" control clicks, saved solved states restored";
 }catch(Throwable e){result="FAIL: "+e;android.util.Log.e("LittleLearningTest",result,e);}try(FileOutputStream out=openFileOutput("native-verification-result.txt",MODE_PRIVATE)){out.write(result.getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}android.util.Log.i("LittleLearningTest",result);stopSelf();return START_NOT_STICKY;}
}
