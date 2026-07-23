// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Roles} from "./Roles.sol";
import {IAssetRegistry} from "./interfaces/IAssetRegistry.sol";

/// @title AssetRegistry
/// @notice Registrar-only attestation of the off-chain real-world assets that
///         back the token. Each asset records a document hash, a metadata URI,
///         and a lifecycle status. Ids are assigned sequentially from zero, so
///         `assetCount` doubles as a cheap total for window-driven pagination.
contract AssetRegistry is Roles, IAssetRegistry {
    /*//////////////////////////////////////////////////////////////
                                  TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Lifecycle status of a registered asset.
    /// @dev `None` is the zero value and means "not registered".
    enum Status {
        None,
        Active,
        Suspended,
        Redeemed
    }

    /// @notice On-chain record attesting to an off-chain asset.
    struct Asset {
        bytes32 docHash;
        string uri;
        Status status;
        bool exists;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice No asset is registered under this id.
    error UnknownAsset(uint256 assetId);
    /// @notice A status update tried to set the zero (`None`) status.
    error InvalidStatus();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new asset is registered.
    event AssetRegistered(uint256 indexed assetId, bytes32 docHash, string uri);
    /// @notice Emitted when an asset's status changes.
    event AssetStatusUpdated(uint256 indexed assetId, Status previousStatus, Status newStatus);

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 assetId => Asset asset) private _assets;
    /// @notice Number of assets registered; also the id the next registration
    ///         will use. Enables O(perPage) pagination over the asset list.
    uint256 public assetCount;

    /// @param initialOwner The deployer; owner and first (registrar) agent.
    constructor(address initialOwner) Roles(initialOwner) {}

    /*//////////////////////////////////////////////////////////////
                                REGISTRAR
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a new asset with `docHash` and metadata `uri`. Starts Active.
    /// @return assetId The sequential id assigned to the new asset.
    function registerAsset(bytes32 docHash, string calldata uri)
        external
        onlyAgent
        returns (uint256 assetId)
    {
        assetId = assetCount;
        _assets[assetId] = Asset({docHash: docHash, uri: uri, status: Status.Active, exists: true});
        assetCount = assetId + 1;
        emit AssetRegistered(assetId, docHash, uri);
    }

    /// @notice Change the status of a registered asset. Cannot set `None`.
    function setAssetStatus(uint256 assetId, Status newStatus) external onlyAgent {
        Asset storage a = _assets[assetId];
        if (!a.exists) revert UnknownAsset(assetId);
        if (newStatus == Status.None) revert InvalidStatus();
        Status previous = a.status;
        a.status = newStatus;
        emit AssetStatusUpdated(assetId, previous, newStatus);
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice The full record for `assetId`. Reverts if unknown.
    function getAsset(uint256 assetId) external view returns (Asset memory) {
        Asset storage a = _assets[assetId];
        if (!a.exists) revert UnknownAsset(assetId);
        return a;
    }

    /// @notice True when `assetId` exists and its status is Active.
    function isActive(uint256 assetId) external view override returns (bool) {
        Asset storage a = _assets[assetId];
        return a.exists && a.status == Status.Active;
    }
}
