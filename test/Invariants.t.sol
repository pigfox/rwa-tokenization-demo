// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Properties} from "./Properties.sol";

/// @dev Foundry invariant runner over the shared {Properties} harness. The same
///      `echidna_*` predicates are re-asserted as Foundry invariants, and
///      {afterInvariant} proves the run actually exercised the token (a run that
///      never minted would pass the invariants vacuously).
contract InvariantsTest is Test {
    Properties internal props;

    function setUp() public {
        props = new Properties();
        targetContract(address(props));
    }

    function invariant_SupplyEqualsSumOfBalances() public view {
        assertTrue(props.echidna_supply_equals_sum_of_balances(), "supply == sum(balances)");
    }

    function invariant_UnverifiedNeverHolds() public view {
        assertTrue(props.echidna_unverified_never_holds(), "phantom balance == 0");
    }

    function invariant_OracleStampMonotonic() public view {
        assertTrue(props.echidna_oracle_stamp_monotonic(), "oracle stamp monotonic");
    }

    /// @dev Non-inertness guard: over a real run the fuzzer must have minted at
    ///      least once, otherwise the invariants above are vacuously true.
    function afterInvariant() public view {
        assertGt(props.ghostMintsView(), 0, "harness never minted - invariants vacuous");
    }
}
