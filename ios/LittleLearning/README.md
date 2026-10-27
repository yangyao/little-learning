# iOS / macOS client

SwiftUI learning games with offline local saves and optional NAS ledger sync. See [the project README](../../README.md) for games, device build instructions and usage limits.

Copy Sources/Configuration/NASConfig.example.json to NASConfig.json in the same folder, fill in your NAS URL and shared token (at least32 characters), then rebuild. The actual config is ignored by Git. Without a valid config, learning and local awards still work; new redemptions require a configured NAS. Existing device history must be backed up and imported before the first sync. See [server setup](../../server/README.md).

The drawer's sync button and lifecycle tasks use NASClient.swift and ServerSync.swift. Durable operation UUIDs survive restarts, earnings deduplicate by challenge, and purchased play minutes are granted only to the requesting device once. QR UI entry points have been removed; the old codec/merge rules remain for historical compatibility checks.

Public builds preserve the existing com.example.littlelearning identifier and LittleLearning save directory; no family developer identity, signing credentials, real NAS config or third-party game bundles are distributed.

```sh
zsh scripts/check_core.sh
zsh scripts/check_store.sh
swift build
python3 scripts/generate_project.py
```

The Configuration folder is copied by both Xcode and Swift Package builds. Optional game bundles remain excluded; see [WebGames](Sources/WebGames/README.md).
