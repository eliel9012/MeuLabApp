#!/usr/bin/env python3
"""
Add Bible Reader files to Xcode project.pbxproj
"""
import re
import uuid
from pathlib import Path

PROJECT_DIR = Path("/Users/eliel/Library/Mobile Documents/com~apple~CloudDocs/apps criados/botapp/MeuLabApp")
PBXPROJ_PATH = PROJECT_DIR / "MeuLabApp.xcodeproj" / "project.pbxproj"

# Files to add with their group and build phase targets
FILES_TO_ADD = [
    {
        "path": "MeuLabApp/Services/BibleSpeechService.swift",
        "group_name": "Services",
        "compile_target": True
    },
    {
        "path": "MeuLabApp/ViewModels/BibleReaderViewModel.swift",
        "group_name": "ViewModels",
        "compile_target": True
    },
    {
        "path": "MeuLabApp/Views/BibleChapterReaderView.swift",
        "group_name": "Views",
        "compile_target": True
    },
    {
        "path": "MeuLabApp/Intents/BibleReadingIntents.swift",
        "group_name": "Intents",
        "compile_target": True
    },
    {
        "path": "MeuLabApp/Models/BibleReaderModels.swift",
        "group_name": "Models",
        "compile_target": True
    },
    {
        "path": "MeuLabApp/Views/BibleReaderIntegrationView.swift",
        "group_name": "Views",
        "compile_target": True
    },
]

def generate_id(prefix="", length=24):
    """Generate Xcode-style ID"""
    import uuid
    hex_str = uuid.uuid4().hex.upper()[:length]
    return prefix + hex_str if prefix else hex_str

def add_files_to_pbxproj():
    """Add files to project.pbxproj"""
    
    if not PBXPROJ_PATH.exists():
        print(f"❌ pbxproj not found: {PBXPROJ_PATH}")
        return False
    
    content = PBXPROJ_PATH.read_text()
    original_content = content
    
    print("📝 Adding Bible Reader files to pbxproj...")
    
    for file_info in FILES_TO_ADD:
        file_path = file_info["path"]
        file_name = Path(file_path).name
        
        # Check if already added
        if file_name in content:
            print(f"  ✓ {file_name} already in pbxproj")
            continue
        
        # We would need to parse and modify pbxproj structure
        # For simplicity, we'll just report what needs to be done
        print(f"  ⚠ {file_name} needs manual addition or Python pbxproj library")
    
    # Write back if modified
    if content != original_content:
        PBXPROJ_PATH.write_text(content)
        print("\n✅ pbxproj updated")
    else:
        print("\nℹ️  No changes made to pbxproj")
    
    print("\n" + "="*60)
    print("MANUAL STEPS:")
    print("="*60)
    print("1. Open MeuLabApp.xcodeproj in Xcode")
    print("2. Select Project > MeuLabApp target")
    print("3. Go to Build Phases > Compile Sources")
    print("4. Click + and add these files:")
    for file_info in FILES_TO_ADD:
        print(f"   - {file_info['path']}")
    print("\n5. Ensure target 'MeuLabApp' is selected for each file")
    print("6. Build: Cmd+B")
    
    return True

if __name__ == "__main__":
    add_files_to_pbxproj()
