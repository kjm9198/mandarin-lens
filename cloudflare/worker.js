export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // API: Version Check Endpoint for in-app updates
    if (url.pathname === "/api/version" || url.pathname === "/api/latest.json" || url.pathname === "/api/update") {
      const payload = {
        latestVersion: "4.3.2",
        releaseDate: "2026-11-03",
        changelog: "Fixed screen OCR text selection, resolved drag jitter vs click detection, added automatic Vision recognition recovery, and updated release packages.",
        macos: {
          version: "4.3.2",
          filename: "KamihiLens-4.3.2-macOS-arm64.dmg",
          url: `${url.origin}/download/macos/latest`,
          directUrl: `${url.origin}/downloads/KamihiLens-4.3.2-macOS-arm64.dmg`,
          sha256: "26d8fc0b93e4f0c2b508c0a94ac19901dc77165aec57f771f9811ea8c4094a9b",
          minOs: "macOS 15.0"
        },
        windows: {
          version: "4.3.2",
          filename: "KamihiLens-4.3.2-Windows-x64.zip",
          url: `${url.origin}/download/windows/latest`,
          directUrl: `${url.origin}/downloads/KamihiLens-4.3.2-Windows-x64.zip`,
          sha256: "d8dc847cfe912b3d6752fc950d0282a6cad90cacfe77e2ff83d78993c40db5cb",
          minOs: "Windows 10 / 11"
        },
        earlierVersions: [
          {
            version: "4.3.1",
            macosUrl: `${url.origin}/downloads/KamihiLens-4.3.1-macOS-arm64.dmg`,
            sha256: "39f6285ab52390135f1d6f9decc22dc8fa1c2c117b8004d1f81fe63851ddfb0d"
          },
          {
            version: "4.3.0",
            macosUrl: `${url.origin}/downloads/KamihiLens-4.3.0-macOS-arm64.dmg`,
            sha256: "a6ffa6898f463d78d8a0262322281016658fe98cd29bf7cea0e9d97808fad73c"
          },
          {
            version: "4.2.0",
            macosUrl: `${url.origin}/downloads/KamihiLens-4.2.0-macOS-arm64.dmg`,
            sha256: "34e345ad8b1b8382c30f56c01af90ccdf38f093f2116214603e0b0f878c39a3b"
          },
          {
            version: "4.1.0",
            macosUrl: `${url.origin}/downloads/KamihiLens-4.1.0-macOS-arm64.dmg`,
            sha256: "97174c2119e93f4801ef3a2a549c740b888eb96cc50924de2632e3f8ede89a73"
          },
          {
            version: "4.0.0",
            macosUrl: `${url.origin}/downloads/KamihiLens-4.0.0-macOS-arm64.dmg`,
            sha256: "ebb2bfa0d05183af7c22c00884f9c5f41480b40219788b4b0e6d008f5f90ab2b"
          }
        ]
      };

      return new Response(JSON.stringify(payload, null, 2), {
        headers: {
          "content-type": "application/json; charset=utf-8",
          "access-control-allow-origin": "*",
          "cache-control": "public, max-age=60"
        }
      });
    }

    // Direct download shortcut: latest macOS DMG
    if (url.pathname === "/download/macos/latest" || url.pathname === "/download/macos") {
      return Response.redirect(`${url.origin}/downloads/KamihiLens-4.3.2-macOS-arm64.dmg`, 302);
    }

    // Direct download shortcut: latest Windows ZIP
    if (url.pathname === "/download/windows/latest" || url.pathname === "/download/windows") {
      return Response.redirect(`${url.origin}/downloads/KamihiLens-4.3.2-Windows-x64.zip`, 302);
    }

    // Static Assets serving (Website HTML, DMG/ZIP downloads, icons)
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    return new Response("Not found", { status: 404 });
  }
};
