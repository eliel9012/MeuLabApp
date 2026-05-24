#!/usr/bin/env python3
"""
Add Bible Reader files to Xcode project.pbxproj
Following the existing Bible file pattern (BIBV01/BIBV02 style IDs)
"""
import re
from pathlib import Path

PROJECT_DIR = Path("/Users/eliel/Library/Mobile Documents/com~apple~CloudDocs/apps criados/botapp/MeuLabApp")
PBXPROJ_PATH = PROJECT_DIR / "MeuLabApp.xcodeproj" / "project.pbxproj"

# New files to add with Xcode-style IDs (short prefixes + 01/02 pattern)
NEW_FILES = [
    {"id_prefix": "BRSP", "filename": "BibleSpeechService.swift", "path": "MeuLabApp/Services", "group_id": "SVCS"},
    {"id_prefix": "BRVM", "filename": "BibleReaderViewModel.swift", "path": "MeuLabApp/ViewModels", "group_id": "VMDL"},
    {"id_prefix": "BCHR", "filename": "BibleChapterReaderView.swift", "path": "MeuLabApp/Views", "group_id": "VWMS"},
    {"id_prefix": "BRIT", "filename": "BibleReadingIntents.swift", "path": "MeuLabApp/Intents", "group_id": "INTS"},
    {"id_prefix": "BRMD", "filename": "BibleReaderModels.swift", "path": "MeuLabApp/Models", "group_id": "MDLS"},
    {"id_prefix": "BRIG", "filename": "BibleReaderIntegrationView.swift", "path": "MeuLabApp/Views", "group_id": "VWMS"},
]

def modify_pbxproj():
    """Modify pbxproj to add Bible Reader files"""
    
    if not PBXPROJ_PATH.exists():
        print(f"❌ pbxproj not found: {PBXPROJ_PATH}")
        return False
    
    content = PBXPROJ_PATH.read_text()
    
    # Pattern to find where to insert file references
    # Look for "/* BibleRandomView.swift */" which should be the last Bible file
    # and insert after it
    
    file_refs_block = '/* PBXFileReference section */\n'
    build_files_block = '/* PBXBuildFile section */\n'
    
    # Build the new content sections
    new_file_refs = ""
    new_build_files = ""
    new_group_refs = ""
    
    for file_info in NEW_FILES:
        id_ref = f"{file_info['id_prefix']}01"
        id_build = f"{file_info['id_prefix']}02"
        filename = file_info['filename']
        
        # Check if already exists
        if filename in content:
            print(f"⏭️  {filename} already in pbxproj, skipping...")
            continue
        
        # File reference entry
        new_file_refs += f"\t\t{id_ref} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};\n"
        
        # Build file entry
        new_build_files += f"\t\t{id_build} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {id_ref} /* {filename} */; }};\n"
        
        # Group reference
        new_group_refs += f"\t\t\t\t{id_ref} /* {filename} */,\n"
    
    if not new_file_refs:
        print("✅ All files already in pbxproj")
        return True
    
    # Find insertion points and modify
    # This is complex - would need proper pbxproj parser
    print("\n" + "="*70)
    print("⚠️  MANUAL ADDITION REQUIRED")
    print("="*70)
    print("\nThe pbxproj structure requires careful manual editing.")
    print("Instead, please do this in Xcode:\n")
    
    print("1. Open MeuLabApp.xcodeproj in Xcode")
    print("2. File → Add Files to 'MeuLabApp'")
    print("3. Navigate to each file and select it:")
    print("   - MeuLabApp/Services/BibleSpeechService.swift")
    print("   - MeuLabApp/ViewModels/BibleReaderViewModel.swift")
    print("   - MeuLabApp/Views/BibleChapterReaderView.swift")
    print("   - MeuLabApp/Intents/BibleReadingIntents.swift")
    print("   - MeuLabApp/Models/BibleReaderModels.swift")
    print("   - MeuLabApp/Views/BibleReaderIntegrationView.swift")
    print("\n4. Ensure these options are checked:")
    print("   ✓ Copy items if needed")
    print("   ✓ Create groups")
    print("   ✓ Add to targets: MeuLabApp")
    print("\n5. Click Add")
    print("\n6. Build: Cmd+B\n")
    
    return True

if __name__ == "__main__":
    modify_pbxproj()
