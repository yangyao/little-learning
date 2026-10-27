package com.family.littlelearning;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.Color;
import android.view.*;
import static com.family.littlelearning.GameModel.*;

/** Large, legible game objects; direction and progress are represented spatially. */
final class BoardView extends View {
 final Paint p=new Paint(3);final RectF rect=new RectF();boolean arithmetic;Group group;Question question;int position;Route route;Frame frame;Runnable left,right,confirm;int downTarget,upTarget;
 final int ink=Color.rgb(62,39,35),green=Color.rgb(74,124,89),muted=Color.rgb(122,102,88);
 BoardView(Context c){super(c);setLayerType(View.LAYER_TYPE_SOFTWARE,null);setContentDescription("游戏地图");}
 void text(Canvas c,String s,float x,float y,float size,int color){p.setColor(color);p.setTextSize(size);p.setTypeface(Typeface.create("sans-serif",Typeface.BOLD));p.setTextAlign(Paint.Align.CENTER);c.drawText(s,x,y,p);}
 void box(Canvas c,float x,float y,float w,float h,float r,int color){p.setColor(color);p.setStyle(Paint.Style.FILL);rect.set(x,y,x+w,y+h);c.drawRoundRect(rect,r,r,p);}
 @Override protected void onFocusChanged(boolean gain,int direction,Rect old){super.onFocusChanged(gain,direction,old);invalidate();}
 @Override public boolean onKeyDown(int key,KeyEvent event){if(arithmetic){if(key==KeyEvent.KEYCODE_DPAD_LEFT){left.run();return true;}if(key==KeyEvent.KEYCODE_DPAD_RIGHT){right.run();return true;}if(key==KeyEvent.KEYCODE_DPAD_CENTER||key==KeyEvent.KEYCODE_ENTER){if(event.getRepeatCount()==0)confirm.run();return true;}}return super.onKeyDown(key,event);}
 @Override protected void onDraw(Canvas canvas){super.onDraw(canvas);float scale=Math.min(getWidth()/880f,getHeight()/235f);canvas.save();canvas.translate((getWidth()-880*scale)/2,(getHeight()-235*scale)/2);canvas.scale(scale,scale);
  if(arithmetic)drawArithmetic(canvas);else drawRoute(canvas);canvas.restore();
 }
 void drawArithmetic(Canvas c){
  box(c,0,0,880,235,22,0xffFBF8F1);if(hasFocus()){p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(3);p.setColor(0xff8C5835);c.drawRoundRect(new RectF(2,2,878,233),22,22,p);p.setStyle(Paint.Style.FILL);}
  float gap=800f/(group.limit+1),start=40+gap/2;float y=146;
  p.setStrokeWidth(3);p.setColor(0xffD8CEBA);c.drawLine(start,y,start+gap*group.limit,y,p);
  for(int n=0;n<=group.limit;n++){float x=start+n*gap;boolean current=n==position;box(c,x-gap*.38f,y-21,gap*.76f,44,18,current?green:0xffE6F0E9);text(c,""+n,x,y+8,24,current?Color.WHITE:ink);if(n==question.start){text(c,"起点",x,y+63,13,muted);p.setColor(ink);c.drawCircle(x,y+31,2,p);}}
  duck(c,start+position*gap,78,1,0);
  text(c,"←  向左跳一格                         向右跳一格  →",440,28,15,muted);
 }
 void duck(Canvas c,float x,float y,float scale,int heading){c.save();c.translate(x,y);c.scale(scale,scale);if(heading==2)c.scale(-1,1);p.setColor(0xffE6AA38);c.drawOval(-22,-12,20,15,p);c.drawCircle(12,-15,13,p);p.setColor(0xffC87A3E);Path bill=new Path();bill.moveTo(22,-18);bill.lineTo(34,-13);bill.lineTo(22,-9);bill.close();c.drawPath(bill,p);p.setColor(ink);c.drawCircle(15,-19,2,p);p.setColor(0xffB37F1E);c.drawOval(-12,-5,9,8,p);c.restore();}
 void drawRoute(Canvas c){
  if(route==null)return;float cell=210f/route.size;float x0=22,y0=10;
  box(c,x0-5,y0-5,220,220,12,0xffD8CEBA);
  for(int y=0;y<route.size;y++)for(int x=0;x<route.size;x++){float px=x0+x*cell,py=y0+y*cell;box(c,px,py,cell-3,cell-3,5,((x+y)%2==0)?0xffFBF8F1:0xffF3EBD9);Point pt=new Point(x,y);if(route.obstacles.contains(pt)){p.setColor(green);Path tree=new Path();tree.moveTo(px+cell*.5f,py+cell*.14f);tree.lineTo(px+cell*.2f,py+cell*.68f);tree.lineTo(px+cell*.8f,py+cell*.68f);tree.close();c.drawPath(tree,p);box(c,px+cell*.44f,py+cell*.66f,cell*.12f,cell*.2f,1,ink);}}
  float gx=x0+(route.goal.x()+.5f)*cell,gy=y0+(route.goal.y()+.5f)*cell;box(c,gx-cell*.26f,gy-cell*.3f,cell*.52f,cell*.46f,5,0xffC87A3E);p.setColor(ink);p.setStrokeWidth(2);c.drawLine(gx-cell*.15f,gy-cell*.06f,gx+cell*.15f,gy-cell*.06f,p);c.drawLine(gx,gy+cell*.16f,gx,gy+cell*.4f,p);
  Frame f=frame==null?new Frame(route.start,0,route.pickup==null):frame;
  if(route.pickup!=null&&!f.collected()){float px=x0+(route.pickup.x()+.5f)*cell,py=y0+(route.pickup.y()+.5f)*cell;box(c,px-cell*.3f,py-cell*.2f,cell*.6f,cell*.4f,3,0xffE6AA38);p.setColor(ink);p.setStrokeWidth(1.5f);c.drawLine(px-cell*.3f,py-cell*.2f,px,py+cell*.05f,p);c.drawLine(px+cell*.3f,py-cell*.2f,px,py+cell*.05f,p);}
  float px=x0+(f.point().x()+.5f)*cell,py=y0+(f.point().y()+.5f)*cell;duck(c,px,py,cell/76f,f.heading());String[] arrows={"→","↓","←","↑"};text(c,arrows[f.heading()],px,py+cell*.39f,cell*.33f,ink);
  text(c,"先想一想，再排指令",550,43,28,ink);text(c,"小鸭出发时面朝右方 →",550,82,18,muted);text(c,"前进走一格 · 左右转只改变方向",550,116,18,muted);text(c,route.pickup==null?"绕开树木，把信送到邮筒":"先到黄色信封取信，再送到邮筒",550,151,18,muted);text(c,"方向键选按钮 · 确定键添加指令",550,204,16,green);
 }
}
