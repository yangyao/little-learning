package com.family.littlelearning;
import android.app.Service;
import android.content.Intent;
import android.os.*;
import android.view.KeyEvent;
import java.io.*;
import java.nio.charset.StandardCharsets;

/** Exercises the production WebView bridge, remote listener and time gate offscreen. */
public class FunIntegrationService extends Service {
 final Handler h=new Handler(Looper.getMainLooper());NativeVerificationService.Harness a;String game;boolean done;int polls;
 @Override public IBinder onBind(Intent i){return null;}
 @Override public int onStartCommand(Intent intent,int flags,int id){game=intent.getStringExtra("game");done=false;polls=0;try{a=new NativeVerificationService.Harness(this);a.active=true;a.profile().funMillis=300000;a.fun.open(game);a.root.measure(android.view.View.MeasureSpec.makeMeasureSpec(1920,android.view.View.MeasureSpec.EXACTLY),android.view.View.MeasureSpec.makeMeasureSpec(1080,android.view.View.MeasureSpec.EXACTLY));a.root.layout(0,0,1920,1080);poll();}catch(Throwable e){finish("FAIL: "+e);}return START_NOT_STICKY;}
 void poll(){if(done)return;if(!a.fun.error.isEmpty()){finish("FAIL: "+a.fun.error);return;}if(!a.fun.ready){if(++polls>400){finish("FAIL: timeout");return;}h.postDelayed(this::poll,50);return;}a.fun.web.evaluateJavascript("if(window.cc){cc.audioEngine.setEffectsVolume(0);cc.audioEngine.setMusicVolume(0);}true",r->{a.fun.start();h.postDelayed(this::running,250);});}
 void running(){try{if(!a.fun.running)throw new AssertionError("Native start failed");long before=a.profile().funMillis;if(!a.change(()->a.fun.charge(1250)))throw new AssertionError("Save failed");if(a.profile().funMillis!=before-1250)throw new AssertionError("Running budget");a.fun.web.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN,21));a.fun.web.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_UP,21));a.fun.web.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_DOWN,23));a.fun.web.dispatchKeyEvent(new KeyEvent(KeyEvent.ACTION_UP,23));a.fun.pause();long paused=a.profile().funMillis;a.fun.charge(5000);if(a.profile().funMillis!=paused)throw new AssertionError("Paused time consumed");h.postDelayed(()->{try{if(!a.fun.file(0,game).getBaseFile().exists())throw new AssertionError("Scene not saved");a.profile().funMillis=500;a.fun.running=true;a.fun.charge(1000);a.fun.afterTick();if(a.fun.running||a.profile().funMillis!=0)throw new AssertionError("Time gate did not stop game");finish("PASS: production ready/start, remote dispatch, shared budget, pause freeze, scene save, zero-time stop");}catch(Throwable e){finish("FAIL: "+e);}},350);}catch(Throwable e){finish("FAIL: "+e);}}
 void finish(String result){if(done)return;done=true;try(FileOutputStream out=openFileOutput("fun-integration-"+game+".txt",MODE_PRIVATE)){out.write(result.getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}android.util.Log.i("LittleLearningTest",game+": "+result);if(a!=null)a.fun.destroy();stopSelf();}
 @Override public void onDestroy(){h.removeCallbacksAndMessages(null);if(a!=null)a.fun.destroy();super.onDestroy();}
}
