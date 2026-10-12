#!/usr/bin/env python3
"""Generate a dependency-free Xcode project. Run from the repository root."""
from pathlib import Path
import plistlib
root = Path(__file__).resolve().parent.parent
info = {
 'CFBundleDevelopmentRegion':'en', 'CFBundleExecutable':'$(EXECUTABLE_NAME)',
 'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion':'6.0',
 'CFBundleName':'PocketFront', 'CFBundlePackageType':'APPL', 'CFBundleShortVersionString':'0.1.0',
 'CFBundleVersion':'1', 'LSRequiresIPhoneOS':True,
 'UISupportedInterfaceOrientations':['UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],
 'UILaunchScreen':{}, 'UIRequiredDeviceCapabilities':['arm64','metal'], 'UIRequiresFullScreen':True,
}
(root/'App/Info.plist').write_bytes(plistlib.dumps(info))
project = '''// !$*UTF8*$!
{
 archiveVersion = 1;
 classes = {};
 objectVersion = 56;
 objects = {
 A00000000000000000000001 = {isa = PBXProject; buildConfigurationList = A00000000000000000000002; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = A00000000000000000000003; productRefGroup = A00000000000000000000004; projectDirPath = ""; projectRoot = ""; targets = (A00000000000000000000005); };
 A00000000000000000000002 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000006, A00000000000000000000007); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
 A00000000000000000000003 = {isa = PBXGroup; children = (A00000000000000000000008,A00000000000000000000009,A00000000000000000000019,A00000000000000000000021,A00000000000000000000004); sourceTree = "<group>"; };
 A00000000000000000000004 = {isa = PBXGroup; children = (A00000000000000000000010); name = Products; sourceTree = "<group>"; };
 A00000000000000000000005 = {isa = PBXNativeTarget; buildConfigurationList = A00000000000000000000011; buildPhases = (A00000000000000000000012,A00000000000000000000013,A00000000000000000000014); buildRules = (); dependencies = (); name = PocketFront; productName = PocketFront; productReference = A00000000000000000000010; productType = "com.apple.product-type.application"; };
 A00000000000000000000006 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 15.0; CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "-Onone";}; name = Debug; };
 A00000000000000000000007 = {isa = XCBuildConfiguration; buildSettings = {SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 15.0; CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; SWIFT_OPTIMIZATION_LEVEL = "-O";}; name = Release; };
 A00000000000000000000008 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App/App.swift; sourceTree = "<group>"; };
 A00000000000000000000009 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App/Game.swift; sourceTree = "<group>"; };
 A00000000000000000000010 = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = PocketFront.app; sourceTree = BUILT_PRODUCTS_DIR; };
 A00000000000000000000011 = {isa = XCConfigurationList; buildConfigurations = (A00000000000000000000015,A00000000000000000000016); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };
 A00000000000000000000012 = {isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (A00000000000000000000017,A00000000000000000000018,A00000000000000000000022); runOnlyForDeploymentPostprocessing = 0; };
 A00000000000000000000013 = {isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };
 A00000000000000000000014 = {isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (A00000000000000000000020); runOnlyForDeploymentPostprocessing = 0; };
 A00000000000000000000015 = {isa = XCBuildConfiguration; buildSettings = {PRODUCT_BUNDLE_IDENTIFIER = com.pocketfront.game; PRODUCT_NAME = "$(TARGET_NAME)"; INFOPLIST_FILE = App/Info.plist; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; SWIFT_VERSION = 5.0; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; }; name = Debug; };
 A00000000000000000000016 = {isa = XCBuildConfiguration; buildSettings = {PRODUCT_BUNDLE_IDENTIFIER = com.pocketfront.game; PRODUCT_NAME = "$(TARGET_NAME)"; INFOPLIST_FILE = App/Info.plist; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; SWIFT_VERSION = 5.0; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks"; }; name = Release; };
 A00000000000000000000017 = {isa = PBXBuildFile; fileRef = A00000000000000000000008; };
 A00000000000000000000018 = {isa = PBXBuildFile; fileRef = A00000000000000000000009; };
 A00000000000000000000019 = {isa = PBXFileReference; lastKnownFileType = folder; path = Assets; sourceTree = "<group>"; };
 A00000000000000000000020 = {isa = PBXBuildFile; fileRef = A00000000000000000000019; };
 A00000000000000000000021 = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App/Animation.swift; sourceTree = "<group>"; };
 A00000000000000000000022 = {isa = PBXBuildFile; fileRef = A00000000000000000000021; };
 };
 rootObject = A00000000000000000000001;
}
'''
(root/'PocketFront.xcodeproj/project.pbxproj').write_text(project)
scheme='''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000005" BuildableName="PocketFront.app" BlueprintName="PocketFront" ReferencedContainer="container:PocketFront.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="A00000000000000000000005" BuildableName="PocketFront.app" BlueprintName="PocketFront" ReferencedContainer="container:PocketFront.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(root/'PocketFront.xcodeproj/xcshareddata/xcschemes/PocketFront.xcscheme').write_text(scheme)
print('Generated Xcode project and Info.plist')
