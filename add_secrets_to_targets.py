#!/usr/bin/env python3
"""
Add Secrets.plist and WatchSecrets.swift to MeuLabApp.xcodeproj targets

This script modifies project.pbxproj to add:
- Secrets.plist to: MeuLabApp, MeuLabWatch, MeuLabWidgets targets
- WatchSecrets.swift to: MeuLabWatch target
"""

import os
import uuid
import re
from pathlib import Path
from typing import Dict, List, Tuple

class PBXProjModifier:
    def __init__(self, pbxproj_path: str):
        self.path = Path(pbxproj_path)
        self.content = self.path.read_text()
        self.original_content = self.content
        
    def generate_uuid(self) -> str:
        """Generate Xcode-style UUID (24 uppercase hex chars)"""
        return uuid.uuid4().hex[:24].upper()
    
    def find_file_ref_id(self, filename: str) -> str:
        """Find or create UUID for file reference"""
        # Look for existing reference
        pattern = rf'/\* {re.escape(filename)} \*/ = [A-F0-9]{{24}};'
        match = re.search(pattern, self.content)
        if match:
            id_match = re.search(r'([A-F0-9]{24});', match.group())
            if id_match:
                return id_match.group(1)
        
        # Generate new one
        return self.generate_uuid()
    
    def find_target_id(self, target_name: str) -> str:
        """Find target ID by name"""
        pattern = rf'name = {target_name};\s+productName = {target_name};'
        match = re.search(pattern, self.content)
        if not match:
            return None
        
        # Find the UUID looking backwards from match
        before = self.content[:match.start()]
        uuids = re.findall(r'([A-F0-9]{24}) = \{', before)
        return uuids[-1] if uuids else None
    
    def add_secrets_plist(self) -> bool:
        """Add Secrets.plist file reference"""
        filename = "Secrets.plist"
        file_id = self.find_file_ref_id(filename)
        
        # Check if already added
        if f'/* {filename} */' in self.content:
            print(f"ℹ️  {filename} already in project")
            return True
        
        # Add to PBXFileReference section
        file_ref = f'''
		{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = {filename}; sourceTree = SOURCE_ROOT; }};'''
        
        # Find end of PBXFileReference section
        patterns = [
            r'(/* Begin PBXFileReference section \*/.*?)(/* End PBXFileReference section \*/)',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, self.content, re.DOTALL)
            if match:
                end_pos = match.end(1)
                self.content = self.content[:end_pos] + file_ref + '\n\t' + self.content[end_pos:]
                print(f"✅ Added {filename} file reference: {file_id}")
                return True
        
        print(f"❌ Could not find PBXFileReference section")
        return False
    
    def add_watchsecrets(self) -> bool:
        """Add WatchSecrets.swift file reference"""
        filename = "WatchSecrets.swift"
        filepath = "MeuLabWatch/Services/WatchSecrets.swift"
        file_id = self.find_file_ref_id(filename)
        
        # Check if already added
        if f'/* {filename} */' in self.content:
            print(f"ℹ️  {filename} already in project")
            return True
        
        # Add to PBXFileReference section
        file_ref = f'''
		{file_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filepath}; sourceTree = SOURCE_ROOT; }};'''
        
        match = re.search(
            r'(/* Begin PBXFileReference section \*/.*?)(/* End PBXFileReference section \*/)',
            self.content, re.DOTALL
        )
        if match:
            end_pos = match.end(1)
            self.content = self.content[:end_pos] + file_ref + '\n\t' + self.content[end_pos:]
            print(f"✅ Added {filename} file reference: {file_id}")
            return True
        
        print(f"❌ Could not find PBXFileReference section")
        return False
    
    def add_to_build_phases(self, file_id: str, target_ids: List[str]) -> bool:
        """Add file to build phases for given targets"""
        build_file_id = self.generate_uuid()
        
        # Create build file entry
        build_file = f'''
		{build_file_id} /* ${{filename}} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* ${{filename}} */; }};'''
        
        # Add to PBXBuildFile section
        match = re.search(
            r'(/* Begin PBXBuildFile section \*/.*?)(/* End PBXBuildFile section \*/)',
            self.content, re.DOTALL
        )
        if match:
            end_pos = match.end(1)
            self.content = self.content[:end_pos] + build_file + '\n\t' + self.content[end_pos:]
            return True
        
        return False
    
    def save(self) -> bool:
        """Save modified pbxproj file"""
        if self.content == self.original_content:
            print("ℹ️  No changes needed")
            return True
        
        # Backup original
        backup_path = self.path.with_suffix('.pbxproj.backup')
        backup_path.write_text(self.original_content)
        print(f"💾 Backup saved to: {backup_path}")
        
        self.path.write_text(self.content)
        print(f"✅ project.pbxproj updated")
        return True
    
    def validate(self) -> bool:
        """Basic validation of pbxproj structure"""
        if '/* Begin PBXFileReference section */' not in self.content:
            print("❌ Invalid pbxproj: missing PBXFileReference section")
            return False
        if '/* Begin PBXBuildFile section */' not in self.content:
            print("❌ Invalid pbxproj: missing PBXBuildFile section")
            return False
        return True


def main():
    print("🔐 Add Secrets to MeuLabApp.xcodeproj")
    print("=" * 50)
    
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    
    if not pbxproj_path.exists():
        print(f"❌ Not found: {pbxproj_path}")
        return False
    
    modifier = PBXProjModifier(str(pbxproj_path))
    
    if not modifier.validate():
        print("❌ Project file validation failed")
        return False
    
    print(f"📝 Modifying: {pbxproj_path}")
    
    # Add files
    if not modifier.add_secrets_plist():
        print("⚠️  Failed to add Secrets.plist")
    
    if not modifier.add_watchsecrets():
        print("⚠️  Failed to add WatchSecrets.swift")
    
    # Save changes
    if not modifier.save():
        print("❌ Failed to save changes")
        return False
    
    print("\n✅ Modification complete!")
    print("\n⚠️  IMPORTANT NEXT STEPS:")
    print("1. Close Xcode completely: cmd+q")
    print("2. Reopen project: open MeuLabApp.xcodeproj")
    print("3. Check Target Membership for each file:")
    print("   - Secrets.plist: ✅ MeuLabApp, ✅ MeuLabWatch, ✅ MeuLabWidgets")
    print("   - WatchSecrets.swift: ✅ MeuLabWatch")
    print("4. Compile: xcodebuild build -scheme MeuLabApp")
    
    return True


if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
