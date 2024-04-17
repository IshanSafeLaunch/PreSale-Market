// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";


contract raisingContract is AccessControl, ReentrancyGuard{
    using SafeMath for uint;

    // defining access control
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SUPER_ADMIN = keccak256("SUPER_ADMIN");
    

    address public superAdmin;
    address public contractCreator;
    uint public totalRaised;
    uint public feePercent=10;
    uint public hardCap;
    uint public minContribution;
    uint public maxContribution;

    bool public raiseStarted;
    bool public raiseEnded;

    uint public numOfContributors;
    mapping(address=>uint) public contributions;
    mapping(address => bool) public whitelist;

    //Events
    event raiseEndedEvent();
    event raiseStartedEvent();
    event HardCapIncreased(uint _newHardCap);
    event MinContributionSet(uint _min);
    event MaxContributionSet(uint _max);
    event totalContributed(address indexed _user,uint _value, uint _time);
    event WhitelistUpdated(address _account, bool _value);
        
    
    //Have to add gratRole for SuperAdmin
    constructor(address _admin,uint _hardcap,address _superAdmin,uint _minContribution) {
        superAdmin = _superAdmin;
        contractCreator = _admin;
        hardCap = _hardcap;
        minContribution = _minContribution;

        _grantRole(ADMIN_ROLE, contractCreator);
        _grantRole(SUPER_ADMIN, _superAdmin);
    }


    // projectAdminAccess
    modifier onlyAdmin(){
        require(hasRole(ADMIN_ROLE,contractCreator), "Not the admin");
        _;
    }

    // Have to define access to the this admin and the superAdmin
    modifier adminOrsuperAdmin(){
        require(hasRole(ADMIN_ROLE,contractCreator) || hasRole(SUPER_ADMIN, superAdmin),"Must have defined Roles");
        _;
    }

    function startRaise() external onlyAdmin {
        require(!raiseStarted, "Raise already started");
        raiseStarted = true;
        emit raiseStartedEvent();
    }


    function endRaise() internal{
        require(!raiseEnded, "Raise already ended");
        raiseEnded = true;
        //this.finaliseRaise();
        emit raiseEndedEvent();
    }

    // adding contributors to whitelist
    function addToWhitelist(address _account) external onlyAdmin {
        whitelist[_account] = true;
        emit WhitelistUpdated(_account, true);
    }
    // removing contributors to whitelist
    function removeFromWhitelist(address _account) external onlyAdmin {
        whitelist[_account] = false;
        emit WhitelistUpdated(_account, false);
    }

    //Contributing tokens 
    function contribute() external payable nonReentrant{
        require(raiseStarted && !raiseEnded,"Rasie must be ongoing");
        require(msg.value >= minContribution && msg.value != 0, "Contribution should be greater than minimum Contribution");

        contributions[msg.sender] = contributions[msg.sender].add(msg.value);
        totalRaised = totalRaised.add(msg.value);
        numOfContributors++;

        emit totalContributed(msg.sender,msg.value,block.timestamp);
    }


    // Finalising the tokens to all at the end
    function finaliseRaise() external payable adminOrsuperAdmin nonReentrant{
        endRaise();
        require(raiseEnded = true, "Raise not ended");
        require(totalRaised > 0,"RasiedAmout should not be zero");

        uint superAdminAmt; 
        uint adminAmount;

        if(totalRaised < hardCap){
            console.log("TotalRaised", totalRaised);

            //Calculating Admin and SuperAdmin to transfer when totalRaised < hardCap
            superAdminAmt = (totalRaised.mul(feePercent)).div(100);
            adminAmount = totalRaised.sub(superAdminAmt);
            console.log("superAdminAmt When total rasied < hardcap ",superAdminAmt);
            console.log("adminAmount When total rasied < hardcap",adminAmount);

            //Admin fee transfer when totalRaised < hardCap
            bool trasnferAdminLessTotalRaise = payable(contractCreator).send(adminAmount);
            require(trasnferAdminLessTotalRaise,"Txn failed for the admin when total rasied < hardcap");

            //superAdmin fee transfer when totalRaised < hardCap
            bool trasnferSuperAdminLessTotalRaise = payable(superAdmin).send(superAdminAmt);
            require(trasnferSuperAdminLessTotalRaise,"Txn failed for the Super Admin when total rasied < hardcap");

        }else if(totalRaised > hardCap){
            // When totalRasied is greater than hardCap 
            //require(totalRaised > hardCap,"TotalRaised is less than hardCap");
            console.log("TotalRaised", totalRaised);

            // Calculating Admin and SuperAdmin to transfer.
            superAdminAmt = (hardCap.mul(feePercent)).div(100);
            adminAmount = hardCap.sub(superAdminAmt);
            console.log("superAdminAmt When total rasied > hardcap ",superAdminAmt);
            console.log("adminAmount When total rasied > hardcap",adminAmount);

            //Admin fee transfer when totalRaised > hardCap
            bool successTransferAdmin = payable(contractCreator).send(adminAmount);
            require(successTransferAdmin,"Txn failed for the admin when total rasied > hardcap");
            
            
            //superAdmin fee transfer when totalRaised > hardCap
            bool sucessTransferSuperAdmin = payable(superAdmin).send(superAdminAmt);
            require(sucessTransferSuperAdmin,"Txn failed for the admin when total rasied > hardcap");


            //Returning the overflow value to the contributors
            uint refundAmountPerContributor = (totalRaised.sub(hardCap)).div(numOfContributors);
            console.log("refundAmountPerContributor", refundAmountPerContributor);

            console.log("Checking every contributor");
            for(uint i = 0; i < numOfContributors; i++){
                address contributor = payable(address(uint160(i))); 
                console.log("contributor list" , contributor);
                
                uint contribution = contributions[contributor];
                console.log("Hello hi how do you do");
                if(contribution > refundAmountPerContributor){
                    require(contributor != address(0) || contributor != 0x0000000000000000000000000000000000000000,"Not a valid address");
                    (bool contributorSend) = payable(contributor).send(refundAmountPerContributor);
                    require(contributorSend,"Txn failed for the contributorSend");
                    // string memory con1 = "Refund to contributor: ";
                    // (bool contributorSend,) = payable(contributor).call{value:refundAmountPerContributor}("");
                    // string memory con1 = "Refund to contributor: ";
                    // require(contributorSend, string(abi.encodePacked(con1, contributor)));
                }
                console.log("return Amount", refundAmountPerContributor);
            }
        }else if(totalRaised == hardCap){
            console.log("TotalRaised", totalRaised);

            // Calculating Admin and SuperAdmin to transfer.
            superAdminAmt = (hardCap.mul(feePercent)).div(100);
            adminAmount = hardCap.sub(superAdminAmt);
            console.log("superAdminAmt When total rasied == hardcap ",superAdminAmt);
            console.log("adminAmount When total rasied == hardcap",adminAmount);

            //Admin fee transfer when totalRaised > hardCap
            bool successTransferAdmin = payable(contractCreator).send(adminAmount);
            require(successTransferAdmin,"Txn failed for the admin when total rasied == hardcap");
            
            
            //superAdmin fee transfer when totalRaised > hardCap
            bool sucessTransferSuperAdmin = payable(superAdmin).send(superAdminAmt);
            require(sucessTransferSuperAdmin,"Txn failed for the admin when total rasied == hardcap");
        }      
         

        totalRaised = 0;
        numOfContributors = 0;
        raiseStarted = false;
        raiseEnded = true;

    }

    receive() external payable {
        revert("Contract does not accept direct payments");
    }


    // setter function for MinContribution
    function setMinContribution(uint256 _min) external onlyAdmin {
        minContribution = _min;
        emit MinContributionSet(_min);
    }
    //setter function for MaxContribution
    function setMaxContribution(uint256 _max) external onlyAdmin {
        maxContribution = _max;
        emit MaxContributionSet(_max);
    }
    //setter function for increaseHardCap
    function increaseHardCap(uint _newHardCap) external onlyAdmin {
        hardCap = _newHardCap;
        emit HardCapIncreased(_newHardCap);
    }

    // setter function for changingHardcap
    function setHardCap(uint _hardCap) external onlyAdmin {
        hardCap = _hardCap;
    }

    // setter function for changingFeePercentage
    function setFeePercent(uint _feePercent) external onlyAdmin {
        feePercent = _feePercent;
    }

    // getContract Balance
    function getContractBalance() public view returns(uint){
        return address(this).balance;
    }

}