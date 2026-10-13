import Foundation
func check(_ condition: @autoclosure () -> Bool, _ message:String) { if !condition() { fatalError(message) } }
// Objective rules, combat attribution, dropped flags, respawn, and navigation.
let conquest=Game(mode:.conquest,hero:.soldier)
for h in conquest.heroes { h.p=conquest.bases[h.team] }
let objective=conquest.objectives[1].p
for h in conquest.heroes where h.team == 0 { h.p=objective }
conquest.heroes.forEach { $0.think=1000 }
for _ in 0..<100 { conquest.update(0.05) }
check(conquest.objectives[1].owner == 0,"Uncontested capture failed")
check(conquest.tickets[1]<70,"Owned points must drain tickets")
let victim=conquest.heroes.first{$0.team == 1}!, attacker=conquest.heroes[0]
victim.invulnerable=0; conquest.hurt(victim,1000,attacker:attacker)
check(!victim.alive && attacker.kills == 1 && victim.deaths == 1,"Kill attribution failed")
for _ in 0..<90 { conquest.update(0.05) }
check(victim.alive,"Conquest respawn failed")
let ctf=Game(mode:.flags,hero:.scout)
ctf.heroes.forEach { $0.think=1000 }
ctf.heroes[0].p=ctf.flags[1].home
ctf.update(0.05)
check(ctf.flags[1].carrier == 0,"Flag pickup failed")
ctf.heroes[0].p=ctf.flags[0].home; ctf.update(0.05)
check(ctf.score[0] == 1 && ctf.flags[1].carrier == nil,"Flag scoring failed")
let elimination=Game(mode:.elimination,hero:.heavy)
for h in elimination.heroes where h.team == 1 { h.invulnerable=0; elimination.hurt(h,1000,attacker:elimination.heroes[0]) }
elimination.update(0.05); check(elimination.winner == 0,"Elimination victory failed")
let rocket=Game(mode:.rocket,hero:.soldier)
rocket.objectives[0].progress = -1; rocket.objectives[0].owner=0
rocket.heroes.forEach { $0.think=1000 }; rocket.score[0]=59.99
rocket.update(0.05); check(rocket.winner == 0,"Rocket victory failed")
let nav=Game(mode:.conquest,hero:.soldier)
let path=nav.route(V2(x:-17,z:0),V2(x:17,z:0))
check(!path.isEmpty,"Pathfinding failed"); check(path.allSatisfy { nav.free($0) },"Path intersects building")
let pause=Game(mode:.conquest,hero:.soldier); pause.paused=true; pause.update(0.05); check(pause.elapsed == 0,"Pause advances simulation")
let jumping=Game(mode:.conquest,hero:.soldier)
let airborne=jumping.heroes[0]
jumping.jump(airborne)
var peak=0.0
for _ in 0..<12 { jumping.update(0.05);peak=max(peak,airborne.elevation) }
check(peak>1 && peak<2,"Jump arc is not usable")
let velocity=airborne.verticalVelocity;jumping.jump(airborne);check(airborne.verticalVelocity==velocity,"Double jump was allowed")
for _ in 0..<30 { jumping.update(0.05) }
check(airborne.elevation==0 && airborne.verticalVelocity==0,"Jump did not land")
for mode in Mode.allCases {
    let game=Game(mode:mode,hero:.soldier,seed:72)
    for _ in 0..<6200 {
        game.update(0.05,autopilot:true)
        for h in game.heroes { check(h.p.x.isFinite && h.p.z.isFinite && game.free(h.p),"Invalid bot position in \(mode)") }
        if game.winner != nil { break }
    }
    check(game.winner != nil,"Match never ends: \(mode)")
    check(game.heroes.contains{$0.kills>0},"Bots never fought: \(mode)")
    print("Bots completed \(mode.rawValue): \(Int(game.elapsed))s, winner \(game.winner!), score \(game.score)")
}
print("All core checks passed")

