package com.family.littlelearning;
import android.app.Activity;
import android.os.Bundle;
import android.content.ContextWrapper;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import static com.family.littlelearning.GameModel.*;

/** Debug-only persistence checks in an isolated directory; never touches family progress. */
public class VerificationActivity extends Activity {
 int checks;
 void check(boolean pass,String name){checks++;if(!pass)throw new AssertionError(name);}
 @Override public void onCreate(Bundle b){super.onCreate(b);String result;try{
  File dir=new File(getFilesDir(),"verification");dir.mkdirs();for(File f:Objects.requireNonNull(dir.listFiles()))f.delete();
  ContextWrapper isolated=new ContextWrapper(this){@Override public File getFilesDir(){return dir;}};
  Content c=new Content(this);Store s=new Store(isolated,c);Profile p=s.profiles[0];p.arithmeticGroup=0;p.position=c.groups.get(0).questions.get(0).answer();p.arithmeticSolved=true;Question q=c.groups.get(0).questions.get(0);p.award(q.id,q.equation(),1,1);p.routeGroup=0;p.route=0;p.commands.addAll(c.routes.get(0).solution);p.routeSolved=true;p.award(c.routes.get(0).id,"送信",3,1);p.consume(12345,100000);s.save();
  Store reload=new Store(isolated,c);check(reload.profiles[0].balance()==4,"balance persisted");check(reload.profiles[0].arithmeticSolved,"solved persisted");check(reload.profiles[0].commands.equals(p.commands),"commands persisted");check(reload.profiles[1].balance()==0,"second child independent");check(reload.profiles[0].used==12345,"usage persisted");check(!reload.profiles[0].award(q.id,q.equation(),1,2),"restart cannot double award");check(reload.profiles[0].redeem("绘本",3,2),"redemption accepted");reload.save();Store third=new Store(isolated,c);check(third.profiles[0].balance()==1,"spending persisted");String id=third.profiles[0].redemptions.get(0).id;check(third.profiles[0].undo(id),"undo accepted");third.save();Store fourth=new Store(isolated,c);check(fourth.profiles[0].balance()==4,"undo persisted");check(!fourth.profiles[0].undo(id),"undo once across restart");String valid=fourth.encode();
  fourth.profiles[1].consume(BUDGET,200000);fourth.save();Store rest=new Store(isolated,c);check(rest.profiles[1].remaining(200001)==0,"rest survives restart");rest.profiles[1].refresh(200000+REST);check(rest.profiles[1].remaining(200000+REST)==BUDGET,"rest completes offline");
  try{fourth.restore(valid.replace("\"version\":1","\"version\":9"));throw new AssertionError("unknown version accepted");}catch(IOException expected){checks++;}
  byte[] corrupt="broken save".getBytes(StandardCharsets.UTF_8);try(FileOutputStream out=new FileOutputStream(s.file.getBaseFile())){out.write(corrupt);}try{new Store(isolated,c);throw new AssertionError("corruption accepted");}catch(Exception expected){checks++;}check(Arrays.equals(corrupt,s.file.readFully()),"corrupt save preserved");
  int extended=ExtendedChecks.run(this);result="PASS: "+checks+" isolated storage checks; "+extended+" extended game checks";
 }catch(Throwable e){result="FAIL: "+e;android.util.Log.e("LittleLearningTest",result,e);}try(FileOutputStream out=openFileOutput("verification-result.txt",MODE_PRIVATE)){out.write(result.getBytes(StandardCharsets.UTF_8));}catch(Exception ignored){}android.util.Log.i("LittleLearningTest",result);finish();}
}
