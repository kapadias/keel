# ADR 0010 — The harness is Nonna

- **Status:** Accepted
- **Date:** 2026-09-24
- **Deciders:** Shashank Kapadia

## Context

The harness shipped as Keel, a ship's part that resists capsizing. The metaphor was accurate and
forgettable: nobody pictures a keel, and a README cannot give it a voice. What the harness does is
closer to a person than to a part. It tastes everything before it leaves the kitchen, it believes
nothing on your word, and it has seen every shortcut go wrong.

## Decision

The harness is **Nonna**: the grandmother who runs the kitchen. The name carries a character, a voice
and a mascot. The plugin id becomes `nonna@nonna`; environment variables become `NONNA_*`; scripts,
functions and docs follow. Gate messages lead with one short line in her voice and keep the exact
technical reason after it, so a log stays greppable. Slash commands, skill names and file layout are
unchanged. The GitHub repository name is the owner's to change; GitHub redirects the old URLs.

## Consequences

- Existing plugin installs must reinstall under the new id, and anyone who set `KEEL_CRITICAL_PATHS`
  sets `NONNA_CRITICAL_PATHS` instead. There is no alias: the harness had one public release.
- The voice lives in the README, the artwork and the first line of a gate message. The rules and
  agent prompts stay plain, because they are instructions, not copy.
