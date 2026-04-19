#!/usr/bin/env python3
"""
Add both Secrets.swift and WatchSecrets.swift to their respective build phases
"""

import re
from pathlib import Path

def fix_build_phases():
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    
    content = pbxproj_path.read_text()
    original = content
    
    print("🔧 Fixing Build Phases...")
    print("=" * 60)
    
    # IDs we know exist:
    # Secrets.swift (iOS): Not yet in pbxproj, need to add
    # WatchSecrets.swift (watchOS): E181A3D935D7491286930152 (fileRef), 3909786604B94EE5BE1AD25A (buildFile)
    
    # Search for Secrets.swift in pbxproj
    secrets_swift_exists = "Secrets.swift" in content
    
    if not secrets_swift_exists:
        print("❌ Secrets.swift not found in project.pbxproj")
        print("\nℹ️  Secrets.swift needs to be added to MeuLabApp target")
        print("   Please add manually via Xcode or run xcode_editor.py first")
        return False
    
    print("✅ Secrets.swift found in project")
    
    # Find if Secrets.swift is in iOS Sources build phase
    # Look for entry in any of the iOS source build phases
    
    #Find where Secrets.swift references are
    secrets_lines = [line for line in content.split('\n') if 'Secrets.swift' in line]
    print(f"Found {len(secrets_lines)} references to Secrets.swift:")
    for line in secrets_lines[:5]:
        print(f"   {line.strip()[:80]}")
    
    # Check if in buildFile section
    has_buildfile = "/* Secrets.swift in Sources */" in content
    if has_buildfile:
        print("✅ Secrets.swift has BuildFile entry")
    else:
        print("❌ Secrets.swift missing BuildFile entry")
    
    # Check if in iOS source build phase files array
    # Pattern: files = ( ... ); (first one should be iOS app, second is watchOS)
    
    sources_phases = list(re.finditer(
        r'(isa = PBXSourcesBuildPhase;.*?files = \((.*?)\);)',
        content,
        re.DOTALL
    ))
    
    print(f"\n✅ Found {len(sources_phases)} PBXSourcesBuildPhase sections")
    
    # We need to add Secrets.swift ref to the first one (iOS app)
    # And WatchSecrets.swift ref should already be in watchOS one (second)
    
    if len(sources_phases) > 0:
        first_phase_content = sources_phases[0].group(2)
        if "Secrets.swift" not in first_phase_content:
            print("\n⚠️  Secrets.swift not in first (iOS) Sources build phase")
            print("   This needs manual addition in Xcode")
        else:
            print("\n✅ Secrets.swift is in iOS Sources phase")
    
    if len(sources_phases) > 1:
        second_phase_content = sources_phases[1].group(2)
        if "WatchSecrets.swift" in second_phase_content:
            print("✅ WatchSecrets.swift is in watchOS Sources phase")
        else:
            print("⚠️  WatchSecrets.swift not in watchOS Sources phase")
    
    return content != original


if __name__ == "__main__":
    print("🔐 Verify Build Phase Status")
    print()
    fix_build_phases()
    print("\n" + "=" * 60)
    print("📋 Status Summary:")
    print("   If any files are missing from build phases,")
    print("   they must be added manually in Xcode.\n")
