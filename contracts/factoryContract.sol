// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RaisingContract.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";


contract factoryContract {
    // Array to keep track of all deployed raising contracts
    raisingContract[] public raisingContracts;
    address public superAdmin;
    uint superAdminFee = 1 ether;
    
    constructor(address _superAdmin){
        superAdmin = _superAdmin;   
    }

    modifier onlyRole(){
        require(msg.sender == superAdmin ,"Must be a superAdmin");
        _;
    }

    // Event to log the creation of a new raising contract
    event RaisingContractCreated(address indexed raisingContractAddress, address indexed creator,address indexed _superAdmin,uint _time);
    event superAdminChanged(address indexed _superAdmin);
    event preSaleChargesEvent(uint _fee);
    
    // Function to create a new raising contract
    function createRaisingContract(uint _hardCap,uint _maxContribution,uint _minContribution) external payable  {
        require(msg.sender != superAdmin,"Cannot be a Super Admin");
        raisingContract newRaisingContract = new raisingContract(msg.sender,_hardCap,superAdmin,_maxContribution,_minContribution);
        raisingContracts.push(newRaisingContract); 

        emit RaisingContractCreated(address(newRaisingContract), msg.sender,superAdmin,block.timestamp);
        
        // sending the contract creation fee
        require(msg.value == superAdminFee, "Insufficient fee");

        (bool successFeeSuperAdmin,) = payable(superAdmin).call{value:superAdminFee}("");
        string memory con1 = "Contract Creation Txn Fees Filed : ";
        require(successFeeSuperAdmin, string(abi.encodePacked(con1, successFeeSuperAdmin)));
    }

    // Function to get the count of raising contracts created
    function getRaisingContractsCount() external view returns (uint) {
        return raisingContracts.length;
    }

    function changingSuperAdmin(address _superAdmin) external onlyRole{
        superAdmin = _superAdmin;
        emit superAdminChanged(_superAdmin);
    }

    function preSaleCharges(uint _fee) external onlyRole{
        superAdminFee = _fee;
        emit preSaleChargesEvent(_fee);
    }

    
}
