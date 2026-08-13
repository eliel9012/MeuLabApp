#!/usr/bin/env python3
"""Final integration: Add all secrets files to build phases"""

import re
from pathlib import Path

def main():
    pbxproj_path = Path("MeuLabApp.xcodeproj/project.pbxproj")
    content = pbxproj_path.read_text()
    original = content
    
    print("🔐 Final Setup: Complete File Integration")
    print("=" * 70)
    
    # IDs we've added
    secrets_swift_build = "A1B2C3D4E5F6A7B8C9D0E1F3"
    watchsecrets_build = "3909786604B94EE5BE1AD25A"
    
    print("\n1️⃣  Adding Secrets.swift to iOS Sources build phase...")
    
    # Find and modify first PBXSourcesBuildPhase
    pattern = r'(isa = PBXSourcesBuildPhase;[\s\S]*?files = \()([\s\S]*?)(\);)'
    match = re.search(pattern, content)
    
    if match:
        before = match.group(1)
        files_content = match.group(2)  
        after = match.group(3)
        
        # Add Secrets.swift if not there
        if secrets_swift_build not in files_content:
            # Add after the last file entry
            new_line = f"\n\t\t\t\t{secrets_swift_build} /* Secrets.swift in Sources */,"
            new_files = files_content + new_line
            # Reconstruct
            full_match = match.group(0)
            replacement = before + new_files + after
            content = content.replace(full_match, replacement)
            print("   ✅ Added Secrets.swift to iOS Sources phase")
        else:
            print("   ✅ Secrets.swift already in iOS Sources phase")
    else:
        print("   ⚠️  Could not find iOS build phase")
    
    print("\n2️⃣  Verifying WatchSecrets.swift...")
    if watchsecrets_build in content:
        print("   ✅ WatchSecrets.swift BuildFile found")
    else:
        print("   ⚠️  WatchSecrets.swift not found")
    
    # Save changes
    if content != original:
        backup = pbxproj_path.with_suffix('.pbxproj.final_backup')
        backup.write_text(original)
        pbxproj_path.write_text(content)
        print(f"\n💾 Changes saved!")
        print(f"   Backup: {backup.name}")
    else:
        print("\n✅ No changes needed")
    
    print("\n" + "=" * 70)
    print("✅ Complete! Build now:")
    print("   xcodebuild clean -scheme MeuLabApp")
    print("   xcodebuild build -scheme MeuLabApp")
    return 0

if __name__ == "__main__":
    exit(main())
