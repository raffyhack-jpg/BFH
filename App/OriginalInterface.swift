import UIKit
import SceneKit

// Geometry follows the original 800 x 600 Flash menu rather than a UIKit stack.
final class OriginalMenuShell:UIView {
    weak var owner:GameController?
    let canvas=UIView(),paper=UIImageView(),redHeader=UIImageView(),logo=UIImageView(),play=UIButton(type:.custom)
    let hero=SCNView(),xp=OriginalXPBar(),heroName=ComicLabel(),level=ComicLabel(),nextLevel=ComicLabel()
    let heading=ComicLabel(),body=ComicLabel(),equipmentHeading=ComicLabel()
    let currencies=(0..<3).map{_ in UIImageView()},balances=(0..<3).map{_ in ComicLabel()}
    let equipment=(0..<10).map{_ in UIImageView()},keys=(0..<10).map{_ in ComicLabel()}
    var tabButtons:[UIButton]=[],subButtons:[UIButton]=[],modeButtons:[UIButton]=[],classButtons:[UIButton]=[]
    var selectedTab="Home",resume=false,result:String?
    init(owner:GameController,resume:Bool,result:String?){
        self.owner=owner;self.resume=resume;self.result=result;super.init(frame:owner.view.bounds)
        backgroundColor=UIColor(red:0.52,green:0.74,blue:0.82,alpha:1)
        let scenery=UIImageView(image:UIImage(contentsOfFile:Bundle.main.path(forResource:"menu",ofType:"png",inDirectory:"Assets/UI") ?? ""));scenery.frame=bounds;scenery.autoresizingMask=[.flexibleWidth,.flexibleHeight];scenery.contentMode = .scaleAspectFill;scenery.layer.contentsRect=CGRect(x:0,y:0,width:1,height:656.0/1024);addSubview(scenery)
        addSubview(canvas);canvas.bounds=CGRect(x:0,y:0,width:800,height:600);canvas.backgroundColor=UIColor(red:0.86,green:0.83,blue:0.72,alpha:1);canvas.layer.cornerRadius=7;canvas.layer.borderColor=UIColor.black.cgColor;canvas.layer.borderWidth=1;canvas.layer.shadowOpacity=0.8;canvas.layer.shadowRadius=5;canvas.clipsToBounds=true
        paper.image=OriginalUIArt.image("background/bg.png");paper.frame=canvas.bounds;paper.contentMode = .scaleToFill;canvas.addSubview(paper)
        redHeader.image=OriginalUIArt.image("background/banner.png");redHeader.backgroundColor=UIColor(red:0.43,green:0.1,blue:0.08,alpha:1);redHeader.frame=CGRect(x:22,y:42,width:756,height:92);canvas.addSubview(redHeader)
        let titlebar=UIImageView(image:OriginalUIArt.image("background/header-bar.png"));titlebar.layer.contentsRect=CGRect(x:0,y:0,width:1,height:0.47);titlebar.frame=CGRect(x:5,y:4,width:790,height:37);canvas.addSubview(titlebar)
        logo.isHidden=true;logo.image=UIImage(contentsOfFile:Bundle.main.path(forResource:"logo",ofType:"png",inDirectory:"Assets/UI") ?? "");logo.contentMode = .scaleAspectFit;logo.frame=CGRect(x:12,y:5,width:110,height:33);canvas.addSubview(logo)
        let submenu=UIImageView(image:OriginalUIArt.image("background/submenu-bg.png"));submenu.frame=CGRect(x:22,y:103,width:756,height:31);canvas.addSubview(submenu)
        for (i,name) in ["Home","My Stuff","Store","Friends","Options"].enumerated(){
            let button=UIButton(type:.custom);button.setAttributedTitle(text(name,color:.white,size:20),for:.normal);button.frame=CGRect(x:CGFloat(25+i*130),y:59,width:122,height:38)
            button.addAction(UIAction{[weak self] _ in self?.selectTab(name)},for:.touchUpInside);canvas.addSubview(button);tabButtons.append(button)
        }
        for (i,name) in ["Appearance","Weapons","Abilities","Emotes","Widgets","Missions"].enumerated(){
            let button=UIButton(type:.custom);button.setAttributedTitle(text(name,color:.white,size:14),for:.normal);button.frame=CGRect(x:CGFloat(22+i*106),y:103,width:106,height:27)
            button.addAction(UIAction{[weak self] _ in self?.openSection(i)},for:.touchUpInside);canvas.addSubview(button);subButtons.append(button)
        }
        play.setImage(OriginalUIArt.image("components/buttonplaynow_en.png"),for:.normal);play.frame=CGRect(x:680,y:40,width:92,height:92);play.addAction(UIAction{[weak self] _ in self?.deploy()},for:.touchUpInside);canvas.addSubview(play)
        let strip=UIView(frame:CGRect(x:24,y:139,width:752,height:40));let stripArt=UIImageView(image:OriginalUIArt.image("background/level-background.png"));stripArt.frame=strip.bounds;stripArt.autoresizingMask=[.flexibleWidth,.flexibleHeight];strip.addSubview(stripArt);strip.backgroundColor=UIColor(red:0.92,green:0.9,blue:0.83,alpha:1);strip.layer.borderWidth=2;strip.layer.borderColor=UIColor.darkGray.cgColor;strip.layer.cornerRadius=8;canvas.addSubview(strip)
        level.frame=CGRect(x:33,y:146,width:28,height:24);nextLevel.frame=CGRect(x:264,y:146,width:28,height:24);xp.frame=CGRect(x:66,y:141,width:192,height:30)
        heroName.frame=CGRect(x:63,y:181,width:220,height:25);heroName.backgroundColor=UIColor.darkGray;heroName.layer.cornerRadius=5;heroName.clipsToBounds=true
        for v in [level,nextLevel,xp,heroName]{canvas.addSubview(v)}
        for (i,suffix) in ["icons/currency_hp.png","icons/currency_vp.png","icons/currency_bf.png"].enumerated(){currencies[i].image=OriginalUIArt.image(suffix);currencies[i].frame=CGRect(x:CGFloat(324+i*127),y:137,width:43,height:43);currencies[i].contentMode = .scaleAspectFit;balances[i].frame=CGRect(x:CGFloat(367+i*127),y:147,width:75,height:23);canvas.addSubview(currencies[i]);canvas.addSubview(balances[i])}
        hero.frame=CGRect(x:28,y:215,width:300,height:285);hero.backgroundColor = .clear;hero.isOpaque=false;hero.antialiasingMode = .multisampling4X;hero.isPlaying=true;canvas.addSubview(hero);buildHero()
        let panel=UIView(frame:CGRect(x:355,y:215,width:410,height:275));panel.backgroundColor=UIColor(red:0.79,green:0.78,blue:0.7,alpha:0.86);panel.layer.borderWidth=2;panel.layer.borderColor=UIColor.black.cgColor;panel.layer.cornerRadius=9;canvas.addSubview(panel)
        let panelArt=UIImageView(image:OriginalUIArt.image("panels/01_bgframesmall.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:12,left:12,bottom:12,right:12)));panelArt.frame=panel.bounds;panelArt.autoresizingMask=[.flexibleWidth,.flexibleHeight];panel.addSubview(panelArt)
        let olive=UIView(frame:CGRect(x:2,y:2,width:406,height:30));olive.backgroundColor=UIColor(red:0.25,green:0.29,blue:0.08,alpha:1);olive.layer.cornerRadius=6;panel.addSubview(olive);let tabArt=UIImageView(image:OriginalUIArt.image("panels/01_fgtabwide.png"));tabArt.frame=olive.bounds;tabArt.contentMode = .scaleToFill;olive.addSubview(tabArt)
        heading.frame=CGRect(x:2,y:0,width:406,height:32);panel.addSubview(heading);body.numberOfLines=3;body.frame=CGRect(x:15,y:42,width:380,height:72);panel.addSubview(body)
        for (i,kind) in HeroClass.allCases.enumerated(){let button=smallButton(kind.rawValue);button.frame=CGRect(x:CGFloat(14+i*128),y:122,width:121,height:32);button.addAction(UIAction{[weak self] _ in self?.owner?.selectedClass=kind;UserDefaults.standard.set(kind.rawValue,forKey:"selected-class");self?.buildHero();self?.refresh()},for:.touchUpInside);panel.addSubview(button);classButtons.append(button)}
        for (i,mode) in Mode.allCases.enumerated(){let button=smallButton(mode.rawValue);button.frame=CGRect(x:CGFloat(14+i%2*193),y:CGFloat(166+i/2*42),width:186,height:36);button.addAction(UIAction{[weak self] _ in self?.owner?.selectedMode=mode;self?.refresh()},for:.touchUpInside);panel.addSubview(button);modeButtons.append(button)}
        equipmentHeading.frame=CGRect(x:35,y:490,width:190,height:28);equipmentHeading.backgroundColor=UIColor(red:0.29,green:0.32,blue:0.1,alpha:1);equipmentHeading.write("Equipment bar",size:16);canvas.addSubview(equipmentHeading)
        let equipmentFrame=UIView(frame:CGRect(x:27,y:518,width:745,height:57));equipmentFrame.backgroundColor=UIColor(red:0.86,green:0.84,blue:0.73,alpha:1);equipmentFrame.layer.borderWidth=2;equipmentFrame.layer.borderColor=UIColor.black.cgColor;equipmentFrame.layer.cornerRadius=8;canvas.addSubview(equipmentFrame);let gearArt=UIImageView(image:OriginalUIArt.image("panels/04_bgframe.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:10,left:10,bottom:10,right:10)));gearArt.frame=equipmentFrame.bounds;equipmentFrame.addSubview(gearArt)
        for i in 0..<10 {let slot=UIView(frame:CGRect(x:CGFloat(5+i*74),y:4,width:71,height:49));slot.backgroundColor=UIColor(red:0.91,green:0.9,blue:0.85,alpha:1);slot.layer.borderWidth=1.5;slot.layer.borderColor=UIColor.gray.cgColor;slot.layer.cornerRadius=5;equipmentFrame.addSubview(slot);let slotArt=UIImageView(image:OriginalUIArt.image("panels/04_fgslotframe.png"));slotArt.frame=slot.bounds;slot.addSubview(slotArt);equipment[i].frame=CGRect(x:2,y:0,width:67,height:33);equipment[i].contentMode = .scaleAspectFit;keys[i].frame=CGRect(x:0,y:31,width:71,height:16);slot.addSubview(equipment[i]);slot.addSubview(keys[i])}
        let version=UILabel(frame:CGRect(x:635,y:578,width:140,height:15));version.text="v0.6 • Offline hero";version.textAlignment = .right;version.font=UIFont.systemFont(ofSize:10,weight:.bold);canvas.addSubview(version)
        refresh()
    }
    required init?(coder:NSCoder){fatalError()}
    override func layoutSubviews(){super.layoutSubviews();let inset=safeAreaInsets,usable=bounds.inset(by:inset),scale=min((usable.width-8)/800,(usable.height-8)/600);canvas.transform=CGAffineTransform(scaleX:scale,y:scale);canvas.center=CGPoint(x:usable.midX,y:usable.midY)}
    func text(_ value:String,color:UIColor,size:CGFloat)->NSAttributedString {NSAttributedString(string:value,attributes:[.font:OriginalFont.heavy(size),.foregroundColor:color,.strokeColor:UIColor.black,.strokeWidth:-5,.kern:1])}
    func smallButton(_ name:String)->UIButton {let b=UIButton(type:.custom);b.setBackgroundImage(OriginalUIArt.image("components/button.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:7,left:8,bottom:7,right:8)),for:.normal);b.setAttributedTitle(text(name,color:.white,size:13),for:.normal);return b}
    func refresh(){
        guard let owner=owner else{return};let p=CareerStore.shared.load(owner.selectedTeam+1,owner.selectedClass)
        level.write(String(p.level),size:14);nextLevel.write(String(min(30,p.level+1)),size:14);xp.progress=Float(p.levelFraction);heroName.write("\(owner.selectedTeam==0 ? "Royal" : "National") \(owner.selectedClass.rawValue)",size:13)
        for (i,value) in [p.heroPoints,p.valor,p.funds].enumerated(){balances[i].write(String(value),color:.white,size:17)}
        heading.write(result ?? "Select your hero",size:18);body.write(result == nil ? "\(owner.selectedClass.rawValue)\n\(owner.selectedMode.rawValue)\nChoose your gear in My Stuff" : "Choose your next battle",color:.white,size:17)
        for (i,b) in classButtons.enumerated(){b.alpha=HeroClass.allCases[i]==owner.selectedClass ? 1 : 0.65}
        for (i,b) in modeButtons.enumerated(){b.alpha=Mode.allCases[i]==owner.selectedMode ? 1 : 0.65}
        for (i,b) in tabButtons.enumerated(){b.setAttributedTitle(text(["Home","My Stuff","Store","Friends","Options"][i],color:["Home","My Stuff","Store","Friends","Options"][i]==selectedTab ? .yellow : .white,size:20),for:.normal)}
        let loadout=owner.wardrobe?.load(owner.selectedTeam+1,owner.selectedClass)
        for i in 0..<10 {equipment[i].image=i<(loadout?.weapons.count ?? 0) ? OriginalUIArt.image("weapons/weapon\(loadout!.weapons[i]).tga") : i==2 ? OriginalUIArt.image("abilities/ability\(owner.selectedClass == .soldier ? 2001 : owner.selectedClass == .heavy ? 2011 : 2016).tga") : nil;keys[i].write(i==2 ? "3" : String((i+1)%10),size:11)}
    }
    func buildHero(){
        guard let owner=owner,let wardrobe=owner.wardrobe,let original=owner.originalWorld,let directory=Bundle.main.resourceURL?.appendingPathComponent("Assets/Characters") else{return}
        let scene=SCNScene();scene.background.contents=UIColor.clear;hero.scene=scene;let camera=SCNNode();camera.camera=SCNCamera();camera.camera?.fieldOfView=32;camera.position=SCNVector3(0,1.2,4.4);camera.look(at:SCNVector3(0,1.05,0));scene.rootNode.addChildNode(camera);hero.pointOfView=camera
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light?.type = .ambient;ambient.light?.intensity=900;scene.rootNode.addChildNode(ambient)
        let sun=SCNNode();sun.light=SCNLight();sun.light?.type = .directional;sun.light?.intensity=1050;sun.eulerAngles=SCNVector3(-0.5,-0.4,0);scene.rootNode.addChildNode(sun)
        do {let actor=try AnimatedCharacter(owner.selectedTeam==0 ? "royal" : "national",directory:directory);let loadout=wardrobe.load(owner.selectedTeam+1,owner.selectedClass);try wardrobe.apply(loadout,faction:owner.selectedTeam+1,to:actor);if let id=loadout.weapons.first,let weapon=wardrobe.weapons[id],let gun=try? original.model(weapon.model){actor.bones[44].addChildNode(gun);actor.weaponPose=weapon.pose ?? "smg"};scene.rootNode.addChildNode(actor.node);owner.menuActor=actor}catch{owner.menuActor=nil}
    }
    func selectTab(_ name:String){selectedTab=name;refresh();guard let owner=owner else{return};switch name {case "My Stuff":owner.customizeHero();case "Store":owner.customizeHero(category:4,shop:true);case "Friends":heading.write("Friends",size:18);body.write("No friends online",size:18);case "Options":heading.write("Options",size:18);body.write("Hold and drag FIRE to aim\nTap equipment to switch\nTap JUMP to jump",size:17);default:break}}
    func openSection(_ i:Int){guard let owner=owner else{return};switch i {case 0:owner.customizeHero(shop:selectedTab=="Store");case 1:owner.customizeHero(category:11,shop:selectedTab=="Store");case 2,5:owner.showCareer();default:heading.write(i==3 ? "Emotes" : "Widgets",size:18);body.write("No items equipped",size:17)}}
    func deploy(){guard let owner=owner else{return};if resume {owner.game?.paused=false;owner.career=CareerStore.shared.load(owner.matchFaction,owner.matchKind);owner.game?.heroes[0].abilityRank=owner.career.abilityRank;owner.menu?.removeFromSuperview();owner.menu=nil;owner.comicHUD.isHidden=false;owner.scoreToast.isHidden=false;for v in [owner.left,owner.right,owner.fire,owner.skill,owner.pause,owner.jumpButton,owner.crosshair,owner.switchButton,owner.reloadButton]{v.isHidden=false}}else{owner.start()}}
}

// Shared Flash-menu artwork; controls are placed in the original 800×600 coordinate space.
final class OriginalInventoryChrome:UIView {
    let canvas=UIView(),heading=ComicLabel(),heroName=ComicLabel(),level=ComicLabel(),xp=OriginalXPBar()
    var title="My Stuff",section="Appearance",onBack:(()->Void)?,onSection:((Int)->Void)?
    var tabs:[UIButton]=[],sections:[UIButton]=[],balances:[ComicLabel]=[]
    override init(frame:CGRect){
        super.init(frame:frame);backgroundColor=UIColor(red:0.5,green:0.72,blue:0.8,alpha:1);addSubview(canvas);canvas.bounds=CGRect(x:0,y:0,width:800,height:600)
        let scenery=UIImageView(image:UIImage(contentsOfFile:Bundle.main.path(forResource:"menu",ofType:"png",inDirectory:"Assets/UI") ?? ""));scenery.frame=bounds;scenery.autoresizingMask=[.flexibleWidth,.flexibleHeight];scenery.contentMode = .scaleAspectFill;insertSubview(scenery,at:0)
        art("background/bg.png",CGRect(x:0,y:0,width:800,height:600));let titlebar=art("background/header-bar.png",CGRect(x:4,y:3,width:792,height:37));titlebar.layer.contentsRect=CGRect(x:0,y:0,width:1,height:0.47);art("background/banner.png",CGRect(x:22,y:42,width:756,height:92))
        art("background/submenu-bg.png",CGRect(x:22,y:103,width:756,height:31))
        for (i,name) in ["Home","My Stuff","Store","Friends","Options"].enumerated(){let b=button(name,size:20);b.setBackgroundImage(nil,for:.normal);b.frame=CGRect(x:CGFloat(29+i*130),y:59,width:125,height:40);b.addAction(UIAction{[weak self] _ in if i==0 || i==1 || i==2 {self?.onBack?()}},for:.touchUpInside);canvas.addSubview(b);tabs.append(b)}
        for (i,name) in ["Appearance","Weapons","Abilities","Emotes","Widgets","Missions"].enumerated(){let b=button(name,size:14);b.setBackgroundImage(nil,for:.normal);b.frame=CGRect(x:CGFloat(25+i*107),y:103,width:107,height:29);b.isEnabled=i<2;b.addAction(UIAction{[weak self] _ in self?.onSection?(i)},for:.touchUpInside);canvas.addSubview(b);sections.append(b)}
        let back=button("Back",size:13);back.frame=CGRect(x:685,y:36,width:85,height:29);back.addAction(UIAction{[weak self] _ in self?.onBack?()},for:.touchUpInside);canvas.addSubview(back)
        art("background/level-background.png",CGRect(x:24,y:139,width:752,height:40));level.frame=CGRect(x:36,y:146,width:28,height:25);xp.frame=CGRect(x:71,y:142,width:197,height:30);heroName.frame=CGRect(x:71,y:181,width:217,height:23);heroName.backgroundColor = .darkGray;heroName.layer.cornerRadius=4;heroName.clipsToBounds=true;for v in [level,xp,heroName]{canvas.addSubview(v)}
        for (i,s) in ["icons/currency_hp.png","icons/currency_vp.png","icons/currency_bf.png"].enumerated(){art(s,CGRect(x:CGFloat(319+i*133),y:133,width:49,height:49));let l=ComicLabel(frame:CGRect(x:CGFloat(367+i*133),y:146,width:77,height:25));canvas.addSubview(l);balances.append(l)}
        art("panels/01_bgframelargelong.png",CGRect(x:336,y:211,width:437,height:375),stretch:true);art("panels/01_fgtabwide.png",CGRect(x:336,y:211,width:437,height:34));heading.frame=CGRect(x:339,y:211,width:430,height:31);canvas.addSubview(heading)
    }
    convenience init(){self.init(frame:.zero)}
    required init?(coder:NSCoder){fatalError()}
    @discardableResult func art(_ suffix:String,_ frame:CGRect,stretch:Bool=false)->UIImageView {let original=OriginalUIArt.image(suffix),v=UIImageView(image:stretch ? original?.resizableImage(withCapInsets:UIEdgeInsets(top:40,left:10,bottom:10,right:10)) : original);v.frame=frame;canvas.addSubview(v);return v}
    func button(_ name:String,size:CGFloat)->UIButton {let b=UIButton(type:.custom);b.setBackgroundImage(OriginalUIArt.image("components/button.png")?.resizableImage(withCapInsets:UIEdgeInsets(top:7,left:8,bottom:7,right:8)),for:.normal);b.setAttributedTitle(NSAttributedString(string:name,attributes:[.font:OriginalFont.heavy(size),.foregroundColor:UIColor.white,.strokeColor:UIColor.black,.strokeWidth:-5,.kern:0.7]),for:.normal);return b}
    func refresh(_ p:HeroCareer,faction:Int,kind:HeroClass){level.write(String(p.level),size:15);xp.progress=Float(p.levelFraction);heroName.write("\(faction==1 ? "Royal" : "National") \(kind.rawValue)",size:12);for (i,n) in [p.heroPoints,p.valor,p.funds].enumerated(){balances[i].write(String(n),size:17)};for (i,b) in tabs.enumerated(){b.setTitleColor(["Home","My Stuff","Store","Friends","Options"][i]==title ? .yellow : .white,for:.normal);let old=b.attributedTitle(for:.normal);if let old=old{let a=NSMutableAttributedString(attributedString:old);a.addAttribute(.foregroundColor,value:["Home","My Stuff","Store","Friends","Options"][i]==title ? UIColor.yellow : UIColor.white,range:NSRange(location:0,length:a.length));b.setAttributedTitle(a,for:.normal)}};for (i,b) in sections.enumerated(){let old=b.attributedTitle(for:.normal);if let old=old{let a=NSMutableAttributedString(attributedString:old);a.addAttribute(.foregroundColor,value:["Appearance","Weapons","Abilities","Emotes","Widgets","Missions"][i]==section ? UIColor.yellow : UIColor.white,range:NSRange(location:0,length:a.length));b.setAttributedTitle(a,for:.normal)}}}
    override func layoutSubviews(){super.layoutSubviews();let b=bounds.inset(by:safeAreaInsets),scale=min((b.width-8)/800,(b.height-8)/600);canvas.transform=CGAffineTransform(scaleX:scale,y:scale);canvas.center=CGPoint(x:b.midX,y:b.midY)}
}

final class OriginalXPBar:UIView {
    let empty=UIImageView(image:OriginalUIArt.image("components/barxpemptyshorteor.png")),full=UIImageView(image:OriginalUIArt.image("components/barxpfullshorteor.png")),mask=CALayer()
    var progress:Float=0 {didSet{setNeedsLayout()}}
    override init(frame:CGRect){super.init(frame:frame);addSubview(empty);addSubview(full);mask.backgroundColor=UIColor.white.cgColor;full.layer.mask=mask}
    convenience init(){self.init(frame:.zero)}
    required init?(coder:NSCoder){fatalError()}
    override func layoutSubviews(){super.layoutSubviews();empty.frame=bounds;full.frame=bounds;CATransaction.begin();CATransaction.setDisableActions(true);mask.frame=CGRect(x:0,y:0,width:bounds.width*CGFloat(max(0,min(1,progress))),height:bounds.height);CATransaction.commit()}
}
