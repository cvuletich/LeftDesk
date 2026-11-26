# LeftDesk 1.1

Free macOS menu bar utility for desktop icon alignment. https://leftdesk.cvuletich.com

## Build and test

On macOS with current Command Line Tools:

```sh
chmod +x build-dmg.sh
./build-dmg.sh --free
open dist/LeftDesk-1.1.dmg
```

The universal build targets macOS 13+; Intel and minimum OS are not yet verified. The free build is ad-hoc signed, not Developer ID signed or notarized. Test a browser-downloaded DMG on another Mac before publishing. Quit/remove duplicate older copies, then drag the app into Applications. If blocked, consult https://support.apple.com/en-us/102445 and only use Open Anyway if you trust the file. Managed Macs may disallow this. Never disable Gatekeeper globally. Grant Finder automation when prompted; updates may require renewed permission.

`--local` produces a separately named local-test image. `--release` requires Developer ID Application signing and a notarytool Keychain profile (SIGN_IDENTITY and NOTARY_PROFILE); the paid route remains available later. All modes derive the output version from Info.plist.

Run portable logic tests:

```sh
swiftc source/Grid.swift source/Tests/main.swift -o /tmp/leftdesk-tests
/tmp/leftdesk-tests
```

## Publish website

Back up the live website before replacing it. The website folder contains the static page, icon and update manifest. Copy the built DMG and checksum into it:

```sh
cp dist/LeftDesk-1.1.dmg dist/LeftDesk-1.1.dmg.sha256 website/
```

Upload the DMG and checksum first, then index.html and icon.png, and updates.json last. Preserve any older downloads you wish to support. Test the public URLs over HTTPS. Verify the downloaded checksum with `shasum -a 256 -c LeftDesk-1.1.dmg.sha256` in the download directory. A checksum detects corruption but is not an independent proof of publisher identity.

## Updates

Check for Updates… fetches https://leftdesk.cvuletich.com/updates.json. Optional checks at launch are off by default. Only numeric versions are supported. A newer version displays release notes and opens the fixed official website if the user chooses; no downloaded code is installed automatically. For the next release, update Info.plist short version and build number, both website download links and checksum link, and updates.json. Publish the manifest last. To test a newer-version notification without advertising a nonexistent release publicly, temporarily point a development copy at a staging feed. Test manual checks, opt-in startup checks, offline behavior and preservation of settings.

## Source publication and donations

This package is GitHub-ready but no repository or donation account has been created. Review the code and choose a license before publishing (MIT is a permissive option; no license is included until approved). The website Support section contains an HTML comment marking where to add verified GitHub and donation URLs. Use your personal GitHub account rather than a work organization. Keep signing credentials and build artifacts out of source control. No donations are required to use LeftDesk.

## Privacy

Desktop data stays local. Manual or opt-in startup update checks contact the website; ordinary web server logs may record request metadata. No telemetry or automatic installation is included.
