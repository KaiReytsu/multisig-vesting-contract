// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title VestingContract
 * @dev A contract that locks tokens for a beneficiary with multi-signature release mechanism.
 * The tokens are released gradually according to a vesting schedule, and each release requires
 * approval from multiple authorized signers.
 */
contract VestingContract {
    // Struct to hold vesting schedule information
    struct VestingSchedule {
        address beneficiary;      // Address of the beneficiary
        uint256 totalAmount;      // Total amount of tokens to be vested
        uint256 startTime;        // Start time of the vesting period
        uint256 duration;         // Duration of the vesting period in seconds
        uint256 releasedAmount;   // Amount of tokens already released
        uint256 cliff;            // Cliff period in seconds
        bool revoked;             // Whether the vesting has been revoked
    }

    // Struct to track release approvals
    struct ReleaseRequest {
        uint256 requestId;        // Unique identifier for the request
        uint256 amount;           // Amount of tokens requested for release
        uint256 approvalCount;    // Number of approvals received
        bool executed;            // Whether the request has been executed
        mapping(address => bool) hasApproved; // Track which signers have approved
    }

    // State variables
    address public owner;
    address public tokenAddress;
    uint256 public requiredApprovals;
    uint256 public signerCount;
    uint256 public nextRequestId;
    
    mapping(address => bool) public isSigner;
    mapping(uint256 => ReleaseRequest) public releaseRequests;
    VestingSchedule public vestingSchedule;

    // Events
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event VestingScheduleCreated(address indexed beneficiary, uint256 totalAmount, uint256 startTime, uint256 duration, uint256 cliff);
    event ReleaseRequested(uint256 indexed requestId, uint256 amount);
    event ReleaseApproved(uint256 indexed requestId, address indexed signer);
    event TokensReleased(uint256 indexed requestId, address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unreleasedAmount);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlySigner() {
        require(isSigner[msg.sender], "Only signer can call this function");
        _;
    }

    modifier vestingActive() {
        require(!vestingSchedule.revoked, "Vesting has been revoked");
        _;
    }

    /**
     * @dev Constructor to initialize the vesting contract
     * @param _tokenAddress Address of the ERC20 token to be vested
     * @param _requiredApprovals Number of approvals required to release tokens
     */
    constructor(address _tokenAddress, uint256 _requiredApprovals) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        require(_requiredApprovals > 0, "Required approvals must be greater than zero");
        
        owner = msg.sender;
        tokenAddress = _tokenAddress;
        requiredApprovals = _requiredApprovals;
        
        // Add the owner as the first signer
        isSigner[msg.sender] = true;
        signerCount = 1;
        
        emit SignerAdded(msg.sender);
    }

    /**
     * @dev Add a new signer
     * @param _signer Address of the signer to add
     */
    function addSigner(address _signer) external onlyOwner {
        require(_signer != address(0), "Signer address cannot be zero");
        require(!isSigner[_signer], "Address is already a signer");
        
        isSigner[_signer] = true;
        signerCount++;
        
        emit SignerAdded(_signer);
    }

    /**
     * @dev Remove a signer
     * @param _signer Address of the signer to remove
     */
    function removeSigner(address _signer) external onlyOwner {
        require(isSigner[_signer], "Address is not a signer");
        require(signerCount > requiredApprovals, "Cannot remove signer: minimum required signers would not be met");
        
        isSigner[_signer] = false;
        signerCount--;
        
        emit SignerRemoved(_signer);
    }

    /**
     * @dev Change the required number of approvals
     * @param _requiredApprovals New number of required approvals
     */
    function changeRequiredApprovals(uint256 _requiredApprovals) external onlyOwner {
        require(_requiredApprovals > 0, "Required approvals must be greater than zero");
        require(_requiredApprovals <= signerCount, "Required approvals cannot exceed signer count");
        
        requiredApprovals = _requiredApprovals;
    }

    /**
     * @dev Create a vesting schedule
     * @param _beneficiary Address of the beneficiary
     * @param _totalAmount Total amount of tokens to be vested
     * @param _startTime Start time of the vesting period
     * @param _duration Duration of the vesting period in seconds
     * @param _cliff Cliff period in seconds
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _startTime,
        uint256 _duration,
        uint256 _cliff
    ) external onlyOwner {
        require(_beneficiary != address(0), "Beneficiary address cannot be zero");
        require(_totalAmount > 0, "Total amount must be greater than zero");
        require(_duration > 0, "Duration must be greater than zero");
        require(_cliff <= _duration, "Cliff must be less than or equal to duration");
        require(vestingSchedule.totalAmount == 0, "Vesting schedule already exists");
        
        vestingSchedule = VestingSchedule({
            beneficiary: _beneficiary,
            totalAmount: _totalAmount,
            startTime: _startTime,
            duration: _duration,
            releasedAmount: 0,
            cliff: _cliff,
            revoked: false
        });
        
        emit VestingScheduleCreated(_beneficiary, _totalAmount, _startTime, _duration, _cliff);
    }

    /**
     * @dev Calculate the amount of tokens that can be released
     * @return The amount of tokens that can be released
     */
    function calculateReleasableAmount() public view vestingActive returns (uint256) {
        if (block.timestamp < vestingSchedule.startTime + vestingSchedule.cliff) {
            return 0;
        }
        
        if (block.timestamp >= vestingSchedule.startTime + vestingSchedule.duration) {
            return vestingSchedule.totalAmount - vestingSchedule.releasedAmount;
        }
        
        uint256 timeFromStart = block.timestamp - vestingSchedule.startTime;
        uint256 vestedAmount = (vestingSchedule.totalAmount * timeFromStart) / vestingSchedule.duration;
        
        return vestedAmount - vestingSchedule.releasedAmount;
    }

    /**
     * @dev Request a release of tokens
     * @param _amount Amount of tokens to release
     */
    function requestRelease(uint256 _amount) external onlySigner vestingActive {
        require(vestingSchedule.totalAmount > 0, "No vesting schedule exists");
        require(_amount > 0, "Amount must be greater than zero");
        require(_amount <= calculateReleasableAmount(), "Requested amount exceeds releasable amount");
        
        uint256 requestId = nextRequestId++;
        
        ReleaseRequest storage request = releaseRequests[requestId];
        request.requestId = requestId;
        request.amount = _amount;
        request.approvalCount = 1;  // The requester automatically approves
        request.executed = false;
        request.hasApproved[msg.sender] = true;
        
        emit ReleaseRequested(requestId, _amount);
        emit ReleaseApproved(requestId, msg.sender);
        
        // If only one approval is required, execute immediately
        if (requiredApprovals == 1) {
            executeRelease(requestId);
        }
    }

    /**
     * @dev Approve a release request
     * @param _requestId ID of the release request to approve
     */
    function approveRelease(uint256 _requestId) external onlySigner vestingActive {
        ReleaseRequest storage request = releaseRequests[_requestId];
        
        require(!request.executed, "Request has already been executed");
        require(!request.hasApproved[msg.sender], "Signer has already approved this request");
        
        request.hasApproved[msg.sender] = true;
        request.approvalCount++;
        
        emit ReleaseApproved(_requestId, msg.sender);
        
        // Execute the release if enough approvals have been collected
        if (request.approvalCount >= requiredApprovals) {
            executeRelease(_requestId);
        }
    }

    /**
     * @dev Execute a release request
     * @param _requestId ID of the release request to execute
     */
    function executeRelease(uint256 _requestId) internal {
        ReleaseRequest storage request = releaseRequests[_requestId];
        
        require(!request.executed, "Request has already been executed");
        require(request.approvalCount >= requiredApprovals, "Not enough approvals");
        
        request.executed = true;
        vestingSchedule.releasedAmount += request.amount;
        
        // Transfer tokens to the beneficiary
        bool success = IERC20(tokenAddress).transfer(vestingSchedule.beneficiary, request.amount);
        require(success, "Token transfer failed");
        
        emit TokensReleased(_requestId, vestingSchedule.beneficiary, request.amount);
    }

    /**
     * @dev Revoke the vesting schedule
     * Only the owner can revoke the vesting schedule
     */
    function revoke() external onlyOwner vestingActive {
        vestingSchedule.revoked = true;
        
        uint256 unreleasedAmount = vestingSchedule.totalAmount - vestingSchedule.releasedAmount;
        
        // Transfer unreleased tokens back to the owner
        if (unreleasedAmount > 0) {
            bool success = IERC20(tokenAddress).transfer(owner, unreleasedAmount);
            require(success, "Token transfer failed");
        }
        
        emit VestingRevoked(vestingSchedule.beneficiary, unreleasedAmount);
    }
}

/**
 * @dev Interface for the ERC20 standard token
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
} 