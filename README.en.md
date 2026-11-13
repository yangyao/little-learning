English | [简体中文](README.md)

# 千臻乐园 · Little Learning

> Note: this README is the English version. The rest of the documentation (including [DESIGN.md](DESIGN.md), [CONTRIBUTING.md](CONTRIBUTING.md) and the READMEs in subdirectories) is written in Chinese.

Learning mini-games for kids at home, with support for iPhone, Mac preview, and Android TV. The phone and the TV sync points through the home NAS.

No accounts, ads, or subscriptions. The learning games work offline; when the NAS is unreachable kids can still play, clear challenges, and earn points — redeeming requires an online confirmation.

## Games and how it works

There are 13 learning games, 42 question sets, and 902 playable challenges:

| Game | Content |
| --- | --- |
| 荷叶跳跳 (Lily-pad Jump) | Addition, subtraction, and number lines |
| 断尺侦探 (Broken Ruler Detective) | Aligning measurements, filling in missing marks, and rulers without a zero |
| 森林野餐 (Forest Picnic) | Equal sharing and division with remainders |
| 拼音火车 (Pinyin Train) | Tones and pinyin combinations |
| 拼字工坊 (Character Workshop) | Chinese character components and radicals |
| 成语拼装 (Idiom Builder) | Read the clues, assemble the idiom |
| 字母面包房 (Letter Bakery) | Spelling English words |
| 滴答时钟 (Tick-tock Clock) | Telling time and elapsed time |
| 巧移火柴 (Matchstick Move) | Move one matchstick to make the equation true |
| 果篮分拣 (Fruit Basket Sort) | Sorting, planning, and undo |
| 七巧板拼图 (Tangram Puzzle) | Move, rotate, and flip |
| 小鸭送信 (Duck Delivery) | Line up commands and plan a route |
| 规律串珠 (Pattern Beads) | Shape and color patterns |

On launch, choose 千一 or 臻一; each child's points and progress are kept separate. Question sets can be switched freely, and each challenge only awards points once per child — reviewing never awards points twice. The TV version is played with the D-pad, OK, and Back buttons, and the animal avatars are drawn natively.

Each child gets a 30-minute usage quota per device; when it runs out they rest for 2 hours. The profile picker, background mode, and lock screen do not count against the quota. Learning and play share the same quota, and purchased play minutes do not increase the total usage quota.

## Phone, TV, and NAS sync

- Both ends automatically sync points, redemptions, and undo — no manual QR scanning.
- Points earned offline are stored locally first and synced once the connection is restored.
- Redemptions are confirmed by the NAS; retrying after a disconnect never deducts points twice, and two devices redeeming at the same time cannot overdraw.
- 5 points buy 5 minutes of play time, delivered to the purchasing device only once — time is never duplicated on other devices.
- In-progress boards, question sets, remaining play minutes, and usage quotas are independent per device.

The server is built with Go + SQLite and compiles into a single binary that runs on the NAS, with support for history import and database backup. QNAP users can install the bundled QPKG wrapper, which is managed by App Center for enable/disable and startup on boot.

Before connecting devices that already have history, back up and import their history first. What the NAS keeps is the points ledger; it is not a replacement for backing up full game saves.

## Code layout

| Directory | Content |
| --- | --- |
| [ios/LittleLearning](ios/LittleLearning/README.md) | iPhone client and Mac preview |
| [android-tv](android-tv/README.md) | Android TV client with remote-friendly UI |
| [server](server/README.md) | NAS sync service, history import, and backup tools |
| [server/deploy/qpkg](server/deploy/qpkg/README.md) | QNAP autostart wrapper |
| [design](DESIGN.md) | UI and interaction notes |

## Build and configuration

### iPhone / Mac

Requires macOS, Xcode, and iOS 17 or newer. Open `ios/LittleLearning/LittleLearning.xcodeproj`, select your own Team and Bundle Identifier, then run on a device or simulator.

NAS settings: copy `Sources/Configuration/NASConfig.example.json` to `NASConfig.json` in the same directory, fill in the NAS URL and shared token, and rebuild. For Mac preview, run `zsh scripts/package_mac_preview.sh` inside that project directory.

### Android TV

Requires JDK 17 and Android SDK 34. In the `android-tv` directory run:

```sh
./gradlew assembleRelease
```

Copy `app/src/main/assets/nas-config.example.json` to `nas-config.json` in the same directory and fill in the same NAS URL and token; when using HTTP, change the example NAS address in `network_security_config.xml` to the real one. For installation and remote-control notes, see the [Android TV README](android-tv/README.md).

### NAS

Go 1.21 or newer is needed to build; the NAS does not need Go to run the binary. In the `server` directory run:

```sh
go build -o learning-server ./cmd/learning-server
cp config.example.json config.json
# Edit config.json: set the listen address and replace the random token
./learning-server -config config.json
```

The clients and the server share the same random token of at least 32 characters. For Linux ARM64 builds, background startup, QNAP installation, migration, and backup commands, see the [server README](server/README.md).

Without a configured NAS, the client still works for offline learning and earning points, but redemption is unavailable. Real configuration, signing keys, saves, databases, and packages are not committed to the repository.

## Optional play content

The bubble-shooter and watermelon-merge game code and assets used by the home installation are not distributed with this repository; the public code only keeps the local-game bridge interfaces. Without the game packages the play list is empty, and the 13 learning games still run on their own. To hook up resources you have the rights to use, see the [iOS notes](ios/LittleLearning/Sources/WebGames/README.md) and the [TV notes](android-tv/THIRD_PARTY.md).

## Local checks

To check your changes, run the commands below in the matching directory:

```sh
# ios/LittleLearning
zsh scripts/check_core.sh
zsh scripts/check_store.sh

# android-tv
sh scripts/check.sh

# server
go test -race ./...
```

## License

[MIT](LICENSE) · Copyright © 2026 yangyao. It only covers the original code and assets provided in this repository; third-party components are used under their own licenses, and the undistributed game assets are not covered by this license.
