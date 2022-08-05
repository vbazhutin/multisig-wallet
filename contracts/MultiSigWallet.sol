// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

error MultiSigWallet__NotOwner();
error MultiSigWallet__TxDoesntExist();
error MultiSigWallet__TxAlreadyExecuted();
error MultiSigWallet__TxAlreadyConfirmed();
error MultiSigWallet__TxNotEnoughConfirmations();
error MultiSigWallet__TxFailed();
error MultiSigWallet__TxNotConfirmed();

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint indexed txIndex);

    address[] public owners;
    mapping(address => bool) isOwner;
    uint public numConfirmationsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint numConfirmations;
    }

    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    Transaction[] public transactions;

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) {
            revert MultiSigWallet__NotOwner();
        }
        _;
    }

    modifier txExists(uint256 txIndex) {
        if (txIndex < transactions.length) {
            revert MultiSigWallet__TxDoesntExist();
        }
        _;
    }

    modifier notExecuted(uint256 txIndex) {
        if (!transactions[txIndex].executed) {
            revert MultiSigWallet__TxAlreadyExecuted();
        }
        _;
    }

    modifier notConfirmed(uint256 txIndex) {
        if (isConfirmed[txIndex][msg.sender]) {
            revert MultiSigWallet__TxAlreadyConfirmed();
        }
        _;
    }

    constructor(address[] memory _owners) {
        require(_owners.length > 0, "Owners required");
        numConfirmationsRequired = _owners.length / 2 + 1;

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Already owner");
            isOwner[owner] = true;
            owners.push(owner);
        }
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction memory transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction memory transaction = transactions[_txIndex];
        if (transaction.numConfirmations < numConfirmationsRequired) {
            revert MultiSigWallet__TxNotEnoughConfirmations();
        }

        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        if (!success) {
            revert MultiSigWallet__TxFailed();
        }

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction memory transaction = transactions[_txIndex];

        if (!isConfirmed[_txIndex][msg.sender]) {
            revert MultiSigWallet__TxNotConfirmed();
        }

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address,
            uint256,
            bytes memory,
            bool,
            uint256
        )
    {
        Transaction memory transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
