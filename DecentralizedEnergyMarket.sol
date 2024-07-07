// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Owned {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        owner = newOwner;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }
}

contract DecentralizedEnergyMarket {
    using SafeMath for uint256;

    address public owner;
    uint256 public totalDeposits;
    uint256 public totalEnergyDeposits;

    enum Permission { None, Consumer, Producer, Prosumer }

    mapping(address => Permission) public permissions;
    mapping(address => uint256) public deposits;
    mapping(address => mapping(address => uint256)) public energyRequests;
    mapping(address => mapping(address => bool)) public energyRequestsApproved;
    mapping(address => mapping(address => uint256)) public energySupplies;
    mapping(address => mapping(address => bool)) public energySuppliesApproved;
    mapping(address => uint256) public energyBalance;

    // events
    event Deposit(address indexed depositor, uint256 amount);
    event AddEnergyBalance(address indexed producer, uint256 amount);
    event PermissionUpdate(address indexed user, Permission permission);
    event EnergyRequested(address indexed requester, address indexed supplier, uint256 amount, uint256 price);
    event EnergyRequestApproved(address indexed requester, address indexed supplier, uint256 amount);
    event EnergySupplyOffered(address indexed supplier, address indexed requester, uint256 amount, uint256 price);
    event EnergySupplyApproved(address indexed supplier, address indexed requester, uint256 amount);
    event EnergyTransactionExecuted(address indexed supplier, address indexed requester, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can perform this operation");
        _;
    }

    function deposit() public payable {
        deposits[msg.sender] = deposits[msg.sender].add(msg.value);
        totalDeposits = totalDeposits.add(msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function addEnergyBalance() public payable {
        energyBalance[msg.sender] = energyBalance[msg.sender].add(msg.value);
        totalEnergyDeposits = totalEnergyDeposits.add(msg.value);
        emit AddEnergyBalance(msg.sender, msg.value);
    }

    function getEnergyBalance(address account) public view returns (uint256) {
        return energyBalance[account];
    }

    function updatePermission(address user, Permission permission) public onlyOwner {
        permissions[user] = permission;
        emit PermissionUpdate(user, permission);
    }

    function requestEnergy(address supplier, uint256 amount, uint256 price) public {
        require(amount > 0, "Amount must be greater than zero");
        require(price > 0, "Price must be greater than zero");
        require(deposits[msg.sender] >= price, "Insufficient funds for requested energy");
        require(permissions[msg.sender] == Permission.Consumer || permissions[msg.sender] == Permission.Prosumer, "Only consumers or prosumers can request energy");
        require(permissions[supplier] == Permission.Producer || permissions[supplier] == Permission.Prosumer, "Only producers or prosumers can supply energy");

        energyRequests[msg.sender][supplier] = energyRequests[msg.sender][supplier].add(amount);
        energyBalance[msg.sender] = energyBalance[msg.sender].add(amount.mul(price));
        deposits[msg.sender] = deposits[msg.sender].sub(price);
        emit EnergyRequested(msg.sender, supplier, amount, price);
    }

    function approveEnergyRequest(address requester, uint256 amount) public {
        require(msg.sender != requester, "Cannot approve own energy request");
        require(permissions[msg.sender] == Permission.Producer || permissions[msg.sender] == Permission.Prosumer, "Only producers or prosumers can approve energy requests");
        require(energyRequests[requester][msg.sender] >= amount, "Energy request does not exist or has insufficient amount");
        require(!energyRequestsApproved[requester][msg.sender], "Energy request has already been approved");

        energyRequestsApproved[requester][msg.sender] = true;
        emit EnergyRequestApproved(requester, msg.sender, amount);
    }

    function offerEnergy(address requester, uint256 amount, uint256 price) public {
        require(amount > 0, "Amount must be greater than zero");
        require(price > 0, "Price must be greater than zero");
        require(energyBalance[msg.sender] >= amount.mul(price), "Insufficient energy balance for offering energy");
        require(permissions[msg.sender] == Permission.Producer || permissions[msg.sender] == Permission.Prosumer, "Only producers or prosumers can offer energy");
        require(permissions[requester] == Permission.Consumer || permissions[requester] == Permission.Prosumer, "Only consumers or prosumers can request energy");

        energySupplies[msg.sender][requester] = energySupplies[msg.sender][requester].add(amount);
        energyBalance[msg.sender] = energyBalance[msg.sender].sub(amount.mul(price));
        emit EnergySupplyOffered(msg.sender, requester, amount, price);
    }

    function approveEnergySupply(address supplier, uint256 amount) public {
        require(msg.sender != supplier, "Cannot approve own energy supply");
        require(permissions[msg.sender] == Permission.Consumer || permissions[msg.sender] == Permission.Prosumer, "Only consumers or prosumers can approve energy supplies");
        require(energySupplies[supplier][msg.sender] >= amount, "Energy supply does not exist or has insufficient amount");
        require(!energySuppliesApproved[supplier][msg.sender], "Energy supply has already been approved");
        energySuppliesApproved[supplier][msg.sender] = true;
        emit EnergySupplyApproved(supplier, msg.sender, amount);
    }

    function executeEnergyTransaction(address supplier, address requester, uint256 amount) public {
        require(energyRequestsApproved[requester][supplier], "Energy request has not been approved by supplier");
        require(energySuppliesApproved[supplier][requester], "Energy supply has not been approved by requester");
        require(energyRequests[requester][supplier] >= amount, "Energy request does not exist or has insufficient amount");
        require(energySupplies[supplier][requester] >= amount, "Energy supply does not exist or has insufficient amount");

        uint256 price = energyBalance[requester].div(energyRequests[requester][supplier]);
        energyBalance[requester] = energyBalance[requester].sub(amount.mul(price));
        energyBalance[supplier] = energyBalance[supplier].add(amount.mul(price));
        energyRequests[requester][supplier] = energyRequests[requester][supplier].sub(amount);
        energySupplies[supplier][requester] = energySupplies[supplier][requester].sub(amount);

        emit EnergyTransactionExecuted(supplier, requester, amount);
    }

    function withdraw(uint256 amount) public {
        require(deposits[msg.sender] >= amount, "Insufficient funds for withdrawal");
        deposits[msg.sender] = deposits[msg.sender].sub(amount);
        totalDeposits = totalDeposits.sub(amount);
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    receive() external payable {
        deposit();
    }
}

