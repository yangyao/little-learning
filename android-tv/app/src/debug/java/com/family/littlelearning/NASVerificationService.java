package com.family.littlelearning;
import android.app.Service;
import android.content.*;
import android.os.IBinder;
import android.view.View;
import org.json.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Headless verification; never opens an activity or changes the television display. */
public class NASVerificationService extends Service {
 static final class Harness extends MainActivity {
  final boolean production;
  Harness(Context context,boolean real)throws Exception{production=real;attachBaseContext(context);content=new Content(this);store=new Store(this,content);child=0;nas=new NASSync(this);}
  @Override public File getFilesDir(){File base=super.getFilesDir();if(production)return base;File f=new File(base,"nas-verification");f.mkdirs();return f;}
  @Override public void setContentView(View view){}
  @Override void fatal(String title,Exception e){throw new IllegalStateException(title,e);}
 }
 Harness a;int checks;
 void check(boolean value)throws Exception{checks++;if(!value)throw new Exception("Check "+checks+" failed");}
 JSONObject snapshot(Harness h)throws Exception{JSONObject children=new JSONObject();for(int i=0;i<2;i++)children.put(NASSync.CHILD_IDS[i],NASSync.ledger(h.store.profiles[i],NASSync.CHILD_IDS[i]));return new JSONObject().put("children",children);}
 void finish(String result){if(a!=null&&a.nas!=null)a.nas.close();try(FileOutputStream out=openFileOutput("nas-verification-result.txt",MODE_PRIVATE)){out.write(result.getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}android.util.Log.i("LittleLearningTest",result);stopSelf();}
 @Override public IBinder onBind(Intent i){return null;}
 @Override public int onStartCommand(Intent intent,int flags,int id){try{
  boolean production=intent.getBooleanExtra("production",false);a=new Harness(this,production);
  if(production){a.nas.sync(ok->{try{check(ok);check(a.store.syncPending==null);Store reloaded=new Store(a,a.content);check(reloaded.profiles[0].balance()==a.store.profiles[0].balance());finish("PASS production NAS sync: qianyi="+a.store.profiles[0].balance()+", zhenyi="+a.store.profiles[1].balance());}catch(Exception e){finish("FAIL: "+e);}});return START_NOT_STICKY;}
  a.store.profiles=new GameModel.Profile[]{new GameModel.Profile(),new GameModel.Profile()};
  int count=0;for(Map.Entry<String,Integer> reward:a.content.rewardValues.entrySet()){a.profile().award(reward.getKey(),reward.getKey(),reward.getValue(),System.currentTimeMillis());if(++count==15)break;}a.store.save();int balance=a.profile().balance();
  JSONObject response=snapshot(a);a.nas.apply(response,null);check(a.profile().balance()==balance);check(a.profile().funMillis==0);
  String spend=UUID.randomUUID().toString().toUpperCase(Locale.ROOT);JSONArray entries=response.getJSONObject("children").getJSONArray("qianyi");entries.put(NASSync.event(spend,System.currentTimeMillis(),"redemption","manual","书",-3));a.nas.apply(response,null);check(a.profile().balance()==balance-3);
  entries.put(NASSync.event(UUID.randomUUID().toString().toUpperCase(Locale.ROOT),System.currentTimeMillis(),"refund",spend,"撤销 · 书",3));a.nas.apply(response,null);check(a.profile().balance()==balance);check(a.profile().redemptions.get(0).undone);
  String purchase=UUID.randomUUID().toString().toUpperCase(Locale.ROOT);JSONObject pending=new JSONObject().put("id",purchase).put("child","qianyi").put("kind","playTime");a.store.syncPending=pending;a.store.save();
  check(new Store(a,a.content).syncPending.getString("id").equals(purchase));
  entries.put(NASSync.event(purchase,System.currentTimeMillis(),"playTime","play-time:5-minutes","趣味游戏 · 5分钟",-5));a.nas.apply(response,pending);check(a.profile().balance()==balance-5);check(a.profile().funMillis==300000);check(a.store.syncPending==null);
  a.profile().funMillis-=12345;a.store.save();a.nas.apply(response,pending);check(a.profile().funMillis==287655);check(new Store(a,a.content).profiles[0].funMillis==287655);
  // A remote purchase must not grant local play minutes.
  String remote=UUID.randomUUID().toString().toUpperCase(Locale.ROOT);entries.put(NASSync.event(remote,System.currentTimeMillis(),"playTime","play-time:5-minutes","趣味游戏 · 5分钟",-5));a.nas.apply(response,null);check(a.profile().funMillis==287655);
  // Missing spending causes no mutation; newly earned local awards survive an in-flight request.
  String before=a.store.encode();JSONObject empty=new JSONObject().put("children",new JSONObject().put("qianyi",new JSONArray()).put("zhenyi",new JSONArray()));boolean rejected=false;try{a.nas.apply(empty,null);}catch(Exception e){rejected=true;}check(rejected);check(before.equals(a.store.encode()));
  for(Map.Entry<String,Integer> reward:a.content.rewardValues.entrySet())if(!a.profile().awards.containsKey(reward.getKey())){a.profile().award(reward.getKey(),reward.getKey(),reward.getValue(),System.currentTimeMillis());break;}
  int newCount=a.profile().awards.size();a.nas.apply(response,null);check(a.profile().awards.size()==newCount);
  check(NASSync.stableID("qianyi:numberLine:3:2").equals("0A3E2B6A-C1E0-3601-9279-CBC87FA02DAB"));
  finish("PASS: "+checks+" NAS canonical ledger, refund, retry persistence, exactly-once grants, remote time isolation, atomic conflict and in-flight awards checks");
 }catch(Throwable e){android.util.Log.e("LittleLearningTest","NAS checks failed",e);finish("FAIL: "+e);}return START_NOT_STICKY;}
}
