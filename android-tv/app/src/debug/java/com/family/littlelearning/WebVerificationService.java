package com.family.littlelearning;
import android.app.Service;
import android.content.Intent;
import android.os.*;
import android.view.*;
import android.webkit.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Offscreen WebView smoke checks. No activity is shown and game audio is muted. */
public class WebVerificationService extends Service {
 WebView web;final Handler h=new Handler(Looper.getMainLooper());String game;boolean done;
 @Override public IBinder onBind(Intent intent){return null;}
 @Override public int onStartCommand(Intent intent,int flags,int id){game=intent.getStringExtra("game");done=false;web=new WebView(this);web.measure(View.MeasureSpec.makeMeasureSpec(880,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(660,View.MeasureSpec.EXACTLY));web.layout(0,0,880,660);web.getSettings().setJavaScriptEnabled(true);web.getSettings().setAllowFileAccess(false);web.getSettings().setBlockNetworkLoads(true);web.getSettings().setMediaPlaybackRequiresUserGesture(false);
  web.addJavascriptInterface(new Object(){@JavascriptInterface public String initial(){return "null";}@JavascriptInterface public void save(String state){}@JavascriptInterface public void error(String error){h.post(()->finish("FAIL: "+error));}@JavascriptInterface public void ready(){h.postDelayed(()->test(),250);}},"FamilyTV");
  web.setWebViewClient(new WebViewClient(){@Override public WebResourceResponse shouldInterceptRequest(WebView w,WebResourceRequest r){String path=r.getUrl().getPath();try{if(!"family.local".equals(r.getUrl().getHost())||path==null||path.contains(".."))throw new IOException();String type=path.endsWith(".js")?"application/javascript":path.endsWith(".html")?"text/html":path.endsWith(".css")?"text/css":path.endsWith(".json")?"application/json":path.endsWith(".png")?"image/png":"application/octet-stream";return new WebResourceResponse(type,"UTF-8",getAssets().open(path.substring(1)));}catch(Exception e){return new WebResourceResponse("text/plain","UTF-8",404,"Missing",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}}});web.loadUrl("https://family.local/webgames/"+game+"/index.html");h.postDelayed(()->finish("FAIL: ready timeout"),25000);return START_NOT_STICKY;
 }
 void test(){if(done)return;String script=game.equals("bubbles")?"(function(){let g=familyGame.snapshot();if(!g||!g.state||!g.state.bubbles.length)return 'missing board';window.familyPaused=false;familyGame.setPaused(false);let before=g.state.angle;tvControl('left');if(g.state.angle===before)return 'aim failed';tvControl('fire');if(!g.state.projectile)return 'fire failed';familyPaused=true;familyGame.setPaused(true);return 'PASS: ready, populated board, aim, fire, pause';})()":"(function(){if(!familyGame.snapshot())return 'missing scene';cc.audioEngine.setEffectsVolume(0);cc.audioEngine.setMusicVolume(0);window.familyPaused=false;familyGame.setPaused(false);let g=__require('GameFunction').default.Instance;let x=g.targetFruit.x;tvControl('left');if(g.targetFruit.x===x)return 'move failed';tvControl('fire');if(g.targetFruit!==null)return 'drop failed';window.familyPaused=true;familyGame.setPaused(true);return 'PASS: ready, scene, move, drop, pause';})()";web.evaluateJavascript(script,result->finish(result));}
 void finish(String result){if(done)return;done=true;try(FileOutputStream out=openFileOutput("web-verification-"+game+".txt",MODE_PRIVATE)){out.write(result.getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}android.util.Log.i("LittleLearningTest",game+": "+result);if(web!=null){web.destroy();web=null;}stopSelf();}
 @Override public void onDestroy(){h.removeCallbacksAndMessages(null);if(web!=null)web.destroy();super.onDestroy();}
}
