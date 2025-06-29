// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title Mock Across Protocol Spoke Pool for testing
contract MockSpokePool {
    mapping(bytes32 => bool) public bridgeRequests;
    mapping(address => uint256) public bridgeFees;
    
    uint256 public bridgeDelay = 300; // 5 minutes
    bool public bridgeEnabled = true;
    
    event BridgeInitiated(
        bytes32 indexed bridgeId,
        address indexed token,
        uint256 amount,
        uint256 destinationChain,
        address recipient
    );
    
    event BridgeCompleted(bytes32 indexed bridgeId);
    event BridgeFailed(bytes32 indexed bridgeId, string reason);

    // V3SpokePool interface function expected by AcrossIntegration
    function depositV3(
        address, // depositor - unused
        address recipient,
        address inputToken,
        address, // outputToken - unused
        uint256 inputAmount,
        uint256, // outputAmount - unused
        uint256 destinationChainId,
        address, // exclusiveRelayer - unused
        uint32,  // quoteTimestamp - unused
        uint32,  // fillDeadline - unused
        uint32,  // exclusivityDeadline - unused
        bytes calldata // message - unused
    ) external payable {
        require(bridgeEnabled, "Bridge disabled");
        require(inputAmount > 0, "Invalid amount");
        
        _executeBridge(inputToken, inputAmount, destinationChainId, recipient);
    }
    
    function _executeBridge(
        address inputToken,
        uint256 inputAmount,
        uint256 destinationChainId,
        address recipient
    ) internal {
        bytes32 bridgeId = keccak256(abi.encodePacked(
            inputToken,
            inputAmount,
            destinationChainId,
            recipient,
            block.timestamp
        ));
        
        bridgeRequests[bridgeId] = true;
        
        emit BridgeInitiated(bridgeId, inputToken, inputAmount, destinationChainId, recipient);
    }

    function initiateBridge(
        address token,
        uint256 amount,
        uint256 destinationChain,
        address recipient
    ) external returns (bytes32 bridgeId) {
        require(bridgeEnabled, "Bridge disabled");
        require(amount > 0, "Invalid amount");
        
        bridgeId = keccak256(abi.encodePacked(
            token,
            amount,
            destinationChain,
            recipient,
            block.timestamp
        ));
        
        bridgeRequests[bridgeId] = true;
        
        emit BridgeInitiated(bridgeId, token, amount, destinationChain, recipient);
        return bridgeId;
    }
    
    function completeBridge(bytes32 bridgeId) external {
        require(bridgeRequests[bridgeId], "Invalid bridge ID");
        
        bridgeRequests[bridgeId] = false;
        emit BridgeCompleted(bridgeId);
    }
    
    function failBridge(bytes32 bridgeId, string memory reason) external {
        require(bridgeRequests[bridgeId], "Invalid bridge ID");
        
        bridgeRequests[bridgeId] = false;
        emit BridgeFailed(bridgeId, reason);
    }
    
    function setBridgeFee(address token, uint256 fee) external {
        bridgeFees[token] = fee;
    }
    
    function getBridgeFee(address token, uint256 amount) external view returns (uint256) {
        return bridgeFees[token] + (amount * 10) / 10000; // 0.1% + base fee
    }
    
    function setBridgeEnabled(bool enabled) external {
        bridgeEnabled = enabled;
    }
    
    function setBridgeDelay(uint256 delay) external {
        bridgeDelay = delay;
    }
}