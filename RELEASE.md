# Release checklist

1. Build from a clean checkout with `./Scripts/package_app.sh release`.
2. Confirm the executable contains no local checkout path.
3. Sign with a Developer ID Application certificate and a secure timestamp.
4. Verify the strict signature and submit the app for notarization.
5. Create the release ZIP from only `BitcoinBar.app`.
6. Extract the ZIP and verify its Developer ID signature and Gatekeeper status.
7. Scan the ZIP for credentials and absolute home paths.
8. Upload only the verified ZIP to GitHub Releases.
