# rwa-tokenization-demo

Real-world asset tokenization with KYC-gated transfers on Base Sepolia.

A minimal, ERC-3643-inspired stack for fractionalizing a real-world asset as a
compliant ERC-20: every acquisition of tokens is gated on an on-chain KYC
whitelist. Minting requires a verified recipient; transfers require **both**
parties verified. The suite is hand rolled — the T-REX reference suite is
deliberately **not** vendored — so every line is in scope, 100% covered, and
checked by Slither and Echidna.

A live web walkthrough with client-signed wallet writes is served at
**https://pigfox.com/demos/rwa-tokenization**.

## Live on Base Sepolia

Chain id `84532`. All five contracts are source-verified on Basescan.

| Contract | Address |
|---|---|
| IdentityRegistry | [`0x8FD97Ede1A00a35b2B74F0Ec84221C6791dd9b82`](https://sepolia.basescan.org/address/0x8FD97Ede1A00a35b2B74F0Ec84221C6791dd9b82) |
| AssetRegistry | [`0x4bB2186DCF0F41F98C1a8D302b35b7c90a44D024`](https://sepolia.basescan.org/address/0x4bB2186DCF0F41F98C1a8D302b35b7c90a44D024) |
| PriceOracle | [`0x5f307908D306987b0100b71b5de7B071D7b415Aa`](https://sepolia.basescan.org/address/0x5f307908D306987b0100b71b5de7B071D7b415Aa) |
| RWAToken (ACME) | [`0xf6d3fcecD5aa3AC8Dc77aF05FD4CC021171cCe32`](https://sepolia.basescan.org/address/0xf6d3fcecD5aa3AC8Dc77aF05FD4CC021171cCe32) |
| Redemption | [`0xcC74129807922abB787363D22955Ec1DebACa822`](https://sepolia.basescan.org/address/0xcC74129807922abB787363D22955Ec1DebACa822) |

Deployed at block **44520778**. Machine-readable addresses and the seeded
narrative transactions live in [`deployments/base-sepolia.json`](deployments/base-sepolia.json).

## The compliance model

Five small contracts, one shared access-control base:

- **IdentityRegistry** — the KYC whitelist. Agents `registerIdentity` /
  `removeIdentity`; the token calls `isVerified` on every mint and transfer. It
  is bound one-shot to the token (`setToken`) so a holder cannot be
  de-verified while still holding tokens.
- **RWAToken** — a fractional ERC-20 (18 decimals). `mint` requires a verified
  recipient; `transfer`/`transferFrom` require both parties verified; `burnFrom`
  is restricted to the redeemer.
- **AssetRegistry** — registrar-only attestation of the off-chain assets that
  back the token (document hash, metadata URI, lifecycle status).
- **PriceOracle** — a mock push oracle exposing a price and a staleness stamp.
- **Redemption** — burns tokens against an active asset (strict CEI) and records
  a request an admin later settles.
- **Roles** — one `owner` (governance) + a set of `agents` (operations). The
  deployer is owner and first agent of every contract, so in this demo every
  privileged role is the one deployer address.

The full threat model, security invariants, and tooling results are in
[`SECURITY.md`](SECURITY.md).

## The seeded narrative

On deploy the stack is seeded so the demo page has real state to read: the
deployer and Investor A are whitelisted, twelve backing assets are registered,
an oracle price is pushed, and 10,000 ACME are minted to Investor A. Investor B
is deliberately left **un-whitelisted and keyless**. Four transactions then tell
the compliance story:

| Step | Tx | Result |
|---|---|---|
| Mint 10,000 ACME to verified Investor A | [`0xe7387c0e…`](https://sepolia.basescan.org/tx/0xe7387c0e5f86684ffa0f0725729f317634ea65789ad458224089d57028f81a05) | success |
| Investor A → deployer, 1,000 ACME (both verified) | [`0x0990eedd…`](https://sepolia.basescan.org/tx/0x0990eedd081c155d351d5ccf9b3fccf400f97d74c5292dc1b8ca9b404ae18a54) | success |
| **Investor A → Investor B, 500 ACME (B not verified)** | [`0x034bccd1…`](https://sepolia.basescan.org/tx/0x034bccd19ef3ad82b7fb1dc7e3cfbc23bc9722261b64a4fb72b35255729f2557) | **reverts on-chain — the compliance block** |
| Investor A redeems 2,000 ACME against asset 0 | [`0x4cb2261d…`](https://sepolia.basescan.org/tx/0x4cb2261d57065794346efcb94b15be6d916ff6807453996791a9d90612a563d4) | success (burned) |

The reverting transfer is the showcase: an ordinary, correctly-formed ERC-20
transfer that the token itself refuses because the recipient is not KYC-verified.

## Cast one-liners

```bash
export RPC=https://sepolia.base.org
export TOKEN=0xf6d3fcecD5aa3AC8Dc77aF05FD4CC021171cCe32
export IDREG=0x8FD97Ede1A00a35b2B74F0Ec84221C6791dd9b82
export ASSETS=0x4bB2186DCF0F41F98C1a8D302b35b7c90a44D024
export ORACLE=0x5f307908D306987b0100b71b5de7B071D7b415Aa
export REDEEM=0xcC74129807922abB787363D22955Ec1DebACa822

# Token facts
cast call $TOKEN 'totalSupply()(uint256)'    --rpc-url $RPC
cast call $TOKEN 'balanceOf(address)(uint256)' 0x1aA17B67bE685BaBbe9DfE7abA44940b247756D6 --rpc-url $RPC

# Is an address KYC-verified?
cast call $IDREG 'isVerified(address)(bool)' <addr> --rpc-url $RPC

# Asset registry + oracle
cast call $ASSETS 'assetCount()(uint256)'    --rpc-url $RPC
cast call $ASSETS 'getAsset(uint256)((bytes32,string,uint8,bool))' 0 --rpc-url $RPC
cast call $ORACLE 'latestPrice()(uint256,uint256)' --rpc-url $RPC

# Redemptions
cast call $REDEEM 'requestCount()(uint256)'  --rpc-url $RPC
cast call $REDEEM 'getRequest(uint256)((address,uint256,uint256,bool,bool))' 0 --rpc-url $RPC
```

## Testing

| Gate | Command | Result |
|---|---|---|
| Unit + fuzz + invariant | `forge test` | 83 tests; 3 invariants at 16,384 calls each, 0 reverts |
| Coverage | `./scripts/coverage.sh` | 100% lines / statements / branches / functions across all six `src/` files |
| Static analysis | `slither . --config-file slither.config.json` | 0 results at `fail_on: low` |
| Property fuzzing | `echidna . --contract Properties --config echidna.yaml` | 3 properties passing over 100,000 calls |

A single harness, `test/Properties.sol`, is driven by both Foundry's invariant
runner and Echidna. The three properties: supply equals the sum of balances, a
never-verified address never holds a balance, and the oracle stamp is monotonic.
Slither's four excluded detectors are individually justified in
[`docs/slither-exclusions.md`](docs/slither-exclusions.md).

## Setup

Secrets live in `.env` (gitignored) — copy [`.env.example`](.env.example) and
populate it, or keep the real file in `../.env`, one directory above this repo,
so it can never be committed. **Nothing in the build, test, or CI path reads
these values**; they are needed only to deploy and to seed. No key is ever placed
on a server or in CI.

```bash
forge build
forge test
./scripts/coverage.sh          # 100% src/ gate
./scripts/deploy.sh            # deploy + seed to Base Sepolia (needs .env)
./scripts/seed-investor.sh     # the Investor-A-signed narrative txs
```

## Layout

```
src/                    Solidity contracts (Roles + the five system contracts)
  interfaces/           minimal interfaces the siblings depend on
test/                   unit + fuzz tests, Properties harness, Invariants runner
script/Deploy.s.sol     chain-id-guarded deploy + seed (deployer key)
scripts/                bash: deploy.sh, seed-investor.sh, coverage.sh
deployments/            committed record of addresses + narrative txs
docs/                   slither-exclusions.md
echidna.yaml            property-fuzzing config
slither.config.json     static-analysis config (fail_on: low)
```

## Licence

MIT. See [LICENSE](LICENSE).
