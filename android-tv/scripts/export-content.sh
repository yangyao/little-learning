#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/export
cat > build/export/main.swift <<'SWIFT'
import Foundation
let arithmetic = StudyCatalog.groups(for: .numberLine).map { group -> [String:Any] in
 ["id":group.id,"title":group.title,"limit":group.limit,"questions":group.arithmetic.map { ["start":$0.start,"change":$0.change,"id":RewardCatalog.arithmetic($0).id] }]
}
let routes = RouteTask.all.map { t -> [String:Any] in
 var r: [String:Any] = ["index":t.index,"size":t.size,"start":[t.start.x,t.start.y],"goal":[t.goal.x,t.goal.y],"obstacles":t.obstacles.sorted {$0.y == $1.y ? $0.x < $1.x : $0.y < $1.y}.map {[$0.x,$0.y]},"solution":t.solution.map(\.rawValue),"id":RewardCatalog.puzzle(.delivery,t.index).id]
 if let p=t.pickup {r["pickup"]=[p.x,p.y]}
 return r
}
var banks=[String:Any]()
for game in [LearningGame.pinyin,.characters,.idioms,.bakery] {
 banks[game.rawValue]=WorkshopContent.questions(for:game).map { q -> [String:Any] in ["title":q.title,"prompt":q.clue,"picture":q.picture,"answer":q.answer,"extras":q.extras,"labels":q.labels,"word":q.word,"reading":q.reading,"explanation":q.explanation,"followUp":q.followUp,"choices":q.choices,"correctChoice":q.correctChoice,"layout":q.layout,"id":RewardCatalog.workshop(game,q).id] }
}
banks["sharing"]=SharingTask.all.map { ["food":$0.food,"name":$0.name,"animal":$0.animal,"total":$0.total,"bowls":$0.bowls,"id":RewardCatalog.sharing($0).id] as [String:Any] }
banks["clock"]=ClockTask.all.map { ["mode":String(describing:$0.mode),"title":$0.title,"prompt":$0.prompt,"tip":$0.tip,"start":$0.start,"target":$0.target,"choices":$0.choices,"correctChoice":$0.correctChoice,"id":RewardCatalog.clock($0).id] as [String:Any] }
banks["matches"]=MatchPuzzle.all.map { ["initial":$0.initial,"solution":$0.solution,"id":RewardCatalog.matches($0).id] as [String:Any] }
banks["sorting"]=(0..<FruitSession.levelCount).map { i -> [String:Any] in let g=FruitSession.generated(level:i);return ["jars":g.board,"solution":g.solution.map{[$0.from,$0.to]},"id":RewardCatalog.sorting(i).id] }
banks["ruler"]=RulerTask.all.map { t -> [String:Any] in ["mode":t.mode.rawValue,"marks":t.marks,"length":t.length,"blank":t.blank ?? -1,"objectStart":t.objectStart,"prompt":t.prompt,"distances":t.distances.sorted(),"id":RewardCatalog.ruler(t).id] }
banks["tangram"]=TangramTask.all.map { t -> [String:Any] in ["solution":t.solution.map{[$0.x,$0.y,$0.rotation,$0.flipped ? 1:0]},"target":t.target.sorted(),"id":RewardCatalog.puzzle(.tangram,t.index).id] }
banks["beads"]=BeadTask.all.map { t -> [String:Any] in ["sequence":t.sequence.map{[$0.shape,$0.color]},"blanks":t.blanks,"options":t.options.map{[$0.shape,$0.color]},"explanation":t.explanation,"id":RewardCatalog.puzzle(.beads,t.index).id] }
let catalog=LearningGame.allCases.filter{ ![.numberLine,.delivery,.printing].contains($0) }.map { g -> [String:Any] in ["key":g.rawValue,"title":g.title,"subtitle":g.subtitle,"groups":StudyCatalog.groups(for:g).map{["id":$0.id,"title":$0.title,"detail":$0.detail,"indices":$0.indices] as [String:Any]}] }
let rewards=RewardCatalog.all.map{["id":$0.id,"points":$0.points] as [String:Any]}
let data=try JSONSerialization.data(withJSONObject:["version":1,"arithmetic":arithmetic,"routes":routes,"banks":banks,"catalog":catalog,"rewards":rewards],options:[.prettyPrinted,.sortedKeys])
try data.write(to:URL(fileURLWithPath:"app/src/main/assets/content.json"))
print("Exported \(arithmetic.count) arithmetic groups and \(routes.count) original route maps")
SWIFT
swiftc ../ios/LittleLearning/Core/*.swift build/export/main.swift -o build/export/content-export
build/export/content-export
