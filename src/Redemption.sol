// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Roles} from "./Roles.sol";
import {IRWAToken} from "./interfaces/IRWAToken.sol";
import {IAssetRegistry} from "./interfaces/IAssetRegistry.sol";

/// @title Redemption
/// @notice Lets a holder burn tokens against a registered, active asset in
///         exchange for an off-chain settlement. A request records who redeemed
///         how much of which asset; an admin agent later marks it settled once
///         the off-chain leg completes. Requests are sequential from zero, so
///         `requestCount` is a cheap total for window-driven pagination.
contract Redemption is Roles {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The asset is not registered or not currently active.
    error AssetNotActive(uint256 assetId);
    /// @notice A redemption for zero tokens was requested.
    error ZeroAmount();
    /// @notice No request exists under this id.
    error UnknownRequest(uint256 requestId);
    /// @notice The request was already settled.
    error AlreadySettled(uint256 requestId);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a holder burns tokens to request redemption.
    event RedemptionRequested(
        uint256 indexed requestId, address indexed holder, uint256 indexed assetId, uint256 amount
    );
    /// @notice Emitted when an admin settles a redemption request.
    event RedemptionSettled(uint256 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                                  TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice A recorded redemption request.
    struct Request {
        address holder;
        uint256 assetId;
        uint256 amount;
        bool settled;
        bool exists;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The token burned on redemption.
    IRWAToken public immutable token;
    /// @notice The registry consulted to confirm an asset is active.
    IAssetRegistry public immutable assetRegistry;

    mapping(uint256 requestId => Request request) private _requests;
    /// @notice Number of redemption requests recorded; also the next request id.
    uint256 public requestCount;

    /// @param token_ The RWA token address (non-zero).
    /// @param assetRegistry_ The asset registry address (non-zero).
    /// @param initialOwner The deployer; owner and first (admin) agent.
    constructor(address token_, address assetRegistry_, address initialOwner) Roles(initialOwner) {
        if (token_ == address(0) || assetRegistry_ == address(0)) revert ZeroAddress();
        token = IRWAToken(token_);
        assetRegistry = IAssetRegistry(assetRegistry_);
    }

    /*//////////////////////////////////////////////////////////////
                                REDEEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Burn `amount` of the caller's tokens against active `assetId` and
    ///         record a redemption request.
    /// @return requestId The sequential id assigned to the new request.
    function requestRedemption(uint256 assetId, uint256 amount) external returns (uint256 requestId) {
        // Checks.
        if (amount == 0) revert ZeroAmount();
        if (!assetRegistry.isActive(assetId)) revert AssetNotActive(assetId);

        // Effects: record the request before the external burn (strict CEI). If
        // the burn reverts (caller lacks the balance) the whole call reverts and
        // this write is rolled back, so state can never diverge from the token.
        requestId = requestCount;
        _requests[requestId] =
            Request({holder: msg.sender, assetId: assetId, amount: amount, settled: false, exists: true});
        requestCount = requestId + 1;
        emit RedemptionRequested(requestId, msg.sender, assetId, amount);

        // Interaction: burn the caller's own tokens against the asset. Only the
        // caller's holding can be redeemed because `holder` is msg.sender.
        token.burnFrom(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                SETTLE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mark a redemption request settled once the off-chain leg completes.
    function settleRedemption(uint256 requestId) external onlyAgent {
        Request storage r = _requests[requestId];
        if (!r.exists) revert UnknownRequest(requestId);
        if (r.settled) revert AlreadySettled(requestId);
        r.settled = true;
        emit RedemptionSettled(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                                  VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice The full record for `requestId`. Reverts if unknown.
    function getRequest(uint256 requestId) external view returns (Request memory) {
        Request storage r = _requests[requestId];
        if (!r.exists) revert UnknownRequest(requestId);
        return r;
    }
}
