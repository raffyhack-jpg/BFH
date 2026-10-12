import UIKit
import SceneKit

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
final class GameController: UIViewController {
    let render=SCNView(); let scene=SCNScene(); let camera=SCNNode(); let target=SCNNode()
    var skyNode:SCNNode?; var originalWorld:OriginalWorld?; var game:Game?; var selectedClass=HeroClass.soldier; var selectedMode=Mode.conquest
    var animators:[AnimatedCharacter?]=[]; var previousPositions:[V2]=[]
    var nodes:[SCNNode]=[]; var objectiveNodes:[SCNNode]=[]; var flagNodes:[SCNNode]=[]
    let effects=SCNNode(); let world=SCNNode(); let hud=UILabel(); let notice=UILabel()
    var left=Stick(frame:CGRect(x:0,y:0,width:116,height:116)); var right=Stick(frame:CGRect(x:0,y:0,width:116,height:116))
    let fire=UIButton(type:.system), skill=UIButton(type:.system), pause=UIButton(type:.system)
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
        for control in [left,right,fire,skill,pause] { view.addSubview(control) }
        style(fire,"FIRE",red); style(skill,"ABILITY",blue); style(pause,"Ⅱ",UIColor.darkGray)
        fire.addTarget(self,action:#selector(fireDown),for:.touchDown)
        fire.addTarget(self,action:#selector(fireUp),for:[.touchUpInside,.touchUpOutside,.touchCancel])
        skill.addTarget(self,action:#selector(useSkill),for:.touchUpInside); pause.addTarget(self,action:#selector(togglePause),for:.touchUpInside)
        display=CADisplayLink(target:self,selector:#selector(tick(_:))); display?.add(to:.main,forMode:.common)
        NotificationCenter.default.addObserver(self,selector:#selector(background),name:UIApplication.willResignActiveNotification,object:nil)
        if let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/OriginalWorld") { originalWorld=try? OriginalWorld(directory:directory) }
        showMenu()
    }
    func style(_ b:UIButton,_ title:String,_ color:UIColor) { b.setTitle(title,for:.normal); b.setTitleColor(.white,for:.normal); b.titleLabel?.font=UIFont.boldSystemFont(ofSize:16); b.backgroundColor=color.withAlphaComponent(0.82); b.layer.cornerRadius=18 }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); let r=view.safeAreaInsets; let w=view.bounds.width,h=view.bounds.height
        left.frame.origin=CGPoint(x:r.left+25,y:h-r.bottom-141); right.frame.origin=CGPoint(x:w-r.right-240,y:h-r.bottom-141)
        fire.frame=CGRect(x:w-r.right-106,y:h-r.bottom-117,width:88,height:88); skill.frame=CGRect(x:w-r.right-128,y:h-r.bottom-182,width:110,height:48)
        pause.frame=CGRect(x:w-r.right-66,y:r.top+14,width:48,height:38)
        hud.frame=CGRect(x:r.left+80,y:r.top+14,width:w-r.left-r.right-160,height:48); notice.frame=CGRect(x:100,y:h*0.24,width:w-200,height:45)
        menu?.frame=view.bounds
    }
    func sphere(_ radius:CGFloat,_ color:UIColor) -> SCNNode { let g=SCNSphere(radius:radius); g.segmentCount=10; g.firstMaterial?.diffuse.contents=color; return SCNNode(geometry:g) }
    func soldier(_ kind:HeroClass,_ team:Int) throws -> SCNNode {
        guard let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/Characters"),let original=originalWorld else { throw CocoaError(.fileReadNoSuchFile) }
        let animator=try AnimatedCharacter(team == 0 ? "royal" : "national",directory:directory)
        animators.append(animator)
        let root=animator.node
        let marker=sphere(0.1,team == 0 ? blue : red); marker.position.y=2.3; root.addChildNode(marker)
        let gun=try original.weapon(kind,team);gun.name="held-weapon";animator.bones[44].addChildNode(gun)
        return root
    }
    func start() {
        menu?.removeFromSuperview(); menu=nil; firing=false; yaw = .pi/2; pitch=0.2; left.reset(); right.reset()
        guard let original=originalWorld else { notice.text="Original assets could not be loaded. Rebuild the IPA."; showMenu(result:"ASSET LOAD FAILED"); return }
        let g=Game(mode:selectedMode,hero:selectedClass,layout:original.layout); game=g
        world.childNodes.forEach{$0.removeFromParentNode()}; effects.childNodes.forEach{$0.removeFromParentNode()}; nodes=[]; animators=[]; previousPositions=g.heroes.map{$0.p}; objectiveNodes=[]; flagNodes=[]
        do { try original.populate(world); let sky=try original.sky();world.addChildNode(sky);skyNode=sky } catch { showMenu(result:"MAP LOAD FAILED"); return }
        let aim=g.objectives[0].p-g.bases[0];yaw=atan2(aim.x,aim.z)
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
        do { for h in g.heroes { let n=try soldier(h.kind,h.team); world.addChildNode(n); nodes.append(n) } } catch { showMenu(result:"CHARACTER LOAD FAILED"); return }
        notice.text="Left: move • Right: look • FIRE: shoot"; hudTime=0; last=0
        for c in [left,right,fire,skill,pause] { c.isHidden=false }
    }
    @objc func fireDown() { firing=true }
    @objc func fireUp() { firing=false }
    @objc func useSkill() { if let g=game, !g.paused, g.winner == nil { g.ability(g.heroes[0]); UIImpactFeedbackGenerator(style:.light).impactOccurred() } }
    @objc func background() { if let g=game, menu == nil, g.winner == nil { g.paused=true; firing=false; left.reset(); right.reset(); showMenu(resume:true) } }
    @objc func togglePause() { guard let g=game else { return }; g.paused=true; firing=false; showMenu(resume:true) }
    @objc func tick(_ link:CADisplayLink) {
        let dt=last == 0 ? 0 : min(0.05,link.timestamp-last); last=link.timestamp
        guard let g=game, menu == nil else { return }
        yaw-=Double(right.value.x)*dt*2.7; pitch=max(-0.25,min(0.6,pitch+Double(right.value.y)*dt))
        let forward=V2(x:sin(yaw),z:cos(yaw)), sideways=V2(x:-cos(yaw),z:sin(yaw))
        let move=forward * -Double(left.value.y)+sideways*Double(left.value.x)
        g.update(dt,input:Input(move:move,yaw:yaw,fire:firing,ability:false))
        for (i,h) in g.heroes.enumerated() {
            nodes[i].position=SCNVector3(Float(h.p.x),originalWorld?.height(h.p) ?? 0,Float(h.p.z)); nodes[i].eulerAngles.y=Float(h.facing); if let animator=animators[i] {
                animator.update(dt,position:h.p,moving:h.p.distance(previousPositions[i])>0.003,firing:h.cooldown>h.kind.interval-0.08,ability:h.ability>11.5,alive:h.alive)

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
        let ground=Double(originalWorld?.height(p) ?? 0)
        camera.position=SCNVector3(p.x-forward.x*5.5,ground+3.4+pitch*4,p.z-forward.z*5.5)
        camera.look(at:SCNVector3(p.x+forward.x*12,ground+1.5-pitch*8,p.z+forward.z*12))
        skyNode?.position=camera.position
        for shot in g.shots { tracer(shot) }
        hudTime+=dt
        if hudTime>0.15 {
            hudTime=0
            let scores=g.mode == .conquest ? "ROYAL \(max(0,Int(g.tickets[0]))) : \(max(0,Int(g.tickets[1]))) NATIONAL" : g.mode == .elimination ? "ROYAL \(g.heroes.filter{$0.team == 0 && $0.alive}.count) : \(g.heroes.filter{$0.team == 1 && $0.alive}.count) NATIONAL" : "ROYAL \(Int(g.score[0])) : \(Int(g.score[1])) NATIONAL"
            hud.text="\(scores)   •   \(max(0,300-Int(g.elapsed)))s\n\(player.kind.rawValue)  HP \(Int(player.hp))  K \(player.kills) / D \(player.deaths)"
            skill.setTitle(player.ability>0 ? "\(Int(ceil(player.ability)))s" : "ABILITY",for:.normal)
            notice.text=player.alive ? (g.elapsed<8 ? "Left: move • Right: look • FIRE: shoot" : g.message) : g.mode == .elimination ? "Eliminated • watching your squad" : "Respawn in \(Int(ceil(max(0,player.respawn))))"
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
        for c in [left,right,fire,skill,pause] { c.isHidden=true }
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
        let subtitle=UILabel(); subtitle.text="ROYAL vs NATIONAL  •  ORIGINAL BFH ASSETS"; subtitle.textColor = .lightGray; subtitle.textAlignment = .center; subtitle.font=UIFont.systemFont(ofSize:13,weight:.semibold); stack.addArrangedSubview(subtitle)
        if resume {
            let button=UIButton(type:.system); style(button,"RESUME",blue); button.addAction(UIAction { [weak self] _ in self?.game?.paused=false; self?.menu?.removeFromSuperview(); self?.menu=nil; for c in [self?.left,self?.right,self?.fire,self?.skill,self?.pause] { c?.isHidden=false } },for:.touchUpInside); stack.addArrangedSubview(button); button.heightAnchor.constraint(equalToConstant:44).isActive=true
        }
        let modes=UISegmentedControl(items:Mode.allCases.map{$0.rawValue}); modes.selectedSegmentIndex=Mode.allCases.firstIndex(of:selectedMode) ?? 0; modes.backgroundColor = .lightGray
        modes.addAction(UIAction { [weak self, weak modes] _ in if let index=modes?.selectedSegmentIndex { self?.selectedMode=Mode.allCases[index] } },for:.valueChanged); stack.addArrangedSubview(modes)
        let classes=UISegmentedControl(items:HeroClass.allCases.map{$0.rawValue}); classes.selectedSegmentIndex=HeroClass.allCases.firstIndex(of:selectedClass) ?? 0; classes.backgroundColor = .lightGray
        classes.addAction(UIAction { [weak self, weak classes] _ in if let index=classes?.selectedSegmentIndex { self?.selectedClass=HeroClass.allCases[index] } },for:.valueChanged); stack.addArrangedSubview(classes)
        let startButton=UIButton(type:.system); style(startButton,resume ? "NEW MATCH" : "DEPLOY",blue); startButton.addAction(UIAction { [weak self] _ in self?.start() },for:.touchUpInside); stack.addArrangedSubview(startButton); startButton.heightAnchor.constraint(equalToConstant:48).isActive=true
        let help=UILabel(); help.text="Soldier: heal squad  •  Gunner: shield  •  Commando: dash\nOriginal map and weapon conversion • gameplay still in development"; help.numberOfLines=2; help.textAlignment = .center; help.textColor = .lightGray; help.font=UIFont.systemFont(ofSize:12); stack.addArrangedSubview(help)
    }
}
