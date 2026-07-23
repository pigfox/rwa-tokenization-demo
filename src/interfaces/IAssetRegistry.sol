// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IAssetRegistry
/// @notice The single method redemption needs from the asset registry: whether
///         an asset id is registered and currently active for redemption.
interface IAssetRegistry {
    /// @notice True when `assetId` exists and its status is Active.
    function isActive(uint256 assetId) external view returns (bool);
}
