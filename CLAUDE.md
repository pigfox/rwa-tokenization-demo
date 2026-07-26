# rwa-tokenization-demo — agent instructions

An ERC-3643-inspired real-world-asset token on Base Sepolia. Fractions of an asset trade as
an ERC-20 whose every mint and transfer is gated on an on-chain KYC identity registry, with
an asset registry attesting the off-chain backing, a push price oracle, and a redemption
ledger that burns against a registered asset. Hand-rolled Solidity (the T-REX suite is not
vendored). The public demo that reads these contracts lives in the `pigfox2` repo at
`/demos/rwa-tokenization`.

## Session tag (BINDING)
- First line of every response: the bare current tag from `.session-tag` (or UNTAGGED).
- Tag format `^(PF|MV|ZK)-S[0-9]+[a-z]?$`; this repo uses the `ZK` prefix. Rotate ONLY at
  session open: bump N (or same-day sub-letter), write `.session-tag`, INSERT a ledger
  session-open row with the tag in the payload. Never reuse/decrement. Never rotate mid-session.
- Every ledger INSERT includes the tag in its payload. Session-open: reconcile the ledger's
  latest tag against `.session-tag`; a mismatch is a stop.
- Work that spans this repo and `pigfox2` carries BOTH tags in the ledger row.
- Web-Claude directive blocks open with a tag guard line; if a pasted directive's tag
  mismatches `.session-tag` it exits 1 — re-request, don't force.
- `.session-tag` is gitignored: it is working-copy state, never committed.

## NO-FORK DOCTRINE (absolute)
- Nothing in this repo may fork a chain. No `vm.createFork` / `createSelectFork` /
  `selectFork` / `rollFork`, no `--fork-url`, no `anvil`, no `[rpc_endpoints]` block in
  `foundry.toml`, no local node. Tests are either pure-EVM unit/invariant tests or they
  run directly against Base Sepolia (84532).
- The token `rehears*` is unrelated to forking (it names a Stripe money-path spec in
  `pigfox2`). Never key a change on it.

## Secrets
- Private keys are write-only at the terminal: never in command output, ledger rows, git,
  `KEYS.md`, or any file that is not a gitignored `.env`.
- `.env` is gitignored and stays that way. Presence-check by NAME
  (`[ -n "$VAR" ] && echo present`), never echo a value.
- Role keys are the unified `DEMO_*` set documented in `../KEYS.md` (addresses only there).

## Demo invariants the site depends on
- Investor A is KYC-verified and holds the minted supply.
- Investor B is deliberately NEVER whitelisted — it exists so a correctly-formed transfer to
  it reverts, which is the showcase compliance block. Do not verify it.
- Whitelisting and minting are agent-only actions. The demo page offers no affordance for
  either, and must not gain one.
- `requestRedemption` burns the caller's own tokens via the token's `redeemer` role, so it
  needs no allowance. Asset 0 must stay registered and active — the site's redemption flow
  drills against it.

## Chain writes
- Never-assume-verify: a read-only check confirming the assumed state runs immediately
  before any state-changing transaction, in the same session. After a write, read the
  state back to confirm it.
- Confirm reachability with a read-only `eth_blockNumber` before any chain write.
- Testnet only. No mainnet key is involved anywhere in this repo.

## Gate
- `forge build` + `forge test` + `forge fmt --check`, plus Slither and Echidna as the repo
  already configures them. Solidity ships 100% covered — new code carries its tests in the
  same patch.
