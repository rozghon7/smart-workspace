//SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title Multisignature Contract
/// @author @rozgon7
/// @notice This contract allows multiple signers to approve and execute transfers
contract MultiSign {
    /// @notice The number of signers required to execute a transfer
    uint256 public quorum;
    /// @notice The total number of transfers initiated
    uint256 public transfersCount;

    /// @notice Constructor to initialize the contract with signers and quorum
    /// @param _signers An array of addresses that are allowed to sign transfers
    /// @param _quorum The number of approvals required to execute a transfer
    constructor(address[] memory _signers, uint256 _quorum) {
        if (_signers.length == 0) revert SignersLengthMustBeGreaterThanZero();
        if (_quorum > _signers.length) revert SignersLengthCantBeLessThanQuorum();
        if (_quorum == 0) revert QuorumMustBeGreaterThanZero();

        quorum = _quorum;

        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), SignerAddressCannotBeZero());
            isSigner[_signers[i]] = true;
        }
    }

    /// @notice Emitted when a transfer is initiated
    /// @param transferId The unique identifier for the transfer
    /// @param to The address to which the transfer is made
    /// @param amount The amount of the transfer
    event TransferInitiated(uint256 indexed transferId, address indexed to, uint256 amount);

    /// @notice Emitted when a transfer is approved by a signer
    /// @param transferId The unique identifier for the transfer
    /// @param signer The address of the signer who approved the transfer
    event TransferApproved(uint256 indexed transferId, address indexed signer);

    /// @notice Emitted when a transfer is executed
    /// @param transferId The unique identifier for the transfer
    /// @param to The address to which the transfer is made
    /// @param amount The amount of the transfer
    event TransferExecuted(uint256 indexed transferId, address indexed to, uint256 amount);

    /// @notice Reverts with an error if the number of signers is less than the quorum
    error SignersLengthCantBeLessThanQuorum();
    /// @notice Reverts with an error if the number of signers is zero
    error SignersLengthMustBeGreaterThanZero();
    /// @notice Reverts with an error if the quorum is zero
    error QuorumMustBeGreaterThanZero();
    /// @notice Reverts with an error if the caller is not a signer
    error OnlySignerAllowed();
    /// @notice Reverts with an error if the transfer address is zero
    error TransferToCannotBeZeroAddress();
    /// @notice Reverts with an error if the transfer amount is zero
    error TransferAmountMustBeGreaterThanZero();
    /// @notice Reverts with an error if the signer address is zero
    error SignerAddressCannotBeZero();
    /// @notice Reverts with an error if the transfer has already been executed
    /// @param _transferId The ID of the transfer that has already been executed
    error TransferAlreadyExecuted(uint256 _transferId);
    /// @notice Reverts with an error if the signer has already approved the transfer
    error AlreadyApprovedBySigner();
    /// @notice Reverts with an error if the transfer ID is invalid
    error InvalidTransferId();
    /// @notice Reverts with an error if the quorum for execution is not reached
    /// @param _needForExecution The number of approvals needed for execution
    /// @param _currentApprovals The current number of approvals for the transfer
    error QuorumNotReached(uint256 _needForExecution, uint256 _currentApprovals);
    /// @notice Reverts with an error if the contract has insufficient balance for the transfer
    /// @param _currentBalance The current balance of the contract
    /// @param _transferAmount The amount to be transferred
    error InsufficientBalance(uint256 _currentBalance, uint256 _transferAmount);
    /// @notice Reverts with an error if the transaction fails
    error TransactionFailed();
    /// @notice Reverts with an error if the contract balance is zero
    error ContractBalanceIsZero();

    /// @dev The struct is used to store the details of a transfer
    /// @param to The address to which the transfer is made
    /// @param amount The amount of the transfer
    /// @param approvalCount The number of approvals received for the transfer
    /// @param executed A boolean indicating whether the transfer has been executed
    /// @param approvals A mapping of addresses to booleans indicating whether they have approved the transfer
    struct Transfer {
        address to;
        uint256 amount;
        uint256 approvalCount;
        bool executed;
        mapping(address => bool) approvals;
    }

    /// @notice A mapping from transfer ID to Transfer struct
    mapping(uint256 => Transfer) private transfers;
    /// @notice A mapping from address to boolean indicating whether the address is a signer
    mapping(address => bool) public isSigner;

    /// @notice Modifier to restrict access to only signers
    modifier onlySigner() {
        require(isSigner[msg.sender], OnlySignerAllowed());
        _;
    }

    /// @notice Function makes a transfer from the contract to a specified address if the quorum is reached
    /// @param _transferId The ID of the transfer to be executed
    function executeTransfer(uint256 _transferId) external onlySigner {
        Transfer storage transfer = transfers[_transferId];

        if (transfer.executed) revert TransferAlreadyExecuted(_transferId);
        if (transfer.approvalCount < quorum) revert QuorumNotReached(quorum, transfer.approvalCount);
        uint256 currentBalance = address(this).balance;
        if (currentBalance < transfer.amount) revert InsufficientBalance(currentBalance, transfer.amount);

        (bool success,) = (transfer.to).call{value: transfer.amount}("");
        require(success, TransactionFailed());

        transfer.executed = true;
        emit TransferExecuted(_transferId, transfer.to, transfer.amount);
    }

    /// @notice Function to initiate a transfer
    /// @param _to The address to which the transfer is made
    /// @param _amount The amount of the transfer
    /// @return transferId The ID of the initiated transfer
    /// @dev Automatically approves the transfer by the caller
    function initiateTransfer(address _to, uint256 _amount) external onlySigner returns (uint256 transferId) {
        if (_to == address(0)) revert TransferToCannotBeZeroAddress();
        if (_amount == 0) revert TransferAmountMustBeGreaterThanZero();
        if ((address(this)).balance == 0) revert ContractBalanceIsZero();

        transferId = transfersCount++;
        Transfer storage transfer = transfers[transferId];
        transfer.to = _to;
        transfer.amount = _amount;
        transfer.approvalCount = transfer.approvalCount + 1;
        transfer.executed = false;
        transfer.approvals[msg.sender] = true;

        emit TransferInitiated(transferId, _to, _amount);
    }

    /// @notice Function to approve a transfer by a signer
    /// @param _transferId The ID of the transfer to be approved
    function approveTransfer(uint256 _transferId) external onlySigner {
        Transfer storage transfer = transfers[_transferId];

        if (transfer.executed) revert TransferAlreadyExecuted(_transferId);
        if (transfer.approvals[msg.sender]) revert AlreadyApprovedBySigner();

        transfer.approvalCount++;
        transfer.approvals[msg.sender] = true;

        emit TransferApproved(_transferId, msg.sender);
    }

    /// @notice View function to get the details of a transfer
    /// @param _transferId The ID of the transfer to retrieve
    /// @return _to The address to which the transfer is made
    /// @return _amount The amount of the transfer
    /// @return _approvalCount The number of approvals received for the transfer
    /// @return _executed A boolean indicating whether the transfer has been executed
    function getTransferInfo(uint256 _transferId)
        external
        view
        returns (address _to, uint256 _amount, uint256 _approvalCount, bool _executed)
    {
        Transfer storage transfer = transfers[_transferId];

        if (transfer.amount == 0) revert InvalidTransferId();

        return (transfer.to, transfer.amount, transfer.approvalCount, transfer.executed);
    }

    /// @notice View function to check if a signer has approved a transfer
    /// @param _signer The address of the signer
    /// @param _transferId The ID of the transfer to check
    /// @return _signed A boolean indicating whether the signer has approved the transfer
    function signedStatus(address _signer, uint256 _transferId) external view returns (bool _signed) {
        Transfer storage transfer = transfers[_transferId];

        if (transfer.amount == 0) revert InvalidTransferId();
        return transfer.approvals[_signer];
    }

    /// @notice View function to get the number of transfers initiated
    /// @return The total number of transfers initiated
    function getTransfersCount() external view returns (uint256) {
        return transfersCount;
    }

    /// @notice Fallback function to receive Ether
    receive() external payable {}
}
