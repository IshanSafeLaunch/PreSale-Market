// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract usdtraisingContract is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    IERC20 public usdtToken;
    // defining access control
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public superAdmin;
    address public contractCreator;
    uint256 public totalRaised;
    uint256 public feePercent = 10;
    uint256 public hardCap;
    uint256 public minContribution;
    uint256 public maxContribution;
   

    bool public raiseStarted;
    bool public raiseEnded;

    uint256 public numOfContributors;
    address[] public contributorsList;
    mapping(address => uint256) public contributions;
    mapping(address => bool) public whitelist;
    bool public whitelistEnabled;
    mapping(address => uint256) public WhitelistAmount;

    //Events
    event raiseEndedEvent();
    event raiseStartedEvent();
    event HardCapIncreased(uint256 _newHardCap);
    event MinContributionSet(uint256 _min);
    event MaxContributionSet(uint256 _max);
    event totalContributed(
        address indexed _user,
        uint256 _value,
        uint256 _time
    );
    event WhitelistUpdated(address _account, bool _value);
    event StartTimeSet(uint256 _startTime);
    event EndTimeSet(uint256 _endTime);

    //Have to add gratRole for SuperAdmin
    constructor(
        address _admin,
        address _superAdmin,
        address stableCoin,
        uint256 _maxContribution,
        uint256 _minContribution
    ) {
        superAdmin = _superAdmin;
        contractCreator = _admin;
        minContribution = _minContribution;
        maxContribution = _maxContribution;
        usdtToken = IERC20(stableCoin);
        _grantRole(ADMIN_ROLE,contractCreator);
        _grantRole(DEFAULT_ADMIN_ROLE,superAdmin);
    }

    // Have to define access to the this admin and the superAdmin
    modifier adminOrsuperAdmin() {
        console.log("Contract Creator", contractCreator);
        console.log("SuperAdmin", superAdmin);
        require(
            hasRole(ADMIN_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Must have defined Roles"
        );
        _;
    }


    function startRaise() external adminOrsuperAdmin {
        require(!raiseStarted, "Raise already started");
        raiseStarted = true;
        emit raiseStartedEvent();
    }

    // setter function for changingHardcap
    function setHardCap(uint256 _hardCap) internal {
        hardCap = _hardCap;
    }

    // Enable the whitelist
    function enableWhitelist(uint _setHardCap) external adminOrsuperAdmin {
        whitelistEnabled = true;
        setHardCap(_setHardCap);
    }

    // // Disable the whitelist
    // function disableWhitelist() external adminOrsuperAdmin {
    //     whitelistEnabled = false;
    // }

    // adding contributors to whitelist
    function addToWhitelist(address _account, uint256 _amount)
        external
        onlyRole(ADMIN_ROLE)
    {
        whitelist[_account] = true;
        WhitelistAmount[_account] = _amount;
        emit WhitelistUpdated(_account, true);
    }

    // removing contributors to whitelist
    function removeFromWhitelist(address _account)
        external
        onlyRole(ADMIN_ROLE)
    {
        whitelist[_account] = false;
        emit WhitelistUpdated(_account, false);
    }

    function isContributor(address _address) internal view returns (bool) {
        for (uint256 i = 0; i < contributorsList.length; i++) {
            if (contributorsList[i] == _address) {
                return true;
            }
        }
        return false;
    }

    //Contributing tokens
    function contribute(uint amount) public payable nonReentrant {
        require(raiseStarted && !raiseEnded, "Raise must be ongoing");
        require(
            amount >= minContribution &&
                amount != 0 &&
                amount <= maxContribution,
            "Contribution should be in between min and max"
        );
        uint256 userBalance = usdtToken.balanceOf(msg.sender);
        require(
            userBalance >= amount,
            "Contrbuting : Insufficient user balance"
        );

        uint256 allowance = usdtToken.allowance(msg.sender, address(this));
        require(
            allowance >= amount,
            "Contrbuting : Approval not provided by the user"
        );

        // when whitelist contribution is enabled
        if (whitelistEnabled) {
            require(whitelist[msg.sender] == true, "Not a whiteList User");


            // Check if the new total contribution is within the allowed amount for the whitelist
            uint256 newTotalContribution = contributions[msg.sender].add(amount);
            require(
            newTotalContribution <= WhitelistAmount[msg.sender],
            "Contribution exceeds allowed maximum for whitelist user"
        );


            contributions[msg.sender] = contributions[msg.sender].add(
                amount
            );
            totalRaised = totalRaised.add(amount);
            numOfContributors++;

            //transfer
            require(
                usdtToken.transferFrom(msg.sender, address(this), amount),
                "Token transfer failed"
            );
            //Add the contributor to the list if not already present
            if (!isContributor(msg.sender)) {
                contributorsList.push(msg.sender);
            }

            // when whitelist is disabled
        } else if (!whitelistEnabled) {
            contributions[msg.sender] = contributions[msg.sender].add(
                amount
            );
            totalRaised = totalRaised.add(amount);
            numOfContributors++;
            //transfer
            require(
                usdtToken.transferFrom(msg.sender, address(this), amount),
                "Token transfer failed"
            );

            //Add the contributor to the list if not already present
            if (!isContributor(msg.sender)) {
                contributorsList.push(msg.sender);
            }
        }
        emit totalContributed(msg.sender, amount, block.timestamp);
    }

    // Finalising the tokens to all at the end
    function finaliseRaise() public payable nonReentrant{
        raiseEnded = true;
        require(msg.sender == contractCreator || msg.sender == superAdmin, "No defeined roles set" );
        require(raiseEnded, "Raise not ended");
        require(totalRaised > 0 && numOfContributors > 0, "RasiedAmout and No of Contributors should be > 0");

        uint256 superAdminAmt;
        uint256 adminAmount;

        if(whitelistEnabled && hardCap != 0  ){

            if (totalRaised < hardCap) {
                // console.log("When totalRasied < hardCap");
                // console.log("TotalRaised", totalRaised);

                //Calculating Admin and SuperAdmin to transfer when totalRaised < hardCap
                superAdminAmt = (totalRaised.mul(feePercent)).div(100);
                adminAmount = totalRaised.sub(superAdminAmt);
                // console.log(
                //     "superAdminAmt When total rasied < hardcap ",
                //     superAdminAmt
                // );
                //console.log("adminAmount When total rasied < hardcap", adminAmount);

                //Admin fee transfer when totalRaised < hardCap
                 IERC20(usdtToken).transfer(contractCreator, adminAmount);
                
                //superAdmin fee transfer when totalRaised < hardCap
                 IERC20(usdtToken).transfer(superAdmin, superAdminAmt);

            } else if (totalRaised > hardCap) {
                console.log("When totalRasied > hardCap");
                //require(totalRaised > hardCap,"TotalRaised is less than hardCap");
                // console.log("TotalRaised", totalRaised);

                // Calculating Admin and SuperAdmin to transfer.
                superAdminAmt = (hardCap.mul(feePercent)).div(100);
                adminAmount = hardCap.sub(superAdminAmt);
                // console.log(
                //     "superAdminAmt When total rasied > hardcap ",
                //     superAdminAmt
                // );
                // console.log("adminAmount When total rasied > hardcap", adminAmount);

                //Admin fee transfer when totalRaised > hardCap
                IERC20(usdtToken).transfer(contractCreator, adminAmount);

                //superAdmin fee transfer when totalRaised > hardCap
                IERC20(usdtToken).transfer(superAdmin, superAdminAmt);

                //Returning the overflow value to the whitelist contributors
                uint256 refundAmountPerContributor = totalRaised.sub(hardCap).div(
                    numOfContributors
                );
                // console.log(
                //     "refundAmountPerContributor",
                //     refundAmountPerContributor
                // );

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
                        // console.log("Are we really refunding to the users");
                        // (bool contributorSend, ) = payable(contributor).call{
                        //     value: refundAmountPerContributor
                        // }("");
                        // string memory con3 = "Txn failed for the whitelisted contributor when total rasied > hardcap : ";
                        // require(
                        //     contributorSend,
                        //     string(abi.encodePacked(con3, contributor))
                        // );
                        IERC20(usdtToken).transfer(contributor,refundAmountPerContributor);
                    }
                    console.log("return Amount", refundAmountPerContributor);
                }
            } else if (totalRaised == hardCap) {
                // console.log("When totalRasied == hardCap");
                // console.log("TotalRaised", totalRaised);

                // Calculating Admin and SuperAdmin to transfer.
                superAdminAmt = (hardCap.mul(feePercent)).div(100);
                adminAmount = hardCap.sub(superAdminAmt);
                // console.log(
                //     "superAdminAmt When total rasied == hardcap ",
                //     superAdminAmt
                // );
                // console.log(
                //     "adminAmount When total rasied == hardcap",
                //     adminAmount
                // );

                //Admin fee transfer when totalRaised > hardCap
                IERC20(usdtToken).transfer(contractCreator, adminAmount);

                //superAdmin fee transfer when totalRaised > hardCap
                IERC20(usdtToken).transfer(superAdmin, superAdminAmt);
            }
        } else if(!whitelistEnabled && hardCap == 0){
            //Calculating Admin and SuperAdmin to transfer when there is no hardcap set
            superAdminAmt = (totalRaised.mul(feePercent)).div(100);
            adminAmount = totalRaised.sub(superAdminAmt);

            // console.log("superAdminAmt when there is no hardcap set",superAdminAmt);
            // console.log("adminAmount when there is no hardcap set", adminAmount);
            // console.log("Contract creator at no hardCAp",contractCreator);
            // console.log("SuperAdmin at no hardCap", superAdmin);

            //Admin fee transfer when there is no harcap
            IERC20(usdtToken).transfer(contractCreator,adminAmount);

            //superAdmin fee transfer when totalRaised < hardCap
            IERC20(usdtToken).transfer(superAdmin, superAdminAmt);
            
        }

        totalRaised = 0;
        numOfContributors = 0;
        raiseStarted = false;
        raiseEnded = true;
    }

    function endRaise() external {
        // console.log("Value of totalRasied", totalRaised);
        // console.log("Value of Contributors", numOfContributors);
        require(msg.sender == contractCreator || msg.sender == superAdmin, "No defeined roles set" );
        require(totalRaised != 0 && numOfContributors != 0, "RasiedAmout and No of Contributors should be > 0");
        require(!raiseEnded, "Raise already ended");
        raiseEnded = true;

        finaliseRaise();
        emit raiseEndedEvent();
    }


    receive() external payable {
        revert("Contract does not accept direct payments");
    }

    // setter function for MinContribution
    function setMinContribution(uint256 _min) external onlyRole(ADMIN_ROLE) {
        minContribution = _min;
        emit MinContributionSet(_min);
    }

    // Adding multiple addresses to the whitelist at once with their respective contributions

    function addMultipleToWhitelist(
        address[] calldata _accounts,
        uint256[] calldata _contributions
    ) external onlyRole(ADMIN_ROLE) {
        require(
            _accounts.length == _contributions.length,
            "Arrays length mismatch"
        );

        for (uint256 i = 0; i < _accounts.length; i++) {
            address account = _accounts[i];
            uint256 contribution = _contributions[i];

            whitelist[account] = true;
            emit WhitelistUpdated(account, true);

            // If the contribution is greater than 0, add it to the totalRaised
            if (contribution > 0) {
                contributions[account] = contributions[account].add(
                    contribution
                );
                totalRaised = totalRaised.add(contribution);
                numOfContributors++;

                // Add the contributor to the list if not already present
                if (!isContributor(account)) {
                    contributorsList.push(account);
                }

                // emit totalContributed(account, contribution, block.timestamp);
                emit totalContributed(
                    _accounts[i],
                    _contributions[i],
                    block.timestamp
                );
            }
        }
    }

    //setter function for MaxContribution
    function setMaxContribution(uint256 _max) external onlyRole(ADMIN_ROLE) {
        maxContribution = _max;
        emit MaxContributionSet(_max);
    }

    //setter function for increaseHardCap
    function increaseHardCap(uint256 _newHardCap)
        external
        onlyRole(ADMIN_ROLE)
    {
        hardCap = _newHardCap;
        emit HardCapIncreased(_newHardCap);
    }

    // Getter function to check if hardCap is set
    function isHardCapSet() external view returns (bool) {
        return hardCap > 0; 
    }

    // setter function for changingFeePercentage
    function setFeePercent(uint256 _feePercent) external onlyRole(ADMIN_ROLE) {
        feePercent = _feePercent;
    }

    // // getContract Balance
    // function getContractBalance() public view returns(uint){
    //     return address(this).balance;
    // }
}
