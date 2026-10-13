import UIKit
import SceneKit
import simd
import CoreText

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let w=UIWindow(frame:UIScreen.main.bounds); w.rootViewController=GameController(); w.makeKeyAndVisible(); window=w; return true
    }
}
final class Stick: UIView {
    var value=CGPoint.zero
    private let knob=UIView()
    override init(frame:CGRect) {
        super.init(frame:frame); backgroundColor=UIColor.white.withAlphaComponent(0.12); layer.cornerRadius=frame.width/2
        layer.borderColor=UIColor.white.withAlphaComponent(0.3).cgColor; layer.borderWidth=2
        knob.backgroundColor=UIColor.white.withAlphaComponent(0.6); knob.frame=CGRect(x:0,y:0,width:42,height:42); knob.layer.cornerRadius=21; addSubview(knob); reset()
    }
    required init?(coder:NSCoder) { fatalError() }
    func reset() { value = .zero; knob.center=CGPoint(x:bounds.midX,y:bounds.midY) }
    func track(_ touches:Set<UITouch>) {
        guard let p=touches.first?.location(in:self) else { return }
        let dx=p.x-bounds.midX, dy=p.y-bounds.midY, radius=bounds.width*0.35
        let length=max(radius,sqrt(dx*dx+dy*dy)); value=CGPoint(x:dx/length,y:dy/length)
        knob.center=CGPoint(x:bounds.midX+value.x*radius,y:bounds.midY+value.y*radius)
    }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) { track(touches) }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) { track(touches) }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) { reset() }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?) { reset() }
}
final class AimSurface:UIView {
    var delta=CGPoint.zero,isHeld=false
    var owned:UITouch?,previous=CGPoint.zero
    var fires=false
    func consume()->CGPoint { let result=delta;delta = .zero;return result }
    func reset() { owned=nil;isHeld=false;delta = .zero }
    override func touchesBegan(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard owned==nil,let touch=touches.first else { return };owned=touch;previous=touch.location(in:self);isHeld=true
    }
    override func touchesMoved(_ touches:Set<UITouch>,with event:UIEvent?) {
        guard let touch=owned,touches.contains(touch) else { return }
        let point=touch.location(in:self);delta.x+=point.x-previous.x;delta.y+=point.y-previous.y;previous=point
    }
    override func touchesEnded(_ touches:Set<UITouch>,with event:UIEvent?) { if let touch=owned,touches.contains(touch) { reset() } }
    override func touchesCancelled(_ touches:Set<UITouch>,with event:UIEvent?) { reset() }
}
final class GameController: UIViewController {
    let render=SCNView(); let scene=SCNScene(); let camera=SCNNode(); let target=SCNNode()
    var skyNode:SCNNode?; var originalWorld:OriginalWorld?; var game:Game?; var selectedClass=HeroClass.soldier; var selectedMode=Mode.conquest
    var menuActor:AnimatedCharacter?,menuHeroView:SCNView?
    var menuCenter:NSLayoutConstraint?,menuLogo:UIImageView?,menuSubtitle:UILabel?,menuResult:UILabel?,menuHeroTitle:ComicLabel?
    var wardrobe:OriginalWardrobe?;var selectedTeam=0;var playerLoadout=HeroLoadout()
    let switchButton=UIButton(type:.system),reloadButton=UIButton(type:.system)
    var animators:[AnimatedCharacter?]=[]; var previousPositions:[V2]=[]
    var nodes:[SCNNode]=[]; var objectiveNodes:[SCNNode]=[]; var flagNodes:[SCNNode]=[]
    let comicHUD=ComicHUD(frame:.zero),scoreToast=ComicLabel()
    var careerDirty=false,careerSaveTime=0.0
    let teamLabels=(0..<16).map{_ in ComicLabel()}
    var career=HeroCareer(),creditedXP=0,matchFaction=1,matchKind=HeroClass.soldier,matchRewarded=false
    let effects=SCNNode(); let world=SCNNode(); let hud=UILabel(); let notice=ComicLabel()
    var left=Stick(frame:CGRect(x:0,y:0,width:116,height:116)); let right=AimSurface(),fire=AimSurface()
    let skill=UIButton(type:.system),pause=UIButton(type:.system),jumpButton=UIButton(type:.system)
    let crosshair=OriginalCrosshair()
    var jumpRequested=false,cameraReady=false
    var firing=false; var yaw=Double.pi/2; var pitch=0.2; var display:CADisplayLink?; var last=0.0; var hudTime=0.0; var menu:UIView?
    let blue=UIColor(red:0.12,green:0.6,blue:0.93,alpha:1), red=UIColor(red:0.96,green:0.33,blue:0.25,alpha:1)
    override var prefersStatusBarHidden:Bool { true }
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        render.frame=view.bounds; render.autoresizingMask=[.flexibleWidth,.flexibleHeight]; view.addSubview(render)
        render.scene=scene; render.isPlaying=true; render.antialiasingMode = .multisampling2X; render.preferredFramesPerSecond=60
        scene.background.contents=UIColor(red:0.58,green:0.81,blue:0.93,alpha:1); scene.fogColor=UIColor(red:143/255,green:173/255,blue:170/255,alpha:1); scene.fogStartDistance=100; scene.fogEndDistance=270
        scene.rootNode.addChildNode(world); scene.rootNode.addChildNode(effects); scene.rootNode.addChildNode(camera); scene.rootNode.addChildNode(target)
        camera.camera=SCNCamera(); camera.camera?.fieldOfView=68;camera.camera?.wantsHDR=false; camera.camera?.zFar=600; render.pointOfView=camera
        let ambient=SCNNode(); ambient.light=SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity=650; scene.rootNode.addChildNode(ambient)
        let sun=SCNNode(); sun.light=SCNLight(); sun.light?.type = .directional; sun.light?.intensity=1100; sun.light?.castsShadow=true; sun.light?.shadowMapSize=CGSize(width:512,height:512);sun.light?.shadowSampleCount=1; sun.eulerAngles=SCNVector3(-0.9,-0.6,0); scene.rootNode.addChildNode(sun)
        for label in [hud,notice] { label.textColor = .white; label.textAlignment = .center; label.font=UIFont.monospacedSystemFont(ofSize:16,weight:.bold); label.layer.shadowOpacity=0.8; label.layer.shadowRadius=2; view.addSubview(label) }
        for label in teamLabels {label.isUserInteractionEnabled=false;label.isHidden=true;view.addSubview(label)}
        view.addSubview(comicHUD);view.addSubview(scoreToast);scoreToast.isUserInteractionEnabled=false
        hud.isHidden=true
        view.addSubview(right)
        for control in [left,fire,skill,pause,jumpButton,switchButton,reloadButton] { view.addSubview(control) }
        fire.fires=true;fire.backgroundColor=UIColor.black.withAlphaComponent(0.12);fire.layer.cornerRadius=42;fire.layer.borderWidth=2;fire.layer.borderColor=UIColor.white.withAlphaComponent(0.6).cgColor
        let fireText=UILabel(frame:fire.bounds);fireText.autoresizingMask=[.flexibleWidth,.flexibleHeight];fireText.text="FIRE";fireText.numberOfLines=2;fireText.textAlignment = .center;fireText.textColor = .white;fireText.font=UIFont.boldSystemFont(ofSize:12);fire.addSubview(fireText)
        style(skill,"ABILITY",blue);style(pause,"Ⅱ",UIColor.darkGray);style(jumpButton,"JUMP",UIColor.darkGray)
        style(switchButton,"SWAP",UIColor.darkGray);style(reloadButton,"RELOAD",UIColor.darkGray)
        for button in [switchButton,skill] {button.backgroundColor = .clear;button.layer.borderWidth=0;button.layer.shadowOpacity=0;button.setTitle("",for:.normal)}
        switchButton.addGestureRecognizer(UITapGestureRecognizer(target:self,action:#selector(selectEquipment(_:))))
        reloadButton.addAction(UIAction{[weak self] _ in guard let self=self,let g=self.game,!g.paused else{return};g.reload(g.heroes[0])},for:.touchUpInside)
        jumpButton.addAction(UIAction { [weak self] _ in self?.jumpRequested=true },for:.touchDown)
        crosshair.text=nil;crosshair.textColor = .white;crosshair.font=UIFont.systemFont(ofSize:26,weight:.light);crosshair.textAlignment = .center;crosshair.isUserInteractionEnabled=false;view.addSubview(crosshair)
        skill.addTarget(self,action:#selector(useSkill),for:.touchUpInside); pause.addTarget(self,action:#selector(togglePause),for:.touchUpInside)
        display=CADisplayLink(target:self,selector:#selector(tick(_:))); display?.add(to:.main,forMode:.common)
        NotificationCenter.default.addObserver(self,selector:#selector(background),name:UIApplication.willResignActiveNotification,object:nil)
        if let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/OriginalWorld") { originalWorld=try? OriginalWorld(directory:directory) }
        if let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/Wardrobe") { wardrobe=try? OriginalWardrobe(directory:directory) }
        selectedTeam=min(1,max(0,UserDefaults.standard.integer(forKey:"selected-faction")))
        if let saved=UserDefaults.standard.string(forKey:"selected-class"),let kind=HeroClass(rawValue:saved) { selectedClass=kind }
        hud.numberOfLines=2;hud.font=UIFont.monospacedSystemFont(ofSize:12,weight:.bold)
        showMenu()
        if ProcessInfo.processInfo.arguments.contains("--qa-navigation"){DispatchQueue.main.asyncAfter(deadline:.now()+2){self.checkMenuNavigation()}}
        if ProcessInfo.processInfo.arguments.contains("--qa-gameplay"){DispatchQueue.main.asyncAfter(deadline:.now()+1){self.start()}}
        if ProcessInfo.processInfo.arguments.contains("--qa-wardrobe"){DispatchQueue.main.asyncAfter(deadline:.now()+1){self.customizeHero(shop:true)}}
        if ProcessInfo.processInfo.arguments.contains("--qa-abilities"){DispatchQueue.main.asyncAfter(deadline:.now()+1){self.showCareer()}}
    }
    func style(_ b:UIButton,_ title:String,_ color:UIColor) { b.setTitle(title,for:.normal); b.setTitleColor(.white,for:.normal); b.titleLabel?.font=UIFont.boldSystemFont(ofSize:16); b.backgroundColor=color.withAlphaComponent(0.82); b.layer.cornerRadius=5;b.layer.borderWidth=2;b.layer.borderColor=UIColor(red:0.95,green:0.9,blue:0.65,alpha:1).cgColor;b.titleLabel?.font=UIFont.systemFont(ofSize:16,weight:.black);b.layer.shadowOpacity=0.6;b.layer.shadowOffset=CGSize(width:2,height:3);b.layer.shadowRadius=0 }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); let r=view.safeAreaInsets; let w=view.bounds.width,h=view.bounds.height
        left.frame.origin=CGPoint(x:r.left+25,y:h-r.bottom-166);right.frame=CGRect(x:w*0.38,y:0,width:w*0.62,height:h)
        fire.frame=CGRect(x:w-r.right-106,y:h-r.bottom-150,width:88,height:88); let k=max(0.85,min(1.1,h/390));skill.frame=CGRect(x:w/2+34*k,y:h-r.bottom-75*k,width:64*k,height:64*k)
        switchButton.frame=CGRect(x:w/2-100*k,y:h-r.bottom-75*k,width:132*k,height:64*k);reloadButton.frame=CGRect(x:w-r.right-224,y:h-r.bottom-110,width:96,height:42)
        pause.frame=CGRect(x:w-r.right-66,y:r.top+14,width:48,height:38)
        jumpButton.frame=CGRect(x:w-r.right-214,y:h-r.bottom-178,width:88,height:60);crosshair.frame=CGRect(x:w/2-20,y:h/2-20,width:40,height:40)
        hud.frame=CGRect(x:r.left+80,y:r.top+14,width:w-r.left-r.right-160,height:48); notice.frame=CGRect(x:100,y:h*0.24,width:w-200,height:45)
        comicHUD.frame=view.bounds;scoreToast.frame=CGRect(x:w/2-165,y:h*0.32,width:330,height:50)
        menu?.frame=view.bounds
    }
    func sphere(_ radius:CGFloat,_ color:UIColor) -> SCNNode { let g=SCNSphere(radius:radius); g.segmentCount=10; g.firstMaterial?.diffuse.contents=color; return SCNNode(geometry:g) }
    func soldier(_ kind:HeroClass,_ team:Int,loadout:HeroLoadout?=nil) throws -> SCNNode {
        guard let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/Characters"),let original=originalWorld else { throw CocoaError(.fileReadNoSuchFile) }
        let animator=try AnimatedCharacter(team == 0 ? "royal" : "national",directory:directory)
        if let wardrobe=wardrobe { try wardrobe.apply(loadout ?? wardrobe.defaults(team+1,kind),faction:team+1,to:animator) }
        animator.weaponID=loadout?.weapons.first
        animator.weaponPose=loadout?.weapons.first.flatMap{wardrobe?.weapons[$0]?.pose} ?? "smg"
        animators.append(animator)
        let root=animator.node
        let gun=try loadout?.weapons.first.flatMap{wardrobe?.weapons[$0]}.map{try original.model($0.model)} ?? original.weapon(kind,team);gun.name="held-weapon";animator.bones[44].addChildNode(gun)
        return root
    }
    func start() {
        render.isHidden=false;render.isPlaying=true;scene.isPaused=false
        (menu as? OriginalMenuShell)?.detachControllers();menu?.removeFromSuperview(); menu=nil;menuActor=nil;menuHeroView=nil; firing=false; yaw = .pi/2; pitch=0.08; left.reset();right.reset();fire.reset();cameraReady=false;jumpRequested=false
        guard let original=originalWorld else { notice.text="Original assets could not be loaded. Rebuild the IPA."; showMenu(result:"ASSET LOAD FAILED"); return }
        comicHUD.portrait.image=makeHeroPortrait()
        let g=Game(mode:selectedMode,hero:selectedClass,layout:original.layout,playerTeam:selectedTeam); game=g
        matchFaction=selectedTeam+1;matchKind=selectedClass;career=CareerStore.shared.load(matchFaction,matchKind);creditedXP=0;matchRewarded=false
        g.heroes[0].abilityRank=career.abilityRank
        g.groundHeight={ Double(original.height($0)) }
        g.shotObstacle={ from,to in
            let end=original.shotEnd(from:SIMD3(Float(from.x),Float(from.y),Float(from.z)),to:SIMD3(Float(to.x),Float(to.y),Float(to.z)))
            return V3(x:Double(end.x),y:Double(end.y),z:Double(end.z))
        }
        world.childNodes.forEach{$0.removeFromParentNode()}; effects.childNodes.forEach{$0.removeFromParentNode()}; nodes=[]; animators=[]; previousPositions=g.heroes.map{$0.p}; objectiveNodes=[]; flagNodes=[]
        do { try original.populate(world); let sky=try original.sky();world.addChildNode(sky);skyNode=sky } catch { showMenu(result:"MAP LOAD FAILED"); return }
        playerLoadout=wardrobe?.load(selectedTeam+1,selectedClass) ?? HeroLoadout()
        if let wardrobe=wardrobe {CareerStore.shared.seed(wardrobe.defaults(matchFaction,matchKind),playerLoadout,matchFaction,matchKind);career=CareerStore.shared.load(matchFaction,matchKind)}
        for h in g.heroes {
            let loadout=h.id==0 ? playerLoadout : wardrobe?.defaults(h.team+1,h.kind)
            h.equip((loadout?.weapons ?? []).compactMap{wardrobe?.weapons[$0]}.map{weaponProfile($0)})
        }
        let aim=g.objectives[0].p-g.bases[selectedTeam];yaw=atan2(aim.x,aim.z)
        if selectedMode == .conquest || selectedMode == .rocket {
            for o in g.objectives {
                let node=SCNNode(); node.position=SCNVector3(Float(o.p.x),original.height(o.p),Float(o.p.z)); world.addChildNode(node); objectiveNodes.append(node)
                if let pole=try? original.flag("pole") { pole.position=SCNVector3(Float(o.p.x),original.height(o.p),Float(o.p.z));world.addChildNode(pole) }
                for key in ["royal","national","neutral"] { if let flag=try? original.flag(key) { flag.name=key;flag.position.y = 0;flag.isHidden=key != "neutral";node.addChildNode(flag) } }

            }
        }
        for t in 0..<2 {
            let flag=(try? original.flag(t == 0 ? "ctf-royal" : "ctf-national")) ?? SCNNode(); world.addChildNode(flag); flag.isHidden=selectedMode != .flags; flagNodes.append(flag)
        }
        do { for h in g.heroes { let n=try soldier(h.kind,h.team,loadout:h.id==0 ? playerLoadout : wardrobe?.defaults(h.team+1,h.kind)); world.addChildNode(n); nodes.append(n) } } catch { showMenu(result:"CHARACTER LOAD FAILED"); return }
        notice.text="Drag right: look • Hold and drag FIRE: aim + shoot • JUMP"; hudTime=0; last=0
        comicHUD.isHidden=false;scoreToast.isHidden=false
        for c in [left,right,fire,skill,pause,jumpButton,crosshair,switchButton,reloadButton] { c.isHidden=false }
    }
    @objc func fireDown() { firing=true }
    @objc func fireUp() { firing=false }
    @objc func useSkill() { if let g=game, !g.paused, g.winner == nil { g.ability(g.heroes[0]); UIImpactFeedbackGenerator(style:.light).impactOccurred() } }
    @objc func background() { if let g=game, menu == nil, g.winner == nil { g.paused=true; firing=false;left.reset();right.reset();fire.reset();jumpRequested=false;showMenu(resume:true) } }
    @objc func togglePause() { guard let g=game else { return }; g.paused=true; firing=false; showMenu(resume:true) }
    @objc func tick(_ link:CADisplayLink) {
        let dt=last == 0 ? 0 : min(0.05,link.timestamp-last); last=link.timestamp
        if menu != nil {menuActor?.update(dt,position:.zero,moving:false,firing:false,ability:false,alive:true);return}
        guard let g=game else { return }
        let look=right.consume(),shootLook=fire.consume()
        yaw-=Double(look.x+shootLook.x)*0.0045;pitch=max(-0.35,min(0.65,pitch+Double(look.y+shootLook.y)*0.0035));firing=fire.isHeld
        let forward=V2(x:sin(yaw),z:cos(yaw)), sideways=V2(x:-cos(yaw),z:sin(yaw))
        let move=forward * -Double(left.value.y)+sideways*Double(left.value.x)
        let player=g.heroes[0], p=player.p
        let ground=(originalWorld?.height(p) ?? 0)+Float(player.elevation)
        let focus=SIMD3(Float(p.x),ground+1.5,Float(p.z)),direction=ThirdPersonCamera.direction(yaw:Float(yaw),pitch:Float(pitch))
        let shoulder=SIMD3<Float>(-cos(Float(yaw)),0,sin(Float(yaw)))*0.55
        let desired=focus-direction*4.6+shoulder
        let safe=originalWorld?.cameraPosition(from:focus,to:desired) ?? desired
        camera.simdPosition=cameraReady ? simd_mix(camera.simdPosition,safe,SIMD3(repeating:Float(1-exp(-dt*18)))) : safe
        camera.simdOrientation=ThirdPersonCamera.rotation(position:camera.simdPosition,target:focus+direction*30+shoulder);cameraReady=true
        skyNode?.position=camera.position
        let rayOrigin=camera.simdPosition
        let rayDirection=simd_normalize(focus+direction*30+shoulder-rayOrigin)
        let aimPoint=firing && player.cooldown<=0 ? g.reticlePoint(origin:V3(x:Double(rayOrigin.x),y:Double(rayOrigin.y),z:Double(rayOrigin.z)),
                                   direction:V3(x:Double(rayDirection.x),y:Double(rayDirection.y),z:Double(rayDirection.z)),excluding:player.id) : nil
        g.update(dt,input:Input(move:move,yaw:yaw,fire:firing,ability:false,jump:jumpRequested,aimPoint:aimPoint));jumpRequested=false

        for (i,h) in g.heroes.enumerated() {
            nodes[i].position=SCNVector3(Float(h.p.x),(originalWorld?.height(h.p) ?? 0)+Float(h.elevation),Float(h.p.z)); nodes[i].eulerAngles.y=Float(h.facing); if let animator=animators[i] {
                if let id=h.weapon?.id,id != animator.weaponID,let weapon=wardrobe?.weapons[id],let original=originalWorld,let node=try? original.model(weapon.model) {
                    animator.bones[44].childNodes.filter{$0.name=="held-weapon"}.forEach{$0.removeFromParentNode()};node.name="held-weapon";animator.bones[44].addChildNode(node);animator.weaponID=id;animator.weaponPose=weapon.pose ?? "smg"
                }
                animator.update(dt,position:h.p,moving:h.p.distance(previousPositions[i])>0.003,firing:h.recentShot>0,ability:h.ability>11.5,alive:h.alive,jumping:h.elevation>0.01,reloading:h.reloadRemaining>0)

            } else { nodes[i].isHidden = !h.alive }
            previousPositions[i]=h.p
            nodes[i].opacity=h.invulnerable>0 ? 0.55 : 1
        }
        for (i,o) in g.objectives.enumerated() where i<objectiveNodes.count {
            let key=o.owner == 0 ? "royal" : o.owner == 1 ? "national" : "neutral"
            for child in objectiveNodes[i].childNodes { child.isHidden=child.name != key }
        }
        for i in 0..<2 { flagNodes[i].position=SCNVector3(Float(g.flags[i].p.x),(originalWorld?.height(g.flags[i].p) ?? 0),Float(g.flags[i].p.z)) }
        for shot in g.shots { tracer(shot) }
        combatFeedback(g)
        let gained=max(0,player.matchXP-creditedXP)
        if gained>0 {let oldLevel=career.level;career.earn(gained);if career.level>oldLevel {scoreToast.alpha=1;scoreToast.write("LEVEL UP!  \(career.level)",color:.systemYellow,size:30);UIView.animate(withDuration:0.4,delay:1.5,options:[],animations:{self.scoreToast.alpha=0},completion:nil)};creditedXP=player.matchXP;careerDirty=true}
        careerSaveTime+=dt;if careerSaveTime>=1 {flushCareer();careerSaveTime=0}
        hudTime+=dt
        if hudTime>0.15 {
            hudTime=0
            comicHUD.refresh(g,career);updateTeamLabels(g)
            reloadButton.setTitle(player.reloadRemaining>0 ? String(format:"%.1fs",player.reloadRemaining) : "RELOAD",for:.normal)
            switchButton.setTitle("",for:.normal)
            skill.setTitle(player.ability>0 ? "\(Int(ceil(player.ability)))" : "",for:.normal)
            notice.text=player.alive ? (g.elapsed<8 ? "Hold and drag FIRE to aim + shoot • JUMP" : g.message) : g.mode == .elimination ? "Eliminated • watching your squad" : "Respawn in \(Int(ceil(max(0,player.respawn))))"
        }
        if let winner=g.winner {
            if !matchRewarded {
                matchRewarded=true;flushCareer()
                let reward=career.finishMatch(id:g.matchID,kills:player.kills,captures:player.captures,won:winner==player.team)
                CareerStore.shared.save(career,matchFaction,matchKind);g.message="+\(reward) VALOR POINTS"
            }
            showMenu(result:winner == -1 ? "DRAW" : winner == 0 ? "ROYAL VICTORY" : "NATIONAL VICTORY") }
    }
    func checkMenuNavigation(){
        guard let panel=menu as? OriginalMenuShell,let initialScene=panel.hero.scene,let initialActor=menuActor else{fatalError("Missing persistent menu")}
        for _ in 0..<3 {panel.selectTab("My Stuff");panel.openSection(1);panel.selectTab("Store");panel.openSection(2);panel.selectTab("Home")}
        precondition(menu === panel && panel.hero.scene === initialScene && menuActor === initialActor && panel.sceneBuilds==1,"Navigation rebuilt the menu/hero")
        panel.layoutIfNeeded();for b in panel.tabs+panel.sections+panel.equipment{precondition(b.bounds.height>=44 && b.bounds.width>=44,"Menu touch target is too small")}
        precondition(panel.paper.frame==panel.bounds && panel.content.bounds.width>panel.bounds.width*0.5,"Menu is not full screen")
        let report:[String:Any]=["persistentScene":true,"sceneBuilds":panel.sceneBuilds,"fullScreen":true,"minimumTapHeight":44,"menuWidth":panel.bounds.width,"menuHeight":panel.bounds.height]
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("mobile-menu-check.json");try! JSONSerialization.data(withJSONObject:report).write(to:url)
        print("MOBILE_NAVIGATION_VERIFIED")
    }
    func flushCareer(){if careerDirty {CareerStore.shared.save(career,matchFaction,matchKind);careerDirty=false}}
    func updateTeamLabels(_ g:Game){let player=g.heroes[0];for h in g.heroes {let label=teamLabels[h.id];let distance=h.p.distance(player.p);let point=render.projectPoint(SCNVector3(Float(h.p.x),(originalWorld?.height(h.p) ?? 0)+Float(h.elevation)+2.2,Float(h.p.z)));let onScreen=point.z>0 && point.z<1 && point.x>0 && point.x<Float(view.bounds.width) && point.y>0 && point.y<Float(view.bounds.height);let visible=h.id != 0 && h.alive && distance<45 && onScreen && g.visible(player.p,h.p);label.isHidden = !visible;if visible {label.frame=CGRect(x:CGFloat(point.x)-85,y:CGFloat(point.y)-22,width:170,height:25);label.write("\(h.team==player.team ? "ALLY" : "ENEMY") • \(h.kind.rawValue)",color:h.team==player.team ? UIColor(red:0.3,green:0.8,blue:1,alpha:1) : UIColor(red:1,green:0.35,blue:0.3,alpha:1),size:14)}}}
    func tracer(_ shot:Shot) {
        let a=SCNVector3(Float(shot.from.x),Float(shot.fromY),Float(shot.from.z)), b=SCNVector3(Float(shot.to.x),Float(shot.toY),Float(shot.to.z))
        let cylinder=SCNCylinder(radius:0.025,height:CGFloat(sqrt(pow(shot.from.distance(shot.to),2)+pow(shot.toY-shot.fromY,2)))); cylinder.radialSegmentCount=4
        cylinder.firstMaterial?.diffuse.contents=UIColor.yellow; cylinder.firstMaterial?.emission.contents=UIColor.yellow
        let node=SCNNode(geometry:cylinder); node.position=SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2); node.look(at:b,up:SCNVector3(0,1,0),localFront:SCNVector3(0,1,0)); effects.addChildNode(node)
        node.runAction(.sequence([.wait(duration:0.06),.removeFromParentNode()]))
    }
    func showMenu(resume:Bool=false,result:String?=nil) {
        render.isHidden=true;render.isPlaying=false;scene.isPaused=true
        comicHUD.isHidden=true;scoreToast.isHidden=true
        flushCareer();teamLabels.forEach{$0.isHidden=true}
        if let panel=menu as? OriginalMenuShell {panel.resume=resume;panel.result=result;panel.selectTab("Home");return}
        menu?.removeFromSuperview();menuActor=nil;menuHeroView=nil;menuCenter=nil;menuLogo=nil;menuSubtitle=nil;menuResult=nil;menuHeroTitle=nil
        right.reset();fire.reset();jumpRequested=false
        for c in [left,right,fire,skill,pause,jumpButton,crosshair,switchButton,reloadButton] {c.isHidden=true}
        let panel=OriginalMenuShell(owner:self,resume:resume,result:result);view.addSubview(panel);menu=panel
    }

}

extension GameController {
    func weaponProfile(_ weapon:WardrobeWeapon)->WeaponProfile {
        let melee=weapon.weaponType?.lowercased().contains("knife")==true || (weapon.pose?.contains("knife") ?? false) || (weapon.pose?.contains("sword") ?? false) || weapon.pose=="machete" || weapon.pose=="fist"
        if melee { return WeaponProfile(id:weapon.id,name:weapon.name,damage:35,interval:max(0.5,60/max(60,weapon.rpm)),range:2.8,magazine:0,reloadTime:0,isMelee:true) }
        let damage=weapon.weaponClass==5 ? 36.0 : weapon.weaponClass==3 ? 28 : weapon.weaponClass==2 ? 22 : weapon.weaponClass==1 ? 13 : 19
        let range=weapon.weaponClass==5 ? 45.0 : weapon.weaponClass==3 ? 16 : weapon.weaponClass==2 ? 24 : 28
        return WeaponProfile(id:weapon.id,name:weapon.name,damage:damage,interval:60/max(60,weapon.rpm),range:range,magazine:max(1,weapon.magazine),reloadTime:max(0.1,weapon.reload))
    }
    @objc func selectEquipment(_ tap:UITapGestureRecognizer){guard let g=game else{return};let slot=tap.location(in:switchButton).x<switchButton.bounds.width/2 ? 0 : 1;if slot != g.heroes[0].weaponSlot {swapWeapon()}}
    func swapWeapon() {
        guard let g=game,!g.paused,g.winner==nil,let actor=animators.first ?? nil,let original=originalWorld else{return}
        g.switchWeapon(g.heroes[0])
        guard let id=g.heroes[0].weapon?.id,let item=wardrobe?.weapons[id],let node=try? original.model(item.model) else{return}
        actor.weaponID=item.id
        actor.weaponPose=item.pose ?? "smg"
        actor.bones[44].childNodes.filter{$0.name=="held-weapon"}.forEach{$0.removeFromParentNode()};node.name="held-weapon";actor.bones[44].addChildNode(node)
    }
    func customizeHero(category:Int=4,shop:Bool=false) {(menu as? OriginalMenuShell)?.openInventory(category:category,shop:shop)}

}
final class ItemCard:UICollectionViewCell {
    let image=UIImageView(),caption=UILabel(),check=UILabel(),price=UILabel(),frameArt=UIImageView()
    override init(frame:CGRect) {
        super.init(frame:frame);contentView.backgroundColor = .clear;contentView.layer.cornerRadius=7;contentView.layer.borderWidth=2
        frameArt.image=OriginalUIArt.image("panels/01_fgslot.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:8,left:8,bottom:8,right:8));contentView.addSubview(frameArt)
        image.contentMode = .scaleAspectFit;contentView.addSubview(image)
        caption.numberOfLines=2;caption.font=OriginalFont.heavy(14);caption.textColor = UIColor(white:0.15,alpha:1);caption.textAlignment = .center;contentView.addSubview(caption)
        price.font=UIFont.systemFont(ofSize:12,weight:.black);price.textColor = UIColor(red:0.37,green:0.14,blue:0.06,alpha:1);price.textAlignment = .center;contentView.addSubview(price)
        check.text="✓";check.font=UIFont.boldSystemFont(ofSize:20);check.textColor = .yellow;contentView.addSubview(check)
    }
    required init?(coder:NSCoder){fatalError()}
    override func layoutSubviews() { super.layoutSubviews();frameArt.frame=contentView.bounds;image.frame=CGRect(x:8,y:5,width:bounds.width-16,height:bounds.height-59);caption.frame=CGRect(x:3,y:bounds.height-56,width:bounds.width-6,height:34);check.frame=CGRect(x:bounds.width-27,y:3,width:24,height:24);price.frame=CGRect(x:3,y:bounds.height-18,width:bounds.width-6,height:16) }
}
final class WardrobeController:UIViewController,UICollectionViewDataSource,UICollectionViewDelegate,UISearchBarDelegate {
    let wardrobe:OriginalWardrobe,original:OriginalWorld
    var faction:Int,kind:HeroClass,loadout:HeroLoadout
    var profile:HeroCareer {CareerStore.shared.load(faction,kind)}
    var changed:((Int,HeroClass)->Void)?
    let categoryScroll=UIScrollView(),categoryStack=UIStackView(),search=UISearchBar(),find=UIButton(type:.custom),status=UILabel(),reset=UIButton(type:.custom),slots=UISegmentedControl(items:["Weapon 1","Weapon 2"]),collection:UICollectionView
    let frameArt=UIImageView(image:OriginalUIArt.image("panels/01_bgframelargelong.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:40,left:10,bottom:10,right:10)))
    var shopMode=false,category=4,query="",visibleItems:[ClothingItem]=[],visibleWeapons:[WardrobeWeapon]=[],visibleColors:[WardrobeColor]=[]
    let categories=["Hats","Face","Neck","Shirts","Jackets","Waist","Trousers","Shoes","Chest","Skin","Hair","Weapons"]
    init(wardrobe:OriginalWardrobe,original:OriginalWorld,faction:Int,kind:HeroClass){self.wardrobe=wardrobe;self.original=original;self.faction=faction;self.kind=kind;loadout=wardrobe.load(faction,kind);let layout=UICollectionViewFlowLayout();layout.minimumInteritemSpacing=8;layout.minimumLineSpacing=8;collection=UICollectionView(frame:.zero,collectionViewLayout:layout);super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError()}
    override func viewDidLoad(){
        super.viewDidLoad();view.backgroundColor = .clear;for v in [frameArt,categoryScroll,find,status,reset,slots,collection]{view.addSubview(v)}
        categoryStack.axis = .horizontal;categoryStack.spacing=6;categoryScroll.addSubview(categoryStack);categoryScroll.showsHorizontalScrollIndicator=true
        for (i,name) in categories.enumerated(){let b=UIButton(type:.custom);b.tag=i;b.setTitle(name,for:.normal);b.titleLabel?.font=OriginalFont.heavy(16);b.setTitleColor(.white,for:.normal);b.setBackgroundImage(OriginalUIArt.image("components/button.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:7,left:8,bottom:7,right:8)),for:.normal);b.widthAnchor.constraint(equalToConstant:94).isActive=true;b.heightAnchor.constraint(equalToConstant:44).isActive=true;b.addAction(UIAction{[weak self] _ in self?.category=i;self?.refreshList()},for:.touchUpInside);categoryStack.addArrangedSubview(b)}
        find.setTitle("Find",for:.normal);find.titleLabel?.font=OriginalFont.heavy(16);find.setBackgroundImage(OriginalUIArt.image("components/button.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:7,left:8,bottom:7,right:8)),for:.normal);find.addAction(UIAction{[weak self] _ in guard let self=self else{return};let alert=UIAlertController(title:"Find an item",message:nil,preferredStyle:.alert);alert.addTextField{$0.text=self.query;$0.placeholder="Item name"};alert.addAction(UIAlertAction(title:"Search",style:.default){_ in self.query=alert.textFields?.first?.text ?? "";self.refreshList()});alert.addAction(UIAlertAction(title:"Clear",style:.default){_ in self.query="";self.refreshList()});alert.addAction(UIAlertAction(title:"Cancel",style:.cancel));self.present(alert,animated:true)},for:.touchUpInside)
        search.placeholder="Find an item";search.delegate=self;search.searchBarStyle = .minimal;search.searchTextField.font=OriginalFont.heavy(16)
        slots.selectedSegmentIndex=0;slots.setTitleTextAttributes([.font:OriginalFont.heavy(14)],for:.normal);slots.addAction(UIAction{[weak self] _ in self?.refreshList();self?.refreshHero()},for:.valueChanged)
        collection.backgroundColor = .clear;collection.dataSource=self;collection.delegate=self;collection.register(ItemCard.self,forCellWithReuseIdentifier:"item")
        status.font=OriginalFont.heavy(12);status.textColor=UIColor(white:0.15,alpha:1);status.numberOfLines=2
        reset.setTitle("Reset",for:.normal);reset.setTitleColor(.white,for:.normal);reset.titleLabel?.font=OriginalFont.heavy(16);reset.setBackgroundImage(OriginalUIArt.image("components/button.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:7,left:8,bottom:7,right:8)),for:.normal);reset.addAction(UIAction{[weak self] _ in guard let self=self else{return};self.loadout=self.wardrobe.defaults(self.faction,self.kind);self.save();self.refreshHero();self.refreshList()},for:.touchUpInside)
        CareerStore.shared.seed(wardrobe.defaults(faction,kind),loadout,faction,kind);refreshList()
    }
    override func viewDidLayoutSubviews(){super.viewDidLayoutSubviews();let w=view.bounds.width,h=view.bounds.height;frameArt.frame=view.bounds;categoryScroll.frame=CGRect(x:7,y:2,width:max(100,w-154),height:46);categoryScroll.isHidden=category==11;categoryStack.frame=CGRect(origin:.zero,size:categoryStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize));categoryScroll.contentSize=categoryStack.bounds.size;slots.frame=CGRect(x:8,y:3,width:max(100,w-160),height:44);find.frame=CGRect(x:w-140,y:3,width:64,height:44);reset.frame=CGRect(x:w-70,y:3,width:64,height:44);status.frame=CGRect(x:8,y:h-22,width:w-16,height:20);collection.frame=CGRect(x:8,y:52,width:w-16,height:max(30,h-76));let layout=collection.collectionViewLayout as! UICollectionViewFlowLayout;let columns=max(2,Int((w-16)/120));layout.itemSize=CGSize(width:(w-16-CGFloat(columns-1)*8)/CGFloat(columns),height:max(78,min(130,collection.bounds.height)))}
    func save() {wardrobe.save(loadout,faction,kind)}
    func changeHero(faction:Int,kind:HeroClass) {save();self.faction=faction;self.kind=kind;loadout=wardrobe.load(faction,kind);CareerStore.shared.seed(wardrobe.defaults(faction,kind),loadout,faction,kind);refreshList();refreshHero()}
    func refreshList() {
        visibleItems=wardrobe.catalog.items.filter{$0.faction==faction && $0.kits & kind.kitMask != 0 && $0.slot==category && (shopMode || profile.owned.contains($0.id)) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))}.sorted{$0.id<$1.id}
        visibleWeapons=wardrobe.catalog.weapons.filter{$0.faction==faction && $0.kits & kind.kitMask != 0 && (shopMode || profile.owned.contains($0.id)) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))}.sorted{$0.id<$1.id}
        visibleColors=wardrobe.catalog.colors.filter{$0.kind==(category==9 ? "skin" : "hair")}
        for view in categoryStack.arrangedSubviews {view.backgroundColor=view.tag==category ? UIColor(red:0.58,green:0.45,blue:0.14,alpha:1) : UIColor.clear}
        slots.isHidden=category != 11;collection.reloadData();view.setNeedsLayout()
    }
    func refreshHero(){status.text="Saved equipment • \(profile.valor) VP";changed?(faction,kind)}
    func searchBar(_ searchBar:UISearchBar,textDidChange text:String) {query=text;refreshList()}
    func collectionView(_ collectionView:UICollectionView,numberOfItemsInSection section:Int)->Int {category==11 ? visibleWeapons.count : category>=9 ? visibleColors.count : visibleItems.count+1}
    func collectionView(_ collectionView:UICollectionView,cellForItemAt indexPath:IndexPath)->UICollectionViewCell {
        let cell=collectionView.dequeueReusableCell(withReuseIdentifier:"item",for:indexPath) as! ItemCard;cell.image.image=nil;cell.image.backgroundColor = .clear;cell.price.text=nil;var selected=false
        if category==11 {
            let item=visibleWeapons[indexPath.item];cell.caption.text=item.name;cell.price.text=shopLabel(id:item.id,level:item.minimumLevel,valor:item.valorPrice,funds:item.fundsPrice,fallback:500);if let file=item.icon,let image=wardrobe.image(file){cell.image.image=UIImage(cgImage:image)};selected=loadout.weapons.indices.contains(slots.selectedSegmentIndex) && loadout.weapons[slots.selectedSegmentIndex]==item.id
        } else if category>=9 {
            let c=visibleColors[indexPath.item];cell.caption.text=c.name;cell.image.backgroundColor=UIColor(red:CGFloat(c.rgb[0])/255,green:CGFloat(c.rgb[1])/255,blue:CGFloat(c.rgb[2])/255,alpha:1);selected=(category==9 ? loadout.skin : loadout.hair)==c.id
        } else if indexPath.item==0 {cell.caption.text="UNEQUIP";selected=loadout.clothing[category]==nil}
        else {let item=visibleItems[indexPath.item-1];cell.caption.text=item.name;cell.price.text=shopLabel(id:item.id,level:item.minimumLevel,valor:item.valorPrice,funds:item.fundsPrice,fallback:250);if let file=item.icon,let image=wardrobe.image(file){cell.image.image=UIImage(cgImage:image)};selected=loadout.clothing[category]==item.id}
        cell.check.isHidden = !selected;cell.contentView.layer.borderColor=(selected ? UIColor.yellow : UIColor.clear).cgColor;return cell
    }
    func shopLabel(id:Int,level:Int?,valor:Int?,funds:Int?,fallback:Int)->String {
        if profile.owned.contains(id){return "OWNED"}
        if profile.level<(level ?? 1){return "UNLOCKS AT LEVEL \(level ?? 1)"}
        if let valor=valor{return "\(valor) VP"}
        if let funds=funds{return "\(funds) BF"}
        return "\(fallback) VP • LOCAL PRICE"
    }
    func collectionView(_ collectionView:UICollectionView,didSelectItemAt indexPath:IndexPath) {
        view.endEditing(true)
        var id:Int?,minimum=1,vp:Int?,bf:Int?
        if category==11 {let item=visibleWeapons[indexPath.item];id=item.id;minimum=item.minimumLevel ?? 1;vp=item.valorPrice;bf=item.fundsPrice;if vp==nil && bf==nil{vp=500}}
        else if category<9 && indexPath.item>0 {let item=visibleItems[indexPath.item-1];id=item.id;minimum=item.minimumLevel ?? 1;vp=item.valorPrice;bf=item.fundsPrice;if vp==nil && bf==nil{vp=250}}
        if let id=id,!profile.owned.contains(id) {
            let p=profile
            if p.level<minimum {status.text="Unlocks at level \(minimum)";return}
            let price=vp.map{"\($0) VP"} ?? bf.map{"\($0) Battlefunds"} ?? ""
            let alert=UIAlertController(title:"UNLOCK ITEM",message:"\(price) • Your balance: \(p.valor) VP / \(p.funds) BF",preferredStyle:.alert)
            alert.addAction(UIAlertAction(title:"CANCEL",style:.cancel))
            alert.addAction(UIAlertAction(title:"UNLOCK & EQUIP",style:.default){[weak self] _ in
                guard let self=self else{return};var p=self.profile
                if p.purchase(id:id,minimumLevel:minimum,valorPrice:vp,fundsPrice:bf){CareerStore.shared.save(p,self.faction,self.kind);self.equipItem(indexPath)}
                else {self.status.text="Not enough currency • earn VP from battles and missions"}
            })
            present(alert,animated:true);return
        }
        equipItem(indexPath)
    }
    func equipItem(_ indexPath:IndexPath) {
        if category==11 {
            let slot=slots.selectedSegmentIndex;while loadout.weapons.count<=slot {loadout.weapons.append(visibleWeapons[indexPath.item].id)};loadout.weapons[slot]=visibleWeapons[indexPath.item].id
        } else if category==9 {loadout.skin=visibleColors[indexPath.item].id}
        else if category==10 {loadout.hair=visibleColors[indexPath.item].id}
        else if indexPath.item==0 {loadout.clothing.removeValue(forKey:category)}
        else {loadout.clothing[category]=visibleItems[indexPath.item-1].id}
        save();refreshHero();collection.reloadData()
    }
}

final class ComicLabel:UILabel {
    var ink=UIColor(red:0.12,green:0.12,blue:0.08,alpha:1)
    func write(_ value:String,color:UIColor = .white,size:CGFloat=24) {
        attributedText=NSAttributedString(string:value,attributes:[.font:OriginalFont.heavy(size),.foregroundColor:color,.strokeColor:ink,.strokeWidth:-5])
        textAlignment = .center;layer.shadowColor=UIColor.black.cgColor;layer.shadowOpacity=0;layer.shadowOffset = .zero;layer.shadowRadius=0
    }
}

final class ComicHUD:UIView {
    let royal=UIImageView(),national=UIImageView(),royalScore=ComicLabel(),nationalScore=ComicLabel(),royalMultiplier=ComicLabel(),nationalMultiplier=ComicLabel()
    let portrait=UIImageView(),xpFrame=UIImageView(),xpFill=UIImageView(),level=ComicLabel()
    let healthFill=UIImageView(),healthFrame=UIImageView(),health=ComicLabel(),ammoFill=UIImageView(),ammoFrame=UIImageView(),ammo=ComicLabel()
    let mission=ComicLabel(),missionProgress=ComicLabel(),weaponIcons=(0..<10).map{_ in UIImageView()},slotNumbers=(0..<10).map{_ in ComicLabel()}
    let xpMask=CAShapeLayer(),roundState=ComicLabel()
    override init(frame:CGRect){
        super.init(frame:frame);isUserInteractionEnabled=false
        let views:[UIView]=[royal,national,royalScore,nationalScore,royalMultiplier,nationalMultiplier,portrait,xpFill,xpFrame,level,healthFill,healthFrame,health,ammoFill,ammoFrame,ammo,mission,missionProgress]
        for v in views+weaponIcons+slotNumbers+[roundState] {addSubview(v)}
        for image in [royal,national,portrait,xpFrame,xpFill,healthFill,healthFrame,ammoFill,ammoFrame]+weaponIcons {image.contentMode = .scaleAspectFit}
        healthFill.image=OriginalUIArt.image("bars/westiconhealthfull.tga");healthFrame.image=OriginalUIArt.image("bars/westiconhealthframe.tga")
        ammoFill.image=OriginalUIArt.image("bars/westiconammofull.tga");ammoFrame.image=OriginalUIArt.image("bars/westiconammoframe52.tga")
        xpFrame.image=OriginalUIArt.image("xpbar/westxpbarframe.tga");xpFill.image=OriginalUIArt.image("xpbar/westxpbarfull.dds");xpFill.layer.mask=xpMask
        portrait.layer.cornerRadius=30;portrait.clipsToBounds=true
    }
    required init?(coder:NSCoder){fatalError()}
    override func layoutSubviews(){
        super.layoutSubviews();let w=bounds.width,h=bounds.height,s=safeAreaInsets,c=w/2,k=max(0.7,min(1,h/600))
        national.frame=CGRect(x:c-105*k,y:s.top+12,width:84*k,height:54*k);royal.frame=CGRect(x:c+20*k,y:s.top+12,width:84*k,height:54*k)
        nationalScore.frame=CGRect(x:c-168*k,y:s.top+15,width:60*k,height:44*k);royalScore.frame=CGRect(x:c+108*k,y:s.top+15,width:60*k,height:44*k)
        nationalMultiplier.frame=CGRect(x:c-80*k,y:s.top+53*k,width:40*k,height:25*k);royalMultiplier.frame=CGRect(x:c+45*k,y:s.top+53*k,width:40*k,height:25*k)
        portrait.frame=CGRect(x:s.left+27*k,y:s.top+20*k,width:77*k,height:82*k)
        xpFill.frame=CGRect(x:s.left+8*k,y:s.top+10*k,width:118*k,height:118*k);xpFrame.frame=CGRect(x:s.left+7*k,y:s.top+7*k,width:120*k,height:151*k)
        level.frame=CGRect(x:s.left+110*k,y:s.top+108*k,width:28*k,height:25*k)
        healthFill.frame=CGRect(x:s.left+12,y:h-s.bottom-58*k,width:52*k,height:52*k);healthFrame.frame=healthFill.frame
        health.frame=CGRect(x:s.left+66*k,y:h-s.bottom-39*k,width:72*k,height:34*k)
        ammoFill.frame=CGRect(x:w-s.right-38*k,y:h-s.bottom-55*k,width:35*k,height:52*k);ammoFrame.frame=ammoFill.frame
        ammo.frame=CGRect(x:w-s.right-113*k,y:h-s.bottom-39*k,width:70*k,height:34*k)
        mission.frame=CGRect(x:w-s.right-245*k,y:h*0.32,width:230*k,height:24*k);missionProgress.frame=CGRect(x:w-s.right-245*k,y:h*0.32+24*k,width:230*k,height:42*k)
        let gear=max(0.85,min(1.1,h/390));for i in 0..<10 {let x=c-100*gear+CGFloat(i)*67*gear;weaponIcons[i].frame=CGRect(x:x,y:h-s.bottom-72*gear,width:64*gear,height:44*gear);slotNumbers[i].frame=CGRect(x:x,y:h-s.bottom-27*gear,width:64*gear,height:23*gear);weaponIcons[i].isHidden=i>=3;slotNumbers[i].isHidden=i>=3}
        roundState.frame=CGRect(x:w/2-200,y:s.top+66,width:400,height:44)
    }
    func refresh(_ game:Game,_ profile:HeroCareer){
        let player=game.heroes[0],k=max(0.7,min(1,bounds.height/600)),animation=Int(game.elapsed*8)%20
        royal.image=OriginalUIArt.image(String(format:"score/british/scoreboard_flag%02d.tga",animation));national.image=OriginalUIArt.image(String(format:"score/national/scoreboard_flag%02d.tga",animation))
        let a=game.mode == .conquest ? Int(max(0,game.tickets[0])) : game.mode == .elimination ? game.heroes.filter{$0.team==0 && $0.alive}.count : Int(game.score[0])
        let b=game.mode == .conquest ? Int(max(0,game.tickets[1])) : game.mode == .elimination ? game.heroes.filter{$0.team==1 && $0.alive}.count : Int(game.score[1])
        royalScore.write(String(a),size:32*k);nationalScore.write(String(b),size:32*k)
        let royalOwned=game.objectives.filter{$0.owner==0}.count,nationalOwned=game.objectives.filter{$0.owner==1}.count
        royalMultiplier.write(royalOwned>nationalOwned ? "2x" : "1x",size:18*k);nationalMultiplier.write(nationalOwned>royalOwned ? "2x" : "1x",size:18*k)
        let seconds=game.remainingSeconds;let state=game.mode == .flags ? "\(Int(game.score[0]))–\(Int(game.score[1])) / 3 flags" : game.mode == .rocket ? "\(Int(game.score[0]))–\(Int(game.score[1])) / 60 sec held" : game.mode == .elimination ? "No respawns • survive" : "Capture flags • drain tickets";roundState.numberOfLines=2;roundState.write(String(format:"%02d:%02d",seconds/60,seconds%60)+" • "+state,size:14)
        health.write(String(Int(player.hp)),size:29*k);healthFill.alpha=player.alive ? 1 : 0.3
        let count=player.weapon?.magazine==0 ? "∞" : player.ammunition.indices.contains(player.weaponSlot) ? String(player.ammunition[player.weaponSlot]) : "∞"
        ammo.write(count,size:29*k);level.write(String(profile.level),size:17*k)
        let center=CGPoint(x:xpFill.bounds.midX,y:xpFill.bounds.midY),radius=max(xpFill.bounds.width,xpFill.bounds.height)
        let path=UIBezierPath();path.move(to:center);path.addArc(withCenter:center,radius:radius,startAngle:.pi/2,endAngle:.pi/2+CGFloat(profile.levelFraction)*2*CGFloat.pi,clockwise:true);path.close();xpMask.path=path.cgPath
        mission.write("INFANTRY HUNTER",size:15*k);missionProgress.numberOfLines=2;missionProgress.write("Eliminate enemies: \(min(10,profile.kills+player.kills))/10\nIn a round",color:UIColor(red:0.95,green:0.95,blue:0.22,alpha:1),size:14*k)
        for i in 0..<10 {
            slotNumbers[i].write(String((i+1)%10),size:15*k)
            if player.equipped.indices.contains(i){weaponIcons[i].image=OriginalUIArt.image("weapons/weapon\(player.equipped[i].id).tga");weaponIcons[i].alpha=i==player.weaponSlot ? 1 : 0.5}
            else if i==2 {let id=player.kind == .soldier ? 2001 : player.kind == .heavy ? 2011 : 2016;weaponIcons[i].image=OriginalUIArt.image("abilities/ability\(id).tga");weaponIcons[i].alpha=player.ability>0 ? 0.45 : 1}
            else {weaponIcons[i].image=nil}
        }
    }
}
struct OriginalUIEntry:Decodable {let name:String,file:String,width:Int,height:Int}
enum OriginalUIArt {
    static let folder=Bundle.main.resourceURL!.appendingPathComponent("Assets/UI")
    static let entries:[OriginalUIEntry] = (try? JSONDecoder().decode([OriginalUIEntry].self,from:Data(contentsOf:folder.appendingPathComponent("manifest.json")))) ?? []
    static let images=NSCache<NSString,UIImage>()
    static func image(_ suffix:String)->UIImage? {
        let suffix=suffix.lowercased()
        if let image=images.object(forKey:suffix as NSString){return image}
        guard let entry=entries.first(where:{$0.name.lowercased().hasSuffix(suffix)}),let image=UIImage(contentsOfFile:folder.appendingPathComponent(entry.file).path) else{return nil}
        images.setObject(image,forKey:suffix as NSString);return image
    }
    static func icon(_ tokens:[String])->UIImage? {
        guard let entry=entries.first(where:{e in tokens.contains(where:{e.name.lowercased().contains($0)}) && e.width<=256 && e.height<=256}) else{return nil}
        return image(entry.name)
    }
}
final class CareerStore {
    static let shared=CareerStore()
    func key(_ faction:Int,_ kind:HeroClass)->String{"career-v1-\(faction)-\(kind.rawValue)"}
    func load(_ faction:Int,_ kind:HeroClass)->HeroCareer{
        guard let data=UserDefaults.standard.data(forKey:key(faction,kind)),let profile=try? JSONDecoder().decode(HeroCareer.self,from:data) else{return HeroCareer()}
        return profile
    }
    func save(_ profile:HeroCareer,_ faction:Int,_ kind:HeroClass){
        guard let data=try? JSONEncoder().encode(profile) else{return}
        UserDefaults.standard.set(data,forKey:key(faction,kind))
    }
    func seed(_ defaults:HeroLoadout,_ existing:HeroLoadout,_ faction:Int,_ kind:HeroClass){
        var p=load(faction,kind);p.owned.formUnion(defaults.weapons+Array(defaults.clothing.values)+existing.weapons+Array(existing.clothing.values));save(p,faction,kind)
    }
}

extension GameController {
    func combatFeedback(_ g:Game) {
        for hit in g.feedback {
            if hit.attacker==0 {
                let point=render.projectPoint(SCNVector3(Float(hit.position.x),Float(hit.height),Float(hit.position.z)))
                if point.z>0 && point.z<1 {
                    let label=ComicLabel(frame:CGRect(x:CGFloat(point.x)-50,y:CGFloat(point.y)-25,width:100,height:50))
                    label.write("+\(hit.damage)",color:.white,size:hit.killed ? 30 : 25)
                    label.isUserInteractionEnabled=false;view.addSubview(label)
                    label.transform=CGAffineTransform(scaleX:0.85,y:0.85)
                    UIView.animate(withDuration:0.12,animations:{label.transform = .identity})
                    UIView.animate(withDuration:0.8,delay:0.12,options:.curveEaseOut,animations:{label.center.y-=70;label.alpha=0},completion:{_ in label.removeFromSuperview()})
                    sparks(at:SCNVector3(Float(hit.position.x),Float(hit.height)-0.7,Float(hit.position.z)),color:UIColor(red:1,green:0.74,blue:0.1,alpha:1))
                }
                crosshair.textColor = .yellow
                UIView.animate(withDuration:0.22,animations:{self.crosshair.transform=CGAffineTransform(scaleX:1.35,y:1.35)},completion:{_ in self.crosshair.transform = .identity;self.crosshair.textColor = .white})
            }
            if hit.victim==0 {
                let wash=UIImageView(image:OriginalUIArt.image("player/icons/hud/hitindicator.tga"));wash.frame=CGRect(x:view.bounds.midX-100,y:view.bounds.height*0.08,width:200,height:140);wash.contentMode = .scaleAspectFit;wash.isUserInteractionEnabled=false;view.addSubview(wash)
                UIView.animate(withDuration:0.25,animations:{wash.alpha=0},completion:{_ in wash.removeFromSuperview()})
            }
        }
        for event in g.scoreFeedback where event.hero==0 {
            scoreToast.layer.removeAllAnimations();scoreToast.alpha=1
            scoreToast.write("+\(event.amount)",color:.white,size:28)
            scoreToast.transform=CGAffineTransform(scaleX:1.2,y:1.2)
            UIView.animate(withDuration:0.2,animations:{self.scoreToast.transform = .identity})
            UIView.animate(withDuration:0.4,delay:1.1,options:[],animations:{self.scoreToast.alpha=0},completion:nil)
        }
        g.feedback.removeAll(keepingCapacity:true);g.scoreFeedback.removeAll(keepingCapacity:true)
    }
    func sparks(at p:SCNVector3,color:UIColor) {
        for i in 0..<6 {
            let spark=sphere(0.045,color);spark.geometry?.firstMaterial?.emission.contents=color;spark.position=p;effects.addChildNode(spark)
            let angle=Double(i)*Double.pi/3
            spark.runAction(.sequence([.group([.moveBy(x:CGFloat(cos(angle)*0.45),y:CGFloat(i%2==0 ? 0.4 : -0.15),z:CGFloat(sin(angle)*0.45),duration:0.16),.scale(to:0,duration:0.2)]),.removeFromParentNode()]))
        }
    }
    func showCareer(){(menu as? OriginalMenuShell)?.openCareer()}
}
final class CareerController:UIViewController {
    let faction:Int,kind:HeroClass
    var done:(()->Void)?
    let scroll=UIScrollView(),frameArt=UIImageView(image:OriginalUIArt.image("panels/01_bgframelargelong.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:40,left:10,bottom:10,right:10))),heading=ComicLabel(),details=UILabel(),upgrade=UIButton(type:.custom),missions=UILabel(),abilityIcon=UIImageView(),rank=UILabel()
    init(faction:Int,kind:HeroClass){self.faction=faction;self.kind=kind;super.init(nibName:nil,bundle:nil)}
    required init?(coder:NSCoder){fatalError()}
    override func viewDidLoad(){super.viewDidLoad();view.addSubview(frameArt);view.addSubview(scroll);for v in [heading,details,upgrade,missions,abilityIcon,rank]{scroll.addSubview(v)};details.font=OriginalFont.heavy(16);details.textColor=UIColor(white:0.15,alpha:1);missions.numberOfLines=0;missions.font=OriginalFont.heavy(16);missions.textColor=UIColor(white:0.15,alpha:1);rank.font=OriginalFont.heavy(20);rank.textColor=UIColor(red:0.15,green:0.4,blue:0.8,alpha:1);upgrade.setTitle("Upgrade • 1 HP",for:.normal);upgrade.titleLabel?.font=OriginalFont.heavy(16);upgrade.setBackgroundImage(OriginalUIArt.image("components/button.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:7,left:8,bottom:7,right:8)),for:.normal);upgrade.addAction(UIAction{[weak self] _ in guard let self=self else{return};var p=CareerStore.shared.load(self.faction,self.kind);if p.upgradeAbility(){CareerStore.shared.save(p,self.faction,self.kind)};self.refresh();self.done?()},for:.touchUpInside);refresh()}
    override func viewDidLayoutSubviews(){super.viewDidLayoutSubviews();frameArt.frame=view.bounds;scroll.frame=view.bounds;let w=view.bounds.width;heading.frame=CGRect(x:8,y:3,width:w-16,height:28);abilityIcon.frame=CGRect(x:12,y:39,width:75,height:48);details.frame=CGRect(x:96,y:37,width:w-104,height:24);rank.frame=CGRect(x:96,y:66,width:max(90,w-286),height:26);upgrade.frame=CGRect(x:w-180,y:63,width:170,height:44);missions.frame=CGRect(x:14,y:125,width:w-28,height:130);scroll.contentSize=CGSize(width:w,height:265)}
    func refresh(){let p=CareerStore.shared.load(faction,kind);heading.write("\(kind == .soldier ? "Combat Medicine" : kind == .heavy ? "Hero's Shield" : "Stealth")  (\(p.abilityRank)/5)",size:18);details.text="\(p.heroPoints) Hero Points available";rank.text=String(repeating:"▰",count:p.abilityRank)+String(repeating:"▱",count:5-p.abilityRank)+" ☆";abilityIcon.image=OriginalUIArt.image("abilities/ability\(kind == .soldier ? 2001 : kind == .heavy ? 2011 : 2016).tga");abilityIcon.contentMode = .scaleAspectFit;missions.text="Offline Missions\nFirst Battle  \(min(1,p.matches))/1  •  100 VP\nInfantry Hunter  \(min(10,p.kills))/10  •  150 VP\nFlag Hero  \(min(3,p.captures))/3  •  200 VP";upgrade.isEnabled=p.heroPoints>0 && p.abilityRank<5;upgrade.alpha=upgrade.isEnabled ? 1 : 0.5}
}


enum OriginalFont {
    static let fontName:String? = {
        guard let folder=Bundle.main.resourceURL?.appendingPathComponent("Assets/UI"),let data=try? Data(contentsOf:folder.appendingPathComponent("fonts.json")),let fonts=try? JSONDecoder().decode([String].self,from:data) else{return nil}
        var names:[String]=[]
        for file in fonts {
            let url=folder.appendingPathComponent(file)
            CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil)
            if let raw=try? Data(contentsOf:url),let descriptors=CTFontManagerCreateFontDescriptorsFromData(raw as CFData) as? [CTFontDescriptor] {
                for d in descriptors {if let name=CTFontDescriptorCopyAttribute(d,kCTFontNameAttribute) as? String {names.append(name)}}
            }
        }
        return names.first(where:{$0.lowercased().contains("heroes") || $0.lowercased().contains("black") || $0.lowercased().contains("bold")}) ?? names.first
    }()
    static func heavy(_ size:CGFloat)->UIFont {fontName.flatMap{UIFont(name:$0,size:size)} ?? UIFont(name:"ArialRoundedMTBold",size:size) ?? UIFont.systemFont(ofSize:size,weight:.bold)}
}

extension GameController {
    func makeHeroPortrait()->UIImage? {
        guard let wardrobe=wardrobe,let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/Characters"),let actor=try? AnimatedCharacter(selectedTeam==0 ? "royal" : "national",directory:directory) else{return nil}
        guard (try? wardrobe.apply(wardrobe.load(selectedTeam+1,selectedClass),faction:selectedTeam+1,to:actor)) != nil else{return nil}
        actor.update(0.05,position:.zero,moving:false,firing:false,ability:false,alive:true)
        let scene=SCNScene();scene.background.contents=UIColor.clear;scene.rootNode.addChildNode(actor.node)
        let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.fieldOfView=34;camera.position=SCNVector3(0,1.9,1.5);camera.look(at:SCNVector3(0,1.85,0));scene.rootNode.addChildNode(camera)
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=850;scene.rootNode.addChildNode(ambient)
        let sun=SCNNode();sun.light=SCNLight();sun.light?.type = .directional;sun.light?.intensity=950;sun.eulerAngles=SCNVector3(-0.5,-0.6,0);scene.rootNode.addChildNode(sun)
        let renderer=SCNRenderer(device:nil,options:nil);renderer.scene=scene;renderer.pointOfView=camera
        return renderer.snapshot(atTime:0,with:CGSize(width:128,height:128),antialiasingMode:.multisampling4X)
    }
}

final class OriginalCrosshair:UILabel {
    override func draw(_ rect:CGRect) {
        let center=CGPoint(x:bounds.midX,y:bounds.midY),radius:CGFloat=12
        for width in [CGFloat(4),CGFloat(1.6)] {
            let path=UIBezierPath()
            for i in 0..<4 {let start=CGFloat(i)*CGFloat.pi/2+0.18;path.move(to:CGPoint(x:center.x+cos(start)*radius,y:center.y+sin(start)*radius));path.addArc(withCenter:center,radius:radius,startAngle:start,endAngle:start+1.15,clockwise:true)}
            path.move(to:CGPoint(x:center.x-3,y:center.y+11));path.addLine(to:CGPoint(x:center.x,y:center.y+3));path.addLine(to:CGPoint(x:center.x+3,y:center.y+11))
            (width>2 ? UIColor.black : textColor ?? UIColor.white).setStroke();path.lineWidth=width;path.stroke()
        }
    }
}
