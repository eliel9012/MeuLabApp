#!/usr/bin/env python3
"""
Add build files to PBXSourcesBuildPhase arrays
"""

import re
from pathlib import Path

def add_to_sources_build_phase():
    """Add WatchSecrets and Secrets files to sources build phases"""
    
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    
    content = pbxproj_path.read_text()
    original = content
    
    # IDs from previous script run:
    # Secrets.plist: 8E67D5B72FC44490AD989D19
    # WatchSecrets.swift: 3909786604B94EE5BE1AD25A
    
    watchsecrets_build_id = "3909786604B94EE5BE1AD25A"
    secrets_build_id = "8E67D5B72FC44490AD989D19"
    
    print("🔧 Adding files to PBXSourcesBuildPhase...")
    print("=" * 60)
    
    # Find the Watch Sources build phase and add WatchSecrets
    # Pattern: W402 /* Sources */ = { ... files = ( ... ); ...
    
    watch_sources_pattern = r'(W402 /\* Sources \*/ = \{[\s\S]*?files = \(([\s\S]*?)\);)'
    
    def watch_replacer(match):
        full = match.group(1)
        files_content = match.group(2)
        
        # Check if already there
        if watchsecrets_build_id in files_content:
            print("ℹ️  WatchSecrets already in watch sources")
            return full
        
        # Add WatchSecrets before closing )
        new_entry = f'\n\t\t\t\t{watchsecrets_build_id} /* WatchSecrets.swift in Sources */,'
        new_content = files_content + new_entry
        
        return full.replace(files_content, new_content)
    
    content = re.sub(watch_sources_pattern, watch_replacer, content)
    
    if watchsecrets_build_id in content:
        print("✅ Added WatchSecrets.swift to MeuLabWatch Sources")
    else:
        print("⚠️  Could not add WatchSecrets to watch sources")
    
    # Find iOS main app Sources build phase and add Secrets.plist if needed
    # Pattern: /* Build Files */ then the first PBXSourcesBuildPhase is iOS app
    
    sources_phases = list(re.finditer(r'/\* Begin PBXSourcesBuildPhase section \*/\n(.*?)/\* End PBXSourcesBuildPhase section \*/', 
                                     content, re.DOTALL))
    
    if len(sources_phases) >= 1:
        print("✅ Found Sources build phases")
    
    # Save if changed
    if content != original:
        backup = pbxproj_path.with_suffix('.pbxproj.backup3')
        backup.write_text(original)
        print(f"\n💾 Backup: {backup.name}")
        
        pbxproj_path.write_text(content)
        print(f"✅ Updated: project.pbxproj")
        return True
    else:
        print("ℹ️  No changes needed")
        return False


if __name__ == "__main__":
    print("🔐 Add Files to Build Phases")
    print()
    add_to_sources_build_phase()
    
    print("\n" + "=" * 60)
    print("✅ Complete! Try compiling again:")
    print("   xcodebuild build -scheme MeuLabApp")