let equipmentGame=Game(mode:.conquest,hero:.soldier,playerTeam:1)
precondition(equipmentGame.heroes[0].team==1 && equipmentGame.heroes.filter{$0.team==1}.count==8)
let equipped=equipmentGame.heroes[0]
equipped.equip([WeaponProfile(id:1,name:"SMG",damage:19,interval:0.2,range:25,magazine:2,reloadTime:1),WeaponProfile(id:2,name:"Pistol",damage:22,interval:0.4,range:24,magazine:8,reloadTime:2)])
equipmentGame.shoot(equipped,aim:V2(x:1,z:0),bot:false);precondition(equipped.ammunition[0]==1)
equipmentGame.reload(equipped);for _ in 0..<10 {equipmentGame.update(0.05,input:Input())};precondition(equipped.ammunition[0]==1 && equipped.reloadRemaining>0)
for _ in 0..<11 {equipmentGame.update(0.05,input:Input())};precondition(equipped.ammunition[0]==2 && equipped.reloadRemaining==0)
equipmentGame.switchWeapon(equipped);precondition(equipped.weapon?.id==2 && equipped.ammunition[1]==8)
print("Validated selectable faction, weapon magazines, reload timing and two equipment slots")

let meleeGame=Game(mode:.conquest,hero:.scout)
let blade=meleeGame.heroes[0],closeTarget=meleeGame.heroes[8]
blade.equip([WeaponProfile(id:3,name:"Knife",damage:35,interval:0.5,range:2.8,magazine:0,reloadTime:0,isMelee:true)])
closeTarget.p=blade.p+V2(x:1,z:0);closeTarget.invulnerable=0
meleeGame.shoot(blade,aim:V2(x:1,z:0),bot:false)
check(closeTarget.hp==closeTarget.kind.hp-35 && meleeGame.shots.isEmpty,"Knife must strike nearby targets without a bullet tracer")
check(blade.ammunition[0]==0 && blade.reloadRemaining==0,"Knife must not consume ammunition")
print("Validated close-range melee equipment without bullet traces or magazine reloads")

let aimingGame=Game(mode:.conquest,hero:.soldier)
aimingGame.heroes.forEach{$0.p=V2(x:-20,z:15)}
let marksman=aimingGame.heroes[0],raised=aimingGame.heroes[8]
marksman.p=V2(x:0,z:0);raised.p=V2(x:0,z:10);raised.elevation=3;raised.invulnerable=0
marksman.equip([WeaponProfile(id:4,name:"Rifle",damage:20,interval:0.2,range:40,magazine:20,reloadTime:1)])
aimingGame.shoot(marksman,aim:V2(x:0,z:1),bot:false,aimPoint:V3(x:0,y:4.1,z:10))
check(raised.hp==raised.kind.hp-20,"Looking up must hit an elevated target")
check(aimingGame.shots.last!.toY>3,"Tracer must rise to the elevated target")
marksman.cooldown=0
aimingGame.shoot(marksman,aim:V2(x:0,z:1),bot:false,aimPoint:V3(x:0,y:1.2,z:10))
check(raised.hp==raised.kind.hp-20,"Horizontal shot must miss a target above the crosshair")
marksman.cooldown=0
aimingGame.shotObstacle={ from,to in from+(to-from)*0.1 }
aimingGame.shoot(marksman,aim:V2(x:0,z:1),bot:false,aimPoint:V3(x:0,y:4.1,z:10))
check(raised.hp==raised.kind.hp-20,"Scenery must block shots before they reach a target")
aimingGame.shotObstacle=nil;marksman.cooldown=0
let friend=aimingGame.heroes[1];friend.p=V2(x:0,z:5);friend.elevation=1.45
aimingGame.shoot(marksman,aim:V2(x:0,z:1),bot:false,aimPoint:V3(x:0,y:4.1,z:10))
check(raised.hp==raised.kind.hp-20 && friend.hp==friend.kind.hp,"A teammate must stop the ray without friendly damage")
check(capsuleHit(origin:V3(x:0,y:1,z:0),direction:V3(x:0,y:0,z:1),feet:V3(x:0,y:0,z:10))!<10,"Capsule intersection must hit the front surface")
print("Validated crosshair height, airborne targets, scenery obstruction and teammate shielding")
