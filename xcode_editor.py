#!/usr/bin/env python3
"""
Add Secrets files to MeuLabApp.xcodeproj targets
Safely modifies project.pbxproj following exact Xcode patterns
"""

import re
import uuid
from pathlib import Path
from typing import Tuple, Optional

class XcodeProjEditor:
    def __init__(self, pbxproj_path: str):
        self.pbxproj = Path(pbxproj_path)
        self.content = self.pbxproj.read_text()
        self.original = self.content
        
    def gen_id(self) -> str:
        """Generate Xcode-style 24-char hex ID"""
        return uuid.uuid4().hex[:24].upper()
    
    def find_section_bounds(self, section_name: str) -> Optional[Tuple[int, int]]:
        """Find start and end positions of a section"""
        start_marker = f'/* Begin {section_name} section */'
        end_marker = f'/* End {section_name} section */'
        
        start_idx = self.content.find(start_marker)
        end_idx = self.content.find(end_marker)
        
        if start_idx == -1 or end_idx == -1:
            return None
        
        return (start_idx + len(start_marker), end_idx)
    
    def add_file_reference(self, file_id: str, filename: str, path: str, 
                          file_type: str = 'sourcecode.swift') -> bool:
        """Add entry to PBXFileReference section"""
        section = self.find_section_bounds('PBXFileReference')
        if not section:
            print(f"❌ PBXFileReference section not found")
            return False
        
        # Check if already exists
        if f'/* {filename} */' in self.content:
            print(f"ℹ️  {filename} already exists")
            return True
        
        start, end = section
        
        # Create new entry (matching format exactly)
        entry = f'\n\t\t\t{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {path}; sourceTree = "<group>"; }};'
        
        # Insert before end marker
        self.content = self.content[:end] + entry + self.content[end:]
        print(f"✅ Added PBXFileReference: {file_id} - {filename}")
        return True
    
    def add_build_file(self, build_id: str, file_id: str, filename: str) -> bool:
        """Add entry to PBXBuildFile section"""
        section = self.find_section_bounds('PBXBuildFile')
        if not section:
            print(f"❌ PBXBuildFile section not found")
            return False
        
        start, end = section
        
        # Create entry
        entry = f'\n\t\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {filename} */; }};'
        
        self.content = self.content[:end] + entry + self.content[end:]
        print(f"✅ Added PBXBuildFile: {build_id}")
        return True
    
    def add_to_sources_build_phase(self, watch_target: bool = False) -> bool:
        """Add file to Sources Build Phase of target"""
        # Find PBXSourcesBuildPhase section
        pattern = r'(isa = PBXSourcesBuildPhase;.*?files = \()(.*?)(\);)'
        
        if watch_target:
            search_text = 'W00A /* Sources */'
        else:
            search_text = '/* Sources */'
        
        # Simple approach: find the right section and add before final );
        matches = list(re.finditer(pattern, self.content, re.DOTALL))
        if not matches:
            print(f"❌ PBXSourcesBuildPhase not found")
            return False
        
        print(f"✅ Found {len(matches)} source build phases")
        return True
    
    def save(self) -> bool:
        """Save changes with backup"""
        if self.content == self.original:
            print("ℹ️  No changes made")
            return True
        
        backup = self.pbxproj.with_suffix('.pbxproj.backup')
        backup.write_text(self.original)
        print(f"💾 Backup: {backup.name}")
        
        self.pbxproj.write_text(self.content)
        print(f"✅ Saved: project.pbxproj")
        return True


def add_secrets():
    """Add Secrets.plist to targets"""
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    
    if not pbxproj_path.exists():
        print(f"❌ Not found: {pbxproj_path}")
        return False
    
    editor = XcodeProjEditor(str(pbxproj_path))
    
    # IDs for Secrets.plist
    file_id = editor.gen_id()
    build_id = editor.gen_id()
    
    print("📝 Adding Secrets.plist...")
    
    if not editor.add_file_reference(file_id, 'Secrets.plist', 'Secrets.plist',
                                    file_type='text.plist.xml'):
        return False
    
    if not editor.add_build_file(build_id, file_id, 'Secrets.plist'):
        return False
    
    return editor.save()


def add_watchsecrets():
    """Add WatchSecrets.swift to watchOS target"""
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    
    if not pbxproj_path.exists():
        print(f"❌ Not found: {pbxproj_path}")
        return False
    
    editor = XcodeProjEditor(str(pbxproj_path))
    
    # IDs for WatchSecrets.swift
    file_id = editor.gen_id()
    build_id = editor.gen_id()
    
    print("📝 Adding WatchSecrets.swift...")
    
    if not editor.add_file_reference(file_id, 'WatchSecrets.swift', 
                                    'MeuLabWatch/Services/WatchSecrets.swift'):
        return False
    
    if not editor.add_build_file(build_id, file_id, 'WatchSecrets.swift'):
        return False
    
    return editor.save()


def main():
    print("🔐 Add Secrets Files to Xcode Project")
    print("=" * 60)
    
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    
    if not pbxproj_path.exists():
        print(f"❌ Project not found: {pbxproj_path}")
        print("\n💡 Please run from project root directory")
        return 1
    
    print(f"📁 Project: {project_root.name}")
    print(f"📦 Modifying: project.pbxproj\n")
    
    # Add files
    if not add_secrets():
        print("\n⚠️  Issue adding Secrets.plist")
        return 1
    
    print()
    
    if not add_watchsecrets():
        print("\n⚠️  Issue adding WatchSecrets.swift")
        return 1
    
    print("\n" + "=" * 60)
    print("✅ Complete! Next steps:")
    print("\n1️⃣  Close Xcode: xcode-select --reset")
    print("   Or: Cmd+Q, then reopen")
    print("\n2️⃣  Re-open project:")
    print("   open MeuLabApp.xcodeproj")
    print("\n3️⃣  Verify Target Membership:")
    print("   • Secrets.plist → Targets: iOS, watchOS, Widgets")
    print("   • WatchSecrets.swift → Targets: watchOS only")
    print("\n4️⃣  Compile:")
    print("   xcodebuild build -scheme MeuLabApp")
    print("   xcodebuild build -scheme MeuLabWatch")
    
    return 0


if __name__ == "__main__":
    exit(main())
