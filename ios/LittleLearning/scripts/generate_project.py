"""Generate the dependency-free iOS Xcode project; never writes signing credentials."""
from pathlib import Path
import json
import re

root=Path(__file__).resolve().parents[1]
# Preserve a team selected in Xcode when regenerating source references.
existing = root/'LittleLearning.xcodeproj'/'project.pbxproj'
team_match = re.search(r'DEVELOPMENT_TEAM\s*=\s*"?([A-Z0-9]+)"?\s*;', existing.read_text()) if existing.exists() else None
def ident(n):return f'{n:024X}'
def quote(v):return json.dumps(str(v))
objects=[]
def obj(n,body):objects.append(f'\t\t{ident(n)} = {{ {body} }};')
sources=sorted((root/'Sources').glob('*.swift'))+sorted((root/'Core').glob('*.swift'))
builds=[];refs=[]
for i,p in enumerate(sources):
    ref=100+i;build=200+i
    path=p.relative_to(root)
    obj(ref,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quote(path)}; sourceTree = "<group>";')
    obj(build,f'isa = PBXBuildFile; fileRef = {ident(ref)};')
    refs.append(ident(ref));builds.append(ident(build))
obj(20,'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = LittleLearning.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj(21,'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";')
obj(22,f'isa = PBXBuildFile; fileRef = {ident(21)};')
obj(24,'isa = PBXFileReference; lastKnownFileType = folder; path = Sources/WebGames; sourceTree = "<group>";')
obj(25,f'isa = PBXBuildFile; fileRef = {ident(24)};')
obj(23,'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>";')
obj(1,f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {ident(4)} = {{ CreatedOnToolsVersion = 16.0; }}; }}; }}; buildConfigurationList = {ident(5)}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "zh-Hans"; hasScannedForEncodings = 0; knownRegions = ("zh-Hans", en, Base); mainGroup = {ident(2)}; productRefGroup = {ident(3)}; projectDirPath = ""; projectRoot = ""; targets = ({ident(4)});')
obj(2,f'isa = PBXGroup; children = ({", ".join(refs+[ident(21),ident(23),ident(24),ident(3)])}); sourceTree = "<group>";')
obj(3,f'isa = PBXGroup; children = ({ident(20)}); name = Products; sourceTree = "<group>";')
obj(4,f'isa = PBXNativeTarget; buildConfigurationList = {ident(6)}; buildPhases = ({ident(7)}, {ident(8)}, {ident(9)}); buildRules = (); dependencies = (); name = LittleLearning; productName = LittleLearning; productReference = {ident(20)}; productType = "com.apple.product-type.application";')
obj(5,f'isa = XCConfigurationList; buildConfigurations = ({ident(10)}, {ident(11)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj(6,f'isa = XCConfigurationList; buildConfigurations = ({ident(12)}, {ident(13)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj(7,f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
obj(8,'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj(9,f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({ident(22)}, {ident(25)}); runOnlyForDeploymentPostprocessing = 0;')
for n,name in [(10,'Debug'),(11,'Release')]:
    settings={'CLANG_ENABLE_MODULES':'YES','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'}
    if name=='Debug':settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
    obj(n,'isa = XCBuildConfiguration; buildSettings = { '+ ' '.join(f'{k} = {quote(v)};' for k,v in settings.items())+' }; name = '+name+';')
for n,name in [(12,'Debug'),(13,'Release')]:
    settings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.example.littlelearning','INFOPLIST_FILE':'Info.plist','GENERATE_INFOPLIST_FILE':'NO','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','CODE_SIGN_STYLE':'Automatic','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ENABLE_PREVIEWS':'YES','SWIFT_EMIT_LOC_STRINGS':'YES','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'}
    if team_match: settings['DEVELOPMENT_TEAM'] = team_match.group(1)
    obj(n,'isa = XCBuildConfiguration; buildSettings = { '+' '.join(f'{k} = {quote(v)};' for k,v in settings.items())+' }; name = '+name+';')
project='// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+ident(1)+'; }\n'
(root/'LittleLearning.xcodeproj'/'project.pbxproj').write_text(project)
print('Generated project for',len(sources),'Swift files.')
