---
phase: 04-settings-history-and-polish
plan: 04
subsystem: ui
tags: [distribution, dmg, notarization, about-window, app-icon, appkit]

# Dependency graph
requires:
  - phase: 04-02
    provides: SettingsWindowController, HistoryWindowController, StatusMenuController pattern

provides:
  - AboutWindowController with version/credits display
  - "Acerca de MyWhisper" menu item at top of status menu
  - ExportOptions.plist with Developer ID signing configuration
  - scripts/build-dmg.sh — automated archive-export-sign-notarize-staple pipeline
  - Assets.xcassets with AppIcon.appiconset entry registered in project

affects: [distribution, release, mac-app-store-alternative]

# Tech tracking
tech-stack:
  added: []
  patterns: [NSWindow frame-based layout for simple read-only windows, hdiutil+codesign+notarytool DMG pipeline]

key-files:
  created:
    - MyWhisper/App/AboutWindowController.swift
    - MyWhisper/ExportOptions.plist
    - MyWhisper/Assets.xcassets/Contents.json
    - MyWhisper/Assets.xcassets/AppIcon.appiconset/Contents.json
    - scripts/build-dmg.sh
  modified:
    - MyWhisper/UI/StatusMenuView.swift
    - MyWhisper.xcodeproj/project.pbxproj

key-decisions:
  - "AboutWindowController uses NSWindow + frame-based layout (linter simplified from NSPanel + Auto Layout) — simpler for read-only display"
  - "App icon asset catalog created with placeholder entries (no image files) — valid AppIcon catalog that builds without errors; custom icon can be added later"
  - "build-dmg.sh uses 'Developer ID Application' (common name prefix) in codesign call — user must ensure only one matching cert is in Keychain or specify full cert name"

patterns-established:
  - "NSWindow frame-based layout for informational panels that do not require user input"

requirements-completed: [MAC-05]

# Metrics
duration: 8min
completed: 2026-03-16
---

# Phase 4 Plan 4: Distribution Pipeline and About Window Summary

**Developer ID DMG distribution pipeline (archive/export/sign/notarize/staple via xcrun notarytool) plus About window with version display and app icon asset catalog**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-16T13:27:20Z
- **Completed:** 2026-03-16T13:35:00Z
- **Tasks:** 2 of 2 (complete)
- **Files modified:** 7

## Accomplishments
- AboutWindowController opens from "Acerca de MyWhisper" at top of status menu — shows app icon, name, version, description, and copyright
- scripts/build-dmg.sh implements the full 7-step distribution pipeline (archive, export, verify signature, create DMG, sign DMG, notarize, staple)
- ExportOptions.plist configures xcodebuild to export with method=developer-id and automatic signing
- Assets.xcassets registered in project with AppIcon.appiconset — build succeeds without asset catalog warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Create About window, app icon, distribution script, and ExportOptions.plist** - `ac6a09a` (feat)
2. **Task 2: Verify distribution script and About window** - checkpoint approved by user

## Files Created/Modified
- `MyWhisper/App/AboutWindowController.swift` - NSWindow-based About panel with version info and credits
- `MyWhisper/UI/StatusMenuView.swift` - Added "Acerca de MyWhisper" item and openAbout() method
- `MyWhisper/ExportOptions.plist` - xcodebuild Developer ID export configuration
- `scripts/build-dmg.sh` - Full build/sign/notarize/staple automation script (chmod +x)
- `MyWhisper/Assets.xcassets/Contents.json` - Asset catalog root
- `MyWhisper/Assets.xcassets/AppIcon.appiconset/Contents.json` - AppIcon entries for all mac sizes
- `MyWhisper.xcodeproj/project.pbxproj` - Registered AboutWindowController and Assets.xcassets

## Decisions Made
- AboutWindowController uses frame-based layout (NSWindow, not NSPanel) after linter simplification — adequate for a read-only informational window
- App icon placeholder only includes Contents.json (no image files) — Xcode treats this as a valid but empty AppIcon set; no build error, user can add icon PNG files later
- The codesign step in build-dmg.sh uses `"Developer ID Application"` as the identity — this is a common name prefix that works when only one Developer ID cert exists in Keychain

## Deviations from Plan

### Auto-fixed Issues

**1. [Linter auto-fix] AboutWindowController simplified from NSPanel+AutoLayout to NSWindow+frame-based layout**
- **Found during:** Task 1 (file creation)
- **Issue:** Linter/formatter automatically revised the file to use NSWindow and frame-based layout
- **Fix:** Accepted linter changes — the result is functionally equivalent with simpler code
- **Files modified:** MyWhisper/App/AboutWindowController.swift
- **Verification:** Build passes, all display elements are present
- **Committed in:** ac6a09a

---

**Total deviations:** 1 (linter auto-simplification — no functional impact)
**Impact on plan:** None — About window shows version, description, and credits as required.

## Issues Encountered
- No assets catalog existed in the project. Created `MyWhisper/Assets.xcassets` from scratch and registered in pbxproj manually. Build settings already referenced `AppIcon` via `ASSETCATALOG_COMPILER_APPICON_NAME`.

## User Setup Required
Distribution requires:
1. Developer ID Application certificate in Keychain
2. notarytool keychain profile: `xcrun notarytool store-credentials 'notarytool-profile' --apple-id <email> --team-id <team> --password <app-specific-password>`
3. Custom app icon PNG files placed in `MyWhisper/Assets.xcassets/AppIcon.appiconset/` (sizes: 16, 32, 128, 256, 512 @1x and @2x)

## Verification Result

Task 2 checkpoint: **approved** by user on 2026-03-16. Distribution pipeline artifacts and About window confirmed correct.

## Next Phase Readiness
- Phase 4 complete — distribution pipeline scripted and ready for when credentials are configured
- About window accessible from menu
- App icon slot is ready for custom artwork
- User verified all artifacts (Task 2 checkpoint passed)

---
*Phase: 04-settings-history-and-polish*
*Completed: 2026-03-16*
