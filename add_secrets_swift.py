#!/usr/bin/env python3
"""
Add Secrets.swift to iOS target (MeuLabApp)
"""

import re
import uuid
from pathlib import Path

def add_secrets_swift_to_ios():
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    content = pbxproj_path.read_text()
    
    print("🔐 Adding Secrets.swift to iOS Target")
    print("=" * 60)
    
    # Generate IDs
    Secrets_swift_fileref_id = "F7A0C1B2D3E4F5A6B7C8D9E0" # Secrets.swift FileReference
    secrets_swift_buildi_id = "A1B2C3D4E5F6A7B8C9D0E1F2"  # Secrets.swift BuildFile
    
    # Check if already there
    if Secrets_swift_fileref_id in content:
        print("✅ Secrets.swift already added")
        return False
    
    # Check if file exists on disk
    secrets_filepath = project_root / "MeuLabApp/Core/Secrets.swift"
    if not secrets_filepath.exists():
        print(f"❌ File not found: {secrets_filepath}")
        return False
    
    print(f"✅ File exists: Secrets.swift")
    
    # Add to PBXFileReference section
    file_ref_entry = f'\n\t\t\t{Secrets_swift_fileref_id} /* Secrets.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "MeuLabApp/Core/Secrets.swift"; sourceTree = SOURCE_ROOT; }};'
    
    # Find PBXFileReference section end
    pbx_fileref_end = content.find('/* End PBXFileReference section */')
    if pbx_fileref_end == -1:
        print("❌ PBXFileReference section not found")
        return False
    
    content = content[:pbx_fileref_end] + file_ref_entry + '\n\t\t' + content[pbx_fileref_end:]
    print("✅ Added Secrets.swift FileReference")
    
    # Add to PBXBuildFile section
    build_file_entry = f'\n\t\t\t{secrets_swift_buildi_id} /* Secrets.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {Secrets_swift_fileref_id} /* Secrets.swift */; }};'
    
    pbx_buildfile_end = content.find('/* End PBXBuildFile section */')
    if pbx_buildfile_end == -1:
        print("❌ PBXBuildFile section not found")
        return False
    
    content = content[:pbx_buildfile_end] + build_file_entry + '\n\t\t' + content[pbx_buildfile_end:]
    print("✅ Added Secrets.swift BuildFile")
    
    # Save
    backup = pbxproj_path.with_suffix('.pbxproj.backup4')
    backup.write_text(pbxproj_path.read_text())
    pbxproj_path.write_text(content)
    
    print(f"\n💾 Backup: {backup.name}")
    print(f"✅ Saved: project.pbxproj")
    
    return True


if __name__ == "__main__":
    add_secrets_swift_to_ios()
    print("\n" + "=" * 60)
    print("✅ Step 1 of 2 complete!")
    print("\nNow run: python3 add_secrets_to_ios_build_phase.py")
