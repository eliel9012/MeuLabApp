#!/bin/bash
cd "/Users/eliel/Library/Mobile Documents/com~apple~CloudDocs/apps criados/botapp/MeuLabApp"
echo "🔨 Iniciando clean build..."
xcodebuild clean -scheme MeuLabApp
xcodebuild build -scheme MeuLabApp -destination 'generic/platform=iOS Simulator' -verbose 2>&1 | grep -E "(error|warning|Secrets|Build complete)" | tail -50
