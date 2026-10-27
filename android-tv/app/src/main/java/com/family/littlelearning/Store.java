package com.family.littlelearning;
import android.content.Context;
import android.util.AtomicFile;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import static com.family.littlelearning.GameModel.*;

/** One atomic family document: a solved question and its reward commit together. */
final class Store {
 String syncDeviceID=UUID.randomUUID().toString();JSONObject syncPending;final AtomicFile file;final Content content;Profile[] profiles={new Profile(),new Profile()};
 Store(Context context,Content c)throws Exception{content=c;file=new AtomicFile(new File(context.getFilesDir(),"family-tv-v1.json"));if(file.getBaseFile().exists()||new File(file.getBaseFile()+".bak").exists())restore(new String(file.readFully(),StandardCharsets.UTF_8));}
 String encode()throws JSONException{
  JSONObject root=new JSONObject().put("version",1).put("syncDeviceID",syncDeviceID).put("syncPending",syncPending);JSONArray children=new JSONArray();for(Profile p:profiles){JSONObject v=new JSONObject().put("arithmeticGroup",p.arithmeticGroup).put("question",p.question).put("position",p.position).put("arithmeticSolved",p.arithmeticSolved).put("routeGroup",p.routeGroup).put("route",p.route).put("routeSolved",p.routeSolved).put("commands",new JSONArray(p.commands)).put("games",new JSONObject(p.games)).put("syncPlayGrants",new JSONArray(p.syncPlayGrants)).put("funMillis",p.funMillis).put("used",p.used).put("restUntil",p.restUntil);
   JSONArray awards=new JSONArray(),redemptions=new JSONArray();for(Receipt r:p.awards.values())awards.put(receipt(r));for(Receipt r:p.redemptions)redemptions.put(receipt(r));v.put("awards",awards).put("redemptions",redemptions);children.put(v);}
  return root.put("children",children).toString();
 }
 JSONObject receipt(Receipt r)throws JSONException{return new JSONObject().put("id",r.id).put("title",r.title).put("points",r.points).put("at",r.at).put("undone",r.undone);}
 Receipt readReceipt(JSONObject r)throws JSONException{return new Receipt(r.getString("id"),r.getString("title"),r.getInt("points"),r.getLong("at"),r.getBoolean("undone"));}
 void restore(String json)throws Exception{
  JSONObject root=new JSONObject(json);if(root.getInt("version")!=1)throw new IOException("Unknown save version");syncDeviceID=root.optString("syncDeviceID",syncDeviceID);syncPending=root.optJSONObject("syncPending");JSONArray children=root.getJSONArray("children");if(children.length()!=2)throw new IOException("Invalid children");Profile[] loaded=new Profile[2];
  for(int n=0;n<2;n++){JSONObject v=children.getJSONObject(n);Profile p=new Profile();JSONArray grants=v.optJSONArray("syncPlayGrants");if(grants!=null)for(int i=0;i<grants.length();i++)p.syncPlayGrants.add(grants.getString(i));p.arithmeticGroup=v.getInt("arithmeticGroup");p.question=v.getInt("question");p.position=v.getInt("position");p.arithmeticSolved=v.getBoolean("arithmeticSolved");p.routeGroup=v.getInt("routeGroup");p.route=v.getInt("route");p.routeSolved=v.getBoolean("routeSolved");p.commands.addAll(Content.strings(v.getJSONArray("commands")));p.funMillis=v.optLong("funMillis",0);if(p.funMillis<0||p.funMillis>300000)throw new IOException("Invalid fun time");JSONObject games=v.optJSONObject("games");if(games!=null){Iterator<String> keys=games.keys();while(keys.hasNext()){String key=keys.next();String state=games.getString(key);ExtraRules.validate(key,new JSONObject(state),content);p.games.put(key,state);}}p.used=v.getLong("used");p.restUntil=v.getLong("restUntil");
   JSONArray awards=v.getJSONArray("awards"),redemptions=v.getJSONArray("redemptions");for(int i=0;i<awards.length();i++){Receipt r=readReceipt(awards.getJSONObject(i));if(!content.rewardValues.containsKey(r.id)||content.rewardValues.get(r.id)!=r.points||p.awards.put(r.id,r)!=null)throw new IOException("Invalid reward");}
   Set<String> redeemedIDs=new HashSet<>();for(int i=0;i<redemptions.length();i++){Receipt r=readReceipt(redemptions.getJSONObject(i));if(r.points<1||r.title.trim().isEmpty()||!redeemedIDs.add(r.id))throw new IOException("Invalid redemption");p.redemptions.add(r);}
   if(p.balance()<0||p.arithmeticGroup< -1||p.arithmeticGroup>=3||p.routeGroup< -1||p.routeGroup>=3||p.route<0||p.route>=36||p.commands.size()>40||!Arrays.asList(COMMANDS).containsAll(p.commands)||p.used<0||p.used>BUDGET||p.restUntil<0||(p.restUntil>0)!=(p.used==BUDGET))throw new IOException("Invalid progress");
   if(p.arithmeticGroup>=0){Group g=content.groups.get(p.arithmeticGroup);if(p.question<0||p.question>=g.questions.size()||p.position<0||p.position>g.limit||(p.arithmeticSolved&&p.position!=g.questions.get(p.question).answer()))throw new IOException("Invalid arithmetic");}else if(p.arithmeticSolved)throw new IOException("No arithmetic group");
   if(p.routeGroup>=0&&p.route/12!=p.routeGroup)throw new IOException("Invalid route group");if(p.routeSolved&&!content.routes.get(p.route).trace(p.commands).success())throw new IOException("Invalid route solution");loaded[n]=p;
  }profiles=loaded;
 }
 void save()throws Exception{byte[] data=encode().getBytes(StandardCharsets.UTF_8);FileOutputStream out=null;try{out=file.startWrite();out.write(data);file.finishWrite(out);}catch(Exception e){if(out!=null)file.failWrite(out);throw e;}}
}
