# Release checklist

1. Confirm the intended version/build in `Resources/Info.plist`, review the
   complete release diff, and commit it. The release script refuses dirty
   checkouts and records the exact source commit.
2. Confirm `security find-identity -v -p codesigning` reports exactly one usable
   Developer ID Application identity, or set `APP_IDENTITY` explicitly.
3. Confirm `asc auth status` succeeds.
4. Run `./Scripts/sign-and-notarize.sh`. The script builds the app, checks for
   local checkout paths, signs with hardened runtime and a secure timestamp,
   submits through ASC, waits for acceptance, staples the ticket, and creates
   the release ZIP.
5. Confirm the script validates the exact extracted ZIP with `codesign`,
   Gatekeeper, and `stapler`, and confirms the version, build, and architecture.
6. Inspect the ZIP member list and confirm it contains only `BitcoinBar.app`,
   with no AppleDouble metadata, credentials, or private paths.
7. Launch the extracted app and smoke-test refresh, settings persistence,
   launch at login, and both detail popovers.
8. Tag the recorded source commit and upload only the verified ZIP plus its
   SHA-256 checksum to the GitHub release.
