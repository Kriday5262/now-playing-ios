# Now Playing — native iOS SwiftUI music player

A single-screen, retro-styled music player for your Navidrome / Subsonic server.
Portrait-only, dark-only, background audio, lock-screen controls, synced .lrc lyrics.

Built from the web prototype (`Kamkazi/now-playing`) as a pixel-matched SwiftUI rebuild.

## What's implemented

- **Subsonic client** — salt + md5 token auth, `ping` (test connection), `search3`,
  `getAlbum` / `getArtist` / `getPlaylist(s)` / `getRandomSongs` / `getGenres`,
  `star` / `unstar`, `getCoverArt`, OpenSubsonic `getLyricsBySongId` (Navidrome serves
  your `.lrc` sidecars through it).
- **Player engine** — AVPlayer, direct streaming (no transcode), background audio,
  MPNowPlayingInfoCenter + MPRemoteCommandCenter (play/pause/next/prev/scrub from the
  lock screen), repeat + shuffle queue engine.
- **UI** — album frame with shadow + scanline overlay, embossed control dial
  (heart / prev / play / next / AirPlay), repeat + shuffle + lyrics + queue buttons,
  rotating meta line (2.8 s, album(year) → artists → composed by → genre),
  HI-RES badge (bitrate ≥ 256 kbps), haptics on every control, VoiceOver labels,
  reduced-motion respected.
- **Sheets** — Search (full-screen), Up Next (drag-reorder, delete, jump), Track Info,
  Settings (server name/URL/user/pass + real Test Connection), Lyrics (synced
  highlighting from `.lrc` timestamps).
- **Persistence** — track, position (sec), queue, repeat, shuffle, favourite,
  collection name, server config saved on every change + on background; restores
  **paused** at the saved position on launch. Never auto-plays.
- **Sample mode** — until a server is configured, the app runs with 3 built-in sample
  albums so the UI can be explored immediately.

## Open & run on your Mac (Xcode project is checked in — easiest)

1. Clone this folder onto your Mac (or copy it over):
   ```
   git clone <this repo> NowPlaying && cd NowPlaying
   ```
2. Double-click **`NowPlaying.xcodeproj`** — it opens in Xcode.
3. In the left file list click the blue **NowPlaying** project → target **NowPlaying**
   → **Signing & Capabilities**:
   - **Team**: pick your Apple Developer account.
   - **Bundle Identifier**: `com.shantanu.nowplaying` (change if Xcode flags a clash).
4. Plug in your iPhone, select it in the device menu at the top, press **⌘R**.
5. On the phone: Settings app → General → VPN & Device Management → trust your
   developer profile if prompted (first run only).
6. In the app open Settings (gear, top centre) and enter your Navidrome URL,
   username, password → **Test connection** → ✅.

## If you prefer to regenerate the project (XcodeGen)

The project is also fully specified in `project.yml`. On the Mac with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) installed (`brew install xcodegen`):

```
cd NowPlaying
xcodegen generate
open NowPlaying.xcodeproj
```

Both routes produce the same app.

## TestFlight distribution

1. In Xcode: Product → Archive (device target "Any iOS Device (arm64)").
2. Window → Organizer → Distribute App → TestFlight → Upload.
3. App Store Connect → your app (com.shantanu.nowplaying) → TestFlight → add yourself
   as an internal tester → install via the TestFlight app.

## Project layout

```
NowPlaying.xcodeproj/          checked-in Xcode project
project.yml                    XcodeGen spec (same app, regenerable)
NowPlaying/
  NowPlayingApp.swift          app entry, scenePhase persistence
  AppModel.swift               server config + sample library + restore
  Models.swift                 Song / Album / Artist / Playlist / Genre
  SubsonicClient.swift         API client (token auth, all endpoints)
  PlayerEngine.swift           AVPlayer + remote commands + queue + persistence
  Persistence.swift            player-state JSON store
  Theme.swift                  design tokens, haptics, dial style, album frame
  NowPlayingScreen.swift       main screen (header / art / track / controls)
  ControlDial.swift            3×3 embossed dial
  AirPlay.swift                AVRoutePickerView cell
  SearchSheet.swift            full-screen universal search
  QueueInfoSheets.swift        Up Next + Track Info
  SettingsLyricsSheets.swift   Settings + Lyrics (synced .lrc)
  Info.plist                   background audio, portrait-only, dark-only
Assets.xcassets/               app icon + 3 sample albums + composer portrait
```

## Notes / known limits

- AirPlay cell uses the system `AVRoutePickerView` — its look is Apple's, not the
  dial's, but the tap target sits exactly where the prototype's AirPlay button is.
- Queue restore on a configured server currently rebuilds from the sample/library
  fetch after reconnect; offline launch with a saved snapshot restores paused exactly.
- Server password is stored in UserDefaults on-device; iCloud backup of it is not
  blocked (add an `exclude` key if you want that).
---
## ⚠️ Note on this repo's location
This project also lives at /media/HIKVISION/Shantanu/Work/NowPlaying/NowPlayingApp on the SmartHub NAS — copy it (or git clone from a remote once pushed) to the Mac.
