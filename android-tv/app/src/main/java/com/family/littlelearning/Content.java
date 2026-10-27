package com.family.littlelearning;
import android.content.Context;
import org.json.*;
import java.util.*;
import java.nio.charset.StandardCharsets;
import static com.family.littlelearning.GameModel.*;

final class Content {
 JSONObject banks;JSONArray catalog;
 final List<Group> groups=new ArrayList<>();final List<Route> routes=new ArrayList<>();final Map<String,Integer> rewardValues=new HashMap<>();
 Content(Context c)throws Exception{
  JSONObject root;try(var in=c.getAssets().open("content.json")){java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream();byte[] bytes=new byte[8192];int n;while((n=in.read(bytes))!=-1)out.write(bytes,0,n);root=new JSONObject(out.toString("UTF-8"));}
  banks=root.optJSONObject("banks");catalog=root.optJSONArray("catalog");
  JSONArray gs=root.getJSONArray("arithmetic");
  for(int i=0;i<gs.length();i++){JSONObject g=gs.getJSONObject(i);JSONArray qs=g.getJSONArray("questions");List<Question> list=new ArrayList<>();for(int j=0;j<qs.length();j++){JSONObject q=qs.getJSONObject(j);Question v=new Question(q.getInt("start"),q.getInt("change"),q.getString("id"));list.add(v);rewardValues.put(v.id,1);}groups.add(new Group(g.getString("id"),g.getString("title"),g.getInt("limit"),list));}
  JSONArray rs=root.getJSONArray("routes");for(int i=0;i<rs.length();i++){JSONObject r=rs.getJSONObject(i);Set<Point> blocks=new HashSet<>();JSONArray bs=r.getJSONArray("obstacles");for(int j=0;j<bs.length();j++)blocks.add(point(bs.getJSONArray(j)));List<String> sol=strings(r.getJSONArray("solution"));Route route=new Route(r.getInt("index"),r.getInt("size"),point(r.getJSONArray("start")),point(r.getJSONArray("goal")),r.has("pickup")?point(r.getJSONArray("pickup")):null,blocks,sol,r.getString("id"));if(!route.trace(sol).success())throw new IllegalStateException("Invalid route content");routes.add(route);rewardValues.put(route.id,3);}
  JSONArray rewards=root.optJSONArray("rewards");if(rewards!=null)for(int i=0;i<rewards.length();i++){JSONObject r=rewards.getJSONObject(i);rewardValues.put(r.getString("id"),r.getInt("points"));}
  if(groups.size()!=3||routes.size()!=36)throw new IllegalStateException("Incomplete content");
 }
 static Point point(JSONArray a)throws JSONException{return new Point(a.getInt(0),a.getInt(1));}
 static List<String> strings(JSONArray a)throws JSONException{List<String> out=new ArrayList<>();for(int i=0;i<a.length();i++)out.add(a.getString(i));return out;}
}
