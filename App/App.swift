import UIKit
import SceneKit
import simd

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
    var wardrobe:OriginalWardrobe?;var selectedTeam=0;var playerLoadout=HeroLoadout()
    let switchButton=UIButton(type:.system),reloadButton=UIButton(type:.system)
    var animators:[AnimatedCharacter?]=[]; var previousPositions:[V2]=[]
    var nodes:[SCNNode]=[]; var objectiveNodes:[SCNNode]=[]; var flagNodes:[SCNNode]=[]
    let effects=SCNNode(); let world=SCNNode(); let hud=UILabel(); let notice=UILabel()
    var left=Stick(frame:CGRect(x:0,y:0,width:116,height:116)); let right=AimSurface(),fire=AimSurface()
    let skill=UIButton(type:.system),pause=UIButton(type:.system),jumpButton=UIButton(type:.system)
    let crosshair=UILabel()
    var jumpRequested=false,cameraReady=false
    var firing=false; var yaw=Double.pi/2; var pitch=0.2; var display:CADisplayLink?; var last=0.0; var hudTime=0.0; var menu:UIView?
    let blue=UIColor(red:0.12,green:0.6,blue:0.93,alpha:1), red=UIColor(red:0.96,green:0.33,blue:0.25,alpha:1)
    override var prefersStatusBarHidden:Bool { true }
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask { .landscape }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .black
        render.frame=view.bounds; render.autoresizingMask=[.flexibleWidth,.flexibleHeight]; view.addSubview(render)
        render.scene=scene; render.isPlaying=true; render.antialiasingMode = .multisampling4X; render.preferredFramesPerSecond=60
        scene.background.contents=UIColor(red:0.58,green:0.81,blue:0.93,alpha:1); scene.fogColor=UIColor(red:143/255,green:173/255,blue:170/255,alpha:1); scene.fogStartDistance=100; scene.fogEndDistance=270
        scene.rootNode.addChildNode(world); scene.rootNode.addChildNode(effects); scene.rootNode.addChildNode(camera); scene.rootNode.addChildNode(target)
        camera.camera=SCNCamera(); camera.camera?.fieldOfView=68; camera.camera?.zFar=600; render.pointOfView=camera
        let ambient=SCNNode(); ambient.light=SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity=650; scene.rootNode.addChildNode(ambient)
        let sun=SCNNode(); sun.light=SCNLight(); sun.light?.type = .directional; sun.light?.intensity=1100; sun.light?.castsShadow=true; sun.light?.shadowMapSize=CGSize(width:1024,height:1024); sun.eulerAngles=SCNVector3(-0.9,-0.6,0); scene.rootNode.addChildNode(sun)
        for label in [hud,notice] { label.textColor = .white; label.textAlignment = .center; label.font=UIFont.monospacedSystemFont(ofSize:16,weight:.bold); label.layer.shadowOpacity=0.8; label.layer.shadowRadius=2; view.addSubview(label) }
        view.addSubview(right)
        for control in [left,fire,skill,pause,jumpButton,switchButton,reloadButton] { view.addSubview(control) }
        fire.fires=true;fire.backgroundColor=red.withAlphaComponent(0.6);fire.layer.cornerRadius=42;fire.layer.borderWidth=2;fire.layer.borderColor=UIColor.white.withAlphaComponent(0.6).cgColor
        let fireText=UILabel(frame:fire.bounds);fireText.autoresizingMask=[.flexibleWidth,.flexibleHeight];fireText.text="FIRE\nDRAG TO AIM";fireText.numberOfLines=2;fireText.textAlignment = .center;fireText.textColor = .white;fireText.font=UIFont.boldSystemFont(ofSize:12);fire.addSubview(fireText)
        style(skill,"ABILITY",blue);style(pause,"Ⅱ",UIColor.darkGray);style(jumpButton,"JUMP",UIColor.darkGray)
        style(switchButton,"SWAP",UIColor.darkGray);style(reloadButton,"RELOAD",UIColor.darkGray)
        switchButton.addAction(UIAction{[weak self] _ in self?.swapWeapon()},for:.touchUpInside)
        reloadButton.addAction(UIAction{[weak self] _ in guard let self=self,let g=self.game,!g.paused else{return};g.reload(g.heroes[0])},for:.touchUpInside)
        jumpButton.addAction(UIAction { [weak self] _ in self?.jumpRequested=true },for:.touchDown)
        crosshair.text="＋";crosshair.textColor = .white;crosshair.font=UIFont.systemFont(ofSize:26,weight:.light);crosshair.textAlignment = .center;crosshair.isUserInteractionEnabled=false;view.addSubview(crosshair)
        skill.addTarget(self,action:#selector(useSkill),for:.touchUpInside); pause.addTarget(self,action:#selector(togglePause),for:.touchUpInside)
        display=CADisplayLink(target:self,selector:#selector(tick(_:))); display?.add(to:.main,forMode:.common)
        NotificationCenter.default.addObserver(self,selector:#selector(background),name:UIApplication.willResignActiveNotification,object:nil)
        if let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/OriginalWorld") { originalWorld=try? OriginalWorld(directory:directory) }
        if let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/Wardrobe") { wardrobe=try? OriginalWardrobe(directory:directory) }
        selectedTeam=min(1,max(0,UserDefaults.standard.integer(forKey:"selected-faction")))
        if let saved=UserDefaults.standard.string(forKey:"selected-class"),let kind=HeroClass(rawValue:saved) { selectedClass=kind }
        hud.numberOfLines=2;hud.font=UIFont.monospacedSystemFont(ofSize:12,weight:.bold)
        showMenu()
    }
    func style(_ b:UIButton,_ title:String,_ color:UIColor) { b.setTitle(title,for:.normal); b.setTitleColor(.white,for:.normal); b.titleLabel?.font=UIFont.boldSystemFont(ofSize:16); b.backgroundColor=color.withAlphaComponent(0.82); b.layer.cornerRadius=18 }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); let r=view.safeAreaInsets; let w=view.bounds.width,h=view.bounds.height
        left.frame.origin=CGPoint(x:r.left+25,y:h-r.bottom-141);right.frame=CGRect(x:w*0.38,y:0,width:w*0.62,height:h)
        fire.frame=CGRect(x:w-r.right-106,y:h-r.bottom-117,width:88,height:88); skill.frame=CGRect(x:w-r.right-128,y:h-r.bottom-182,width:110,height:48)
        switchButton.frame=CGRect(x:w-r.right-224,y:h-r.bottom-116,width:96,height:42);reloadButton.frame=CGRect(x:w-r.right-224,y:h-r.bottom-65,width:96,height:42)
        pause.frame=CGRect(x:w-r.right-66,y:r.top+14,width:48,height:38)
        jumpButton.frame=CGRect(x:r.left+155,y:h-r.bottom-82,width:76,height:58);crosshair.frame=CGRect(x:w/2-20,y:h/2-20,width:40,height:40)
        hud.frame=CGRect(x:r.left+80,y:r.top+14,width:w-r.left-r.right-160,height:48); notice.frame=CGRect(x:100,y:h*0.24,width:w-200,height:45)
        menu?.frame=view.bounds
    }
    func sphere(_ radius:CGFloat,_ color:UIColor) -> SCNNode { let g=SCNSphere(radius:radius); g.segmentCount=10; g.firstMaterial?.diffuse.contents=color; return SCNNode(geometry:g) }
    func soldier(_ kind:HeroClass,_ team:Int,loadout:HeroLoadout?=nil) throws -> SCNNode {
        guard let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/Characters"),let original=originalWorld else { throw CocoaError(.fileReadNoSuchFile) }
        let animator=try AnimatedCharacter(team == 0 ? "royal" : "national",directory:directory)
        if let wardrobe=wardrobe { try wardrobe.apply(loadout ?? wardrobe.defaults(team+1,kind),faction:team+1,to:animator) }
        animator.weaponPose=loadout?.weapons.first.flatMap{wardrobe?.weapons[$0]?.pose} ?? "smg"
        animators.append(animator)
        let root=animator.node
        let marker=sphere(0.1,team == 0 ? blue : red); marker.position.y=2.3; root.addChildNode(marker)
        let gun=try loadout?.weapons.first.flatMap{wardrobe?.weapons[$0]}.map{try original.model($0.model)} ?? original.weapon(kind,team);gun.name="held-weapon";animator.bones[44].addChildNode(gun)
        return root
    }
    func start() {
        menu?.removeFromSuperview(); menu=nil; firing=false; yaw = .pi/2; pitch=0.08; left.reset();right.reset();fire.reset();cameraReady=false;jumpRequested=false
        guard let original=originalWorld else { notice.text="Original assets could not be loaded. Rebuild the IPA."; showMenu(result:"ASSET LOAD FAILED"); return }
        let g=Game(mode:selectedMode,hero:selectedClass,layout:original.layout,playerTeam:selectedTeam); game=g
        world.childNodes.forEach{$0.removeFromParentNode()}; effects.childNodes.forEach{$0.removeFromParentNode()}; nodes=[]; animators=[]; previousPositions=g.heroes.map{$0.p}; objectiveNodes=[]; flagNodes=[]
        do { try original.populate(world); let sky=try original.sky();world.addChildNode(sky);skyNode=sky } catch { showMenu(result:"MAP LOAD FAILED"); return }
        playerLoadout=wardrobe?.load(selectedTeam+1,selectedClass) ?? HeroLoadout()
        for h in g.heroes {
            let loadout=h.id==0 ? playerLoadout : wardrobe?.defaults(h.team+1,h.kind)
            h.equip((loadout?.weapons ?? []).compactMap{wardrobe?.weapons[$0]}.map{weaponProfile($0)})
        }
        let aim=g.objectives[0].p-g.bases[selectedTeam];yaw=atan2(aim.x,aim.z)
        if selectedMode == .conquest || selectedMode == .rocket {
            for o in g.objectives {
                let ring=SCNTorus(ringRadius:3.5,pipeRadius:0.06); ring.firstMaterial?.diffuse.contents=UIColor.white
                let node=SCNNode(geometry:ring); node.position=SCNVector3(Float(o.p.x),original.height(o.p)+0.07,Float(o.p.z)); world.addChildNode(node); objectiveNodes.append(node)
                if let pole=try? original.flag("pole") { pole.position=SCNVector3(Float(o.p.x),original.height(o.p),Float(o.p.z));world.addChildNode(pole) }
                for key in ["royal","national","neutral"] { if let flag=try? original.flag(key) { flag.name=key;flag.position.y = -0.07;flag.isHidden=key != "neutral";node.addChildNode(flag) } }

            }
        }
        for t in 0..<2 {
            let base=SCNTorus(ringRadius:3,pipeRadius:0.13); base.firstMaterial?.diffuse.contents=t == 0 ? blue : red
            let n=SCNNode(geometry:base); n.position=SCNVector3(Float(g.bases[t].x),original.height(g.bases[t])+0.1,Float(g.bases[t].z)); world.addChildNode(n)
            let flag=(try? original.flag(t == 0 ? "ctf-royal" : "ctf-national")) ?? SCNNode(); world.addChildNode(flag); flag.isHidden=selectedMode != .flags; flagNodes.append(flag)
        }
        do { for h in g.heroes { let n=try soldier(h.kind,h.team,loadout:h.id==0 ? playerLoadout : wardrobe?.defaults(h.team+1,h.kind)); world.addChildNode(n); nodes.append(n) } } catch { showMenu(result:"CHARACTER LOAD FAILED"); return }
        notice.text="Drag right: look • Hold and drag FIRE: aim + shoot • JUMP"; hudTime=0; last=0
        for c in [left,right,fire,skill,pause,jumpButton,crosshair,switchButton,reloadButton] { c.isHidden=false }
    }
    @objc func fireDown() { firing=true }
    @objc func fireUp() { firing=false }
    @objc func useSkill() { if let g=game, !g.paused, g.winner == nil { g.ability(g.heroes[0]); UIImpactFeedbackGenerator(style:.light).impactOccurred() } }
    @objc func background() { if let g=game, menu == nil, g.winner == nil { g.paused=true; firing=false;left.reset();right.reset();fire.reset();jumpRequested=false;showMenu(resume:true) } }
    @objc func togglePause() { guard let g=game else { return }; g.paused=true; firing=false; showMenu(resume:true) }
    @objc func tick(_ link:CADisplayLink) {
        let dt=last == 0 ? 0 : min(0.05,link.timestamp-last); last=link.timestamp
        guard let g=game, menu == nil else { return }
        let look=right.consume(),shootLook=fire.consume()
        yaw-=Double(look.x+shootLook.x)*0.0045;pitch=max(-0.35,min(0.65,pitch+Double(look.y+shootLook.y)*0.0035));firing=fire.isHeld
        let forward=V2(x:sin(yaw),z:cos(yaw)), sideways=V2(x:-cos(yaw),z:sin(yaw))
        let move=forward * -Double(left.value.y)+sideways*Double(left.value.x)
        g.update(dt,input:Input(move:move,yaw:yaw,fire:firing,ability:false,jump:jumpRequested));jumpRequested=false
        for (i,h) in g.heroes.enumerated() {
            nodes[i].position=SCNVector3(Float(h.p.x),(originalWorld?.height(h.p) ?? 0)+Float(h.elevation),Float(h.p.z)); nodes[i].eulerAngles.y=Float(h.facing); if let animator=animators[i] {
                animator.update(dt,position:h.p,moving:h.p.distance(previousPositions[i])>0.003,firing:h.recentShot>0,ability:h.ability>11.5,alive:h.alive,jumping:h.elevation>0.01,reloading:h.reloadRemaining>0)

            } else { nodes[i].isHidden = !h.alive }
            previousPositions[i]=h.p
            nodes[i].opacity=h.invulnerable>0 ? 0.55 : 1
        }
        for (i,o) in g.objectives.enumerated() where i<objectiveNodes.count {
            objectiveNodes[i].geometry?.firstMaterial?.diffuse.contents=o.owner == 0 ? blue : o.owner == 1 ? red : UIColor.white
            let key=o.owner == 0 ? "royal" : o.owner == 1 ? "national" : "neutral"
            for child in objectiveNodes[i].childNodes { child.isHidden=child.name != key }
        }
        for i in 0..<2 { flagNodes[i].position=SCNVector3(Float(g.flags[i].p.x),(originalWorld?.height(g.flags[i].p) ?? 0),Float(g.flags[i].p.z)) }
        let player=g.heroes[0], p=player.p
        let ground=(originalWorld?.height(p) ?? 0)+Float(player.elevation)
        let focus=SIMD3(Float(p.x),ground+1.5,Float(p.z)),direction=ThirdPersonCamera.direction(yaw:Float(yaw),pitch:Float(pitch))
        let shoulder=SIMD3<Float>(-cos(Float(yaw)),0,sin(Float(yaw)))*0.55
        let desired=focus-direction*4.6+shoulder
        let safe=originalWorld?.cameraPosition(from:focus,to:desired) ?? desired
        camera.simdPosition=cameraReady ? simd_mix(camera.simdPosition,safe,SIMD3(repeating:Float(1-exp(-dt*18)))) : safe
        camera.simdOrientation=ThirdPersonCamera.rotation(position:camera.simdPosition,target:focus+direction*30+shoulder);cameraReady=true
        skyNode?.position=camera.position
        for shot in g.shots { tracer(shot) }
        hudTime+=dt
        if hudTime>0.15 {
            hudTime=0
            let scores=g.mode == .conquest ? "ROYAL \(max(0,Int(g.tickets[0]))) : \(max(0,Int(g.tickets[1]))) NATIONAL" : g.mode == .elimination ? "ROYAL \(g.heroes.filter{$0.team == 0 && $0.alive}.count) : \(g.heroes.filter{$0.team == 1 && $0.alive}.count) NATIONAL" : "ROYAL \(Int(g.score[0])) : \(Int(g.score[1])) NATIONAL"
            hud.text="\(scores)   •   \(max(0,300-Int(g.elapsed)))s\n\(player.kind.rawValue)  HP \(Int(player.hp))  K \(player.kills) / D \(player.deaths)"
            let gun=player.weapon?.name ?? player.kind.rawValue
            let ammo=player.ammunition.indices.contains(player.weaponSlot) ? String(player.ammunition[player.weaponSlot]) : "∞"
            hud.text=(hud.text ?? "")+"  •  \(gun)  \(ammo)"
            reloadButton.setTitle(player.reloadRemaining>0 ? String(format:"%.1fs",player.reloadRemaining) : "RELOAD",for:.normal)
            switchButton.setTitle("WEAPON \(player.weaponSlot+1) ⇄",for:.normal)
            skill.setTitle(player.ability>0 ? "\(Int(ceil(player.ability)))s" : "ABILITY",for:.normal)
            notice.text=player.alive ? (g.elapsed<8 ? "Hold and drag FIRE to aim + shoot • JUMP" : g.message) : g.mode == .elimination ? "Eliminated • watching your squad" : "Respawn in \(Int(ceil(max(0,player.respawn))))"
        }
        if let winner=g.winner { showMenu(result:winner == -1 ? "DRAW" : winner == 0 ? "ROYAL VICTORY" : "NATIONAL VICTORY") }
    }
    func tracer(_ shot:Shot) {
        let a=SCNVector3(Float(shot.from.x),(originalWorld?.height(shot.from) ?? 0)+1.2,Float(shot.from.z)), b=SCNVector3(Float(shot.to.x),(originalWorld?.height(shot.to) ?? 0)+1.2,Float(shot.to.z))
        let cylinder=SCNCylinder(radius:0.025,height:CGFloat(shot.from.distance(shot.to))); cylinder.radialSegmentCount=4
        cylinder.firstMaterial?.diffuse.contents=UIColor.yellow; cylinder.firstMaterial?.emission.contents=UIColor.yellow
        let node=SCNNode(geometry:cylinder); node.position=SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2); node.look(at:b,up:SCNVector3(0,1,0),localFront:SCNVector3(0,1,0)); effects.addChildNode(node)
        node.runAction(.sequence([.wait(duration:0.06),.removeFromParentNode()]))
    }
    func showMenu(resume:Bool=false,result:String?=nil) {
        menu?.removeFromSuperview(); let panel=UIView(frame:view.bounds); panel.backgroundColor=UIColor(red:0.05,green:0.10,blue:0.16,alpha:0.96); view.addSubview(panel); menu=panel
        right.reset();fire.reset();jumpRequested=false
        for c in [left,right,fire,skill,pause,jumpButton,crosshair,switchButton,reloadButton] { c.isHidden=true }
        if let path=Bundle.main.path(forResource:"menu",ofType:"png",inDirectory:"Assets/UI"),let image=UIImage(contentsOfFile:path) {
            let background=UIImageView(image:image);background.frame=panel.bounds;background.autoresizingMask=[.flexibleWidth,.flexibleHeight];background.contentMode = .scaleAspectFill;background.clipsToBounds=true;background.layer.contentsRect=CGRect(x:0,y:0,width:1,height:656.0/1024.0);panel.addSubview(background)
            let shade=UIView(frame:panel.bounds);shade.autoresizingMask=[.flexibleWidth,.flexibleHeight];shade.backgroundColor=UIColor.black.withAlphaComponent(0.35);panel.addSubview(shade)
        }
        let stack=UIStackView(); stack.axis = .vertical; stack.spacing=14; stack.alignment = .fill; stack.translatesAutoresizingMaskIntoConstraints=false; panel.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo:panel.centerXAnchor),stack.centerYAnchor.constraint(equalTo:panel.centerYAnchor),stack.widthAnchor.constraint(equalTo:panel.widthAnchor,multiplier:0.72)])
        if result == nil,let path=Bundle.main.path(forResource:"logo",ofType:"png",inDirectory:"Assets/UI"),let image=UIImage(contentsOfFile:path) {
            let logo=UIImageView(image:image);logo.contentMode = .scaleAspectFit;stack.addArrangedSubview(logo);logo.heightAnchor.constraint(equalToConstant:70).isActive=true
        } else {
            let title=UILabel();title.text=result ?? "BATTLEFIELD HEROES";title.textColor = .white;title.textAlignment = .center;title.font=UIFont.systemFont(ofSize:30,weight:.black);stack.addArrangedSubview(title)
        }
        let subtitle=UILabel(); subtitle.text="ROYAL vs NATIONAL"; subtitle.textColor = .lightGray; subtitle.textAlignment = .center; subtitle.font=UIFont.systemFont(ofSize:13,weight:.semibold); stack.addArrangedSubview(subtitle)
        if resume {
            let button=UIButton(type:.system); style(button,"RESUME",blue); button.addAction(UIAction { [weak self] _ in self?.game?.paused=false; self?.menu?.removeFromSuperview(); self?.menu=nil; for c in [self?.left,self?.right,self?.fire,self?.skill,self?.pause,self?.jumpButton,self?.crosshair,self?.switchButton,self?.reloadButton] { c?.isHidden=false } },for:.touchUpInside); stack.addArrangedSubview(button); button.heightAnchor.constraint(equalToConstant:44).isActive=true
        }
        let modes=UISegmentedControl(items:Mode.allCases.map{$0.rawValue}); modes.selectedSegmentIndex=Mode.allCases.firstIndex(of:selectedMode) ?? 0; modes.backgroundColor = .lightGray
        modes.addAction(UIAction { [weak self, weak modes] _ in if let index=modes?.selectedSegmentIndex { self?.selectedMode=Mode.allCases[index] } },for:.valueChanged); stack.addArrangedSubview(modes)
        let classes=UISegmentedControl(items:HeroClass.allCases.map{$0.rawValue}); classes.selectedSegmentIndex=HeroClass.allCases.firstIndex(of:selectedClass) ?? 0; classes.backgroundColor = .lightGray
        classes.addAction(UIAction { [weak self, weak classes] _ in if let index=classes?.selectedSegmentIndex { self?.selectedClass=HeroClass.allCases[index];UserDefaults.standard.set(HeroClass.allCases[index].rawValue,forKey:"selected-class") } },for:.valueChanged); stack.addArrangedSubview(classes)
        let customize=UIButton(type:.system);style(customize,"CUSTOMIZE HERO",UIColor(red:0.62,green:0.49,blue:0.17,alpha:1));customize.heightAnchor.constraint(equalToConstant:44).isActive=true
        customize.addAction(UIAction{[weak self] _ in self?.customizeHero()},for:.touchUpInside);stack.addArrangedSubview(customize)
        let startButton=UIButton(type:.system); style(startButton,resume ? "NEW MATCH" : "DEPLOY",blue); startButton.addAction(UIAction { [weak self] _ in self?.start() },for:.touchUpInside); stack.addArrangedSubview(startButton); startButton.heightAnchor.constraint(equalToConstant:48).isActive=true
        let help=UILabel(); help.text="Soldier: heal squad  •  Gunner: shield  •  Commando: dash\nChoose your outfit and weapons in CUSTOMIZE HERO"; help.numberOfLines=2; help.textAlignment = .center; help.textColor = .lightGray; help.font=UIFont.systemFont(ofSize:12); stack.addArrangedSubview(help)
    }
}

