package com.family.littlelearning;

import java.util.*;

/** Platform-independent rules. IDs and geometry match the iOS content export. */
public final class GameModel {
    public static final long BUDGET = 30L * 60 * 1000, REST = 2L * 60 * 60 * 1000;
    public static final String[] CHILDREN={"千一","臻一"};
    public static final String[] ROUTE_GROUPS={"认识方向","绕开障碍","取信再送信"};
    public static final String[] COMMANDS={"forward","left","right"};
    public static final class Question {
        public final int start,change; public final String id;
        public Question(int s,int c,String id) { start=s;change=c;this.id=id; }
        public int answer(){return start+change;}
        public String equation(){return start+(change>0?" + ":" − ")+Math.abs(change);}
        public String instruction(){return "从 "+start+" 出发，往"+(change>0?"右":"左")+"跳 "+Math.abs(change)+" 格";}
    }
    public static final class Group {
        public final String id,title;public final int limit;public final List<Question> questions;
        public Group(String id,String title,int limit,List<Question> qs){this.id=id;this.title=title;this.limit=limit;questions=Collections.unmodifiableList(new ArrayList<>(qs));}
    }
    public record Point(int x,int y) {}
    public record Frame(Point point,int heading,boolean collected) {}
    public record Trace(List<Frame> frames,boolean success,String message) {}
    public static final class Route {
        public final int index,size; public final Point start,goal,pickup;public final Set<Point> obstacles;public final List<String> solution;public final String id;
        public Route(int i,int s,Point a,Point b,Point p,Set<Point> blocks,List<String> sol,String id){index=i;size=s;start=a;goal=b;pickup=p;obstacles=Collections.unmodifiableSet(new HashSet<>(blocks));solution=Collections.unmodifiableList(new ArrayList<>(sol));this.id=id;}
        public Trace trace(List<String> commands){
            Point p=start;int h=0;boolean collected=pickup==null;List<Frame> frames=new ArrayList<>();frames.add(new Frame(p,h,collected));
            int[] dx={1,0,-1,0},dy={0,1,0,-1};
            for(String command:commands){
                if(command.equals("left"))h=(h+3)%4;
                else if(command.equals("right"))h=(h+1)%4;
                else if(command.equals("forward")){
                    Point next=new Point(p.x+dx[h],p.y+dy[h]);
                    if(next.x<0||next.y<0||next.x>=size||next.y>=size||obstacles.contains(next))return new Trace(frames,false,"前面走不通，修改指令再试试。");
                    p=next;
                } else return new Trace(frames,false,"指令无效，请重新排列。");
                if(p.equals(pickup))collected=true;
                frames.add(new Frame(p,h,collected));
            }
            boolean success=p.equals(goal)&&collected;
            return new Trace(Collections.unmodifiableList(new ArrayList<>(frames)),success,success?"信送到了！":p.equals(goal)?"先去信封处取信，再送到邮筒。":"还没到邮筒，看看方向和前进步数。");
        }
    }
    public static final class Receipt {
        public String id,title;public int points;public long at;public boolean undone;
        public Receipt(String id,String title,int points,long at,boolean undone){this.id=id;this.title=title;this.points=points;this.at=at;this.undone=undone;}
    }
    public static final class Profile {
        public int arithmeticGroup=-1,question=0,position=0,routeGroup=-1,route=0;
        public boolean arithmeticSolved,routeSolved;
        public final List<String> commands=new ArrayList<>();
        public final LinkedHashMap<String,Receipt> awards=new LinkedHashMap<>();
        public final List<Receipt> redemptions=new ArrayList<>();
        public final Map<String,String> games=new LinkedHashMap<>();
        public final Set<String> syncPlayGrants=new HashSet<>();
        public long funMillis=0;
        public long used=0,restUntil=0;
        public int balance(){int n=0;for(Receipt r:awards.values())n+=r.points;for(Receipt r:redemptions)if(!r.undone)n-=r.points;return n;}
        public boolean award(String id,String title,int points,long now){if(awards.containsKey(id))return false;awards.put(id,new Receipt(id,title,points,now,false));return true;}
        public boolean redeem(String title,int points,long now){if(title==null||title.trim().isEmpty()||title.trim().length()>80||points<1||points>balance())return false;redemptions.add(new Receipt(UUID.randomUUID().toString(),title.trim(),points,now,false));return true;}
        public boolean undo(String id){if(id.startsWith("playtime:"))return false;for(Receipt r:redemptions)if(r.id.equals(id)&&!r.undone){r.undone=true;return true;}return false;}
        public void refresh(long now){if(restUntil>0&&now>=restUntil){used=0;restUntil=0;}}
        public void consume(long ms,long now){refresh(now);if(ms<=0||restUntil>0)return;long consumed=Math.min(ms,BUDGET-used);used+=consumed;if(used==BUDGET)restUntil=now+REST-(ms-consumed);}
        public long remaining(long now){refresh(now);return restUntil>0?0:BUDGET-used;}
    }
    private GameModel(){}
}
