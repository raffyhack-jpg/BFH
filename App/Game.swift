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
enum Mode: String, CaseIterable { case conquest = "Conquest", flags = "Capture the Flag", elimination = "Elimination", rocket = "Rocket Control" }
enum HeroClass: String, CaseIterable {
    case soldier = "Soldier", heavy = "Heavy", scout = "Scout"
    var hp: Double { self == .heavy ? 160 : self == .scout ? 85 : 115 }
    var speed: Double { self == .heavy ? 4.2 : self == .scout ? 6.4 : 5.2 }
    var damage: Double { self == .scout ? 36 : self == .heavy ? 13 : 19 }
    var interval: Double { self == .scout ? 0.8 : self == .heavy ? 0.18 : 0.3 }
    var range: Double { self == .scout ? 28 : self == .heavy ? 17 : 22 }
}
struct Block { var center: V2; var half: V2 }
struct Objective { var p: V2; var progress: Double = 0; var owner: Int = -1 }
struct Flag { var home: V2; var p: V2; var carrier: Int?; var droppedAt: Double = 0 }
final class Hero {
    let id: Int; let team: Int; let kind: HeroClass
    var p: V2; var facing: Double = 0; var hp: Double
    var respawn: Double = 0; var invulnerable: Double = 2
    var cooldown: Double = 0; var ability: Double = 0
    var think: Double = 0; var path: [V2] = []; var target: V2 = .zero
    var kills = 0; var deaths = 0; var lastAttacker: Int?
    var alive: Bool { hp > 0 }
    init(_ id: Int, _ team: Int, _ kind: HeroClass, _ p: V2) {
        self.id=id; self.team=team; self.kind=kind; self.p=p; hp=kind.hp
    }
}
struct Shot { var from: V2; var to: V2; var team: Int }
struct Input { var move = V2.zero; var yaw: Double = 0; var fire = false; var ability = false }
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
    let bases = [V2(x:-24,z:0),V2(x:24,z:0)]
    var objectives: [Objective]
    var flags: [Flag]
    let blocks: [Block] = [
        Block(center:V2(x:-12,z:-9),half:V2(x:3,z:3)), Block(center:V2(x:12,z:9),half:V2(x:3,z:3)),
        Block(center:V2(x:-10,z:9),half:V2(x:2,z:4)), Block(center:V2(x:10,z:-9),half:V2(x:2,z:4)),
        Block(center:V2(x:0,z:-10),half:V2(x:3,z:2)), Block(center:V2(x:0,z:10),half:V2(x:3,z:2)),
        Block(center:V2(x:-5,z:0),half:V2(x:1,z:2)), Block(center:V2(x:5,z:0),half:V2(x:1,z:2))]
    var score = [0.0,0.0]; var tickets = [70.0,70.0]
    var elapsed = 0.0; var winner: Int?; var shots: [Shot] = []; var message = ""
    var rng = RNG(); var paused = false
    init(mode: Mode, hero: HeroClass, seed: UInt64 = 42) {
        self.mode=mode; rng.state=seed
        objectives = mode == .rocket ? [Objective(p:.zero)] : [Objective(p:V2(x:-17,z:0)),Objective(p:.zero),Objective(p:V2(x:17,z:0))]
        flags = [Flag(home:bases[0],p:bases[0]),Flag(home:bases[1],p:bases[1])]
        for i in 0..<12 {
            let team = i < 6 ? 0 : 1
            let kind = i == 0 ? hero : HeroClass.allCases[i%3]
            heroes.append(Hero(i,team,kind,bases[team]+V2(x:0,z:Double(i%6)-2.5)))
        }
    }
    func free(_ p: V2) -> Bool {
        abs(p.x) < 28 && abs(p.z) < 18 && !blocks.contains { abs(p.x-$0.center.x)<$0.half.x+0.45 && abs(p.z-$0.center.z)<$0.half.z+0.45 }
    }
    func visible(_ a: V2, _ b: V2) -> Bool {
        let d=b-a; let n=max(1,Int(d.length/0.45))
        for i in 0...n { if !free(a+d*(Double(i)/Double(n))) { return false } }
        return true
    }
    func move(_ h: Hero, _ direction: V2, _ dt: Double) {
        let d=direction.unit * (h.kind.speed*dt)
        let x=V2(x:h.p.x+d.x,z:h.p.z), z=V2(x:h.p.x,z:h.p.z+d.z)
        if free(x) { h.p.x=x.x }
        if free(z) { h.p.z=z.z }
    }
    // Grid A*: deterministic, small bounded arena; collision footprint matches movement.
    func route(_ a: V2, _ b: V2) -> [V2] {
        if visible(a,b) { return [b] }
        func point(_ key: Int) -> V2 { V2(x:Double(key%57)-28,z:Double(key/57)-18) }
        func key(_ p: V2) -> Int { Int(max(-18,min(18,p.z)).rounded()+18)*57+Int(max(-28,min(28,p.x)).rounded()+28) }
        let start=key(a), end=key(b)
        var open:Set<Int>=[start], cost=[start:0.0], parent:[Int:Int]=[:], closed:Set<Int>=[]
        while !open.isEmpty {
            let current=open.min { (cost[$0] ?? 1e9)+point($0).distance(b) < (cost[$1] ?? 1e9)+point($1).distance(b) }!
            if current == end {
                var result=[b]; var k=current
                while k != start, let prev=parent[k] { result.append(point(k)); k=prev }
                return Array(result.reversed())
            }
            open.remove(current); closed.insert(current)
            let p=point(current)
            for d in [V2(x:1,z:0),V2(x:-1,z:0),V2(x:0,z:1),V2(x:0,z:-1)] {
                let q=p+d; guard free(q) else { continue }
                let k=key(q); guard !closed.contains(k) else { continue }
                let c=(cost[current] ?? 0)+1
                if c < (cost[k] ?? 1e9) { cost[k]=c; parent[k]=current; open.insert(k) }
            }
        }
        return []
    }
    func objective(for h: Hero) -> V2 {
        if h.hp < h.kind.hp*0.25 { return bases[h.team] }
        switch mode {
        case .flags:
            let enemy=1-h.team
            if flags[enemy].carrier == h.id { return flags[h.team].home }
            if let carrier=flags[h.team].carrier { return heroes[carrier].p }
            if flags[h.team].p.distance(flags[h.team].home)>1 { return flags[h.team].p }
            if let carrier=flags[enemy].carrier { return heroes[carrier].p + V2(x:0,z:Double(h.id%3)-1) }
            if h.id%3 == 1 { return flags[h.team].home + V2(x:h.team == 0 ? 5 : -5,z:Double(h.id%4)-2) }
            return flags[enemy].p
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
        h.hp -= amount; h.lastAttacker=attacker.id
        if h.hp <= 0 {
            h.hp=0; h.deaths+=1; attacker.kills+=1; h.respawn=4
            for t in 0..<2 where flags[t].carrier == h.id { flags[t].carrier=nil; flags[t].p=h.p; flags[t].droppedAt=elapsed }
            if mode == .conquest { tickets[h.team] -= 1 }
            message=attacker.id == 0 ? "Eliminated enemy" : h.id == 0 ? "Respawning…" : ""
        }
    }
    func shoot(_ h: Hero, aim: V2, bot: Bool) {
        guard h.cooldown <= 0 else { return }
        h.cooldown=h.kind.interval
        let direction=aim.unit
        let target=heroes.filter {
            guard $0.team != h.team && $0.alive else { return false }
            let d=$0.p-h.p; let alignment=d.unit.x*direction.x+d.unit.z*direction.z
            return d.length<h.kind.range && alignment>(bot ? 0.96 : 0.985) && visible(h.p,$0.p)
        }.min { $0.p.distance(h.p)<$1.p.distance(h.p) }
        var end=h.p+direction*h.kind.range
        if let target=target {
            end=target.p
            // Bots have imperfect aim; class rate of fire is also enforced.
            if !bot || rng.next() < 0.62 { hurt(target,h.kind.damage,attacker:h) }
        } else {
            for i in 1...Int(h.kind.range*2) {
                let p=h.p+direction*(Double(i)/2)
                if !free(p) { end=p; break }
            }
        }
        shots.append(Shot(from:h.p,to:end,team:h.team))
    }
    func ability(_ h: Hero) {
        guard h.ability <= 0, h.alive else { return }
        h.ability=12
        switch h.kind {
        case .soldier:
            for friend in heroes where friend.team == h.team && friend.alive && friend.p.distance(h.p)<7 { friend.hp=min(friend.kind.hp,friend.hp+45) }
            if h.id == 0 { message="Field heal" }
        case .heavy: h.invulnerable=3; if h.id == 0 { message="Shield up" }
        case .scout:
            for _ in 0..<15 { move(h,V2(x:sin(h.facing),z:cos(h.facing)),0.055) }
            h.invulnerable=0.6; if h.id == 0 { message="Dash" }
        }
    }
    func update(_ dt: Double, input: Input = Input(), autopilot: Bool = false) {
        guard !paused, winner == nil else { return }
        let dt=max(0,min(dt,0.05)); elapsed+=dt; shots=[]
        for h in heroes {
            h.cooldown=max(0,h.cooldown-dt); h.ability=max(0,h.ability-dt); h.invulnerable=max(0,h.invulnerable-dt)
            if !h.alive {
                h.respawn-=dt
                if h.respawn<=0 && mode != .elimination {
                    h.hp=h.kind.hp; h.p=bases[h.team]+V2(x:0,z:Double(h.id%6)-2.5); h.invulnerable=2; h.path=[]
                }
                continue
            }
            if h.p.distance(bases[h.team])<4 { h.hp=min(h.kind.hp,h.hp+8*dt) }
            if h.id == 0 && !autopilot {
                h.facing=input.yaw; move(h,input.move,dt)
                if input.fire { shoot(h,aim:V2(x:sin(h.facing),z:cos(h.facing)),bot:false) }
                if input.ability { ability(h) }
                continue
            }
            h.think-=dt
            if h.think<=0 {
                h.think=0.55+rng.next()*0.3; h.target=objective(for:h); h.path=route(h.p,h.target)
            }
            let enemy=heroes.filter { $0.team != h.team && $0.alive && $0.p.distance(h.p)<h.kind.range && visible(h.p,$0.p) }.min { $0.p.distance(h.p)<$1.p.distance(h.p) }
            if let enemy=enemy {
                let aim=enemy.p-h.p; h.facing=atan2(aim.x,aim.z)
                shoot(h,aim:aim,bot:true)
                if h.hp<h.kind.hp*0.55 || (h.kind == .heavy && aim.length<9) { ability(h) }
                // Retreat toward base at critical health, otherwise strafe between shots.
                if h.hp<h.kind.hp*0.25 { move(h,bases[h.team]-h.p,dt) }
                else if aim.length<5 { move(h,aim * -1,dt) }
                else { move(h,V2(x:aim.z,z:-aim.x) * (h.id%2 == 0 ? 1 : -1),dt*0.35) }
            }
            if let next=h.path.first {
                if h.p.distance(next)<0.6 { h.path.removeFirst() }
                else { let d=next-h.p; if enemy == nil { h.facing=atan2(d.x,d.z) }; move(h,d,dt) }
            }
        }
        switch mode {
        case .conquest, .rocket:
            for i in objectives.indices {
                let near=heroes.filter { $0.alive && $0.p.distance(objectives[i].p)<3.8 }
                let blue=near.filter { $0.team == 0 }.count, red=near.count-blue
                if blue != red {
                    let direction=blue>red ? -1.0 : 1.0
                    objectives[i].progress=max(-1,min(1,objectives[i].progress+direction*dt*0.22*Double(min(3,abs(blue-red)))))
                    objectives[i].owner=objectives[i].progress<=(-1) ? 0 : objectives[i].progress>=1 ? 1 : -1
                }
            }
            if mode == .conquest {
                let a=objectives.filter { $0.owner == 0 }.count, b=objectives.filter { $0.owner == 1 }.count
                if a>b { tickets[1]-=dt*Double(a-b)*0.7 }; if b>a { tickets[0]-=dt*Double(b-a)*0.7 }
                if tickets[0]<=0 { winner=1 }; if tickets[1]<=0 { winner=0 }
            } else if objectives[0].owner>=0 {
                let team=objectives[0].owner; score[team]+=dt
                if score[team]>=60 { winner=team }
            }
        case .flags:
            for t in 0..<2 {
                if let id=flags[t].carrier { flags[t].p=heroes[id].p }
                else {
                    if flags[t].p.distance(flags[t].home)>1 && elapsed-flags[t].droppedAt>18 { flags[t].p=flags[t].home }
                    for h in heroes where h.alive && h.p.distance(flags[t].p)<1.6 {
                        if h.team != t { flags[t].carrier=h.id; break }
                        else if flags[t].p.distance(flags[t].home)>1 { flags[t].p=flags[t].home }
                    }
                }
            }
            for t in 0..<2 {
                if let id=flags[1-t].carrier, heroes[id].p.distance(flags[t].home)<2.5, flags[t].carrier == nil, flags[t].p.distance(flags[t].home)<1 {
                    score[t]+=1; flags[1-t].carrier=nil; flags[1-t].p=flags[1-t].home; message=t == 0 ? "Blue captured!" : "Red captured!"
                    if score[t]>=3 { winner=t }
                }
            }
        case .elimination:
            if !heroes.contains(where: { $0.team == 0 && $0.alive }) { winner=1 }
            if !heroes.contains(where: { $0.team == 1 && $0.alive }) { winner=0 }
        }
        if elapsed>=300 && winner == nil {
            let a=mode == .conquest ? tickets[0] : mode == .elimination ? Double(heroes.filter{$0.team == 0 && $0.alive}.count) : score[0]
            let b=mode == .conquest ? tickets[1] : mode == .elimination ? Double(heroes.filter{$0.team == 1 && $0.alive}.count) : score[1]
            winner=a == b ? -1 : a>b ? 0 : 1
        }
    }
}
