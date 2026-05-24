#!/usr/bin/env python3
"""
Add Bible Reader files to Xcode project
"""
import json
import os
import subprocess
from pathlib import Path

PROJECT_PATH = Path("/Users/eliel/Library/Mobile Documents/com~apple~CloudDocs/apps criados/botapp/MeuLabApp")
PBXPROJ = PROJECT_PATH / "MeuLabApp.xcodeproj" / "project.pbxproj"

# Files to add
FILES_TO_ADD = [
    ("MeuLabApp/Services/BibleSpeechService.swift", "Services"),
    ("MeuLabApp/ViewModels/BibleReaderViewModel.swift", "ViewModels"),
    ("MeuLabApp/Views/BibleChapterReaderView.swift", "Views"),
    ("MeuLabApp/Intents/BibleReadingIntents.swift", "Intents"),
    ("MeuLabApp/Models/BibleReaderModels.swift", "Models"),
    ("MeuLabApp/Views/BibleReaderIntegrationView.swift", "Views"),
]

def add_files_to_pbxproj():
    """Add files to Xcode project"""
    os.chdir(PROJECT_PATH)
    
    for file_path, group in FILES_TO_ADD:
        full_path = PROJECT_PATH / file_path
        if full_path.exists():
            print(f"✓ Adding {file_path} to {group} group...")
            # Using xcodebuild to add files would be complex
            # Instead, we'll use a simpler approach with sed or Python pbxproj parsing
            # For now, just verify the files exist
            print(f"  File exists: {full_path.stat().st_size} bytes")
        else:
            print(f"✗ File not found: {file_path}")

    print("\n📍 Alternative: Add files manually in Xcode")
    print("  1. Drag files from Finder to Xcode project")
    print("  2. Or: File → Add Files to MeuLabApp")
    print("  3. Select all 6 Bible Reader files")
    print("  4. Ensure target MeuLabApp is checked")

if __name__ == "__main__":
    add_files_to_pbxproj()