extension GameController {
    func weaponProfile(_ weapon:WardrobeWeapon)->WeaponProfile {
        let damage=weapon.weaponClass==5 ? 36.0 : weapon.weaponClass==3 ? 28 : weapon.weaponClass==2 ? 22 : weapon.weaponClass==1 ? 13 : 19
        let range=weapon.weaponClass==5 ? 45.0 : weapon.weaponClass==3 ? 16 : weapon.weaponClass==2 ? 24 : 28
        return WeaponProfile(id:weapon.id,name:weapon.name,damage:damage,interval:60/max(60,weapon.rpm),range:range,magazine:max(1,weapon.magazine),reloadTime:max(0.1,weapon.reload))
    }
    func swapWeapon() {
        guard let g=game,!g.paused,g.winner==nil,let actor=animators.first ?? nil,let original=originalWorld else{return}
        g.switchWeapon(g.heroes[0])
        guard let id=g.heroes[0].weapon?.id,let item=wardrobe?.weapons[id],let node=try? original.model(item.model) else{return}
        actor.weaponPose=item.pose ?? "smg"
        actor.bones[44].childNodes.filter{$0.name=="held-weapon"}.forEach{$0.removeFromParentNode()};node.name="held-weapon";actor.bones[44].addChildNode(node)
    }
    func customizeHero() {
        guard let wardrobe=wardrobe,let original=originalWorld else { notice.text="Wardrobe assets could not be loaded";return }
        let screen=WardrobeController(wardrobe:wardrobe,original:original,faction:selectedTeam+1,kind:selectedClass)
        screen.finished={ [weak self] faction,kind in
            self?.selectedTeam=faction-1;self?.selectedClass=kind;UserDefaults.standard.set(faction-1,forKey:"selected-faction");UserDefaults.standard.set(kind.rawValue,forKey:"selected-class");self?.showMenu(resume:self?.game?.paused==true && self?.game?.winner==nil)
        }
        screen.modalPresentationStyle = .fullScreen;present(screen,animated:true)
    }
}
final class ItemCard:UICollectionViewCell {
    let image=UIImageView(),caption=UILabel(),check=UILabel()
    override init(frame:CGRect) {
        super.init(frame:frame);contentView.backgroundColor=UIColor(red:0.16,green:0.2,blue:0.19,alpha:0.95);contentView.layer.cornerRadius=7;contentView.layer.borderWidth=2
        image.contentMode = .scaleAspectFit;contentView.addSubview(image)
        caption.numberOfLines=2;caption.font=UIFont.boldSystemFont(ofSize:11);caption.textColor = .white;caption.textAlignment = .center;contentView.addSubview(caption)
        check.text="✓";check.font=UIFont.boldSystemFont(ofSize:20);check.textColor = .yellow;contentView.addSubview(check)
    }
    required init?(coder:NSCoder){fatalError()}
    override func layoutSubviews() { super.layoutSubviews();image.frame=CGRect(x:8,y:5,width:bounds.width-16,height:bounds.height-37);caption.frame=CGRect(x:3,y:bounds.height-34,width:bounds.width-6,height:30);check.frame=CGRect(x:bounds.width-27,y:3,width:24,height:24) }
}
final class WardrobeController:UIViewController,UICollectionViewDataSource,UICollectionViewDelegate,UISearchBarDelegate {
    let wardrobe:OriginalWardrobe,original:OriginalWorld
    var faction:Int,kind:HeroClass,loadout:HeroLoadout
    var finished:((Int,HeroClass)->Void)?
    let preview=SCNView(),previewScene=SCNScene(),previewCamera=SCNNode(),heroRoot=SCNNode()
    var actor:AnimatedCharacter?,clock=0.0,last=0.0,link:CADisplayLink?,rotation:Float=0
    let heroTitle=UILabel(),factions=UISegmentedControl(items:["ROYAL","NATIONAL"]),classes=UISegmentedControl(items:["COMMANDO","SOLDIER","GUNNER"])
    let categoryScroll=UIScrollView(),categoryStack=UIStackView(),search=UISearchBar(),status=UILabel(),close=UIButton(type:.system),reset=UIButton(type:.system)
    let slots=UISegmentedControl(items:["WEAPON 1","WEAPON 2"])
    let collection:UICollectionView
    var category=4,query="",visibleItems:[ClothingItem]=[],visibleWeapons:[WardrobeWeapon]=[],visibleColors:[WardrobeColor]=[]
    let categories=["HATS","FACE","NECK","SHIRTS","JACKETS","WAIST","TROUSERS","SHOES","CHEST","SKIN","HAIR","WEAPONS"]
    init(wardrobe:OriginalWardrobe,original:OriginalWorld,faction:Int,kind:HeroClass) {
        self.wardrobe=wardrobe;self.original=original;self.faction=faction;self.kind=kind;loadout=wardrobe.load(faction,kind)
        let layout=UICollectionViewFlowLayout();layout.minimumInteritemSpacing=8;layout.minimumLineSpacing=8;collection=UICollectionView(frame:.zero,collectionViewLayout:layout)
        super.init(nibName:nil,bundle:nil)
    }
    required init?(coder:NSCoder){fatalError()}
    override var prefersStatusBarHidden:Bool {true}
    override var supportedInterfaceOrientations:UIInterfaceOrientationMask {.landscape}
    override func viewDidLoad() {
        super.viewDidLoad();view.backgroundColor=UIColor(red:0.07,green:0.12,blue:0.12,alpha:1)
        if let path=Bundle.main.path(forResource:"menu",ofType:"png",inDirectory:"Assets/UI"),let image=UIImage(contentsOfFile:path) {
            let background=UIImageView(image:image);background.frame=view.bounds;background.autoresizingMask=[.flexibleWidth,.flexibleHeight];background.contentMode = .scaleAspectFill;background.layer.contentsRect=CGRect(x:0,y:0,width:1,height:656.0/1024);view.addSubview(background)
            let shade=UIView(frame:view.bounds);shade.backgroundColor=UIColor.black.withAlphaComponent(0.65);shade.autoresizingMask=[.flexibleWidth,.flexibleHeight];view.addSubview(shade)
        }
        heroTitle.text="MY HERO";heroTitle.textColor = .white;heroTitle.font=UIFont.systemFont(ofSize:23,weight:.black)
        for v in [preview,heroTitle,factions,classes,categoryScroll,collection,search,status,close,reset,slots] {view.addSubview(v)}
        preview.scene=previewScene;preview.backgroundColor = .clear;preview.antialiasingMode = .multisampling4X;preview.isPlaying=true;preview.pointOfView=previewCamera
        previewScene.rootNode.addChildNode(heroRoot);previewCamera.camera=SCNCamera();previewCamera.camera?.fieldOfView=36;previewCamera.position=SCNVector3(0,1.2,4.7);previewCamera.look(at:SCNVector3(0,1.1,0));previewScene.rootNode.addChildNode(previewCamera)
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=900;previewScene.rootNode.addChildNode(ambient)
        let light=SCNNode();light.light=SCNLight();light.light?.type = .directional;light.light?.intensity=1100;light.eulerAngles=SCNVector3(-0.5,-0.4,0);previewScene.rootNode.addChildNode(light)
        let pan=UIPanGestureRecognizer(target:self,action:#selector(turn(_:)));preview.addGestureRecognizer(pan)
        factions.selectedSegmentIndex=faction-1;classes.selectedSegmentIndex=kind.kit
        for segmented in [factions,classes,slots] {segmented.backgroundColor=UIColor.white.withAlphaComponent(0.75);segmented.selectedSegmentTintColor=UIColor(red:0.7,green:0.57,blue:0.24,alpha:1)}
        factions.addAction(UIAction{[weak self] _ in guard let self=self else{return};self.changeHero(faction:self.factions.selectedSegmentIndex+1,kind:self.kind)},for:.valueChanged)
        classes.addAction(UIAction{[weak self] _ in guard let self=self else{return};let kinds:[HeroClass]=[.scout,.soldier,.heavy];self.changeHero(faction:self.faction,kind:kinds[self.classes.selectedSegmentIndex])},for:.valueChanged)
        slots.selectedSegmentIndex=0;slots.addAction(UIAction{[weak self] _ in self?.refreshList();self?.refreshHero()},for:.valueChanged)
        categoryStack.axis = .horizontal;categoryStack.spacing=5;categoryScroll.addSubview(categoryStack);categoryScroll.showsHorizontalScrollIndicator=false
        for (i,name) in categories.enumerated() {
            let button=UIButton(type:.system);button.tag=i;button.setTitle(name,for:.normal);button.titleLabel?.font=UIFont.boldSystemFont(ofSize:11);button.setTitleColor(.white,for:.normal);button.layer.cornerRadius=5;button.contentEdgeInsets=UIEdgeInsets(top:8,left:12,bottom:8,right:12)
            button.addAction(UIAction{[weak self] _ in self?.category=i;self?.refreshList()},for:.touchUpInside);categoryStack.addArrangedSubview(button)
        }
        search.placeholder="Find an item";search.delegate=self;search.searchBarStyle = .minimal;search.searchTextField.textColor = .white
        collection.backgroundColor = .clear;collection.dataSource=self;collection.delegate=self;collection.register(ItemCard.self,forCellWithReuseIdentifier:"item")
        status.numberOfLines=2;status.font=UIFont.systemFont(ofSize:12,weight:.semibold);status.textColor = .white;status.textAlignment = .center
        close.setTitle("SAVE & BACK",for:.normal);close.setTitleColor(.white,for:.normal);close.titleLabel?.font=UIFont.boldSystemFont(ofSize:13);close.backgroundColor=UIColor(red:0.45,green:0.54,blue:0.19,alpha:1);close.layer.cornerRadius=7
        close.addAction(UIAction{[weak self] _ in guard let self=self else{return};self.save();self.finished?(self.faction,self.kind);self.dismiss(animated:true)},for:.touchUpInside)
        reset.setTitle("RESET OUTFIT",for:.normal);reset.setTitleColor(.white,for:.normal);reset.titleLabel?.font=UIFont.boldSystemFont(ofSize:12)
        reset.addAction(UIAction{[weak self] _ in guard let self=self else{return};self.loadout=self.wardrobe.defaults(self.faction,self.kind);self.save();self.refreshHero();self.refreshList()},for:.touchUpInside)
        refreshList();refreshHero();link=CADisplayLink(target:self,selector:#selector(animate(_:)));link?.add(to:.main,forMode:.common)
    }
    override func viewDidDisappear(_ animated:Bool) {super.viewDidDisappear(animated);link?.invalidate();link=nil}
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews();let safe=view.safeAreaInsets,w=view.bounds.width-safe.left-safe.right,h=view.bounds.height-safe.top-safe.bottom,x=safe.left
        heroTitle.frame=CGRect(x:x+18,y:safe.top+8,width:w*0.3,height:30);close.frame=CGRect(x:x+w-142,y:safe.top+6,width:130,height:34)
        factions.frame=CGRect(x:x+14,y:safe.top+45,width:w*0.29,height:30);classes.frame=CGRect(x:x+w*0.34,y:safe.top+45,width:w*0.64,height:30)
        preview.frame=CGRect(x:x,y:safe.top+82,width:w*0.33,height:h-128);status.frame=CGRect(x:x+8,y:safe.top+h-55,width:w*0.31-16,height:45)
        let rightX=x+w*0.34,rightWidth=w*0.64
        categoryScroll.frame=CGRect(x:rightX,y:safe.top+83,width:rightWidth,height:34);categoryStack.frame=CGRect(origin:.zero,size:categoryStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize));categoryScroll.contentSize=categoryStack.bounds.size
        search.frame=CGRect(x:rightX-8,y:safe.top+118,width:rightWidth*0.61,height:42);slots.frame=CGRect(x:rightX+rightWidth*0.61,y:safe.top+126,width:rightWidth*0.39,height:28)
        collection.frame=CGRect(x:rightX,y:safe.top+163,width:rightWidth,height:h-205)
        let layout=collection.collectionViewLayout as! UICollectionViewFlowLayout;let columns=max(3,Int(rightWidth/115));layout.itemSize=CGSize(width:(rightWidth-CGFloat(columns-1)*8)/CGFloat(columns),height:108)
        reset.frame=CGRect(x:rightX,y:safe.top+h-36,width:rightWidth,height:28)
    }
    func save() {wardrobe.save(loadout,faction,kind)}
    func changeHero(faction:Int,kind:HeroClass) {save();self.faction=faction;self.kind=kind;loadout=wardrobe.load(faction,kind);refreshList();refreshHero()}
    func refreshList() {
        visibleItems=wardrobe.catalog.items.filter{$0.faction==faction && $0.kits & kind.kitMask != 0 && $0.slot==category && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))}.sorted{$0.id<$1.id}
        visibleWeapons=wardrobe.catalog.weapons.filter{$0.faction==faction && $0.kits & kind.kitMask != 0 && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))}.sorted{$0.id<$1.id}
        visibleColors=wardrobe.catalog.colors.filter{$0.kind==(category==9 ? "skin" : "hair")}
        for view in categoryStack.arrangedSubviews {view.backgroundColor=view.tag==category ? UIColor(red:0.58,green:0.45,blue:0.14,alpha:1) : UIColor.white.withAlphaComponent(0.14)}
        slots.isHidden=category != 11;collection.reloadData()
    }
    func refreshHero() {
        heroRoot.childNodes.forEach{$0.removeFromParentNode()}
        do {
            let a=try AnimatedCharacter(faction==1 ? "royal" : "national",directory:Bundle.main.resourceURL!.appendingPathComponent("Assets/Characters"));try wardrobe.apply(loadout,faction:faction,to:a)
            let slot=category==11 ? slots.selectedSegmentIndex : 0
            if loadout.weapons.indices.contains(slot),let weapon=wardrobe.weapons[loadout.weapons[slot]] {let gun=try original.model(weapon.model);a.bones[44].addChildNode(gun);a.weaponPose=weapon.pose ?? "smg"}
            actor=a;a.node.simdEulerAngles.y=rotation;heroRoot.addChildNode(a.node);status.text="\(faction==1 ? "Royal" : "National") \(kind.rawValue)\nDrag your hero to rotate"
        } catch {actor=nil;status.text="This outfit could not be loaded"}
    }
    @objc func turn(_ gesture:UIPanGestureRecognizer) {rotation+=Float(gesture.translation(in:preview).x)*0.008;gesture.setTranslation(.zero,in:preview);actor?.node.simdEulerAngles.y=rotation}
    @objc func animate(_ display:CADisplayLink) {let dt=last==0 ? 0 : min(0.05,display.timestamp-last);last=display.timestamp;actor?.update(dt,position:.zero,moving:false,firing:false,ability:false,alive:true)}
    func searchBar(_ searchBar:UISearchBar,textDidChange text:String) {query=text;refreshList()}
    func collectionView(_ collectionView:UICollectionView,numberOfItemsInSection section:Int)->Int {category==11 ? visibleWeapons.count : category>=9 ? visibleColors.count : visibleItems.count+1}
    func collectionView(_ collectionView:UICollectionView,cellForItemAt indexPath:IndexPath)->UICollectionViewCell {
        let cell=collectionView.dequeueReusableCell(withReuseIdentifier:"item",for:indexPath) as! ItemCard;cell.image.image=nil;cell.image.backgroundColor = .clear;var selected=false
        if category==11 {
            let item=visibleWeapons[indexPath.item];cell.caption.text=item.name;if let file=item.icon,let image=wardrobe.image(file){cell.image.image=UIImage(cgImage:image)};selected=loadout.weapons.indices.contains(slots.selectedSegmentIndex) && loadout.weapons[slots.selectedSegmentIndex]==item.id
        } else if category>=9 {
            let c=visibleColors[indexPath.item];cell.caption.text=c.name;cell.image.backgroundColor=UIColor(red:CGFloat(c.rgb[0])/255,green:CGFloat(c.rgb[1])/255,blue:CGFloat(c.rgb[2])/255,alpha:1);selected=(category==9 ? loadout.skin : loadout.hair)==c.id
        } else if indexPath.item==0 {cell.caption.text="UNEQUIP";selected=loadout.clothing[category]==nil}
        else {let item=visibleItems[indexPath.item-1];cell.caption.text=item.name;if let file=item.icon,let image=wardrobe.image(file){cell.image.image=UIImage(cgImage:image)};selected=loadout.clothing[category]==item.id}
        cell.check.isHidden = !selected;cell.contentView.layer.borderColor=(selected ? UIColor.yellow : UIColor.white.withAlphaComponent(0.25)).cgColor;return cell
    }
    func collectionView(_ collectionView:UICollectionView,didSelectItemAt indexPath:IndexPath) {
        view.endEditing(true)
        if category==11 {
            let slot=slots.selectedSegmentIndex;while loadout.weapons.count<=slot {loadout.weapons.append(visibleWeapons[indexPath.item].id)};loadout.weapons[slot]=visibleWeapons[indexPath.item].id
        } else if category==9 {loadout.skin=visibleColors[indexPath.item].id}
        else if category==10 {loadout.hair=visibleColors[indexPath.item].id}
        else if indexPath.item==0 {loadout.clothing.removeValue(forKey:category)}
        else {loadout.clothing[category]=visibleItems[indexPath.item-1].id}
        save();refreshHero();collection.reloadData()
    }
}
