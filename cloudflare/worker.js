export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // API: Version Check Endpoint for in-app updates
    if (url.pathname === "/api/version" || url.pathname === "/api/latest.json") {
      const payload = {
        latestVersion: "4.3.0",
        releaseDate: "2026-10-31",
        changelog: "Added simultaneous dual-target translation (English to Chinese and Polish), slower speech rate for clear comprehension, robust Polish bidirectional translation, standalone Windows edition, and in-app update downloader.",
        macos: {
          version: "4.3.0",
          filename: "KamihiLens-4.3.0-macOS-arm64.dmg",
          url: `${url.origin}/download/macos/latest`,
          directUrl: `${url.origin}/downloads/KamihiLens-4.3.0-macOS-arm64.dmg`,
          sha256: "e5c4f869d30fdf8f69eb0b34db932a9bc9efc92dc28d74e4f2ec17062c5b6c1e",
          minOs: "macOS 15.0"
        },
        windows: {
          version: "4.3.0",
          filename: "KamihiLens-4.3.0-Windows-x64.zip",
          url: `${url.origin}/download/windows/latest`,
          directUrl: `${url.origin}/downloads/KamihiLens-4.3.0-Windows-x64.zip`,
          sha256: "309afa6d8c65700bc985bee4c830fe27198c84bd01071d497a2d3e3756f81055",
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
