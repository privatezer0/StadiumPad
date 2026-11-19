from pathlib import Path
import hashlib,json,os
root=Path(__file__).resolve().parent.parent
resources=root/'iPad/Resources';resources.mkdir(exist_ok=True)
if not (resources/'ModelNames.json').exists():(resources/'ModelNames.json').write_text('{}')
if not (resources/'CommandCatalog.json').exists():(resources/'CommandCatalog.json').write_text('{}')
if not (resources/'ParameterCatalog.json').exists():(resources/'ParameterCatalog.json').write_text('{}')
objects={}
def obj(key,body):
 i=hashlib.sha256(key.encode()).hexdigest()[:24].upper();objects[i]=body;return i
def q(x):return json.dumps(str(x))
files=[];sources=[];resources=[]
for path in sorted((root/'iPad/Sources').glob('*.swift')):
 rel=path.relative_to(root).as_posix();ref=obj(rel,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = "<group>";');files.append(ref);sources.append(obj('build:'+rel,f'isa = PBXBuildFile; fileRef = {ref};'))
for path in sorted((root/'iPad/Resources').glob('*.json')):
 rel=path.relative_to(root).as_posix();ref=obj(rel,f'isa = PBXFileReference; lastKnownFileType = text.json; path = {q(rel)}; sourceTree = "<group>";');files.append(ref);resources.append(obj('build:'+rel,f'isa = PBXBuildFile; fileRef = {ref};'))
assets=root/'iPad/Resources/Assets.xcassets'
if assets.exists():
 rel=assets.relative_to(root).as_posix();ref=obj(rel,f'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {q(rel)}; sourceTree = "<group>";');files.append(ref);resources.append(obj('build:'+rel,f'isa = PBXBuildFile; fileRef = {ref};'))
product=obj('app','isa = PBXFileReference; explicitFileType = wrapper.application; path = "StadiumPad.app"; sourceTree = BUILT_PRODUCTS_DIR;')
group=obj('group',f'isa = PBXGroup; children = ({",".join(files+[product])},); sourceTree = "<group>";')
sp=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(sources)},); runOnlyForDeploymentPostprocessing = 0;')
rp=obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resources)},); runOnlyForDeploymentPostprocessing = 0;')
package=obj('package','isa = XCLocalSwiftPackageReference; relativePath = .;')
products=[];frameworks=[]
for name in ['StadiumProtocol','StadiumNetwork']:
 dep=obj('dep:'+name,f'isa = XCSwiftPackageProductDependency; package = {package}; productName = {name};');products.append(dep)
 frameworks.append(obj('framework:'+name,f'isa = PBXBuildFile; productRef = {dep};'))
fp=obj('frameworks' ,f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({",".join(frameworks)},); runOnlyForDeploymentPostprocessing = 0;')
base=dict(ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',ALWAYS_SEARCH_USER_PATHS='NO',SDKROOT='iphoneos',IPHONEOS_DEPLOYMENT_TARGET='18.0',TARGETED_DEVICE_FAMILY='2',SUPPORTED_PLATFORMS='iphoneos iphonesimulator',SWIFT_VERSION='5.0',ENABLE_USER_SCRIPT_SANDBOXING='NO',PRODUCT_BUNDLE_IDENTIFIER=os.environ.get('STADIUMPAD_BUNDLE_ID','com.example.stadiumpad'),PRODUCT_NAME='StadiumPad',PRODUCT_MODULE_NAME='StadiumPad',INFOPLIST_FILE='iPad/Info.plist',GENERATE_INFOPLIST_FILE='NO',DEVELOPMENT_TEAM=os.environ.get('STADIUMPAD_DEVELOPMENT_TEAM',''),CODE_SIGN_IDENTITY='Apple Development',CODE_SIGN_STYLE='Automatic',ENABLE_PREVIEWS='YES')
def config(prefix):
 a=[]
 for name in ['Debug','Release']:
  settings=dict(base,SWIFT_OPTIMIZATION_LEVEL='-Onone' if name=='Debug' else '-O',SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' if name=='Debug' else '');body=' '.join(f'{k} = {q(v)};' for k,v in settings.items());a.append(obj(prefix+name,f'isa = XCBuildConfiguration; buildSettings = {{{body}}}; name = {name};'))
 return obj(prefix+'list',f'isa = XCConfigurationList; buildConfigurations = ({",".join(a)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
pc=config('project');tc=config('target')
target=obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {tc}; buildPhases = ({sp},{fp},{rp},); buildRules = (); dependencies = (); name = StadiumPad; packageProductDependencies = ({",".join(products)},); productName = "StadiumPad"; productReference = {product}; productType = "com.apple.product-type.application";')
project=obj('project',f'isa = PBXProject; attributes = {{LastUpgradeCheck = 1600;}}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {group}; packageReferences = ({package},); projectDirPath = ""; projectRoot = ""; targets = ({target},);')
destination=root/'StadiumPad.xcodeproj';destination.mkdir(exist_ok=True)
(destination/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(f'{i} = {{{v}}};\n' for i,v in objects.items())+f'}}; rootObject = {project}; }}\n')
