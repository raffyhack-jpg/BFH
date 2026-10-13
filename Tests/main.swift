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
    print("Bots completed \(mode.rawValue): \(Int(game.elapsed))s, winner \(game.winner!), score \(game.score), flag pickups \(game.flagPickups)")
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

aimingGame.heroes[1].p=V2(x:-20,z:15)
let cameraOrigin=V3(x:-0.55,y:1.5,z:-4.6),bodyPoint=V3(x:0,y:4.1,z:10)
let reticle=aimingGame.reticlePoint(origin:cameraOrigin,direction:(bodyPoint-cameraOrigin).unit,excluding:marksman.id)
check(reticle.z<10 && reticle.z>9,"Crosshair must converge on a visible character before the background")
marksman.cooldown=0
aimingGame.shoot(marksman,aim:V2(x:0,z:1),bot:false,aimPoint:reticle)
check(raised.hp==raised.kind.hp-40,"Shoulder camera parallax must not miss the selected target")
print("Validated shoulder-camera crosshair convergence on characters")

let tactics=Game(mode:.flags,hero:.soldier)
let carrier=tactics.heroes[1]
tactics.flags[1].carrier=carrier.id;carrier.hp=carrier.kind.hp*0.1
check(tactics.objective(for:carrier)==tactics.flags[0].home,"Wounded carrier must prioritize returning the flag")
carrier.hp=carrier.kind.hp
let escort=tactics.heroes[2],thief=tactics.heroes[8]
carrier.p=V2(x:10,z:0)
tactics.flags[0].carrier=thief.id
for h in tactics.heroes where h.team==0 && h.id != carrier.id { h.p=V2(x:Double(h.id)-10,z:14) }
thief.p=V2(x:-15,z:14)
let retrieval=tactics.heroes.filter{$0.team==0 && $0.id != 0 && $0.id != carrier.id && tactics.objective(for:$0)==thief.p}
check(retrieval.count==3,"Only a three-bot retrieval squad should chase the stolen home flag")
let remaining=tactics.heroes.filter { h in h.team==0 && h.id != 0 && h.id != carrier.id && !retrieval.contains(where:{$0.id==h.id}) }
check(remaining.allSatisfy{tactics.objective(for:$0).distance(carrier.p)<6},"Remaining bots must protect their carrier")

let pursuit=Game(mode:.flags,hero:.soldier)
for h in pursuit.heroes { h.hp=0;h.respawn=10000 }
let knifeBot=pursuit.heroes[1],opponent=pursuit.heroes[8]
knifeBot.hp=knifeBot.kind.hp;opponent.hp=opponent.kind.hp
knifeBot.p=V2(x:0,z:0);opponent.p=V2(x:0,z:4);opponent.think=1000;opponent.cooldown=1000
knifeBot.equip([WeaponProfile(id:5,name:"Knife",damage:35,interval:0.5,range:2.8,magazine:0,reloadTime:0,isMelee:true)])
knifeBot.think=1000;knifeBot.path=[]
let before=knifeBot.p.distance(opponent.p)
pursuit.update(0.05)
check(knifeBot.p.distance(opponent.p)<before,"Knife bot must approach instead of backing away")
check(knifeBot.p.distance(V2(x:0,z:0))<=knifeBot.kind.speed*0.05+0.0001,"Bot movement exceeded one speed budget")
pursuit.flags[1].carrier=knifeBot.id
knifeBot.path=[V2(x:-3,z:0)];let previous=knifeBot.p
pursuit.update(0.05)
check(knifeBot.p.x<previous.x,"Flag carrier must keep following the return route during combat")
knifeBot.equip([WeaponProfile(id:5,name:"Knife",damage:35,interval:0.5,range:2.8,magazine:0,reloadTime:0,isMelee:true),WeaponProfile(id:6,name:"Rifle",damage:20,interval:0.4,range:40,magazine:8,reloadTime:2)])
check(pursuit.preferredWeapon(knifeBot,distance:15)==1,"Bot must select its ranged weapon for a distant enemy")
check(pursuit.preferredWeapon(knifeBot,distance:2)==0,"Bot must select its stronger melee weapon at close range")
print("Validated flag return, split retrieval/escort squads, melee pursuit and bot movement budgets")

let returnTrip=Game(mode:.flags,hero:.soldier)
for h in returnTrip.heroes { h.hp=0;h.respawn=10000 }
let runner=returnTrip.heroes[1];runner.hp=runner.kind.hp;runner.p=V2(x:22,z:0)
returnTrip.flags[1].carrier=runner.id;returnTrip.flags[1].p=runner.p
for _ in 0..<600 { returnTrip.update(0.05);if returnTrip.score[0]>0 { break } }
check(returnTrip.score[0]==1,"Bot carrier must navigate the buildings and complete a capture without teleporting")

let fieldMedic=Game(mode:.flags,hero:.soldier)
for h in fieldMedic.heroes { h.hp=0;h.respawn=10000 }
let medic=fieldMedic.heroes[3],patient=fieldMedic.heroes[4]
medic.hp=medic.kind.hp;medic.p=V2(x:0,z:0);medic.think=1000
patient.hp=patient.kind.hp*0.4;patient.p=V2(x:1,z:0);patient.think=1000
let injury=patient.hp
fieldMedic.update(0.05)
check(patient.hp>injury && medic.ability>0,"Healthy soldier bot must heal a wounded teammate even between fights")
print("Validated autonomous flag capture around buildings and proactive squad healing")

let raid=Game(mode:.flags,hero:.soldier),raiderID=2
let raider=raid.heroes[raiderID],flank=raid.objective(for:raid.heroes[raiderID])
check(flank != raid.flags[1].p && raid.free(flank),"Raider must choose a walkable flanking waypoint")
raider.p=flank
check(raid.objective(for:raider)==raid.flags[1].p,"Raider must advance to the flag after reaching its flank")
raider.p=flank+V2(x:2,z:0)
check(raid.objective(for:raider)==raid.flags[1].p,"Raider must not oscillate back to its completed waypoint")
print("Validated committed flanking routes without waypoint oscillation")
