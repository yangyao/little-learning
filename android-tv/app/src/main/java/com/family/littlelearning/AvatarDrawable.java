package com.family.littlelearning;
import android.graphics.*;
import android.graphics.drawable.Drawable;

/** Original vector animal portraits; independent of the TV's emoji fonts. */
final class AvatarDrawable extends Drawable {
 final boolean rabbit;final Paint p=new Paint(3);final int pixels;
 AvatarDrawable(boolean rabbit,int size){this.rabbit=rabbit;pixels=size;}
 void oval(Canvas c,float l,float t,float r,float b,int color){p.setColor(color);c.drawOval(l,t,r,b,p);}
 @Override public void draw(Canvas original){Canvas c=original;c.save();Rect b=getBounds();c.translate(b.left,b.top);c.scale(b.width()/120f,b.height()/120f);oval(c,2,2,118,118,0xffE6F0E9);
  if(rabbit){oval(c,28,3,51,67,0xffFDF9EF);oval(c,68,3,91,67,0xffFDF9EF);oval(c,34,10,46,53,0xffD9A99F);oval(c,73,10,85,53,0xffD9A99F);oval(c,18,38,102,111,0xffFDF9EF);}else{oval(c,15,13,48,49,0xff9C6A44);oval(c,72,13,105,49,0xff9C6A44);oval(c,23,20,41,41,0xffD8B28A);oval(c,79,20,97,41,0xffD8B28A);oval(c,15,27,105,112,0xffB78151);}
  oval(c,40,64,80,99,rabbit?0xffF4E6DA:0xffE8C9A0);oval(c,36,57,43,66,0xff3E2723);oval(c,77,57,84,66,0xff3E2723);oval(c,27,74,40,81,0x55CC7D72);oval(c,80,74,93,81,0x55CC7D72);
  Path nose=new Path();nose.moveTo(54,76);nose.quadTo(60,72,66,76);nose.lineTo(60,82);nose.close();p.setColor(0xff3E2723);c.drawPath(nose,p);p.setStyle(Paint.Style.STROKE);p.setStrokeWidth(2);p.setStrokeCap(Paint.Cap.ROUND);Path mouth=new Path();mouth.moveTo(60,81);mouth.lineTo(60,86);mouth.quadTo(55,91,51,85);mouth.moveTo(60,86);mouth.quadTo(65,91,69,85);c.drawPath(mouth,p);p.setStyle(Paint.Style.FILL);c.restore();}
 @Override public void setAlpha(int a){p.setAlpha(a);}@Override public void setColorFilter(ColorFilter f){p.setColorFilter(f);}@Override public int getOpacity(){return PixelFormat.TRANSLUCENT;}@Override public int getIntrinsicWidth(){return pixels;}@Override public int getIntrinsicHeight(){return pixels;}
}
