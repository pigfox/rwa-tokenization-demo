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
| IdentityRegistry | [`0xF34D21a506777BB65c31955D90940453C990597D`](https://sepolia.basescan.org/address/0xF34D21a506777BB65c31955D90940453C990597D) |
| AssetRegistry | [`0xCF6B60AD5C71c39270a17953277Da6419Dde4c96`](https://sepolia.basescan.org/address/0xCF6B60AD5C71c39270a17953277Da6419Dde4c96) |
| PriceOracle | [`0x0c61ecA41912a9B8d805c2AB55fCb5E461861fbF`](https://sepolia.basescan.org/address/0x0c61ecA41912a9B8d805c2AB55fCb5E461861fbF) |
| RWAToken (ACME) | [`0xb2D5BF6993d78793EFeb875E854602269D84626D`](https://sepolia.basescan.org/address/0xb2D5BF6993d78793EFeb875E854602269D84626D) |
| Redemption | [`0x5b6A9e4424Ccf10c6420CE9135E6D1e3e43ED250`](https://sepolia.basescan.org/address/0x5b6A9e4424Ccf10c6420CE9135E6D1e3e43ED250) |

Deployed at block **44641883**. Machine-readable addresses and the seeded
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
| Mint 10,000 ACME to verified Investor A | [`0xf17b7c6f…`](https://sepolia.basescan.org/tx/0xf17b7c6f57dc1c595f65b1844c43da5b79e4170ad5d8b82f87299fd008cf8627) | success |
| Investor A → deployer, 1,000 ACME (both verified) | [`0x895150f4…`](https://sepolia.basescan.org/tx/0x895150f45071d97ede20123e52ada39ed478b37c21e9cda69297c8ddf9302eba) | success |
| **Investor A → Investor B, 500 ACME (B not verified)** | [`0xf037a788…`](https://sepolia.basescan.org/tx/0xf037a7887d1682821732913194956f805d686f9845deb533f62061a493658ef2) | **reverts on-chain — the compliance block** |
| Investor A redeems 2,000 ACME against asset 0 | [`0xed22ff33…`](https://sepolia.basescan.org/tx/0xed22ff339d334a865fbfad98c55fc747ddf034a53e72246ac3ab6343306c4460) | success (burned) |

The reverting transfer is the showcase: an ordinary, correctly-formed ERC-20
transfer that the token itself refuses because the recipient is not KYC-verified.

## v1 deployment (retired 2026-07-26)

Everything above describes the deployment made on **2026-07-26**. An earlier one
ran from 2026-07-21 and is **retired**: its contracts are still on chain and keep
their own history, but nothing here reads them and none of the numbers above
belong to them. They are listed because the honest way to retire a deployment is
to say where it went, not to delete it.

| Contract | Retired address |
|---|---|
| IdentityRegistry | [`0x8FD97Ede1A00a35b2B74F0Ec84221C6791dd9b82`](https://sepolia.basescan.org/address/0x8FD97Ede1A00a35b2B74F0Ec84221C6791dd9b82) |
| AssetRegistry | [`0x4bB2186DCF0F41F98C1a8D302b35b7c90a44D024`](https://sepolia.basescan.org/address/0x4bB2186DCF0F41F98C1a8D302b35b7c90a44D024) |
| PriceOracle | [`0x5f307908D306987b0100b71b5de7B071D7b415Aa`](https://sepolia.basescan.org/address/0x5f307908D306987b0100b71b5de7B071D7b415Aa) |
| RWAToken (ACME) | [`0xf6d3fcecD5aa3AC8Dc77aF05FD4CC021171cCe32`](https://sepolia.basescan.org/address/0xf6d3fcecD5aa3AC8Dc77aF05FD4CC021171cCe32) |
| Redemption | [`0xcC74129807922abB787363D22955Ec1DebACa822`](https://sepolia.basescan.org/address/0xcC74129807922abB787363D22955Ec1DebACa822) |

Deployed at block 44520778. Its Investor A was
[`0x1aA17B67…`](https://sepolia.basescan.org/address/0x1aA17B67bE685BaBbe9DfE7abA44940b247756D6)
and its unverified Investor B
[`0xaF83046d…`](https://sepolia.basescan.org/address/0xaF83046d1B3FDDCF894E05Bc293E7f9dE26ee3ec).
The rotation that replaced every key and redeployed from scratch is recorded in
`pigfox2-repos/KEYS.md`.

## Cast one-liners

```bash
export RPC=https://sepolia.base.org
export TOKEN=0xb2D5BF6993d78793EFeb875E854602269D84626D
export IDREG=0xF34D21a506777BB65c31955D90940453C990597D
export ASSETS=0xCF6B60AD5C71c39270a17953277Da6419Dde4c96
export ORACLE=0x0c61ecA41912a9B8d805c2AB55fCb5E461861fbF
export REDEEM=0x5b6A9e4424Ccf10c6420CE9135E6D1e3e43ED250

# Token facts
cast call $TOKEN 'totalSupply()(uint256)'    --rpc-url $RPC
cast call $TOKEN 'balanceOf(address)(uint256)' 0xe2DA56b0f99bAfBC6c8E2c92f647F1F5ffBcc03E --rpc-url $RPC

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
