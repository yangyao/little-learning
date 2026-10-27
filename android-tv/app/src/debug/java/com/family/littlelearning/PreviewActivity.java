package com.family.littlelearning;
import android.os.Bundle;
import java.io.File;
import org.json.*;
/** Debug-only TV interaction sandbox. Production family progress is never used. */
public class PreviewActivity extends MainActivity {
 @Override public File getFilesDir(){File dir=new File(super.getFilesDir(),"ui-verification");dir.mkdirs();return dir;}
 @Override public void onCreate(Bundle saved){super.onCreate(saved);if(blocked)return;child=0;lastTick=android.os.SystemClock.elapsedRealtime();String game=getIntent().getStringExtra("game");if(game==null||game.equals("children")){child=-1;screen="children";render("child-0");return;}if(game.equals("home")){screen="home";render("math-card");return;}if(game.equals("bubbles")||game.equals("watermelon")){for(int i=0;i<5;i++){GameModel.Question q=content.groups.get(0).questions.get(i);profile().award(q.id,q.equation(),1,System.currentTimeMillis());}profile().funMillis=getIntent().getBooleanExtra("noBudget",false)?0:300000;fun.open(game);return;}extra.key=game;previousGame=game;int group=getIntent().getIntExtra("group",0),index=getIntent().getIntExtra("index",-1);if(index<0)index=ExtraRules.groups(game,content).optJSONObject(group).optJSONArray("indices").optInt(0);profile().games.put(game,ExtraRules.fresh(game,group,index,content).toString());screen="extra";render("check");}
}
