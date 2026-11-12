# Mornye Studio — Qobuz-inspired listening and offline workflow

**This is an independent, unofficial Mornye fork. It is not Qobuz, not endorsed
by Qobuz, and does not use Qobuz trademarks, logos, or proprietary artwork.**

## What changed

- New installs default to a black/graphite interface with warm-gold accents.
  Saved user themes are respected (and can be changed under Settings).
- Album and playlist headers prioritize a large **Play** action and provide
  a separate **Download all** control.
- Each track row has its own **▶ stream** and **↓ offline download** buttons.
- Tap a track row to listen: prefer a completed local file when available,
  otherwise start the in-app online stream. Tap never downloads implicitly.
- Long-press **▶** to choose stream quality; long-press **↓** to force the
  original download quality picker. The settings remain independent.
- Play album/playlist uses Mornye's playback queue with automatic next-track
  handling and direct stream resolution when each new song starts.
- Mornye's library, offline files, download provider, extension repository,
  and existing local audio player remain in place.
- The player shows format, bit depth, sample rate and approximate average
  bitrate only when determined from the stream or provider metadata.

## What it does not do

This is not a substitute for a Qobuz subscription, rights-cleared catalog,
Qobuz Connect or its proprietary backend. It does not change access rights
or bypass DRM. The experimental Qobuz extension is required to attempt
online streaming, which depends on availability and authentication.
Downloads use Mornye's existing provider pipeline.

## Verification and installation

The branch is **untested on-device** until GitHub Actions and device tests
verify streaming, download completion, offline playback and track transitions.
Do not publish it as fully working before those checks.

An Android ARM64 Lite build is configured in GitHub Actions for PRs.
Use a stable signing key for upgrades and back up data before changing keys.
The experimental Qobuz Online v1.2.29 extension is installed separately.