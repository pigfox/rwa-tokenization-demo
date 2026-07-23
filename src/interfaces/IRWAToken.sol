// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IRWAToken
/// @notice The subset of the token surface that sibling contracts depend on:
///         the identity registry reads balances to guard de-verification, and
///         the redemption contract burns tokens against a registered asset.
interface IRWAToken {
    /// @notice The token balance of `account`.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Burn `amount` tokens held by `from`. Restricted to the token's
    ///         configured redeemer.
    function burnFrom(address from, uint256 amount) external;
}
