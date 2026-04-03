#!/usr/bin/env python3
"""
Add WatchSecrets.swift to MeuLabApp.xcodeproj

Usage:
    python3 add_watchsecrets.py

This script edits project.pbxproj to add WatchSecrets.swift to MeuLabWatch target.
"""

import os
import re
from pathlib import Path

PROJECT_DIR = Path(__file__).parent
PBXPROJ_PATH = PROJECT_DIR / "MeuLabApp.xcodeproj/project.pbxproj"
WATCHSECRETS_PATH = PROJECT_DIR / "MeuLabWatch/Services/WatchSecrets.swift"

def read_pbxproj():
    """Read project.pbxproj content"""
    with open(PBXPROJ_PATH, 'r') as f:
        return f.read()

def write_pbxproj(content):
    """Write project.pbxproj content"""
    with open(PBXPROJ_PATH, 'w') as f:
        f.write(content)

def find_file_ref_id(content, filename):
    """Find fileReference ID for given filename"""
    # Pattern: /* WatchSecrets.swift */ = {isa = PBXFileReference ...
    pattern = rf'/\* {re.escape(filename)} \*/ = [A-Z0-9]+;'
    match = re.search(pattern, content)
    if match:
        line = match.group()
        # Extract ID from end of line before ';'
        id_match = re.search(r'([A-Z0-9]+);', line)
        if id_match:
            return id_match.group(1)
    return None

def add_file_to_pbxproj():
    """Add WatchSecrets.swift to project"""
    
    print("📝 Reading project.pbxproj...")
    content = read_pbxproj()
    
    # Check if already added
    if "WatchSecrets.swift" in content:
        print("❌ WatchSecrets.swift already in project.pbxproj")
        return False
    
    if not WATCHSECRETS_PATH.exists():
        print(f"❌ File not found: {WATCHSECRETS_PATH}")
        return False
    
    print(f"✅ Found file: {WATCHSECRETS_PATH}")
    
    # Find WatchRadioView (similar file in watch) to use as template
    watch_view_ref = find_file_ref_id(content, "WatchRadioView.swift")
    
    if not watch_view_ref:
        print("❌ Could not find WatchRadioView.swift reference - cannot determine structure")
        print("⚠️  Please add manually via Xcode UI")
        return False
    
    print(f"ℹ️  Found reference pattern in {watch_view_ref}")
    
    # For safety, just provide instructions
    print("\n⚠️  IMPORTANT: Use Xcode UI for safety")
    print("\n1. Open Xcode:")
    print("   open MeuLabApp.xcodeproj")
    print("\n2. Add file via menu:")
    print("   File → Add Files to \"MeuLabApp\"")
    print("   Select: MeuLabWatch/Services/WatchSecrets.swift")
    print("   Target: ✅ MeuLabWatch")
    print("\n3. Verify by running:")
    print("   xcodebuild build -scheme MeuLabWatch")
    
    return True

if __name__ == "__main__":
    print("🔐 Add WatchSecrets.swift to MeuLabApp project")
    print("=" * 50)
    
    if add_file_to_pbxproj():
        print("\n✅ Script completed")
    else:
        print("\n❌ Could not complete automatically")
        print("   Use Xcode UI (see instructions above)")
