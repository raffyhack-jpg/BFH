import Foundation

struct V2: Equatable {
    var x: Double; var z: Double
    static let zero = V2(x: 0, z: 0)
    static func + (a: V2, b: V2) -> V2 { V2(x: a.x+b.x, z:a.z+b.z) }
    static func - (a: V2, b: V2) -> V2 { V2(x:a.x-b.x,z:a.z-b.z) }
    static func * (a: V2, b: Double) -> V2 { V2(x:a.x*b,z:a.z*b) }
    var length: Double { sqrt(x*x+z*z) }
    var unit: V2 { length > 0.001 ? self * (1/length) : .zero }
    func distance(_ b: V2) -> Double { (self-b).length }
}
struct V3: Equatable {
    var x:Double,y:Double,z:Double
    static func + (a:V3,b:V3)->V3 { V3(x:a.x+b.x,y:a.y+b.y,z:a.z+b.z) }
    static func - (a:V3,b:V3)->V3 { V3(x:a.x-b.x,y:a.y-b.y,z:a.z-b.z) }
    static func * (a:V3,b:Double)->V3 { V3(x:a.x*b,y:a.y*b,z:a.z*b) }
    func dot(_ b:V3)->Double { x*b.x+y*b.y+z*b.z }
    var length:Double { sqrt(dot(self)) }
    var unit:V3 { length>0.00001 ? self*(1/length) : V3(x:0,y:0,z:1) }
    var horizontal:V2 { V2(x:x,z:z) }
}
// Vertical capsule: feet and jumping body remain hittable without oversized cones.
func capsuleHit(origin:V3,direction:V3,feet:V3,radius:Double=0.45)->Double? {
    var hits:[Double]=[]
    for y in [radius,1.8-radius] {
        let offset=origin-(feet+V3(x:0,y:y,z:0))
        let b=offset.dot(direction),c=offset.dot(offset)-radius*radius,d=b*b-c
        if d>=0 { let t = -b-sqrt(d);if t>=0 { hits.append(t) } }
    }
    let offset=origin-feet,a=direction.x*direction.x+direction.z*direction.z
    let b=offset.x*direction.x+offset.z*direction.z,c=offset.x*offset.x+offset.z*offset.z-radius*radius
    let d=b*b-a*c
    if a>0.000001 && d>=0 {
        let t=(-b-sqrt(d))/a,y=offset.y+t*direction.y
        if t>=0 && y>=radius && y<=1.8-radius { hits.append(t) }
    }
    return hits.min()
}

// Local career. Original level thresholds are transcribed from the historically documented BFH level table.
// Shop fallback prices and VP mission payouts are offline adaptations, not historical prices.
struct HeroCareer:Codable {
    static let thresholds=[0,600,1800,4000,7600,13100,21200,32700,48600,71400,102700,144000,196800,261900,339800,430400,533300,647500,772100,906100,1055900,1221300,1402200,1598200,1809300,2035500,2276600,2532700,2803900,3090300]
    var xp=0,valor=0,funds=0,spentHeroPoints=1,abilityRank=1
    var owned:Set<Int>=[],kills=0,captures=0,matches=0
    var rewardedMatches:Set<String>=[],claimedMissions:Set<String>=[]
    var level:Int { min(30,Self.thresholds.filter{$0<=xp}.count) }
    var heroPoints:Int { max(0,1+level/2-spentHeroPoints) }
    var levelFraction:Double {
        guard level<30 else {return 1}
        let base=Self.thresholds[level-1],next=Self.thresholds[level]
        return Double(xp-base)/Double(next-base)
    }
    mutating func earn(_ amount:Int) {xp=max(0,xp+max(0,amount))}
    mutating func upgradeAbility()->Bool {
        guard heroPoints>0,abilityRank<5 else{return false}
        spentHeroPoints+=1;abilityRank+=1;return true
    }
    mutating func purchase(id:Int,minimumLevel:Int,valorPrice:Int?,fundsPrice:Int?)->Bool {
        guard !owned.contains(id),level>=minimumLevel else{return false}
        if let price=valorPrice {guard price>=0,valor>=price else{return false};valor-=price}
        else if let price=fundsPrice {guard price>=0,funds>=price else{return false};funds-=price}
        else {return false}
        owned.insert(id);return true
    }
    @discardableResult mutating func finishMatch(id:String,kills:Int,captures:Int,won:Bool)->Int {
        guard rewardedMatches.insert(id).inserted else{return 0}
        self.kills+=max(0,kills);self.captures+=max(0,captures);matches+=1
        var reward=20+max(0,kills)*3+max(0,captures)*10+(won ? 15 : 0)
        for (key,done,bonus) in [("first-match",matches>=1,100),("infantry-10",self.kills>=10,150),("flags-3",self.captures>=3,200)] where done && !claimedMissions.contains(key) {
            claimedMissions.insert(key);reward+=bonus
        }
        valor+=reward
        return reward
    }
}
struct CombatFeedback {
    var attacker:Int,victim:Int,position:V2,height:Double,damage:Int,killed:Bool
}
struct ScoreFeedback {var hero:Int,amount:Int,reason:String}

