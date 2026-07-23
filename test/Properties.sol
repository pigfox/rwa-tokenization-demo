// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {PriceOracle} from "../src/PriceOracle.sol";

/// @title Properties
/// @notice A single property harness driven by BOTH engines: Foundry's
///         invariant runner (via {Invariants}) and Echidna. It deploys the RWA
///         system, holds the owner/agent AND redeemer roles itself, and exposes
///         action functions the fuzzer calls plus `echidna_*` predicates.
/// @dev The harness is the privileged caller for every action, so the fuzzer's
///      arbitrary `msg.sender` never needs the agent role — it drives token
///      state exclusively through these wrapped calls. `PHANTOM` is deliberately
///      left unverified: no action can ever give it a balance, which is the
///      transfer-hook invariant made concrete.
contract Properties {
    IdentityRegistry internal immutable IDENTITY;
    RWAToken internal immutable TOKEN;
    PriceOracle internal immutable ORACLE;

    uint256 internal constant NUM_HOLDERS = 4;
    /// @notice The one address that is never KYC-verified.
    address internal constant PHANTOM = address(0xBAD);

    address[NUM_HOLDERS] internal holders;

    // Ghost state proving the run was not inert + tracking oracle monotonicity.
    uint256 internal ghostMints;
    uint256 internal ghostTransfers;
    uint256 internal ghostBurns;
    uint256 internal lastOracleStamp;

    constructor() {
        IDENTITY = new IdentityRegistry(address(this));
        TOKEN = new RWAToken("RWA Property", "RWAP", address(IDENTITY), address(this));
        ORACLE = new PriceOracle(address(this));
        IDENTITY.setToken(address(TOKEN));
        TOKEN.setRedeemer(address(this)); // harness burns directly in `burn`

        // The harness itself must be verified to hold and transfer tokens.
        IDENTITY.registerIdentity(address(this));
        for (uint256 i = 0; i < NUM_HOLDERS; i++) {
            address h = address(uint160(uint256(keccak256(abi.encode("holder", i)))));
            holders[i] = h;
            IDENTITY.registerIdentity(h);
        }
        // PHANTOM is intentionally NOT registered.
    }

    /*//////////////////////////////////////////////////////////////
                                ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint bounded tokens to the harness (a verified holder).
    function mintToSelf(uint256 amount) public {
        amount = _bound(amount);
        TOKEN.mint(address(this), amount);
        ghostMints++;
    }

    /// @notice Mint bounded tokens directly to a verified holder.
    function mintToHolder(uint256 who, uint256 amount) public {
        amount = _bound(amount);
        TOKEN.mint(holders[who % NUM_HOLDERS], amount);
        ghostMints++;
    }

    /// @notice Move tokens from the harness to a verified holder.
    function distribute(uint256 who, uint256 amount) public {
        uint256 bal = TOKEN.balanceOf(address(this));
        if (bal == 0) return;
        amount = amount % (bal + 1);
        TOKEN.transfer(holders[who % NUM_HOLDERS], amount);
        ghostTransfers++;
    }

    /// @notice Burn tokens from a holder (harness is the redeemer).
    function burn(uint256 who, uint256 amount) public {
        address h = holders[who % NUM_HOLDERS];
        uint256 bal = TOKEN.balanceOf(h);
        if (bal == 0) return;
        amount = amount % (bal + 1);
        TOKEN.burnFrom(h, amount);
        ghostBurns++;
    }

    /// @notice Attempt to mint to the never-verified PHANTOM. Must always revert.
    function tryMintPhantom(uint256 amount) public {
        amount = _bound(amount);
        try TOKEN.mint(PHANTOM, amount) {
            // A successful mint to PHANTOM would break the transfer-hook invariant.
            revert("phantom mint succeeded");
        } catch {
            // expected
        }
    }

    /// @notice Push a bounded price; records the stamp for the monotonic check.
    function pushPrice(uint256 p) public {
        ORACLE.setPrice(p % 1_000_000);
        lastOracleStamp = ORACLE.updatedAt();
    }

    /*//////////////////////////////////////////////////////////////
                              PROPERTIES
    //////////////////////////////////////////////////////////////*/

    /// @notice totalSupply always equals the sum of every account's balance.
    function echidna_supply_equals_sum_of_balances() public view returns (bool) {
        uint256 sum = TOKEN.balanceOf(address(this)) + TOKEN.balanceOf(PHANTOM);
        for (uint256 i = 0; i < NUM_HOLDERS; i++) {
            sum += TOKEN.balanceOf(holders[i]);
        }
        return sum == TOKEN.totalSupply();
    }

    /// @notice The never-verified PHANTOM can never hold a non-zero balance.
    function echidna_unverified_never_holds() public view returns (bool) {
        return TOKEN.balanceOf(PHANTOM) == 0;
    }

    /// @notice The oracle timestamp never moves backwards.
    function echidna_oracle_stamp_monotonic() public view returns (bool) {
        return ORACLE.updatedAt() >= lastOracleStamp;
    }

    /// @notice Number of mints the fuzzer has driven; used by the non-inertness guard.
    function ghostMintsView() external view returns (uint256) {
        return ghostMints;
    }

    /// @notice Number of transfers the fuzzer has driven.
    function ghostTransfersView() external view returns (uint256) {
        return ghostTransfers;
    }

    /// @notice Number of burns the fuzzer has driven.
    function ghostBurnsView() external view returns (uint256) {
        return ghostBurns;
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _bound(uint256 amount) internal pure returns (uint256) {
        // Keep amounts in a range that can never overflow uint256 supply.
        return amount % (1_000_000 ether);
    }
}
