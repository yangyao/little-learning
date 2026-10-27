package com.family.littlelearning;
import android.app.AlertDialog;
import android.graphics.Color;
import android.net.Uri;
import android.util.AtomicFile;
import android.view.*;
import android.webkit.*;
import android.widget.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/** Sandboxed offline copies of the same two HTML5 games as iOS. */
final class FunGames {
 final MainActivity a;String key="";int owner=-1;WebView web;boolean ready,running;String error="";TextView time;long loadGeneration;
 FunGames(MainActivity a){this.a=a;}
 boolean bundled(String game){try(InputStream ignored=a.getAssets().open("webgames/"+game+"/index.html")){return true;}catch(IOException missing){return false;}}
 int bundledCount(){return (bundled("bubbles")?1:0)+(bundled("watermelon")?1:0);}
 boolean available(){return web!=null&&ready&&error.isEmpty();}
 AtomicFile file(int child,String game){File dir=new File(a.getFilesDir(),"webgames/"+child);dir.mkdirs();return new AtomicFile(new File(dir,game+".json"));}
 void open(String game){if(!game.equals(key)||owner!=a.child||web==null){pause();if(web!=null)web.destroy();key=game;owner=a.child;load();}a.extra.homeCategory="playing";a.previousGame=game;a.screen="fun";a.message="";a.render("play");}
 @SuppressWarnings("SetJavaScriptEnabled") void load(){ready=false;running=false;error="";long gen=++loadGeneration;final int child=owner;final String game=key;
  web=new WebView(a);WebSettings settings=web.getSettings();settings.setJavaScriptEnabled(true);settings.setDomStorageEnabled(false);settings.setAllowFileAccess(false);settings.setAllowContentAccess(false);settings.setBlockNetworkLoads(true);settings.setMediaPlaybackRequiresUserGesture(false);settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);web.setBackgroundColor(Color.rgb(247,242,234));
  web.addJavascriptInterface(new Object(){
   @JavascriptInterface public String initial(){try{return new String(file(child,game).readFully(),StandardCharsets.UTF_8);}catch(FileNotFoundException missing){return "null";}catch(Exception e){a.runOnUiThread(()->fail("本局进度读取失败，原存档已保留。"));return "null";}}
   @JavascriptInterface public void ready(){a.runOnUiThread(()->{if(gen!=loadGeneration)return;ready=true;pause();if(a.screen.equals("fun"))a.render("play");});}
   @JavascriptInterface public void save(String json){if(json==null||json.length()>1_000_000)return;a.runOnUiThread(()->{AtomicFile f=file(child,game);FileOutputStream out=null;try{new org.json.JSONObject(json);out=f.startWrite();out.write(json.getBytes(StandardCharsets.UTF_8));f.finishWrite(out);}catch(Exception e){if(out!=null)f.failWrite(out);fail("游戏场景保存失败，已暂停，原进度保留。");}});}
   @JavascriptInterface public void error(String text){a.runOnUiThread(()->{if(gen==loadGeneration)fail("游戏运行遇到问题："+text);});}
  },"FamilyTV");
  web.setWebViewClient(new WebViewClient(){@Override public boolean shouldOverrideUrlLoading(WebView view,WebResourceRequest request){return !"family.local".equals(request.getUrl().getHost());}@Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest request){Uri uri=request.getUrl();String path=uri.getPath();if(!"family.local".equals(uri.getHost())||path==null||!path.startsWith("/webgames/")||path.contains(".."))return denied();try{String ext=path.substring(path.lastIndexOf('.')+1);String mime=switch(ext){case "html"->"text/html";case "js"->"application/javascript";case "css"->"text/css";case "json"->"application/json";case "png"->"image/png";case "jpg","jpeg"->"image/jpeg";case "mp3"->"audio/mpeg";case "ogg"->"audio/ogg";default->"application/octet-stream";};return new WebResourceResponse(mime,"UTF-8",a.getAssets().open(path.substring(1)));}catch(IOException e){return denied();}}@Override public void onReceivedError(WebView view,WebResourceRequest r,WebResourceError e){if(web==view&&r.isForMainFrame())fail("无法载入离线游戏。没有开始计时。");}@Override public boolean onRenderProcessGone(WebView view,RenderProcessGoneDetail detail){if(web!=view){view.destroy();return true;}running=false;ready=false;if(view.getParent() instanceof android.view.ViewGroup parent)parent.removeView(view);view.destroy();if(web==view)web=null;error="游戏画面已停止，请重新载入。剩余时间和已保存进度保留。";if(a.screen.equals("fun")&&!a.blocked)a.render("reload");return true;}});
  web.setOnKeyListener((view,code,event)->{if(event.getAction()!=KeyEvent.ACTION_DOWN)return code==19||code==20||code==21||code==22||code==23||code==66;if(code==19||code==20){pause();a.render("play");return true;}if(code==21||code==22||code==23||code==66){if(running&&(event.getRepeatCount()==0||code==21||code==22))web.evaluateJavascript("window.tvControl('"+(code==21?"left":code==22?"right":"fire")+"')",null);return true;}return false;});
  web.loadUrl("https://family.local/webgames/"+key+"/index.html");a.handler.postDelayed(()->{if(gen==loadGeneration&&!ready&&web!=null)fail("游戏未能准备好，请重新载入。没有开始计时。");},25000);
 }
 WebResourceResponse denied(){return new WebResourceResponse("text/plain","UTF-8",404,"Not found",Collections.emptyMap(),new ByteArrayInputStream(new byte[0]));}
 void fail(String text){if(!error.isEmpty())return;error=text;pause();if(a.screen.equals("fun")&&!a.blocked)a.render("reload");}
 void pause(){running=false;if(web!=null)web.evaluateJavascript("window.familyPaused=true;if(window.familyGame)window.familyGame.setPaused(true);true",null);}
 void leave(){pause();}
 void charge(long elapsed){if(running&&available())a.profile().funMillis=Math.max(0,a.profile().funMillis-elapsed);}
 void afterTick(){if(running&&a.profile().funMillis==0){pause();a.message="游玩时间用完了，可用 5 积分兑换 5 分钟。";if(a.screen.equals("fun"))a.render("exchange-time");}if(time!=null&&a.child>=0)time.setText(label());}
 String label(){return String.format(Locale.ROOT,"游玩剩余 %d:%02d",a.profile().funMillis/60000,a.profile().funMillis/1000%60);}
 void start(){if(!available()){a.message="游戏还没准备好，不会扣游玩时间。";a.render("play");return;}if(a.profile().funMillis==0){exchange();return;}if(running){pause();a.render("play");return;}web.evaluateJavascript("window.familyPaused=false;window.familyGame.setPaused(false);true",result->{if(!"true".equals(result)){fail("游戏未能启动，已暂停。");return;}if(a.screen.equals("fun")&&a.active&&a.child==owner){running=true;a.lastTick=android.os.SystemClock.elapsedRealtime();a.render("web-game");}else pause();});}
 void exchange(){if(a.profile().funMillis>0){a.message="还有剩余游玩时间，用完后才能再兑换。";a.render("play");return;}if(a.profile().balance()<5){a.message="需要 5 积分；先去完成学习挑战吧。";a.render("play");return;}a.currentDialog=new AlertDialog.Builder(a).setTitle("用 5 积分兑换 5 分钟？").setMessage("泡泡龙和合成大西瓜共用，不增加本次总使用额度。").setNegativeButton("取消",null).setPositiveButton("确认兑换",(d,w)->{if(a.profile().funMillis==0&&a.nas!=null)a.nas.action("playTime","趣味游戏 · 5分钟",5,"",ok->{a.message=ok?"已兑换 5 分钟，选择开始。":a.message;if(a.screen.equals("fun"))a.render("play");if(!ok)a.nas.ToastMessage();});}).show();}
 void render(){a.heading(key.equals("bubbles")?"泡泡龙":"合成大西瓜","左右键"+(key.equals("bubbles")?"瞄准":"移动")+" · 确定"+(key.equals("bubbles")?"发射":"落下")+" · 上下键暂停并返回按钮");time=a.text(label(),17,MainActivity.MUTED);a.add(a.root,time,-1,28);
  android.widget.FrameLayout frame=new android.widget.FrameLayout(a);if(web!=null){if(web.getParent() instanceof android.view.ViewGroup parent)parent.removeView(web);web.setTag("web-game");frame.addView(web,new android.widget.FrameLayout.LayoutParams(-1,-1));}a.weighted(a.root,frame);
  a.feedback(!error.isEmpty()?error:!a.message.isEmpty()?a.message:ready?"本局得分不会换成学习积分。离开或暂停不扣游玩时间。":"离线游戏准备中，尚未开始计时…");android.widget.LinearLayout buttons=a.row();a.inRow(buttons,a.button(running?"暂停":ready?"开始／继续":"准备中","play",this::start),1);a.inRow(buttons,a.button("5 分换 5 分钟","exchange-time",this::exchange),1);a.inRow(buttons,a.button("重新载入","reload",()->{pause();if(web!=null)web.destroy();load();a.message="";a.render("play");}),1);a.add(a.root,buttons,-1,54);
 }
 void destroy(){pause();if(web!=null){web.destroy();web=null;}loadGeneration++;}
}
