//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Multisig {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed _txId);
    event Approve(address indexed owner, uint256 indexed _txId);
    event Revoke(address indexed owner, uint256 indexed _txId);
    event Execute(uint256 indexed _txId);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "You are not an owner");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "Transaction doesn't exist");
        _;
    }

    modifier notApproved(uint256 _txId) {
        require(
            !approved[_txId][msg.sender],
            "Transaction has already been approved"
        );
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Transaction already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owner inputs are required");
        require(
            _required > 0 && _required <= _owners.length,
            "invalid numbers of owners used"
        );
        for (uint256 i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "The owner address is invalid");
            require(!isOwner[owner], "An owner is not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        transactions.push(
            Transaction({to: _to, value: _value, data: _data, executed: false})
        );
        emit Submit(transactions.length - 1);
    }

    function approve(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notApproved(_txId)
        notExecuted(_txId)
    {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function _getApprovalCount(uint256 _txId)
        private
        view
        returns (uint256 count)
    {
        for (uint256 i; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count += 1;
            }
        }
    }

    function execute(uint256 _txId)
        external
        txExists(_txId)
        notExecuted(_txId)
    {
        require(
            _getApprovalCount(_txId) >= required,
            "Number of approvers is less than required"
        );
        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;
        (bool sent, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(sent, "Transaction failed");
        emit Execute(_txId);
    }

    function revoke(uint256 _txId)
        external
        onlyOwner
        txExists(_txId)
        notExecuted(_txId)
    {
        require(approved[_txId][msg.sender], "Transaction is not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }
}
