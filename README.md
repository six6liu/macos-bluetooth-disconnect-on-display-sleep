# macos-bluetooth-disconnect-on-display-sleep

**Auto-disconnect a Bluetooth device (e.g. earbuds, headphones, speaker) when your macOS display sleeps, and reconnect it on wake.** Single .app, menu bar icon, no system modification, no daemons, easy to remove.

If you have a Mac that runs 24/7 — a home server, a media box, a workstation you walk away from — and a pair of Bluetooth earbuds that keeps grabbing the audio connection even after the screen is off, blocking your phone or tablet from using them, this is for you.

[中文文档](#中文简介) · [Features](#features) · [Quick start](#quick-start) · [Configuration](#configuration) · [Build from source](#build-from-source) · [Troubleshooting](#troubleshooting) · [License](#license)

---

## The problem

You have a Mac that you keep on 24/7. Power-saving on the host doesn't matter — you want the host awake, downloading, syncing, running scripts, serving files, whatever. But the *display* should sleep when you walk away.

When the display sleeps, macOS does not turn off Bluetooth. So your paired Bluetooth earbuds, headphones or speaker stay connected to the Mac, hogging the A2DP audio channel. Meanwhile your phone or tablet cannot pair to those earbuds because the Mac is still holding the slot.

Built-in macOS tools don't solve this:

- **Bluetooth menu → Disconnect** — works, but only manually, and macOS re-pairs the device the moment it wakes the host.
- **System Settings → Energy → “Disconnect Bluetooth when Mac sleeps”** — toggles the *whole* radio, not the specific device you want to release. And it requires the host to sleep, which a 24/7 Mac won't.
- **Hot-corner “Put display to sleep”** — kills the display, leaves the host awake, and leaves the BT device connected. Same problem.
- **Bluesnooze** (the popular menu-bar app for this) — also watches for *host* sleep, not display sleep. On a 24/7 Mac it never fires.
- **Shortcuts / Automator** — has a “Mac Sleeps” trigger but no “Display Sleeps” trigger. Same gap.

So your only options are: keep clicking Disconnect manually, or keep the display always on and waste power.

## The solution

This app watches the macOS unified log for actual display-sleep events (`com.apple.SkyLight:display` — the same event the system itself fires when the screen goes black) and runs a user-configurable command when those events arrive. By default it disconnects one specific Bluetooth device when the display sleeps and reconnects it when the display wakes. You can change both the device and the command.

The whole thing is a single `.app` that you put in `/Applications`. It does not install a launch daemon, does not modify system preferences, does not need accessibility or full-disk-access permissions. Click the menu bar icon → Quit to stop. Drag the .app to the Trash to remove.

## Features

- **Event-driven, not polling** — reacts to real `Event: Did Sleep` / `Event: Did Wake` from the system's display power log. No CPU spin, no 5-second lag.
- **Targets one device, not the whole radio** — leaves your keyboard, mouse, and any other BT peripherals alone. Only the device you specify gets disconnected.
- **No false positives** — if a video, a download manager, or any other app is keeping your display awake, the watcher correctly does nothing. The trigger is the actual sleep event, not an idle-time heuristic.
- **No system modification** — no `launchd` agents, no `~/.zshrc` edits, no sudo, no Accessibility/Full-Disk-Access prompts.
- **Surface-level, removable** — a single .app in `/Applications`. Quit it from the menu bar, or drag it to the Trash. No residue.
- **Configurable** — pick any paired Bluetooth device, or replace the action with any shell command (run a Shortcut, play a sound, toggle a Home Assistant switch, send a notification, …). The trigger predicate is configurable too, so you can react to other events if you want.
- **Idempotent** — running disconnect on an already-disconnected device is a no-op. Multiple events firing the same action is safe.

## Quick start

### 1. Install `blueutil`

```bash
brew install blueutil
```

### 2. Find your device's MAC address

```bash
blueutil --paired
```

Look for the device you want to release. Example output:

```
address: 88-92-cc-e5-ce-aa, connected (master, 0 dBm), not favourite, paired, name: "OPPO Enco Free4", ...
```

Copy the address (the `xx-xx-xx-xx-xx-xx` part).

### 3. Set up the config

```bash
mkdir -p ~/.config/macos-bluetooth-disconnect
cp config.example ~/.config/macos-bluetooth-disconnect/config
$EDITOR ~/.config/macos-bluetooth-disconnect/config
```

Edit at minimum the `MAC` line. Everything else has sensible defaults.

### 4. Build and install the app

```bash
git clone https://github.com/<your-username>/macos-bluetooth-disconnect-on-display-sleep.git
cd macos-bluetooth-disconnect-on-display-sleep
INSTALL=1 ./build.sh
```

The .app is built and moved to `/Applications/Display BT Toggle.app`.

### 5. Launch it

Double-click `Display BT Toggle.app` in Finder, or:

```bash
open /Applications/Display\ BT\ Toggle.app
```

A 📺 icon appears in the menu bar. Click it to see the status and a Quit option.

### 6. Test

- Move your cursor to a Hot Corner set to “Put display to sleep”, or wait for the display-sleep timeout to fire.
- Your device should disconnect within a second of the screen going black.
- Touch the mouse / keyboard. The display wakes, and your device reconnects.

If something doesn't work, see [Troubleshooting](#troubleshooting) below.

## Configuration

All configuration lives in `~/.config/macos-bluetooth-disconnect/config`. Copy `config.example` to that path and edit. The shell script `sources` it, so any bash variable assignment works.

| Variable | Default | What it does |
|---|---|---|
| `MAC` | `88-92-cc-e5-ce-aa` | Bluetooth MAC of the device to disconnect on display sleep. |
| `BT` | `/opt/homebrew/bin/blueutil` | Path to `blueutil`. Change if you installed it elsewhere. |
| `LOG_PREDICATE` | `category == "display" AND subsystem == "com.apple.SkyLight"` | Predicate for `log stream`. Change to listen to different events (see below). |
| `SLEEP_PATTERN` | `Event: Will Sleep\|Event: Did Sleep` | awk regex matching "going to sleep" events. |
| `WAKE_PATTERN` | `Event: Did Wake` | awk regex matching "waking up" events. |
| `ON_SLEEP_CMD` | `$BT --disconnect $MAC` | Shell command run on sleep. |
| `ON_WAKE_CMD` | `$BT --connect $MAC` | Shell command run on wake. |

### Examples

**Multiple devices (any of two earbuds):**

```bash
MAC="88-92-cc-e5-ce-aa, aa-bb-cc-dd-ee-ff"
ON_SLEEP_CMD="for m in ${MAC//,/ }; do $BT --disconnect $m; done"
ON_WAKE_CMD="for m in ${MAC//,/ }; do $BT --connect $m; done"
```

**Don't reconnect automatically (so other devices can grab the earbuds freely):**

```bash
ON_WAKE_CMD="true"   # no-op
```

**Run a Shortcut on sleep instead of blueutil:**

```bash
ON_SLEEP_CMD="shortcuts run 'Free Up My Earbuds'"
```

**Play a sound when the display wakes:**

```bash
ON_WAKE_CMD="afplay /System/Library/Sounds/Glass.aiff"
```

### Custom triggers

The trigger isn't limited to display sleep. The `LOG_PREDICATE` is just an argument to `log stream`, and the patterns are awk regexes. Some ideas:

| Trigger | Predicate | Pattern |
|---|---|---|
| Mac sleeps | `subsystem == "com.apple.powermanagement"` | `Entering Sleep state` |
| Mac wakes | `subsystem == "com.apple.powermanagement"` | `Wake from Sleep` |
| Screen locks | `subsystem == "com.apple.screensaver"` | `ScreenSaver did change to locked screen` |
| Specific app quits | `process == "Safari"` | `Safari.*terminated` |
| Bluetooth connects | `subsystem == "com.apple.bluetooth"` | `device connected` |

Run `log stream --predicate '...'` interactively first to see what messages exist before wiring it up.

## Build from source

```bash
git clone https://github.com/<your-username>/macos-bluetooth-disconnect-on-display-sleep.git
cd macos-bluetooth-disconnect-on-display-sleep
./build.sh              # builds ./Display BT Toggle.app
INSTALL=1 ./build.sh    # also moves it to /Applications
```

`build.sh` is a thin wrapper around `osacompile` (built into macOS) plus a few `PlistBuddy` tweaks and a `codesign --sign -` (ad-hoc) so the modified Info.plist doesn't break the bundle.

You don't need Xcode; you just need the command-line developer tools (`xcode-select --install`).

## How it works

```
Display sleeps
   │
   ▼
WindowServer / SkyLight logs "Event: Did Sleep" to the unified log
   │
   ▼
log stream --predicate 'category == "display" AND subsystem == "com.apple.SkyLight"'
   │
   ▼ (stdin, line by line)
awk matches SLEEP_PATTERN → runs ON_SLEEP_CMD
   │
   ▼
blueutil --disconnect 88-92-cc-e5-ce-aa
   │
   ▼
The Bluetooth device is released. Your phone can now pair with it.
```

The reverse happens on wake. The whole pipeline is event-driven: zero CPU when nothing is happening, immediate response when something does.

## Troubleshooting

**“Nothing happens when the display sleeps.”**
Open a Terminal and run the watcher directly so you can see what it sees:

```bash
./display-bt-watcher.sh
```

Then trigger a display sleep. You should see no output (the script is silent by design) but the `blueutil` call should fire. To debug visually, edit `display-bt-watcher.sh` and add `print` statements inside the awk block.

**“It disconnects but the device keeps auto-reconnecting.”**
The earbuds themselves are trying to reconnect to the last-paired host. The `ON_WAKE_CMD` is for when the *display* wakes, not the earbuds — your device is re-pairing on its own. If you don't want it to reconnect on wake, set `ON_WAKE_CMD="true"`.

**“Multiple instances of the watcher are running.”**
The lockfile at `/tmp/macos-bt-disconnect.lock` prevents this. If you've launched it manually (e.g. via `./display-bt-watcher.sh &`) and also via the .app, kill the manual one. Or just `pkill -f display-bt-watcher`.

**“I want to see a notification when the device disconnects.”**
Edit the config and replace `ON_SLEEP_CMD`:

```bash
ON_SLEEP_CMD="osascript -e 'display notification \"Released OPPO Enco Free4\" with title \"Display BT Toggle\"' && $BT --disconnect $MAC"
```

**“I uninstalled it but the menu bar icon is still there.”**
Quit it from the menu bar icon first, *then* move the .app to the Trash. Or:

```bash
pkill -f 'Display BT Toggle.app'
rm -rf /Applications/Display\ BT\ Toggle.app
```

## 中文简介

把 Mac 当 24/7 主机用的人（家庭服务器、媒体盒、永远开着的工位）经常会遇到一个烦人的小问题：屏幕睡了，Mac 没睡，配对的蓝牙耳机还一直占着音频通道，结果你手机/平板想用这对耳机就连不上。

macOS 自带的几个办法都不灵：系统设置里的"Mac 睡眠时关闭蓝牙"是关整个蓝牙、且要 Mac 整机睡眠；Bluesnooze 也是盯整机睡眠；快捷指令只有"Mac 睡眠"触发器、没有"屏幕睡眠"。在 24/7 主机上这些都不会触发。

这个 app 直接监听系统自己的 `Event: Did Sleep` 日志（屏幕真黑时由 WindowServer 发出），瞬间断开你指定的那一个蓝牙设备；屏幕亮了就重连。事件驱动、不轮询、不误报（看视频时屏幕没睡，就不会动你的耳机）。

整个东西就是 `/Applications` 下的一个 `.app`，菜单栏里有 📺 图标，Cmd+Q 退出、拖废纸篓删除——没有任何 daemon、launchd 残留、权限申请。

高级玩法：所有触发条件和执行动作都在 `~/.config/macos-bluetooth-disconnect/config` 里可改。可以监听别的日志、跑任意 shell 命令（快捷指令、声音、通知、Home Assistant …），不限于屏幕睡眠。

## License

[MIT](LICENSE)
