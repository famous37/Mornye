#!/usr/bin/env python3
"""Build opt-in full-track streaming actions for compatible open-source providers.

Only directly playable HTTPS URLs are exposed. No auth bypass, protected media
decryption, preview URL substitution, background downloads, or DRM handling.
Jellyfin accesses the user's own authenticated media server; SoundCloud uses
the extension's existing public-playable track resolver.
"""
from __future__ import annotations

import json
import pathlib
import sys

JELLYFIN_STREAM = r"""
// Experimental direct streaming of an audio file owned by the user's Jellyfin
// server. HTTPS is required because the stream URL carries an API access token.
function resolvePlaybackStream(request) {
  request = request || {};
  try {
    var origin = String(request.source || "").toLowerCase();
    var supplied = String(request.id || "").replace(/^jellyfin:/i, "");
    var item = null;
    if ((origin === "jellyfin" || origin === "extension:jellyfin") && isId(supplied)) {
      item = getItem(supplied, "MediaSources,Path");
    }
    if (!item) {
      item = findTrack(
        String(request.title || ""),
        String(request.artist || ""),
        Number(request.duration_ms || 0) / 1000
      );
    }
    if (!item || !isId(item.Id)) {
      return { success: false, error: "No matching track in the Jellyfin library" };
    }
    // ORIGINAL preserves the server's original codec and quality. Do not
    // mislabel Jellyfin MP3/Opus tracks as Hi-Res FLAC.
    var info = getDownloadUrl(item.Id, "ORIGINAL");
    var url = String(info && info.url || "").trim();
    if (!info || info.success !== true || !/^https:\/\//i.test(url)) {
      return {
        success: false,
        error: !/^https:\/\//i.test(url)
          ? "Jellyfin server must use HTTPS for secure online playback"
          : String(info && info.error || "No playable Jellyfin URL")
      };
    }
    return {
      success: true,
      full_track: true,
      url: url,
      format: String(info.format || "").toLowerCase(),
      provider: "jellyfin",
      quality_requested: "ORIGINAL",
      expires: "server-controlled"
    };
  } catch (error) {
    return { success: false, error: String(error && error.message || error) };
  }
}
"""

SOUNDCLOUD_STREAM = r"""
// Full playback is offered only for SoundCloud tracks explicitly marked
// playable and for non-snipped, non-preview progressive audio transcodings.
// This uses the same client/track authorization as the regular extension.
function resolvePlaybackStream(request) {
  request = request || {};
  try {
    var origin = String(request.source || "").toLowerCase();
    var ownId = String(request.id || "").replace(/^soundcloud:/i, "");
    var track = null;
    if ((origin === "soundcloud" || origin === "extension:soundcloud") &&
        /^\d{5,}$/.test(ownId)) {
      track = fetchTrackData(ownId);
    }
    if (!track) {
      var matched = checkAvailability(
        String(request.isrc || ""),
        String(request.title || ""),
        String(request.artist || ""),
        { duration_ms: Number(request.duration_ms || 0) }
      );
      if (matched && matched.available === true) {
        track = matched.prepared_context && matched.prepared_context.track || null;
        if (!track && matched.track_id) {
          track = fetchTrackData(matched.track_id);
        }
      }
    }
    if (!track || track.streamable === false ||
        (track.access && track.access !== "playable")) {
      return { success: false, error: "SoundCloud track is not fully playable" };
    }
    var expected = Number(request.duration_ms || 0);
    if (expected > 45000 && Number(track.duration || 0) > 0 &&
        Math.abs(expected - Number(track.duration)) > Math.max(7000, expected * 0.04)) {
      return { success: false, error: "SoundCloud track duration does not match" };
    }
    ensureClientId();
    var ranked = rankTranscodings(
      track.media && track.media.transcodings || [], "aac"
    );
    // HLS manifests may require specialized player support. Only hand the
    // standard player a progressive URL, not an HLS playlist or download job.
    for (var i = 0; i < ranked.length; i++) {
      var candidate = ranked[i];
      if (!candidate || !candidate.format ||
          candidate.format.protocol !== "progressive" ||
          candidate.snipped || /preview/i.test(candidate.preset || "")) continue;
      var url = resolveStreamURL(candidate, track);
      if (!/^https:\/\//i.test(String(url || ""))) continue;
      return {
        success: true,
        full_track: true,
        url: url,
        format: transcodingFormat(candidate),
        provider: "soundcloud",
        expires: "provider-controlled"
      };
    }
    return {
      success: false,
      error: "No full progressive SoundCloud stream; HLS-only source is unsupported"
    };
  } catch (error) {
    return { success: false, error: String(error && error.message || error) };
  }
}
"""

SOURCES = {
    "jellyfin": ("1.1.2", JELLYFIN_STREAM),
    "soundcloud": ("1.0.15", SOUNDCLOUD_STREAM),
}

def main(root: pathlib.Path) -> None:
    for name, (version, implementation) in SOURCES.items():
        source = root / "sources" / name / "index.js"
        manifest_path = root / "sources" / name / "manifest.json"
        js = source.read_text(encoding="utf-8")
        marker = "registerExtension({"
        assert js.count(marker) == 1, f"{name}: unexpected registerExtension layout"
        assert "function resolvePlaybackStream(" not in js, f"{name}: already patched"
        js = js.replace(
            marker,
            implementation + "\n" + marker + "\n  resolvePlaybackStream: resolvePlaybackStream,",
            1,
        )
        source.write_text(js, encoding="utf-8")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        assert manifest["name"] == name
        manifest["version"] = version
        manifest["displayName"] = str(manifest.get("displayName") or name) + " (Online)"
        manifest["description"] = (
            str(manifest.get("description") or "")
            + " Experimental full-track HTTPS in-app playback for authorized media."
        )
        manifest.setdefault("capabilities", {})["fullTrackStreaming"] = True
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Patched {name} v{version} with secure full-length playback")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("Usage: patch_multisource_online_extensions.py <registry-checkout>")
    main(pathlib.Path(sys.argv[1]).resolve())
