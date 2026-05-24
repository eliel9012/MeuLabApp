# Fonts — Mac OS 9 Design System

Place the following font files in this directory and add them to the Xcode project target (MeuLabApp):

## Required Files

| File | PostScript Name | Usage |
|------|----------------|-------|
| `AppleGaramond-Light.ttf` | `AppleGaramond-Light` | Editorial titles (large) |
| `AppleGaramond-LightItalic.ttf` | `AppleGaramond-LightItalic` | Editorial italic |
| `AppleGaramond.ttf` | `AppleGaramond` | Regular editorial text |
| `AppleGaramond-Bold.ttf` | `AppleGaramond-Bold` | Bold editorial text |
| `Charcoal.ttf` | `Charcoal` | Window titles, headings, menus |
| `Geneva.ttf` or `GENEVA.TTF` | `Geneva` | Body text, labels, captions |

## Sources
The font files were provided as zip attachments:
- `apple_garamond.zip` → extract all .ttf files here
- `charcoal-regular_*.zip` → extract the .ttf from the `Charcoal Regular/` subfolder
- `geneva.zip` → extract `GENEVA.TTF` and rename to `Geneva.ttf` (optional)

## Xcode Setup

1. Drag all .ttf files into the Xcode project navigator under `Resources/Fonts/`
2. Check "Add to target: MeuLabApp" when prompted
3. Info.plist already has the `UIAppFonts` key configured

## Validating Fonts

In any SwiftUI preview, add this to `onAppear`:
```swift
MacOS9Typography.debugAvailableFonts()
```

This prints which fonts loaded successfully and which are using fallbacks.

## Fallback Fonts (used when .ttf not loaded)
- Apple Garamond → Georgia
- Charcoal → Helvetica Neue
- Geneva → Helvetica Neue
