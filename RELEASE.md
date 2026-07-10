# Release checklist

1. Build from a clean checkout with `./Scripts/package_app.sh release`.
2. Confirm the executable contains no local checkout path.
3. Sign with a Developer ID Application certificate and a secure timestamp.
4. Verify the signature, submit for notarization, and staple the accepted ticket.
5. Create the release ZIP from only `BitcoinBar.app`.
6. Inspect the ZIP member list and scan it for credentials and absolute home paths.
7. Upload only the verified ZIP to GitHub Releases.
