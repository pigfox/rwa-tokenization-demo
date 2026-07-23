# Slither detector exclusions

`slither.config.json` sets `"fail_on": "low"`, so CI reddens on any finding of
low severity or above that is **not** on the exclusion list below. Slither's
config file cannot hold comments, so the rationale for every excluded detector
lives here. With these four detectors excluded, a full run over `src/` reports
**zero results**.

Everything not listed here remains enabled — in particular reentrancy,
arbitrary-send, uninitialized-state, unchecked-transfer, tx-origin, and the
access-control detectors all run and must stay clean.

| Detector | Where it fires | Why it is excluded |
|---|---|---|
| `naming-convention` | `RWAToken.decimals` (constant), `RWAToken.identityRegistry` / `Redemption.token` / `Redemption.assetRegistry` (immutables) | ERC-20 fixes the public names `decimals`, `name`, `symbol` in lower case; renaming them to `SCREAMING_SNAKE_CASE` would break every ERC-20 consumer. The immutable registry/token handles are public getters that read most naturally in `mixedCase` and mirror the ERC-3643 naming. These are stylistic, not correctness, findings. |
| `solc-version` | every file's `pragma solidity 0.8.28;` | The pragma is pinned to a single exact version (no caret), which is the stricter, reproducible choice. Slither still emits an informational note about the compiler version generally; there is no action to take on a deliberately pinned modern release. |
| `timestamp` | `PriceOracle.latestPrice` / `PriceOracle.isStale` | A price oracle's staleness check is *defined* in terms of `block.timestamp`; that is the feature, not a bug. A miner can nudge the timestamp by a few seconds, which is immaterial to a staleness window measured in minutes or hours. No value transfer or authorization depends on the comparison. |
| `incorrect-equality` | `PriceOracle` `updatedAt == 0` | `updatedAt == 0` is a sentinel meaning "no price has ever been pushed" — `updatedAt` is only ever zero (never set) or a real block timestamp, so the strict equality is exact and safe. It gates a revert (`NoPrice`), never a fund movement. |

## Findings that were fixed rather than excluded

Two Slither findings from the first run were resolved in code, not suppressed:

- **`reentrancy-no-eth` / `reentrancy-events` in `Redemption.requestRedemption`** —
  the request record and event now land *before* the external `token.burnFrom`
  call (strict checks-effects-interactions). The burn reverts the whole call on
  insufficient balance, so state can never diverge from the token.
- **`missing-inheritance`** — `IdentityRegistry`, `AssetRegistry`, and `RWAToken`
  now explicitly inherit and `override` the interfaces (`IIdentityRegistry`,
  `IAssetRegistry`, `IRWAToken`) their siblings depend on, so the compiler
  enforces the surface the callers rely on.
