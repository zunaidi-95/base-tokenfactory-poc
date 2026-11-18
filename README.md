# T2-F01 — TokenFactory deploy is permissionless: anyone can deploy a counterfeit "official" wrapped token

Foundry proof-of-concept for a Low-severity finding (Tier 1) in the
Coinbase / Base bug bounty program (Cantina).

**The bug:** `TokenFactory` (`0x0000D340e876e1De249CcA0FD91d91aE612741E8`,
Base) lets any EOA CREATE2-deploy a FiatTokenV2_2 proxy with an arbitrary
name/symbol (e.g. "Coinbase Wrapped BTC" / "cbBTC"), arbitrary decimals, and
itself as owner/masterMinter/pauser/blacklister/proxy-admin — then mint
unlimited tokens. The deployed token shares the exact implementation
(`0xCA7658A2…`, same as the genuine cbADA) and deployment provenance (created
by Coinbase's TokenFactory) as genuine wrapped tokens. No existing user funds
are directly at risk; loss requires a victim to trust/buy the counterfeit
(official-factory provenance is the deception primitive) and/or a
future-launch salt squat.

## Setup

Install the dependency (pinned in `foundry.lock`), then run the tests:

```sh
forge install foundry-rs/forge-std@v1.17.0
forge test
```

Expected: **17 passed, 0 failed** (stable across repeat runs).

Each test file selects its fork in `setUp()` via the `[rpc_endpoints]` in
`foundry.toml` (`base = https://mainnet.base.org`,
`mainnet = https://ethereum.publicnode.com`):

- Base fork block: **59038136** (2026-11-18)
- Ethereum fork block: **26441372** (2026-11-18)

To use different RPCs, set `BASE_RPC_URL` / `MAINNET_RPC_URL`. Local fork
only — nothing is sent to mainnet. Forge 1.9.0, solc 0.8.33. `forge-std`
v1.17.0 is installed with `forge install` (see Setup above, pinned in
`foundry.lock`) — nothing is vendored under `lib/` in this repo.

## Tests

`test/T2Fork.t.sol` (3 tests, Base fork) — the finding:

- `test_TF_permissionlessDeploy` — an unprivileged EOA deploys a
  FiatTokenV2_2 proxy via TokenFactory `0x0000D340…` with name "Coinbase
  Wrapped BTC" / symbol "cbBTC" and itself as owner/masterMinter/pauser/
  blacklister.
- `test_TF_deployedTokenMintableByAttacker` — the deployed counterfeit token
  is mintable by the attacker (changeAdmin to a dead address first, because a
  proxy admin cannot call token fallback functions; then configureMinter +
  mint 1000 cbBTC).
- `test_MFF_permissionlessDeploy` — companion observation (NOT part of this
  submission): an unprivileged EOA can also deploy a MintForwarder via
  MintForwarderFactory `0x000054fC…` pointing at cbBTC with itself as owner.
  It is included because it ships in the same suite; it is reported
  separately as an Informational companion, not with this finding.

`test/T2Controls.t.sol` (8 tests, Base fork) — negative controls: V2_2
approve-from-blacklisted confirmation + initialize/mint/pause/blacklist/
configureMinter all revert for unprivileged callers.

`test/T2EthControls.t.sol` (6 tests, Ethereum fork) — Ethereum negative
controls (cbETH mint, MintForwarder mint, exchange-rate updates) + ERU
allowance-bound enforcement (rate + 11e18 reverts against a 10e18 allowance).

## Affected contract (Base mainnet, Tier 1 scope)

| Contract | Address |
|---|---|
| `TokenFactory` | `0x0000D340e876e1De249CcA0FD91d91aE612741E8` |
| Live wrapped-token implementation (FiatTokenV2_2) | `0xCA7658A2…` |

Deploy function selector: `0xba81b8b0`.

## Live-configuration evidence

The factory has no owner storage (slots 1–5 are zero) and no CALLER/ORIGIN
check in the full disassembly. Its sole historical caller is the Coinbase
Deployer `0x480E47Da…` (1 transaction ever, deploying cbADA, tx
`0x2441b60f…`, block 30188657, salt `0xddaa2cdcff0fdd02b3d587`). The live
implementation slot is `0xCA7658A2…` — the genuine wrapped-token
implementation. The factory contracts postdate the August 2022 OpenZeppelin
cbETH audit and are outside its scope. No privileged accounts are used: all
attacker actions are `vm.prank` as unprivileged EOAs; the only "admin" call
is the attacker administering its OWN freshly deployed proxy.
