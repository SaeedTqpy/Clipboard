# Security policy

Clipboard processes **sensitive copied content**. Treat this project as a **developer preview** until a security review and physical-macOS acceptance tests have been completed.

## Supported versions

| Version | Security maintenance |
| --- | --- |
| v0.2.x developer preview | Best-effort fixes; not production-certified |
| Older development artifacts | Not supported for secure use |

No stable security support SLA has been announced.

## Reporting a vulnerability

**Do not open a public issue containing an exploit, private clipboard data, database files, passwords, or other sensitive proof.** If GitHub's private vulnerability reporting is enabled for this repository, use **Security → Report a vulnerability**. Otherwise contact the repository maintainer privately via their GitHub profile; do not publish details until a private reporting channel is agreed.

Useful reports include a reproducible scenario with **synthetic content**, affected commit/OS, plausible security impact, and mitigations. Never attach real user secrets.

## Security model

- Encrypted clipboard content and image assets use **AES-256-GCM**. A device-bound key is stored in **macOS Keychain**, and keyed HMAC fingerprints help prevent offline guessing of repeated short clips.
- A portable `.clipbackup` is encrypted independently from the device key with a password-derived key. Backup passwords are not persisted by the app.
- History starts paused on first installation. App exclusions and concealed/transient pasteboard signals are only **best-effort**, since macOS clipboard provenance is not cryptographically authenticated.
- The app does not implement network telemetry, automatic cloud sync or content reporting.
- The app currently **does not enable App Sandbox** and development artifacts are **unsigned and not notarized**.
- Copy/paste integration may require macOS **Accessibility** privileges; those rights must be granted only after the user trusts the local app build.

## Limitations and non-goals

- Encrypted-at-rest storage cannot protect secrets already present in the macOS system clipboard, decrypted process memory, old backups, screenshots, APFS snapshots or SSD remnants.
- Keychain reset or losing the device's encryption key may make local encrypted history unrecoverable. Create and verify a password-protected portable backup before migration/reinstall.
- Source application identification is approximate. Some password managers do not flag confidential clipboard formats.
- The current app is not approved for storing authentication secrets, credentials or recovery phrases.
- This repository does not promise absence of vulnerabilities, protected memory, or guaranteed secure deletion.

## Release gate

Before recommending Clipboard for broad use, validate real-device permissions, secure-field interactions, safe app-source exclusions, backup recovery, schema migrations, protected pasteboard types, focus restoration, crash/energy behavior, and signing/notarization. See [docs/TEST_PLAN.md](docs/TEST_PLAN.md).
