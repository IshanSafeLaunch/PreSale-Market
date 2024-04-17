// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./RaisingContract.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

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
    function createRaisingContract(uint _hardCap,uint _minContribution) external {
        require(msg.sender != superAdmin,"Cannot be a Super Admin");
        raisingContract newRaisingContract = new raisingContract(msg.sender,_hardCap,superAdmin,_minContribution);
        raisingContracts.push(newRaisingContract); 

        emit RaisingContractCreated(address(newRaisingContract), msg.sender,superAdmin,block.timestamp);
        

        // bool successFeeSuperAdmin = payable(msg.sender).send(superAdminFee);
        // require(successFeeSuperAdmin,"Txn failed for the Super Admin");
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