enum Mode: String, CaseIterable { case conquest = "Conquest", flags = "Capture the Flag", elimination = "Elimination", rocket = "Rocket Control" }
enum HeroClass: String, CaseIterable {
    case soldier = "Soldier", heavy = "Gunner", scout = "Commando"
    var hp: Double { self == .heavy ? 160 : self == .scout ? 85 : 115 }
    var speed: Double { self == .heavy ? 4.2 : self == .scout ? 6.4 : 5.2 }
    var damage: Double { self == .scout ? 36 : self == .heavy ? 13 : 19 }
    var interval: Double { self == .scout ? 0.8 : self == .heavy ? 0.18 : 0.3 }
    var range: Double { self == .scout ? 28 : self == .heavy ? 17 : 22 }
}
struct Block {
    var center:V2;var half:V2;var angle:Double=0
    var axisHalf:V2 {
        let c=abs(cos(angle)),s=abs(sin(angle))
        return V2(x:half.x*c+half.z*s,z:half.x*s+half.z*c)
    }
    func contains(_ p:V2)->Bool {
        let d=p-center,c=cos(angle),s=sin(angle)
        return abs(d.x*c-d.z*s)<half.x+0.45 && abs(d.x*s+d.z*c)<half.z+0.45
    }
}
struct MapLayout {
    var bases:[V2],objectives:[V2],blocks:[Block]
    var extent:Double,gridStep:Double
    var walkable:(V2)->Bool
    var airborneFree:((V2,Double)->Bool)?=nil
}
struct Objective { var p: V2; var progress: Double = 0; var owner: Int = -1 }
struct Flag { var home: V2; var p: V2; var carrier: Int?; var droppedAt: Double = 0 }
struct WeaponProfile {
    let id:Int,name:String
    let damage:Double,interval:Double,range:Double
    let magazine:Int,reloadTime:Double
    var isMelee=false
}
final class Hero {
    let id: Int; let team: Int; let kind: HeroClass
    var p: V2; var facing: Double = 0; var hp: Double
    var respawn: Double = 0; var invulnerable: Double = 2
    var elevation=0.0,verticalVelocity=0.0
    var equipped:[WeaponProfile]=[],weaponSlot=0,ammunition:[Int]=[],reloadRemaining=0.0
    var weapon:WeaponProfile? { equipped.indices.contains(weaponSlot) ? equipped[weaponSlot] : nil }
    var weaponInterval:Double { weapon?.interval ?? kind.interval }
    var weaponDamage:Double { weapon?.damage ?? kind.damage }
    var weaponRange:Double { weapon?.range ?? kind.range }
    func equip(_ weapons:[WeaponProfile]) { equipped=weapons;ammunition=weapons.map{$0.magazine};weaponSlot=0;reloadRemaining=0 }
    var matchXP=0,captures=0,abilityRank=1
    var recentShot=0.0
    var cooldown: Double = 0; var ability: Double = 0
    var raidWaypoint:V2?=nil,raidComplete=false,raidReadyAt:Double?=nil
    var returnWaypoint:V2?=nil,returnComplete=false,wasCarrier=false
    var think: Double = 0; var path: [V2] = []; var target: V2 = .zero
    var kills = 0; var deaths = 0; var lastAttacker: Int?
    var alive: Bool { hp > 0 }
    init(_ id: Int, _ team: Int, _ kind: HeroClass, _ p: V2) {
        self.id=id; self.team=team; self.kind=kind; self.p=p; hp=kind.hp
    }
}
struct Shot { var from: V2; var to: V2; var team: Int; var fromY:Double=1.2;var toY:Double=1.2 }
struct Input { var move = V2.zero; var yaw: Double = 0; var fire = false; var ability = false; var jump=false;var aimPoint:V3?=nil }
struct RNG {
    var state: UInt64 = 42
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64.max >> 11)
    }
}
final class Game {
    let mode: Mode
    var heroes: [Hero] = []
    var bases = [V2(x:-24,z:0),V2(x:24,z:0)]
    var groundHeight:(V2)->Double = { _ in 0 }
    var shotObstacle:((V3,V3)->V3)?=nil
    var mapLayout:MapLayout?
    var spatialBlocks:[Int:[Block]]=[:]
    var navigationEdges:[Int:[Int]]=[:]
    var objectives: [Objective] = []
    var flags: [Flag] = []
    var blocks: [Block] = [
        Block(center:V2(x:-12,z:-9),half:V2(x:3,z:3)), Block(center:V2(x:12,z:9),half:V2(x:3,z:3)),
        Block(center:V2(x:-10,z:9),half:V2(x:2,z:4)), Block(center:V2(x:10,z:-9),half:V2(x:2,z:4)),
        Block(center:V2(x:0,z:-10),half:V2(x:3,z:2)), Block(center:V2(x:0,z:10),half:V2(x:3,z:2)),
        Block(center:V2(x:-5,z:0),half:V2(x:1,z:2)), Block(center:V2(x:5,z:0),half:V2(x:1,z:2))]
    let matchID=UUID().uuidString
    var feedback:[CombatFeedback]=[],scoreFeedback:[ScoreFeedback]=[]
    var flagPickups=[0,0]
    var score = [0.0,0.0]; var tickets = [70.0,70.0]
    var roundDuration:Double
    var endReason=""
    var remainingSeconds:Int {max(0,Int(ceil(roundDuration-elapsed)))}
    var elapsed = 0.0; var winner: Int?; var shots: [Shot] = []; var message = ""
    var rng = RNG(); var paused = false
    init(mode: Mode, hero: HeroClass, seed: UInt64 = 42, layout:MapLayout?=nil,playerTeam:Int=0,roundDuration:Double=900) {
        self.mode=mode;self.roundDuration=max(1,roundDuration); rng.state=seed
        mapLayout=layout
        if let layout=layout { bases=layout.bases; blocks=layout.blocks }
        for b in blocks {
            let bounds=b.axisHalf
            for x in Int(floor((b.center.x-bounds.x-1)/8))...Int(floor((b.center.x+bounds.x+1)/8)) {
                for z in Int(floor((b.center.z-bounds.z-1)/8))...Int(floor((b.center.z+bounds.z+1)/8)) { spatialBlocks[x*10000+z,default:[]].append(b) }
            }
        }
        objectives = layout?.objectives.map{Objective(p:$0)} ?? [Objective(p:V2(x:-17,z:0)),Objective(p:.zero),Objective(p:V2(x:17,z:0))]
        if mode == .rocket { objectives=[objectives[objectives.count/2]] }
        for i in bases.indices { bases[i]=nearestFree(bases[i]) }
        for i in objectives.indices { objectives[i].p=nearestFree(objectives[i].p) }
        flags = [Flag(home:bases[0],p:bases[0]),Flag(home:bases[1],p:bases[1])]
        for i in 0..<16 {
            let team = i < 8 ? playerTeam : 1-playerTeam
            let kind = i == 0 ? hero : HeroClass.allCases[i%3]
            let h=Hero(i,team,kind,nearestFree(bases[team]+V2(x:0,z:Double(i%8)-3.5)));h.think=Double(i%8)*0.09;heroes.append(h)
        }
    }
    func free(_ p: V2) -> Bool {
        let extent=mapLayout?.extent ?? 28
        let within=abs(p.x)<extent && abs(p.z)<(mapLayout == nil ? 18 : extent)
        let nearby=spatialBlocks[Int(floor(p.x/8))*10000+Int(floor(p.z/8))] ?? []
        return within && (mapLayout?.walkable(p) ?? true) && !nearby.contains { $0.contains(p) }
    }
    func nearestFree(_ p:V2) -> V2 {
        if free(p) { return p }
        for radius in 1...30 { for i in 0..<32 {
            let a=Double(i)*Double.pi/16;let q=p+V2(x:cos(a),z:sin(a))*Double(radius)
            if free(q) { return q }
        } }
        return p
    }
    func visible(_ a: V2, _ b: V2) -> Bool {
        let d=b-a; let n=max(1,Int(d.length/0.45))
        for i in 0...n { if !free(a+d*(Double(i)/Double(n))) { return false } }
        return true
    }
    func move(_ h: Hero, _ direction: V2, _ dt: Double) {
        let d=direction.unit * (h.kind.speed*dt)
        let x=V2(x:h.p.x+d.x,z:h.p.z)
        if canMove(x,h) { h.p.x=x.x }
        let z=V2(x:h.p.x,z:h.p.z+d.z)
        if canMove(z,h) { h.p.z=z.z }
    }
    func canMove(_ p:V2,_ h:Hero)->Bool {
        if h.elevation>0.05,let airborne=mapLayout?.airborneFree { return abs(p.x)<(mapLayout?.extent ?? 28) && abs(p.z)<(mapLayout?.extent ?? 18) && airborne(p,h.elevation) }
        return free(p)
    }
    func jump(_ h:Hero) {
        guard !paused,winner==nil,h.alive,h.elevation<=0.001,h.verticalVelocity<=0 else { return }
        h.verticalVelocity=7.5
    }
    // Grid A*: deterministic, small bounded arena; collision footprint matches movement.
    func route(_ a: V2, _ b: V2) -> [V2] {
        if visible(a,b) { return [b] }
        let step=mapLayout?.gridStep ?? 1,extent=mapLayout?.extent ?? 28,zExtent=mapLayout?.extent ?? 18
        let width=Int(extent*2/step)+1
        func point(_ key:Int)->V2 { V2(x:Double(key%width)*step-extent,z:Double(key/width)*step-zExtent) }
        func key(_ p:V2)->Int { Int(((max(-zExtent,min(zExtent,p.z))+zExtent)/step).rounded())*width+Int(((max(-extent,min(extent,p.x))+extent)/step).rounded()) }
        let goal=nearestFree(b)
        func nearestKey(_ p:V2)->Int {
            let center=key(p)
            for radius in 0...6 {
                var best:Int?;var distance=Double.infinity
                for x in -radius...radius { for z in -radius...radius {
                    let k=center+x+z*width;guard k>=0 else { continue }
                    let q=point(k)
                    if free(q) && visible(p,q) && q.distance(p)<distance { best=k;distance=q.distance(p) }
                } }
                if let best=best { return best }
            }
            return center
        }
        let start=nearestKey(a),end=nearestKey(goal)
        var heap:[(Int,Double)]=[],cost=[start:0.0],parent:[Int:Int]=[:],closed:Set<Int>=[]
        func push(_ entry:(Int,Double)) {
            heap.append(entry);var i=heap.count-1
            while i>0 { let p=(i-1)/2;if heap[p].1<=heap[i].1 { break };heap.swapAt(p,i);i=p }
        }
        func pop()->Int {
            let result=heap[0].0;let last=heap.removeLast()
            if !heap.isEmpty { heap[0]=last;var i=0
                while i*2+1<heap.count { var c=i*2+1;if c+1<heap.count && heap[c+1].1<heap[c].1 { c+=1 };if heap[i].1<=heap[c].1 { break };heap.swapAt(i,c);i=c }
            };return result
        }
        push((start,a.distance(goal)))
        while !heap.isEmpty {
            let current=pop();if closed.contains(current) { continue }
            if current == end {
                var result=[goal]; var k=current
                while k != start, let prev=parent[k] { result.append(point(k)); k=prev }
                return Array(result.reversed())
            }
            closed.insert(current)
            let p=point(current)
            if navigationEdges[current]==nil {
                var neighbors:[Int]=[]
                for dx in -1...1 { for dz in -1...1 where dx != 0 || dz != 0 {
                    let q=p+V2(x:Double(dx)*step,z:Double(dz)*step)
                    if free(q) && visible(p,q) { neighbors.append(key(q)) }
                } }
                navigationEdges[current]=neighbors
            }
            for k in navigationEdges[current] ?? [] {
                guard !closed.contains(k) else { continue }
                let c=(cost[current] ?? 0)+p.distance(point(k))
                if c < (cost[k] ?? 1e9) { cost[k]=c;parent[k]=current;push((k,c+point(k).distance(goal))) }
            }
        }
        return []
    }
    func flagCarrier(_ h:Hero)->Bool { mode == .flags && flags[1-h.team].carrier == h.id }
    func objective(for h: Hero) -> V2 {
        // A carrier must return the flag even while wounded.
        if flagCarrier(h) {
            let home=flags[h.team].home,enemy=flags[1-h.team].home
            if !h.wasCarrier {
                h.wasCarrier=true;h.returnComplete=h.p.distance(home)<home.distance(enemy)*0.35
                let axis=(enemy-home).unit,side=V2(x:axis.z,z:-axis.x),midpoint=(home+enemy)*0.5
                let offset=min(36,home.distance(enemy)*0.28)
                let left=nearestFree(midpoint+side*offset),right=nearestFree(midpoint-side*offset)
                h.returnWaypoint=h.raidWaypoint ?? (h.p.distance(left)<h.p.distance(right) ? left : right)
            }
            if !h.returnComplete,let waypoint=h.returnWaypoint {
                if h.p.distance(waypoint)>1.8 { return waypoint }
                h.returnComplete=true
            }
            return home
        }
        h.wasCarrier=false;h.returnWaypoint=nil;h.returnComplete=false
        if h.hp < h.kind.hp*0.25 { return bases[h.team] }
        switch mode {
        case .flags:
            let home=flags[h.team],enemy=flags[1-h.team]
            let squad=heroes.filter{$0.team==h.team && $0.alive && $0.id != 0 && $0.id != enemy.carrier}
            if let thief=home.carrier {
                // Keep a retrieval squad instead of abandoning our carrier with the whole team.
                let interceptors=squad.sorted {
                    let a=$0.p.distance(heroes[thief].p),b=$1.p.distance(heroes[thief].p)
                    return a==b ? $0.id<$1.id : a<b
                }.prefix(3)
                if interceptors.contains(where:{$0.id==h.id}) { return heroes[thief].p }
            } else if home.p.distance(home.home)>1 {
                if squad.min(by:{$0.p.distance(home.p)<$1.p.distance(home.p)})?.id==h.id { return home.p }
            }
            if let id=enemy.carrier {
                let carrier=heroes[id],towardHome=(home.home-carrier.p).unit
                let side=V2(x:towardHome.z,z:-towardHome.x)
                // Soldiers stay within healing distance; escorts spread out to avoid blocking fire.
                let offset=towardHome*2.5+side*(h.id%2==0 ? 2 : -2)
                return nearestFree(carrier.p+offset)
            }
            let defenders=squad.sorted {
                let a=$0.kind == .heavy ? 0 : 1,b=$1.kind == .heavy ? 0 : 1
                return a==b ? $0.id<$1.id : a<b
            }.prefix(2)
            if defenders.contains(where:{$0.id==h.id}) {
                return nearestFree(home.home+(enemy.home-home.home).unit*4+V2(x:0,z:Double(h.id%3)-1))
            }
            if h.p.distance(home.home)<4 && h.raidComplete { h.raidComplete=false;h.raidWaypoint=nil;h.raidReadyAt=nil }
            if !h.raidComplete {
                if h.raidWaypoint==nil {
                    let axis=(enemy.home-home.home).unit,side=V2(x:axis.z,z:-axis.x)
                    let midpoint=(home.home+enemy.home)*0.5
                    let offset=min(36,home.home.distance(enemy.home)*0.28)*(h.id%2==0 ? 1.0 : -1.0)
                    h.raidWaypoint=nearestFree(midpoint+side*offset)
                }
                if let waypoint=h.raidWaypoint {
                    if h.p.distance(waypoint)>1.8 { return waypoint }
                    if h.raidReadyAt==nil { h.raidReadyAt=elapsed }
                    let ready=squad.filter { $0.id != h.id && ($0.raidWaypoint?.distance(waypoint) ?? 1000)<4 && $0.p.distance(waypoint)<6 }
                    if ready.isEmpty && elapsed-(h.raidReadyAt ?? elapsed)<3 { return waypoint }
                    h.raidComplete=true
                }
            }
            return enemy.p
        case .conquest, .rocket:
            let candidates=objectives.filter { $0.owner != h.team }
            if candidates.isEmpty { return objectives[h.id%objectives.count].p }
            func priority(_ o: Objective) -> Double {
                let assigned=heroes.filter { $0.id != h.id && $0.team == h.team && $0.alive && $0.target.distance(o.p)<3 }.count
                return o.p.distance(h.p)+Double(assigned)*8
            }
            return candidates.min { priority($0)<priority($1) }!.p
        case .elimination:
            return heroes.filter { $0.team != h.team && $0.alive }.min { $0.p.distance(h.p)<$1.p.distance(h.p) }?.p ?? .zero
        }
    }
    func hurt(_ h: Hero, _ amount: Double, attacker: Hero) {
        guard h.alive, h.invulnerable <= 0 else { return }
        let actual=max(0,min(h.hp,amount))
        guard actual>0 else{return}
        h.hp -= actual; h.lastAttacker=attacker.id
        let points=Int(actual.rounded())
        attacker.matchXP+=points
        feedback.append(CombatFeedback(attacker:attacker.id,victim:h.id,position:h.p,height:groundHeight(h.p)+h.elevation+1.9,damage:points,killed:h.hp<=0))
        if h.hp <= 0 {
            h.hp=0; h.deaths+=1; attacker.kills+=1; h.respawn=4
            award(attacker,50,reason:"ENEMY ELIMINATED")
            for t in 0..<2 where flags[t].carrier == h.id { flags[t].carrier=nil; flags[t].p=h.p; flags[t].droppedAt=elapsed }
            if mode == .conquest { tickets[h.team] -= 1 }
            message=attacker.id == 0 ? "Eliminated enemy" : h.id == 0 ? "Respawning…" : ""
        }
    }
    func award(_ h:Hero,_ points:Int,reason:String) {
        h.matchXP+=max(0,points);scoreFeedback.append(ScoreFeedback(hero:h.id,amount:points,reason:reason))
    }
    func reload(_ h:Hero) {
        guard h.alive,h.reloadRemaining<=0,let weapon=h.weapon,h.ammunition[h.weaponSlot]<weapon.magazine else { return }
        h.reloadRemaining=weapon.reloadTime
    }
    func switchWeapon(_ h:Hero) {
        guard h.alive,h.equipped.count>1 else { return }
        h.weaponSlot=(h.weaponSlot+1)%h.equipped.count;h.reloadRemaining=0;h.cooldown=0.2
    }
    func reticlePoint(origin:V3,direction:V3,excluding:Int,range:Double=150)->V3 {
        let direction=direction.unit,end=origin+direction*range
        let obstruction=shotObstacle?(origin,end) ?? end
        let limit=(obstruction-origin).length
        let distance=heroes.filter{$0.id != excluding && $0.alive}.compactMap { h -> Double? in
            let feet=V3(x:h.p.x,y:groundHeight(h.p)+h.elevation,z:h.p.z)
            guard let hit=capsuleHit(origin:origin,direction:direction,feet:feet),hit<limit else { return nil }
            return hit
        }.min()
        return distance.map{origin+direction*$0} ?? obstruction
    }
    func shoot(_ h: Hero, aim: V2, bot: Bool, aimPoint:V3?=nil) {
        guard h.cooldown <= 0,h.reloadRemaining<=0 else { return }
        if let weapon=h.weapon,weapon.magazine>0 {
            if h.ammunition[h.weaponSlot]<=0 { reload(h);return }
            h.ammunition[h.weaponSlot]-=1
        }
        h.cooldown=h.weaponInterval;h.recentShot=0.12
        if let aimPoint=aimPoint {
            let origin=V3(x:h.p.x,y:groundHeight(h.p)+h.elevation+1.2,z:h.p.z)
            let direction=(aimPoint-origin).unit
            let desired=origin+direction*h.weaponRange
            var end=shotObstacle?(origin,desired) ?? desired
            let obstruction=(end-origin).length
            let hit=heroes.filter{$0.id != h.id && $0.alive}.compactMap { target -> (Hero,Double)? in
                let feet=V3(x:target.p.x,y:groundHeight(target.p)+target.elevation,z:target.p.z)
                guard let distance=capsuleHit(origin:origin,direction:direction,feet:feet),distance<obstruction else { return nil }
                return (target,distance)
            }.min{$0.1<$1.1}
            if let (target,distance)=hit {
                end=origin+direction*distance
                if target.team != h.team && (!bot || rng.next()<0.62) { hurt(target,h.weaponDamage,attacker:h) }
            }
            if h.weapon?.isMelee != true { shots.append(Shot(from:origin.horizontal,to:end.horizontal,team:h.team,fromY:origin.y,toY:end.y)) }
            return
        }
        let direction=aim.unit
        let target=heroes.filter {
            guard $0.team != h.team && $0.alive else { return false }
            let d=$0.p-h.p; let alignment=d.unit.x*direction.x+d.unit.z*direction.z
            return d.length<h.weaponRange && alignment>0.96 && visible(h.p,$0.p)
        }.min { $0.p.distance(h.p)<$1.p.distance(h.p) }
        var end=h.p+direction*h.weaponRange
        if let target=target {
            end=target.p
            // Bots have imperfect aim; class rate of fire is also enforced.
            if !bot || rng.next() < 0.62 { hurt(target,h.weaponDamage,attacker:h) }
        } else {
            for i in 1...Int(h.weaponRange*2) {
                let p=h.p+direction*(Double(i)/2)
                if !free(p) { end=p; break }
            }
        }
        if h.weapon?.isMelee != true { shots.append(Shot(from:h.p,to:end,team:h.team,fromY:groundHeight(h.p)+h.elevation+1.2,toY:groundHeight(end)+1.2)) }
    }
    func preferredWeapon(_ h:Hero,distance:Double)->Int? {
        let usable=h.equipped.indices.filter {
            let w=h.equipped[$0]
            return w.range>=distance && (w.magazine==0 || h.ammunition[$0]>0) && ($0 != h.weaponSlot || h.reloadRemaining==0)
        }
        return usable.max {
            let a=h.equipped[$0],b=h.equipped[$1]
            let ad=a.damage/max(0.05,a.interval),bd=b.damage/max(0.05,b.interval)
            return ad==bd ? $0>$1 : ad<bd
        }
    }
    func ability(_ h: Hero) {
        guard h.ability <= 0, h.alive else { return }
        h.ability=max(6,12-Double(h.abilityRank-1))
        switch h.kind {
        case .soldier:
            for friend in heroes where friend.team == h.team && friend.alive && friend.p.distance(h.p)<7 { friend.hp=min(friend.kind.hp,friend.hp+45+Double(h.abilityRank-1)*8) }
            if h.id == 0 { message="Field heal" }
        case .heavy: h.invulnerable=3+Double(h.abilityRank-1)*0.3; if h.id == 0 { message="Shield up" }
        case .scout:
            for _ in 0..<(15+h.abilityRank-1) { move(h,V2(x:sin(h.facing),z:cos(h.facing)),0.055) }
            h.invulnerable=0.6; if h.id == 0 { message="Dash" }
        }
    }
    func finish(_ team:Int,reason:String){guard winner==nil else{return};winner=team;endReason=reason}
    func update(_ dt: Double, input: Input = Input(), autopilot: Bool = false) {
        guard !paused, winner == nil else { return }
        let dt=max(0,min(dt,0.05)); elapsed+=dt; shots=[]
        var pathBudget=1
        for h in heroes {
            if h.elevation>0 || h.verticalVelocity>0 {
                h.verticalVelocity-=20*dt;h.elevation=max(0,h.elevation+h.verticalVelocity*dt)
                if h.elevation==0 { h.verticalVelocity=0 }
            }
            if h.reloadRemaining>0 {
                h.reloadRemaining=max(0,h.reloadRemaining-dt)
                if h.reloadRemaining==0,let weapon=h.weapon { h.ammunition[h.weaponSlot]=weapon.magazine }
            }
            h.recentShot=max(0,h.recentShot-dt)
            h.cooldown=max(0,h.cooldown-dt); h.ability=max(0,h.ability-dt); h.invulnerable=max(0,h.invulnerable-dt)
            if !h.alive {
                h.respawn-=dt
                if h.respawn<=0 && mode != .elimination {
                    h.hp=h.kind.hp;h.ammunition=h.equipped.map{$0.magazine};h.reloadRemaining=0; h.p=nearestFree(bases[h.team]+V2(x:0,z:Double(h.id%8)-3.5)); h.invulnerable=2; h.path=[];h.raidWaypoint=nil;h.raidComplete=false;h.raidReadyAt=nil;h.returnWaypoint=nil;h.returnComplete=false;h.wasCarrier=false;h.elevation=0;h.verticalVelocity=0
                }
                continue
            }
            if h.p.distance(bases[h.team])<4 { h.hp=min(h.kind.hp,h.hp+8*dt) }
            if h.id == 0 && !autopilot {
                if input.jump { jump(h) }
                h.facing=input.yaw; move(h,input.move,dt)
                if input.fire { shoot(h,aim:V2(x:sin(h.facing),z:cos(h.facing)),bot:false,aimPoint:input.aimPoint) }
                if input.ability { ability(h) }
                continue
            }
            h.think-=dt
            if h.think<=0 {
                let destination=objective(for:h)
                let needsPath=(h.path.isEmpty && h.p.distance(destination)>0.8) || h.target.distance(destination)>2.5
                if needsPath && pathBudget==0 {h.think=0.04}
                else {h.think=0.55+rng.next()*0.3;if needsPath {h.path=route(h.p,destination);pathBudget-=1};h.target=destination}
            }
            let detection=max(10,h.equipped.map(\.range).max() ?? h.weaponRange)
            let enemy=heroes.filter { $0.team != h.team && $0.alive && $0.p.distance(h.p)<detection && visible(h.p,$0.p) }.min { $0.p.distance(h.p)<$1.p.distance(h.p) }
            if h.kind == .soldier && heroes.contains(where: { $0.team==h.team && $0.alive && $0.hp<$0.kind.hp*0.65 && $0.p.distance(h.p)<6.5 }) { ability(h) }
            var movement=V2.zero
            while let next=h.path.first,h.p.distance(next)<0.6 { h.path.removeFirst() }
            if let next=h.path.first { movement=(next-h.p).unit }
            if let enemy=enemy {
                let aim=enemy.p-h.p; h.facing=atan2(aim.x,aim.z)
                if let index=preferredWeapon(h,distance:aim.length),index != h.weaponSlot {
                    h.weaponSlot=index;h.reloadRemaining=0;h.cooldown=max(h.cooldown,0.2)
                }
                shoot(h,aim:aim,bot:true,aimPoint:shotObstacle == nil ? nil : V3(x:enemy.p.x,y:groundHeight(enemy.p)+enemy.elevation+1.1,z:enemy.p.z))
                if h.hp<h.kind.hp*0.55 || (h.kind == .heavy && aim.length<9) {
                    let facing=h.facing
                    if h.kind == .scout {
                        let escape=(h.path.first ?? objective(for:h))-h.p
                        if escape.length>0.1 { h.facing=atan2(escape.x,escape.z) }
                    }
                    ability(h);h.facing=facing
                }
                if !flagCarrier(h) && h.hp>=h.kind.hp*0.25 {
                    if h.weapon?.isMelee==true && aim.length<h.weaponRange+3 {
                        movement=aim.length>h.weaponRange*0.7 ? aim.unit : .zero
                    } else if aim.length<2.7 {
                        movement=aim.unit * -1
                    } else {
                        let lateral=V2(x:aim.z,z:-aim.x).unit*(h.id%2==0 ? 0.2 : -0.2)
                        movement=movement+lateral
                    }
                }
            } else {
                if movement.length>0 { h.facing=atan2(movement.x,movement.z) }
                // Reload between fights, so bots do not reach the next objective with an empty gun.
                if let weapon=h.weapon,weapon.magazine>0,h.ammunition[h.weaponSlot]<max(1,weapon.magazine/2) { reload(h) }
            }
            // Use one movement budget per frame; combat must not add a second full-speed move.
            if movement.length>0 { move(h,movement,dt) }
        }
        switch mode {
        case .conquest, .rocket:
            for i in objectives.indices {
                let previousOwner=objectives[i].owner
                let near=heroes.filter { $0.alive && $0.p.distance(objectives[i].p)<3.8 }
                let blue=near.filter { $0.team == 0 }.count, red=near.count-blue
                if blue != red {
                    let direction=blue>red ? -1.0 : 1.0
                    objectives[i].progress=max(-1,min(1,objectives[i].progress+direction*dt*0.22*Double(min(3,abs(blue-red)))))
                    objectives[i].owner=objectives[i].progress<=(-1) ? 0 : objectives[i].progress>=1 ? 1 : -1
                }
                if objectives[i].owner>=0 && previousOwner != objectives[i].owner {
                    for h in near where h.team==objectives[i].owner {h.captures+=1;award(h,150,reason:"FLAG CAPTURED")}
                }
            }
            if mode == .conquest {
                let a=objectives.filter { $0.owner == 0 }.count, b=objectives.filter { $0.owner == 1 }.count
                if a>b { tickets[1]-=dt*Double(a-b)*0.12 }; if b>a { tickets[0]-=dt*Double(b-a)*0.12 }
                if tickets[0]<=0 || tickets[1]<=0 {finish(tickets[0]<=0 && tickets[1]<=0 ? -1 : tickets[0]<=0 ? 1 : 0,reason:"Conquest • enemy tickets exhausted")}
            } else if objectives[0].owner>=0 {
                let team=objectives[0].owner; score[team]+=dt
                if score[team]>=60 {finish(team,reason:"Rocket Control • held the objective for 60 seconds")}
            }
        case .flags:
            for t in 0..<2 {
                if let id=flags[t].carrier { flags[t].p=heroes[id].p }
                else {
                    if flags[t].p.distance(flags[t].home)>1 && elapsed-flags[t].droppedAt>18 { flags[t].p=flags[t].home }
                    for h in heroes where h.alive && h.p.distance(flags[t].p)<1.6 {
                        if h.team != t { flags[t].carrier=h.id;flagPickups[h.team]+=1; break }
                        else if flags[t].p.distance(flags[t].home)>1 { flags[t].p=flags[t].home }
                    }
                }
            }
            for t in 0..<2 {
                if let id=flags[1-t].carrier, heroes[id].p.distance(flags[t].home)<2.5, flags[t].carrier == nil, flags[t].p.distance(flags[t].home)<1 {
                    score[t]+=1;heroes[id].captures+=1;award(heroes[id],150,reason:"FLAG CAPTURED"); flags[1-t].carrier=nil; flags[1-t].p=flags[1-t].home; message=t == 0 ? "Blue captured!" : "Red captured!"
                    if score[t]>=3 {finish(t,reason:"Capture the Flag • 3 flags captured")}
                }
            }
        case .elimination:
            let blueAlive=heroes.contains{$0.team==0 && $0.alive},redAlive=heroes.contains{$0.team==1 && $0.alive}
            if !blueAlive || !redAlive {finish(!blueAlive && !redAlive ? -1 : blueAlive ? 0 : 1,reason:"Elimination • opposing squad eliminated")}
        }
        if elapsed>=roundDuration && winner == nil {
            let a=mode == .conquest ? tickets[0] : mode == .elimination ? Double(heroes.filter{$0.team == 0 && $0.alive}.count) : score[0]
            let b=mode == .conquest ? tickets[1] : mode == .elimination ? Double(heroes.filter{$0.team == 1 && $0.alive}.count) : score[1]
            finish(abs(a-b)<0.001 ? -1 : a>b ? 0 : 1,reason:"Time limit reached • \(Int(roundDuration/60)) minute round")
        }
    }
}

extension Mode {
    var rules:String {switch self{case .conquest:return "Capture flags and drain enemy tickets • 15 minute round";case .flags:return "First to capture 3 flags wins • 15 minute round";case .elimination:return "Eliminate the opposing squad • no respawns";case .rocket:return "Hold the rocket for 60 total seconds to win"}}
}
