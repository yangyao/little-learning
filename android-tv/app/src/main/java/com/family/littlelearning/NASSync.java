package com.family.littlelearning;

import org.json.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import static com.family.littlelearning.GameModel.*;

/** Immutable ledger sync. Only the server can authorize new spending. */
final class NASSync {
 static final String[] CHILD_IDS={"qianyi","zhenyi"};
 final MainActivity a;final ExecutorService executor=Executors.newSingleThreadExecutor();
 boolean busy,closed;String status="离线可用 · 等待同步";final String url,token;final boolean configured;
 final Runnable periodic=new Runnable(){public void run(){if(closed)return;sync(null);a.handler.postDelayed(this,30000);}};
 final Runnable debounce=()->sync(null);
 NASSync(MainActivity owner){
  a=owner;String candidateURL="",candidateToken="";boolean valid=false;status="离线可用 · 尚未配置NAS";
  try(InputStream in=a.getAssets().open("nas-config.json")){
   JSONObject config=new JSONObject(new String(read(in,16384),StandardCharsets.UTF_8));candidateURL=config.getString("url");candidateToken=config.getString("token");URI endpoint=new URI(candidateURL);
   valid=("http".equals(endpoint.getScheme())||"https".equals(endpoint.getScheme()))&&endpoint.getHost()!=null&&endpoint.getUserInfo()==null&&endpoint.getQuery()==null&&endpoint.getFragment()==null&&candidateToken.length()>=32;
   status=valid?"离线可用 · 等待同步":"离线可用 · NAS配置无效";
  }catch(FileNotFoundException missing){/* Credentials are deliberately absent from public source. */}
  catch(Exception invalid){status="离线可用 · NAS配置无效";}
  url=candidateURL;token=candidateToken;configured=valid;
 }
 void resume(){if(!configured)return;a.handler.removeCallbacks(periodic);a.handler.post(periodic);}
 void close(){closed=true;a.handler.removeCallbacks(periodic);a.handler.removeCallbacks(debounce);executor.shutdown();}
 void awardsChanged(){a.handler.removeCallbacks(debounce);a.handler.postDelayed(debounce,500);}
 static byte[] read(InputStream in,int limit)throws IOException{ByteArrayOutputStream out=new ByteArrayOutputStream();byte[] buffer=new byte[8192];int n;while((n=in.read(buffer))!=-1){if(out.size()+n>limit)throw new IOException("Response too large");out.write(buffer,0,n);}return out.toByteArray();}
 static String canonicalID(String id){return id.replaceFirst("^playtime:","").toUpperCase(Locale.ROOT);}
 static String stableID(String text){return UUID.nameUUIDFromBytes(text.getBytes(StandardCharsets.UTF_8)).toString().toUpperCase(Locale.ROOT);}
 static JSONObject event(String id,long date,String kind,String reference,String title,int amount)throws JSONException{return new JSONObject().put("id",id).put("date",date).put("kind",kind).put("reference",reference).put("title",title).put("amount",amount);}
 static JSONArray ledger(Profile p,String child)throws JSONException{
  JSONArray out=new JSONArray();for(Receipt r:p.awards.values())out.put(event(stableID(child+":"+r.id),r.at,"award",r.id,r.title,r.points));
  for(Receipt r:p.redemptions){String id=canonicalID(r.id);boolean play=r.id.startsWith("playtime:");out.put(event(id,r.at,play?"playTime":"redemption",play?"play-time:5-minutes":"manual",r.title,-r.points));if(r.undone)out.put(event(stableID("refund:"+child+":"+id),r.at,"refund",id,"撤销 · "+r.title,r.points));}return out;
 }
 JSONObject request()throws JSONException{JSONObject children=new JSONObject();for(int i=0;i<2;i++)children.put(CHILD_IDS[i],ledger(a.store.profiles[i],CHILD_IDS[i]));return new JSONObject().put("device",a.store.syncDeviceID).put("children",children).put("operation",a.store.syncPending);}
 interface Completion{void done(boolean success);}
 void action(String kind,String title,int points,String reference,Completion completion){
  if(!configured){a.message="请先配置家中NAS，学习和得分仍可离线使用。";ToastMessage();completion.done(false);return;}
  if(busy||a.store.syncPending!=null){a.message="上次请求正在确认，联网后会自动恢复。";ToastMessage();sync(null);completion.done(false);return;}
  try{JSONObject op=new JSONObject().put("id",UUID.randomUUID().toString().toUpperCase(Locale.ROOT)).put("child",CHILD_IDS[a.child]).put("kind",kind).put("title",title).put("points",points).put("reference",reference);
   if(!a.change(()->a.store.syncPending=op)){completion.done(false);return;}sync(completion);
  }catch(Exception e){a.message="请求无法保存，没有发送兑换。";ToastMessage();completion.done(false);}
 }
 void ToastMessage(){android.widget.Toast.makeText(a,a.message,android.widget.Toast.LENGTH_LONG).show();}
 void sync(Completion completion){
  if(!configured){updateLabels();if(completion!=null)completion.done(false);return;}
  if(closed||a.blocked||busy){if(completion!=null)completion.done(false);return;}
  final String payload;final JSONObject pending;
  try{if(!a.change(()->{})){if(completion!=null)completion.done(false);return;}pending=a.store.syncPending;payload=request().toString();}catch(Exception e){status="本机记录已保留 · 同步待处理";if(completion!=null)completion.done(false);return;}
  busy=true;status="正在同步…";updateLabels();
  executor.execute(()->{JSONObject response=null;Exception failure=null;HttpURLConnection connection=null;
   try{connection=(HttpURLConnection)new URL(url+"/v1/sync").openConnection();connection.setConnectTimeout(5000);connection.setReadTimeout(8000);connection.setInstanceFollowRedirects(false);connection.setRequestMethod("POST");connection.setRequestProperty("Authorization","Bearer "+token);connection.setRequestProperty("Content-Type","application/json");connection.setDoOutput(true);byte[] bytes=payload.getBytes(StandardCharsets.UTF_8);connection.setFixedLengthStreamingMode(bytes.length);try(OutputStream out=connection.getOutputStream()){out.write(bytes);}int code=connection.getResponseCode();if(code!=200&&code!=409)throw new IOException("HTTP "+code);try(InputStream in=code==200?connection.getInputStream():connection.getErrorStream()){byte[] data=read(in,4*1024*1024);if(data.length>4*1024*1024)throw new IOException("Response too large");response=new JSONObject(new String(data,StandardCharsets.UTF_8));}}
   catch(Exception e){failure=e;}finally{if(connection!=null)connection.disconnect();}
   final JSONObject result=response;final Exception error=failure;a.handler.post(()->{
    if(closed)return;boolean success=false;
    if(error!=null){status="离线可用 · 本机记录已保存";}
    else try{apply(result,pending);success=!result.has("error");status=success?"已同步":"已同步 · 兑换未成功";if(result.has("error"))a.message=result.getString("error");}
    catch(Exception e){status="离线可用 · 历史记录待核对";android.util.Log.e("NASSync","Canonical ledger rejected; retained local save",e);}
    busy=false;updateLabels();if(completion!=null){if(!success&&a.store.syncPending!=null)a.message="暂时无法确认，本次请求已保存；联网后自动恢复，不会重复扣分。";completion.done(success);}
   });
  });
 }
 void updateLabels(){if(a.root==null||a.child<0)return;android.view.View v=a.root.findViewWithTag("points");if(v instanceof android.widget.TextView)((android.widget.TextView)v).setText(CHILDREN[a.child]+" · "+a.profile().balance()+" 积分");v=a.root.findViewWithTag("sync-status");if(v instanceof android.widget.TextView)((android.widget.TextView)v).setText(status+" · 兑换需连接家中NAS");}
 void apply(JSONObject response,JSONObject pending)throws Exception{
  JSONObject children=response.getJSONObject("children");if(children.length()!=2)throw new IOException("Invalid children");
  @SuppressWarnings("unchecked") LinkedHashMap<String,Receipt>[] awards=new LinkedHashMap[2];
  @SuppressWarnings("unchecked") List<Receipt>[] spent=new List[2];boolean[] grants=new boolean[2];
  for(int i=0;i<2;i++){JSONArray entries=children.getJSONArray(CHILD_IDS[i]);awards[i]=new LinkedHashMap<>();spent[i]=new ArrayList<>();Map<String,Receipt> byID=new HashMap<>();List<JSONObject> refunds=new ArrayList<>();Set<String> ids=new HashSet<>();
   for(int j=0;j<entries.length();j++){JSONObject e=entries.getJSONObject(j);String id=e.getString("id").toUpperCase(Locale.ROOT),kind=e.getString("kind"),ref=e.getString("reference"),title=e.getString("title");int amount=e.getInt("amount");long date=e.getLong("date");UUID.fromString(id);if(!ids.add(id)||date<0||title.trim().isEmpty())throw new IOException("Invalid event");
    if(kind.equals("award")){Integer points=a.content.rewardValues.get(ref);if(points==null||points!=amount||awards[i].containsKey(ref))throw new IOException("Invalid award");awards[i].put(ref,new Receipt(ref,title,amount,date,false));}
    else if(kind.equals("redemption")||kind.equals("playTime")){boolean play=kind.equals("playTime");if(amount>=0||amount< -1000000||(play&&(amount!= -5||!ref.equals("play-time:5-minutes"))))throw new IOException("Invalid spending");Receipt r=new Receipt(play?"playtime:"+id:id,title,-amount,date,false);spent[i].add(r);byID.put(id,r);}
    else if(kind.equals("refund")){refunds.add(e);}else throw new IOException("Unknown event");
   }
   for(JSONObject e:refunds){Receipt r=byID.get(e.getString("reference").toUpperCase(Locale.ROOT));if(r==null||r.undone||r.id.startsWith("playtime:")||r.points!=e.getInt("amount"))throw new IOException("Invalid refund");r.undone=true;}
   spent[i].sort((left,right)->Long.compare(left.at,right.at));
   Profile local=a.store.profiles[i];for(Receipt r:local.redemptions)if(!byID.containsKey(canonicalID(r.id)))throw new IOException("Historical spend not imported");
   for(Receipt r:local.awards.values())awards[i].putIfAbsent(r.id,r);
   long balance=0;for(Receipt r:awards[i].values())balance+=r.points;for(Receipt r:spent[i])if(!r.undone)balance-=r.points;if(balance<0||balance>1000000)throw new IOException("Invalid balance");
   grants[i]=!response.has("error")&&pending!=null&&pending.getString("kind").equals("playTime")&&pending.getString("child").equals(CHILD_IDS[i])&&byID.containsKey(pending.getString("id"))&&!local.syncPlayGrants.contains(pending.getString("id"));
   if(grants[i]&&local.funMillis!=0)throw new IOException("Unconsumed play time");
  }
  if(!a.change(()->{for(int i=0;i<2;i++){Profile p=a.store.profiles[i];p.awards.clear();p.awards.putAll(awards[i]);p.redemptions.clear();p.redemptions.addAll(spent[i]);if(grants[i]){p.funMillis=300000;p.syncPlayGrants.add(pending.optString("id"));}}a.store.syncPending=null;}))throw new IOException("Failed to commit sync");
  JSONObject diagnostic=new JSONObject().put("status","synced").put("date",System.currentTimeMillis()).put("pending",a.store.syncPending!=null).put("balances",new JSONObject().put("qianyi",a.store.profiles[0].balance()).put("zhenyi",a.store.profiles[1].balance()));
  try(FileOutputStream out=new FileOutputStream(new File(a.getFilesDir(),"nas-sync-status.json"))){out.write(diagnostic.toString().getBytes(StandardCharsets.UTF_8));}catch(IOException ignored){}
 }
}
