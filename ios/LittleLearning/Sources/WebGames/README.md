# Optional offline games

No third-party game source, artwork, audio, compiled bundle or runtime is distributed here.

The private family version integrated these upstream games:

- Bubble Shooter — Neon Edition: https://github.com/vivek-belwal/BubbleShooter. Its README declares MIT, but the reviewed checkout contains no standalone LICENSE; redistribution terms have not been fully resolved.
- 合成大西瓜: https://github.com/liyupi/daxigua. Its README specifies technical learning and entertainment and warns against wide redistribution/commercial use. This repository does not relicense or redistribute it.

Only the native integration interface is published. Supply your own independently licensed game bundle when you have permission to do so.

## Bundle layout

The native descriptors reserve these optional slots:

```
WebGames/
  bubbles/index.html
  watermelon/index.html
```

The drawer lists a slot only when its local index.html exists. Xcode and the Mac packaging script copy this folder. Optional bundles are ignored by Git to prevent accidental redistribution.

## JavaScript bridge

`EmbeddedGame.swift` injects `window.familyGame` at document start:

- Read `familyGame.initialState` and restore JSON-compatible state.
- Assign `familyGame.snapshot = () => ({ ... })` to return a JSON object.
- Assign `familyGame.setPaused = (paused) => { ... }` to stop/resume physics, animation and sound.
- Call `familyGame.ready()` after the game can safely start. The native gate prevents billing before readiness.
- Call `familyGame.save()` periodically while playing and immediately when pausing.
- Check `window.familyPaused` before processing input. Native controls also block paused/expired input.

Games must start paused and work offline. A local-only content security policy blocks external resources and navigation; paths are normalized before access. Never award learning points from JavaScript or in-game scores.

With no optional bundles, the play list is intentionally empty. All 13 native learning/creative games work independently.
