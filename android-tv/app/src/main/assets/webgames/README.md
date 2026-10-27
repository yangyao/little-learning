# Optional offline web games

This directory intentionally contains no third-party game bundles. Native learning games work without them; absent optional slots are hidden.

Only supply independently licensed bundles when you have permission. Reserved entry points are bubbles/index.html and watermelon/index.html. No advertising, external requests, shared account storage or learning-point rewards may be added through this integration.

The WebView serves local assets under https://family.local/webgames/ with network loads blocked. The game must provide window.familyGame.setPaused(boolean) and window.tvControl("left"|"right"|"fire"). Native calls pause before play, and sends initial per-child JSON through FamilyTV.initial(); the game signals FamilyTV.ready() only after restoration and input setup, periodically calls FamilyTV.save(JSON.stringify(snapshot)), and calls FamilyTV.error(message) on failure. Start paused, stop physics/audio while paused, and keep snapshots self-contained JSON under 1MB.

For the private upstream slots and unresolved redistribution restrictions, see ../../../../../../ios/LittleLearning/Sources/WebGames/README.md. No upstream code or assets are distributed here.
