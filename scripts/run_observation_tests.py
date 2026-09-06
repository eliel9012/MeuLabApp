#!/usr/bin/env python3
"""Build and run hosted simulator tests without changing the production Xcode project."""
import argparse
import csv
import json
import plistlib
import re
import subprocess
from xml.sax.saxutils import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def structural_checks():
    state = (ROOT / 'MeuLabApp/ViewModels/AppState.swift').read_text()
    model = state.split('\nstruct LabIntelligenceSnapshot', 1)[0]
    assert '@Published' not in model
    assert '@Observable\n@MainActor\nclass AppState {' in model
    members = re.findall(r'^    (@ObservationIgnored )?(?:private(?:\(set\))? )?(?:var|let) (\w+)', model, re.M)
    with (ROOT / 'docs/appstate-observation-audit.csv').open() as handle:
        audit = {row['property']: row for row in csv.DictReader(handle)}
    assert {name for _, name in members} == set(audit)
    for ignored, name in members:
        assert bool(ignored) == (audit[name]['observation'] == 'ignored'), name
        assert ignored or audit[name]['view_references_at_baseline'], name
    sources = '\n'.join(p.read_text() for p in (ROOT / 'MeuLabApp').rglob('*.swift'))
    assert not re.search(r'@(?:EnvironmentObject|ObservedObject|StateObject)[^\n]*\bAppState\b', sources)
    assert '.environmentObject(AppState())' not in sources
    assert '.environmentObject(appState)' not in sources
    assert sources.count('$appState.isOpenSkyEnabled') == 6
    print(f'Structural checks passed: {len(members)} audited properties, 6 OpenSky bindings.', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', required=True, help='e.g. platform=iOS Simulator,id=UUID')
    parser.add_argument('--work-dir', required=True, type=Path, help='Scratch output directory outside source files')
    args = parser.parse_args()
    work = args.work_dir.resolve()
    work.mkdir(parents=True, exist_ok=True)
    structural_checks()

    def run(command, name):
        with (work / f'{name}.log').open('w') as output:
            result = subprocess.run(command, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT)
        if result.returncode:
            print((work / f'{name}.log').read_text()[-10000:])
            raise SystemExit(result.returncode)

    original = json.loads(subprocess.check_output([
        'plutil', '-convert', 'json', '-o', '-', str(ROOT / 'MeuLabApp.xcodeproj/project.pbxproj')]))
    objects = original['objects']
    project = objects[original['rootObject']]
    project['projectDirPath'] = str(ROOT)
    app_target = next(key for key, value in objects.items()
                      if value.get('isa') == 'PBXNativeTarget' and value.get('name') == 'MeuLabApp')

    def add(identifier, isa, **fields):
        objects[identifier] = {'isa': isa, **fields}
        return identifier

    file_ids = []
    build_ids = []
    for index, source in enumerate(sorted((ROOT / 'Tests').glob('*.swift'))):
        file_id = add(f'FILE{index}', 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=str(source), sourceTree='<absolute>')
        file_ids.append(file_id)
        build_ids.append(add(f'BUILD{index}', 'PBXBuildFile', fileRef=file_id))
    product = add('PRODUCT', 'PBXFileReference', explicitFileType='wrapper.cfbundle', path='ObservationTests.xctest', sourceTree='BUILT_PRODUCTS_DIR')
    products = add('PRODUCTS', 'PBXGroup', children=[product], name='Products', sourceTree='<group>')
    objects[project['mainGroup']]['children'].extend(file_ids + [products])
    sources = add('SOURCES', 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=build_ids, runOnlyForDeploymentPostprocessing=0)
    frameworks = add('FRAMEWORKS', 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
    config = add('CONFIG', 'XCBuildConfiguration', name='Debug', buildSettings={
        'SDKROOT': 'iphonesimulator', 'SUPPORTED_PLATFORMS': 'iphonesimulator',
        'IPHONEOS_DEPLOYMENT_TARGET': '26.0', 'SWIFT_VERSION': '5.0',
        'PRODUCT_NAME': 'ObservationTests', 'PRODUCT_BUNDLE_IDENTIFIER': 'fun.meulab.observationtests',
        'GENERATE_INFOPLIST_FILE': 'YES', 'CODE_SIGNING_ALLOWED': 'NO',
        'TEST_HOST': '$(BUILT_PRODUCTS_DIR)/MeuLabApp.app/MeuLabApp', 'BUNDLE_LOADER': '$(TEST_HOST)',
        'SWIFT_INCLUDE_PATHS': ['$(BUILT_PRODUCTS_DIR)'],
        'LD_RUNPATH_SEARCH_PATHS': ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks'],
    })
    configs = add('CONFIGS', 'XCConfigurationList', buildConfigurations=[config], defaultConfigurationIsVisible=0, defaultConfigurationName='Debug')
    dependency = add('DEPENDENCY', 'PBXTargetDependency', target=app_target)
    target = add('TARGET', 'PBXNativeTarget', name='ObservationTests', productName='ObservationTests', productType='com.apple.product-type.bundle.unit-test', productReference=product, buildConfigurationList=configs, buildPhases=[sources, frameworks], buildRules=[], dependencies=[dependency])
    project['targets'].append(target)
    project.setdefault('attributes', {}).setdefault('TargetAttributes', {})[target] = {'TestTargetID': app_target}

    project_path = work / 'ObservationTests.xcodeproj'
    project_path.mkdir(exist_ok=True)
    (project_path / 'project.pbxproj').write_bytes(plistlib.dumps(original))
    schemes = project_path / 'xcshareddata/xcschemes'
    schemes.mkdir(parents=True, exist_ok=True)
    container = escape('container:' + str(project_path), {'"': '&quot;'})
    reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="TARGET" BuildableName="ObservationTests.xctest" BlueprintName="ObservationTests" ReferencedContainer="{container}"/>'
    (schemes / 'ObservationTests.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3">
<BuildAction buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{reference}</TestableReference></Testables></TestAction>
</Scheme>''')
    run(['xcodebuild', '-project', str(project_path), '-scheme', 'ObservationTests', '-destination', args.destination, '-derivedDataPath', str(work / 'DerivedData'), 'test'], 'tests')
    print('Hosted simulator tests passed. Logs:', work, flush=True)


if __name__ == '__main__':
    main()
