# Security Policy

Thank you for taking the time to help keep Bloccpay and its users safe.

## Reporting a vulnerability

**Please do NOT report security issues through public GitHub issues, discussions, or pull requests.**

Report vulnerabilities to: **`security@bloccpay.com`** <!-- TODO: confirm this is the right address -->

If you'd like to encrypt your report, our PGP key is available at: <!-- TODO: add PGP fingerprint or link, or delete this line if not applicable -->
`<PGP_FINGERPRINT_HERE>`

Please include as much of the following as you can:

- Type of issue (auth, injection, business-logic, cryptographic, etc.)
- Full paths / URLs of affected code
- Location of the affected source (branch, tag, commit, direct file link)
- Any special configuration required to reproduce
- Step-by-step reproduction
- Proof-of-concept or exploit code (if you have one)
- Impact — what an attacker could achieve

This helps us triage your report faster.

## Response

- **Acknowledgment:** within 72 hours of your report.
- **Initial assessment + severity:** within 5 business days.
- **Fix + release window:** depends on severity — typically 30 days for high/critical, longer for lower-severity issues.
- **Disclosure:** we coordinate a disclosure timeline with you. Default is 90 days from initial report or when a fix ships, whichever comes first.

## Scope

**In scope** <!-- TODO: confirm this list matches what we want researchers looking at -->:

- All private and public repositories under [github.com/BloccPay-org](https://github.com/BloccPay-org)
- Production web app (`https://app.bloccpay.com` — TODO: confirm domain)
- Production API (`https://api.bloccpay.com` — TODO: confirm domain)
- Marketing / website (`https://bloccpay.com`)
- Backoffice / admin surface (auth boundary, session handling, IDOR)

**Out of scope**:

- Denial-of-service testing against production
- Physical attacks against Bloccpay staff or premises
- Social-engineering of Bloccpay staff, users, or partners
- Third-party services (Dojah, Blockradar, Bridge, Paycrest, Onramp.money, Stellar SDK) — report directly to those providers
- Reports from automated scanners without validated impact
- Missing security headers with no proven exploit chain

## Safe harbor

We will not pursue legal action against researchers who:

- Make a good-faith effort to avoid privacy violations, degradation, or data loss
- Report the issue promptly to `security@bloccpay.com`
- Do not disclose the issue publicly until we have coordinated disclosure
- Do not access user data beyond what's necessary to demonstrate the vulnerability

## Recognition

We do not currently run a paid bug bounty program. <!-- TODO: if that changes, edit this section -->
We are happy to acknowledge researchers in release notes / this file (with permission) once an issue is fixed.

<!-- TODO: consider adding hall of fame section once we have real reporters -->

---

*Last updated: 2026-07-02*
