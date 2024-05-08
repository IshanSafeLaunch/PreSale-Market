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


    address public superAdmin;
    address public contractCreator;
    uint public totalRaised;
    uint public feePercent=10;
    uint public hardCap;
    uint public minContribution;
    uint public maxContribution;

    bool public raiseStarted;
    bool public raiseEnded;
    uint public startTime;
    uint public endTime;

    uint public numOfContributors;
    address[] public contributorsList;
    mapping(address=>uint) public contributions;
    mapping(address => bool) public whitelist;
    bool public whitelistEnabled;

    //Events
    event raiseEndedEvent();
    event raiseStartedEvent();
    event HardCapIncreased(uint _newHardCap);
    event MinContributionSet(uint _min);
    event MaxContributionSet(uint _max);
    event totalContributed(address indexed _user,uint _value, uint _time);
    event WhitelistUpdated(address _account, bool _value);
        
    
    //Have to add gratRole for SuperAdmin
    constructor(address _admin,address _superAdmin, uint _maxContribution,uint _minContribution) {
        superAdmin = _superAdmin;
        contractCreator = _admin;
        // hardCap = _hardcap;
        minContribution = _minContribution;
        maxContribution = _maxContribution;

        _grantRole(ADMIN_ROLE, contractCreator);
        _grantRole(DEFAULT_ADMIN_ROLE, superAdmin);
    }

    // Have to define access to the this admin and the superAdmin
    modifier adminOrsuperAdmin(){
        console.log("Contract Creator", contractCreator);
        console.log("SuperAdmin", superAdmin);
        require(hasRole(ADMIN_ROLE,msg.sender) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),"Must have defined Roles");
        _;
    }

    function startRaise() external adminOrsuperAdmin {
        require(!raiseStarted, "Raise not started yet");
        raiseStarted = true;
        emit raiseStartedEvent();
    }

    function endRaise() external adminOrsuperAdmin {
        require(!raiseEnded, "Raise already ended");
        raiseEnded = true;
        this.finaliseRaise();
        emit raiseEndedEvent();
    }

    // Enable the whitelist
    function enableWhitelist(uint _setHardCap) external adminOrsuperAdmin {
        whitelistEnabled = true;
        this.setHardCap(_setHardCap);
    }

    // Disable the whitelist
    // function disableWhitelist() external adminOrsuperAdmin {
    //     whitelistEnabled = false;
    // }

    // adding contributors to whitelist
    function addToWhitelist(address _account) external adminOrsuperAdmin{
        whitelist[_account] = true;
        emit WhitelistUpdated(_account, true);
    }
    // removing contributors to whitelist
    function removeFromWhitelist(address _account) external adminOrsuperAdmin {
        whitelist[_account] = false;
        emit WhitelistUpdated(_account, false);
    }

    function isContributor(address _address) internal view returns (bool) {
    for (uint i = 0; i < contributorsList.length; i++) {
        if (contributorsList[i] == _address) {
            return true;
        }
    }
            return false;
    }

    //Contributing tokens 
    function contribute() external payable nonReentrant{
        require(raiseStarted && !raiseEnded,"Raise must be ongoing");
        require(msg.value >= minContribution && msg.value != 0 && msg.value <= maxContribution, "Contribution should be in between min and max");

        // when whitelist contribution is enabled
        if(whitelistEnabled){
        require(whitelist[msg.sender] == true,"Not a whiteList User");

        contributions[msg.sender] = contributions[msg.sender].add(msg.value);
        totalRaised = totalRaised.add(msg.value);
        numOfContributors++;

            //Add the contributor to the list if not already present
            if (!isContributor(msg.sender)) {
                contributorsList.push(msg.sender);
            }

        // when whitelist is disabled
        }else if(!whitelistEnabled){ 
            contributions[msg.sender] = contributions[msg.sender].add(msg.value);
            totalRaised = totalRaised.add(msg.value);
            numOfContributors++;

            //Add the contributor to the list if not already present
            if (!isContributor(msg.sender)) {
                contributorsList.push(msg.sender);
            }
        } 
        emit totalContributed(msg.sender,msg.value,block.timestamp);
    }


    // Finalising the tokens to all at the end
    // function finaliseRaise() external payable nonReentrant adminOrsuperAdmin{
    //     raiseEnded = true;
    //     require(raiseEnded == true, "Raise not ended");
    //     require(totalRaised > 0,"RasiedAmout should not be zero");

    //     uint superAdminAmt; 
    //     uint adminAmount;

    //     if(totalRaised < hardCap){
    //         console.log("When totalRasied < hardCap"); 
    //         console.log("TotalRaised", totalRaised);

    //         //Calculating Admin and SuperAdmin to transfer when totalRaised < hardCap
    //         superAdminAmt = (totalRaised.mul(feePercent)).div(100);
    //         adminAmount = totalRaised.sub(superAdminAmt);
    //         console.log("superAdminAmt When total rasied < hardcap ",superAdminAmt);
    //         console.log("adminAmount When total rasied < hardcap",adminAmount);

    //         //Admin fee transfer when totalRaised < hardCap
    //         bool trasnferAdminLessTotalRaise = payable(contractCreator).send(adminAmount);
    //         require(trasnferAdminLessTotalRaise,"Txn failed for the admin when total rasied < hardcap");

    //         //superAdmin fee transfer when totalRaised < hardCap
    //         bool trasnferSuperAdminLessTotalRaise = payable(superAdmin).send(superAdminAmt);
    //         require(trasnferSuperAdminLessTotalRaise,"Txn failed for the Super Admin when total rasied < hardcap");

    //     }else if(totalRaised > hardCap){
    //         console.log("When totalRasied > hardCap"); 
    //         //require(totalRaised > hardCap,"TotalRaised is less than hardCap");
    //         console.log("TotalRaised", totalRaised);

    //         // Calculating Admin and SuperAdmin to transfer.
    //         superAdminAmt = (hardCap.mul(feePercent)).div(100);
    //         adminAmount = hardCap.sub(superAdminAmt);
    //         console.log("superAdminAmt When total rasied > hardcap ",superAdminAmt);
    //         console.log("adminAmount When total rasied > hardcap",adminAmount);

    //         //Admin fee transfer when totalRaised > hardCap
    //         bool successTransferAdmin = payable(contractCreator).send(adminAmount);
    //         require(successTransferAdmin,"Txn failed for the admin when total rasied > hardcap");
            
            
    //         //superAdmin fee transfer when totalRaised > hardCap
    //         bool sucessTransferSuperAdmin = payable(superAdmin).send(superAdminAmt);
    //         require(sucessTransferSuperAdmin,"Txn failed for the SuperAdmin when total rasied > hardcap");


    //         //Returning the overflow value to the contributors
    //         uint refundAmountPerContributor = totalRaised.sub(hardCap).div(numOfContributors);
    //         console.log("refundAmountPerContributor", refundAmountPerContributor);

    //         console.log("Checking every contributor");
    //         for(uint i = 0; i < numOfContributors; i++){
    //             //address contributor = payable(address(uint160(i)));
    //             address contributor = contributorsList[i];
    //             console.log("contributor list" , contributor);
                
    //             uint contribution = contributions[contributor];
    //             if(contribution > refundAmountPerContributor){
    //                 require(contributor != address(0) || contributor != 0x0000000000000000000000000000000000000000,"Not a valid address");
    //                 console.log("Are we really refunding to the users");
    //                 (bool contributorSend,) = payable(contributor).call{value:refundAmountPerContributor}("");
    //                 string memory con1 = "Refund failed for contributor: ";
    //                 require(contributorSend, string(abi.encodePacked(con1, contributor)));
    //             }
    //             console.log("return Amount", refundAmountPerContributor);
    //         }
    //     }else if(totalRaised == hardCap){
    //         console.log("When totalRasied == hardCap"); 
    //         console.log("TotalRaised", totalRaised);

    //         // Calculating Admin and SuperAdmin to transfer.
    //         superAdminAmt = (hardCap.mul(feePercent)).div(100);
    //         adminAmount = hardCap.sub(superAdminAmt);
    //         console.log("superAdminAmt When total rasied == hardcap ",superAdminAmt);
    //         console.log("adminAmount When total rasied == hardcap",adminAmount);

    //         //Admin fee transfer when totalRaised > hardCap
    //         bool successTransferAdmin = payable(contractCreator).send(adminAmount);
    //         require(successTransferAdmin,"Txn failed for the admin when total rasied == hardcap");
            
            
    //         //superAdmin fee transfer when totalRaised > hardCap
    //         bool sucessTransferSuperAdmin = payable(superAdmin).send(superAdminAmt);
    //         require(sucessTransferSuperAdmin,"Txn failed for the SuperAdmin when total rasied == hardcap");
    //     }      
         

    //     totalRaised = 0;
    //     numOfContributors = 0;
    //     raiseStarted = false;
    //     raiseEnded = true;

    // }

     function finaliseRaise() external payable nonReentrant adminOrsuperAdmin {
        raiseEnded = true;
        require(raiseEnded == true, "Raise not ended");
        require(totalRaised > 0 && numOfContributors > 0, "RasiedAmout and No of Contributors should be > 0");

        uint256 superAdminAmt;
        uint256 adminAmount;

        if(whitelistEnabled && hardCap > 0){

            if (totalRaised < hardCap) {
                console.log("When totalRasied < hardCap");
                console.log("TotalRaised", totalRaised);

                //Calculating Admin and SuperAdmin to transfer when totalRaised < hardCap
                superAdminAmt = (totalRaised.mul(feePercent)).div(100);
                adminAmount = totalRaised.sub(superAdminAmt);
                console.log(
                    "superAdminAmt When total rasied < hardcap ",
                    superAdminAmt
                );
                console.log("adminAmount When total rasied < hardcap", adminAmount);

                //Admin fee transfer when totalRaised < hardCap
                (bool trasnferAdminLessTotalRaise,) = payable(contractCreator).call{value:adminAmount}("");
                string memory con1 = "Txn failed for the Admin when total rasied < hardcap : ";
                require(trasnferAdminLessTotalRaise, string(abi.encodePacked(con1, trasnferAdminLessTotalRaise)));
                

                //superAdmin fee transfer when totalRaised < hardCap
                (bool trasnferSuperAdminLessTotalRaise,) = payable(superAdmin).call{value:superAdminAmt}("");
                string memory con2 = "Txn failed for the Super Admin when total rasied < hardcap : ";
                require(trasnferSuperAdminLessTotalRaise, string(abi.encodePacked(con2, trasnferSuperAdminLessTotalRaise)));

            } else if (totalRaised > hardCap) {
                console.log("When totalRasied > hardCap");
                //require(totalRaised > hardCap,"TotalRaised is less than hardCap");
                console.log("TotalRaised", totalRaised);

                // Calculating Admin and SuperAdmin to transfer.
                superAdminAmt = (hardCap.mul(feePercent)).div(100);
                adminAmount = hardCap.sub(superAdminAmt);
                console.log(
                    "superAdminAmt When total rasied > hardcap ",
                    superAdminAmt
                );
                console.log("adminAmount When total rasied > hardcap", adminAmount);

                //Admin fee transfer when totalRaised > hardCap
                (bool successTransferAdmin,) = payable(contractCreator).call{value:adminAmount}("");
                string memory con1 = "Txn failed for the Admin when total rasied > hardcap : ";
                require(successTransferAdmin, string(abi.encodePacked(con1, successTransferAdmin)));

                //superAdmin fee transfer when totalRaised > hardCap
                (bool sucessTransferSuperAdmin,) = payable(superAdmin).call{value:superAdminAmt}("");
                string memory con2 = "Txn failed for the Super Admin when total rasied > hardcap : ";
                require(sucessTransferSuperAdmin, string(abi.encodePacked(con2, sucessTransferSuperAdmin)));

                //Returning the overflow value to the whitelist contributors
                uint256 refundAmountPerContributor = totalRaised.sub(hardCap).div(
                    numOfContributors
                );
                console.log(
                    "refundAmountPerContributor",
                    refundAmountPerContributor
                );

                console.log("Checking every contributor");
                for (uint256 i = 0; i < numOfContributors; i++) {
                    //address contributor = payable(address(uint160(i)));
                    address contributor = contributorsList[i];
                    console.log("contributor list", contributor);

                    uint256 contribution = contributions[contributor];
                    if (contribution > refundAmountPerContributor) {
                        require(
                            contributor != address(0) ||
                                contributor !=
                                0x0000000000000000000000000000000000000000,
                            "Not a valid address"
                        );
                        console.log("Are we really refunding to the users");
                        (bool contributorSend, ) = payable(contributor).call{
                            value: refundAmountPerContributor
                        }("");
                        string memory con3 = "Txn failed for the whitelisted contributor when total rasied > hardcap : ";
                        require(
                            contributorSend,
                            string(abi.encodePacked(con3, contributor))
                        );
                    }
                    console.log("return Amount", refundAmountPerContributor);
                }
            } else if (totalRaised == hardCap) {
                console.log("When totalRasied == hardCap");
                console.log("TotalRaised", totalRaised);

                // Calculating Admin and SuperAdmin to transfer.
                superAdminAmt = (hardCap.mul(feePercent)).div(100);
                adminAmount = hardCap.sub(superAdminAmt);
                console.log(
                    "superAdminAmt When total rasied == hardcap ",
                    superAdminAmt
                );
                console.log(
                    "adminAmount When total rasied == hardcap",
                    adminAmount
                );

                //Admin fee transfer when totalRaised > hardCap
                (bool successTransferAdmin,) = payable(contractCreator).call{value:adminAmount}("");
                string memory con1 = "Txn failed for the Admin when total rasied == hardcap : ";
                require(successTransferAdmin, string(abi.encodePacked(con1, successTransferAdmin)));

                //superAdmin fee transfer when totalRaised > hardCap
                (bool sucessTransferSuperAdmin,) = payable(superAdmin).call{value:superAdminAmt}("");
                string memory con2 = "Txn failed for the Super Admin when total rasied == hardcap : ";
                require(sucessTransferSuperAdmin, string(abi.encodePacked(con2, sucessTransferSuperAdmin)));
            }
        } else if(!whitelistEnabled && hardCap == 0){
            //Calculating Admin and SuperAdmin to transfer when there is no hardcap set
            superAdminAmt = (totalRaised.mul(feePercent)).div(100);
            adminAmount = totalRaised.sub(superAdminAmt);

            console.log("superAdminAmt when there is no hardcap set",superAdminAmt);
            console.log("adminAmount when there is no hardcap set", adminAmount);

            //Admin fee transfer when there is no harcap
            // (bool trasnferAdminTotalRaise,) = payable(contractCreator).call{value:adminAmount}("");
            // string memory con1 = "Txn failed for the Admin when there is no hardcap set : ";
            // require(trasnferAdminTotalRaise, string(abi.encodePacked(con1, trasnferAdminTotalRaise)));

            bool sent = payable (contractCreator).send(adminAmount);
            require(sent, "Failed to send Ether");

            //superAdmin fee transfer when totalRaised < hardCap
            (bool trasnferSuperAdminTotalRaise,) = payable(superAdmin).call{value:superAdminAmt}("");
            string memory con2 = "Txn failed for the Super Admin when there is no hardcap set : ";
            require(trasnferSuperAdminTotalRaise, string(abi.encodePacked(con2, trasnferSuperAdminTotalRaise)));
            
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
    function setMinContribution(uint256 _min) external onlyRole(ADMIN_ROLE) {
        minContribution = _min;
        emit MinContributionSet(_min);
    }
    //setter function for MaxContribution
    function setMaxContribution(uint256 _max) external onlyRole(ADMIN_ROLE) {
        maxContribution = _max;
        emit MaxContributionSet(_max);
    }
    //setter function for increaseHardCap
    function increaseHardCap(uint _newHardCap) external onlyRole(ADMIN_ROLE) {
        hardCap = _newHardCap;
        emit HardCapIncreased(_newHardCap);
    }

    // setter function for changingHardcap
    function setHardCap(uint _hardCap) external onlyRole(ADMIN_ROLE) {
        hardCap = _hardCap;
    }

    // setter function for changingFeePercentage
    function setFeePercent(uint _feePercent) external onlyRole(ADMIN_ROLE) {
        feePercent = _feePercent;
    }

    // // getContract Balance
    // function getContractBalance() public view returns(uint){
    //     return address(this).balance;
    // }

}