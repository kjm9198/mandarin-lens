export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // API: Version Check Endpoint for in-app updates
    if (url.pathname === "/api/version" || url.pathname === "/api/latest.json" || url.pathname === "/api/update") {
      const payload = {
        latestVersion: "4.3.0",
        releaseDate: "2026-10-31",
        changelog: "Added robust Polish bidirectional translation with instant offline dictionary and online fallback (fixes single-word Polish lookups like strajk), interactive live demo, slower speech playback, dual simultaneous translation, standalone Windows edition, and in-app update downloader.",
        macos: {
          version: "4.3.0",
          filename: "KamihiLens-4.3.0-macOS-arm64.dmg",
          url: `${url.origin}/download/macos/latest`,
          directUrl: `${url.origin}/downloads/KamihiLens-4.3.0-macOS-arm64.dmg`,
          sha256: "c3e370e6d255b977ce84a36dc9e82c77df74f4118e605c89171eb950912ca8ce",
          minOs: "macOS 15.0"
        },
        windows: {
          version: "4.3.0",
          filename: "KamihiLens-4.3.0-Windows-x64.zip",
          url: `${url.origin}/download/windows/latest`,
          directUrl: `${url.origin}/downloads/KamihiLens-4.3.0-Windows-x64.zip`,
          sha256: "d6a30d79b54ad9cbffc408ac623b6f25e546f5bd121e09c250159ae57897d7e2",
          minOs: "Windows 10 / 11"
        },
        earlierVersions: [
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
      return Response.redirect(`${url.origin}/downloads/KamihiLens-4.3.0-macOS-arm64.dmg`, 302);
    }

    // Direct download shortcut: latest Windows ZIP
    if (url.pathname === "/download/windows/latest" || url.pathname === "/download/windows") {
      return Response.redirect(`${url.origin}/downloads/KamihiLens-4.3.0-Windows-x64.zip`, 302);
    }

    // Static Assets serving (Website HTML, DMG/ZIP downloads, icons)
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    return new Response("Not found", { status: 404 });
  }
};
