package com.family.littlelearning;
import android.content.*;
import org.json.*;
import java.io.*;
import java.util.*;
import static com.family.littlelearning.ExtraRules.*;

final class ExtendedChecks {
 static int checks;
 static void check(boolean value,String title){checks++;if(!value)throw new AssertionError(title);}
 static int run(Context context)throws Exception{
  checks=0;Content c=new Content(context);int challenges=0;
  File dir=new File(context.getFilesDir(),"extended-verification");dir.mkdirs();for(File f:Objects.requireNonNull(dir.listFiles()))f.delete();ContextWrapper isolated=new ContextWrapper(context){@Override public File getFilesDir(){return dir;}};Store store=new Store(isolated,c);
  for(int game=0;game<c.catalog.length();game++){JSONObject meta=c.catalog.getJSONObject(game);String key=meta.getString("key");JSONArray groups=meta.getJSONArray("groups");
   for(int g=0;g<groups.length();g++)for(int index:ints(groups.getJSONObject(g).getJSONArray("indices"))){JSONObject s=fresh(key,g,index,c),q=task(key,s,c);validate(key,s,c);check(!s.optBoolean("solved"),key+" fresh");
    switch(key){
     case "sharing":int[] values=new int[q.getInt("bowls")];Arrays.fill(values,q.getInt("total")/values.length);put(s,"values",arr(values));break;
     case "pinyin":case "characters":case "idioms":case "bakery":JSONArray chosen=new JSONArray();for(int i=0;i<q.getJSONArray("answer").length();i++)chosen.put(i);put(s,"chosen",chosen);if(q.getJSONArray("choices").length()>0){put(s,"follow",true);check(!satisfied(key,s,c),"follow-up must precede reward");put(s,"answer",q.getInt("correctChoice"));}break;
     case "clock":switch(q.getString("mode")){case "conversion":put(s,"answer",q.getInt("correctChoice"));break;case "seconds":put(s,"seconds",q.getInt("target"));break;default:put(s,"minutes",q.getInt("target"));}break;
     case "matches":put(s,"mask",q.getInt("solution"));check(!matchAccepts(q,q.getInt("initial")),"unchanged equation rejected");break;
     case "sorting":JSONArray solution=q.getJSONArray("solution");for(int i=0;i<solution.length();i++){JSONArray m=solution.getJSONArray(i);check(moveFruit(s,m.getInt(0),m.getInt(1)).isEmpty(),"original fruit move legal");}break;
     case "ruler":String mode=q.getString("mode");if(mode.equals("measure")||mode.equals("offset")){List<Integer> marks=ints(q.getJSONArray("marks"));boolean found=false;for(int origin=0;origin<=4;origin++){int a=q.getInt("objectStart")-origin,b=a+q.getInt("length");if(marks.contains(a)&&marks.contains(b)&&(!mode.equals("measure")||a==0)){put(s,"origin",origin);found=true;break;}}check(found,"ruler can align");put(s,"answer",q.getInt("length"));}else if(mode.equals("missingNumber"))put(s,"answer",q.getInt("blank"));else if(mode.equals("explore"))put(s,"found",cloneArray(q.getJSONArray("distances")));else{List<Integer> marks=ints(q.getJSONArray("marks"));outer:for(int a:marks)for(int b:marks)if(b-a==q.getInt("length")){put(s,"pair",arr(a,b));break outer;}}break;
     case "beads":JSONArray blanks=q.getJSONArray("blanks"),options=q.getJSONArray("options"),seq=q.getJSONArray("sequence"),answers=new JSONArray();for(int i=0;i<blanks.length();i++){String expected=seq.getJSONArray(blanks.getInt(i)).toString();int found=-1;for(int j=0;j<options.length();j++)if(options.getJSONArray(j).toString().equals(expected)){found=j;break;}check(found>=0,"bead available");answers.put(found);}put(s,"values",answers);break;
     case "tangram":put(s,"placements",cloneArray(q.getJSONArray("solution")));break;
    }
    check(satisfied(key,s,c),key+" solution "+index);put(s,"solved",true);validate(key,s,c);check(c.rewardValues.containsKey(q.getString("id")),"stable reward ID");challenges++;
    store.profiles[0].games.put(key,s.toString());
   }
   store.save();Store restored=new Store(isolated,c);check(restored.profiles[0].games.equals(store.profiles[0].games),key+" survives restart");
  }
  GameModel.Profile p=store.profiles[0];for(int i=0;i<5;i++){GameModel.Question question=c.groups.get(0).questions.get(i);p.award(question.id,"测试",1,1);}check(p.redeem("游玩时间",5,2),"time exchange deducts");GameModel.Receipt r=p.redemptions.get(0);r.id="playtime:"+r.id;p.funMillis=300000;check(!p.undo(r.id),"playtime cannot be refunded for free play");store.save();check(new Store(isolated,c).profiles[0].funMillis==300000,"shared play budget persists");
  // First-version JSON without games/funMillis continues to load without losing rewards.
  JSONObject legacy=new JSONObject(store.encode());for(int i=0;i<2;i++){JSONObject child=legacy.getJSONArray("children").getJSONObject(i);child.remove("games");child.remove("funMillis");}store.restore(legacy.toString());check(store.profiles[0].games.isEmpty()&&store.profiles[0].awards.size()==5,"v1 save compatibility");
  android.util.Log.i("LittleLearningTest","PASS: "+challenges+" extended group challenges, "+checks+" checks");return checks;
 }
}
