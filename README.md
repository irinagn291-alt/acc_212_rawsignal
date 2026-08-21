# RawSignal

Brutalist calorie grid for iPhone. Local vault. No account.

**Bundle ID:** `com.rawsignal.grid`  
**Stack:** iOS 17+, portrait, Swift 6.2, Clean Swift VIP + SwiftUI overlays on SpriteKit scenes  
**Store:** custom `RSG1` binary archive (magic + version + binary plist payload + CRC32)

## Architecture

Clean Swift (VIP): View → Interactor → Presenter → View. Routers only change destination.

SpriteKit is the navigation canvas. Each user flow is an `SKScene` that hosts one SwiftUI VIP overlay. Custom `SKTransition`s (crimson fade, CI swipe, grid doors, pixellate) replace `UINavigationController`. See `Application/ArchitectureComment.swift`.

Flows live in `Onboarding/`, `MainFlow/`, `Settings/`. Names stay verbose (`DailyIntakeDisplayView`, `CatalogSearchInteractor`, `PreferenceConfigurationScene`).

## Twist

- Themes: Void Grid / Chalk Bleed / Crimson Field
- Layout density: compact / standard / wide
- Renameable lane labels (defaults `PULSE-A` / `PULSE-B` / `PULSE-C` / `NOISE`)
- Plan horizon 7 / 14 / 30 (`NOISE` is eaten-only)

Default targets: **2150 / 110 / 240 / 70**.

## How it differs

Clean Swift VIP on SpriteKit scene transitions. Custom RSG1 binary store. Brutalist themes and renameable lanes. Not a glass tray, arcade, oak pantry, civic memo, or watercolor kitchen.

## Build

```bash
xcodegen generate
xcodebuild -project RawSignal.xcodeproj -scheme RawSignal -destination 'platform=iOS Simulator,name=iPhone 16' build
```

No SPM / CocoaPods / Alamofire. Fonts: IBM Plex Mono OFL in `RawSignal/Resources/Fonts/` (`LICENSE`, `OFL.txt`).

## Image prompts

Cyberpunk, digital art, high contrast, futuristic. Unique per asset:

| Asset | Prompt |
|---|---|
| AppIcon | Square app icon, brutalist cyberpunk, pure black field, thick raw white L-shaped corner brackets, a single vertical crimson signal spike through a 4x4 wire grid, high contrast digital art, futuristic HUD fragment, no text, no letters, no logo type, no watermark |
| SplashSignal | Full-bleed vertical splash art, brutalist cyberpunk city signal tower, black void, raw white structural beams, pulsing red data lightning, high contrast digital painting, futuristic broadcast mast, no text, no letters, no watermark |
| OnboardingPulseGrid | Vertical onboarding illustration 1, brutalist cyberpunk control room, black walls, white tape-mark floor grid, red warning strobe, raw unfinished concrete edges, digital art high contrast, no text, no letters, no watermark |
| OnboardingLaneMap | Vertical onboarding illustration 2, four brutalist signal lanes as raw steel channels labeled only by colored pulses red white black, cyberpunk digital art, high contrast, industrial cables, no letters, no watermark |
| OnboardingScanLock | Vertical onboarding illustration 3, handheld barcode laser cutting through darkness, crimson scan line, white brutalist frame, cyberpunk digital art high contrast futuristic, no text, no letters, no watermark |
| OnboardingHorizon | Vertical onboarding illustration 4, three stacked horizon slabs 7 14 30 as raw concrete plates with red time ticks, brutalist cyberpunk, high contrast digital art, no readable text, no watermark |
| EmptyTodayGrid | Square empty-state art, brutalist cyberpunk vacant meal grid, black field, raw white empty brackets, faint red heartbeat missing, high contrast digital art, no text, no letters, no watermark |
| EmptyWishLedger | Square empty-state art, brutalist wish ledger as a blank steel clipboard with a single unused red clip, cyberpunk high contrast digital art, dark industrial, no text, no letters, no watermark |
| EmptyHorizonPlan | Square empty-state art, brutalist horizon calendar as uncarved concrete slabs in a void, one red pin unused, cyberpunk digital art high contrast, no text, no letters, no watermark |
| SlotPulseA | Square slot glyph PULSE-A, brutalist cyberpunk, black square, white raw frame, thick red diagonal pulse bar top-left energy, high contrast digital art, no text, no letters, no watermark |
| SlotPulseB | Square slot glyph PULSE-B, brutalist cyberpunk, black square, white raw frame, two parallel crimson horizontal signal bars mid height, high contrast digital art, no text, no letters, no watermark |
| SlotPulseC | Square slot glyph PULSE-C, brutalist cyberpunk, black square, white raw frame, red downward chevron pulse like a closing gate, high contrast digital art, no text, no letters, no watermark |
| SlotNoise | Square slot glyph NOISE, brutalist cyberpunk, black square, white raw jagged torn edge, scattered red static specks like analog noise, high contrast digital art, no text, no letters, no watermark |
| ShelfGraphiteOat | Square food still as cyberpunk product tile: graphite oat brick, rectangular dense oat block on black, harsh white rim light, red specular edge, digital art high contrast, no packaging text, no watermark |
| ShelfCrimsonBean | Square food still as cyberpunk product tile: crimson bean pulse, dark red beans in a raw steel cup, black void, white hard shadow, high contrast digital art, no text, no watermark |
| ShelfNeutralRice | Square food still as cyberpunk product tile: pale rice slab like a compressed white brick, brutalist lighting, black background, thin red underglow, digital art, no text, no watermark |
| ShelfVoltAlmond | Square food still cyberpunk product tile: volt almond paste as a dense ochre-gold paste brick, black void, white brutalist rim, red electric edge spark, high contrast digital art, no text, no watermark |
| ShelfStaticBerry | Square food still cyberpunk product tile: static berry cube, dark purple-red frozen berry cube, harsh studio light, black background, raw white corner marks, digital art high contrast, no text, no watermark |
| ShelfCarbonLentil | Square food still cyberpunk product tile: carbon lentil mash, near-black lentil puree in a raw metal tray, red underlight slit, high contrast digital art, no text, no watermark |
| ShelfSignalTuna | Square food still cyberpunk product tile: signal tuna block, dense pink-gray fish loaf sliced, brutalist lighting, black field, white hard shadow, digital art, no text, no watermark |
| ShelfNoiseYogurt | Square food still cyberpunk product tile: noise yogurt disk, pale yogurt puck with cracked surface, black background, red drip at the rim, high contrast digital art, no text, no watermark |
| TextureConcreteBleed | Seamless-looking background texture, brutalist concrete wall with raw formwork holes, black and white, faint red rust streak, cyberpunk digital art high contrast, no text, no watermark |
| TextureWireMesh | Seamless-looking background texture, fine white wire grid on pure black, occasional broken red pixel, cyberpunk HUD mesh, high contrast digital art, no text, no watermark |
| ChromeSignalButton | UI chrome button plate, long brutalist rectangle, raw unrounded corners, black fill, thick white border, small red corner tick, cyberpunk digital art, no text, no letters, no watermark |
| ChromeRawFrame | UI chrome frame, square brutalist viewfinder, thick white raw edges, uneven cut corners, red registration marks, black interior void, cyberpunk high contrast, no text, no watermark |
| ChromeScanReticle | UI chrome scan reticle, square cyberpunk targeting bracket, white L-corners, single red laser crosshair, black void center, high contrast digital art, no text, no letters, no watermark |

Same prompts are stored in each `Assets.xcassets/*/Contents.json` `info.comment`.
