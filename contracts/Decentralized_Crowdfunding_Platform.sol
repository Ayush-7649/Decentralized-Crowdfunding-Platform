// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Crowdfunding Platform
 * @dev A smart contract for crowdfunding projects with automatic refunds
 * @author Crowdfunding Team
 */
contract Project {
    // State variables
    address public owner;
    string public projectTitle;
    string public description;
    uint256 public fundingGoal;
    uint256 public deadline;
    uint256 public totalFundsRaised;
    bool public isProjectActive;
    bool public goalAchieved;
    
    // Mapping to track individual contributions
    mapping(address => uint256) public contributions;
    address[] public contributors;
    
    // Events for transparency
    event ContributionReceived(address indexed contributor, uint256 amount, uint256 timestamp);
    event FundingGoalReached(uint256 totalAmount, uint256 timestamp);
    event FundsWithdrawn(address indexed owner, uint256 amount, uint256 timestamp);
    event RefundProcessed(address indexed contributor, uint256 amount, uint256 timestamp);
    event ProjectStatusChanged(bool isActive, uint256 timestamp);
    
    // Modifiers for access control and validation
    modifier onlyOwner() {
        require(msg.sender == owner, "Only project owner can perform this action");
        _;
    }
    
    modifier projectActive() {
        require(isProjectActive, "Project is not active");
        require(block.timestamp < deadline, "Funding deadline has passed");
        _;
    }
    
    modifier deadlinePassed() {
        require(block.timestamp >= deadline, "Funding deadline has not passed yet");
        _;
    }
    
    modifier validContribution() {
        require(msg.value > 0, "Contribution must be greater than 0");
        _;
    }
    
    /**
     * @dev Constructor to initialize the crowdfunding project
     * @param _title Project title
     * @param _description Project description
     * @param _fundingGoal Target amount to raise (in wei)
     * @param _durationDays Duration of funding period in days
     */
    constructor(
        string memory _title,
        string memory _description,
        uint256 _fundingGoal,
        uint256 _durationDays
    ) {
        require(bytes(_title).length > 0, "Project title cannot be empty");
        require(bytes(_description).length > 0, "Project description cannot be empty");
        require(_fundingGoal > 0, "Funding goal must be greater than 0");
        require(_durationDays > 0, "Duration must be at least 1 day");
        
        owner = msg.sender;
        projectTitle = _title;
        description = _description;
        fundingGoal = _fundingGoal;
        deadline = block.timestamp + (_durationDays * 1 days);
        totalFundsRaised = 0;
        isProjectActive = true;
        goalAchieved = false;
    }
    
    /**
     * @dev Core Function 1: Contribute funds to the project
     * Contributors can send ETH to support the project
     */
    function contributeToProject() 
        external 
        payable 
        projectActive 
        validContribution 
    {
        // Record the contribution
        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
        }
        
        contributions[msg.sender] += msg.value;
        totalFundsRaised += msg.value;
        
        // Emit contribution event
        emit ContributionReceived(msg.sender, msg.value, block.timestamp);
        
        // Check if funding goal is reached
        if (totalFundsRaised >= fundingGoal && !goalAchieved) {
            goalAchieved = true;
            emit FundingGoalReached(totalFundsRaised, block.timestamp);
        }
    }
    
    /**
     * @dev Core Function 2: Withdraw funds (only if goal is achieved)
     * Project owner can withdraw funds if the funding goal is met
     */
    function withdrawFunds() 
        external 
        onlyOwner 
        deadlinePassed 
    {
        require(goalAchieved, "Funding goal was not reached");
        require(address(this).balance > 0, "No funds available to withdraw");
        
        uint256 withdrawAmount = address(this).balance;
        isProjectActive = false;
        
        // Transfer funds to project owner
        (bool success, ) = payable(owner).call{value: withdrawAmount}("");
        require(success, "Fund withdrawal failed");
        
        emit FundsWithdrawn(owner, withdrawAmount, block.timestamp);
        emit ProjectStatusChanged(false, block.timestamp);
    }
    
    /**
     * @dev Core Function 3: Claim refund (only if goal is not achieved)
     * Contributors can get their money back if funding goal is not met
     */
    function claimRefund() 
        external 
        deadlinePassed 
    {
        require(!goalAchieved, "Funding goal was reached, refunds not available");
        require(contributions[msg.sender] > 0, "No contributions found for this address");
        
        uint256 refundAmount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        
        // Transfer refund to contributor
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");
        
        emit RefundProcessed(msg.sender, refundAmount, block.timestamp);
    }
    
    // View functions for getting project information
    
    /**
     * @dev Get comprehensive project details
     */
    function getProjectInfo() 
        external 
        view 
        returns (
            string memory title,
            string memory desc,
            address projectOwner,
            uint256 goal,
            uint256 raised,
            uint256 timeLeft,
            bool active,
            bool goalReached,
            uint256 contributorCount
        ) 
    {
        uint256 remaining = 0;
        if (block.timestamp < deadline) {
            remaining = deadline - block.timestamp;
        }
        
        return (
            projectTitle,
            description,
            owner,
            fundingGoal,
            totalFundsRaised,
            remaining,
            isProjectActive,
            goalAchieved,
            contributors.length
        );
    }
    
    /**
     * @dev Get contribution amount for a specific address
     */
    function getContribution(address contributor) 
        external 
        view 
        returns (uint256) 
    {
        return contributions[contributor];
    }
    
    /**
     * @dev Get list of all contributors
     */
    function getAllContributors() 
        external 
        view 
        returns (address[] memory) 
    {
        return contributors;
    }
    
    /**
     * @dev Get funding progress percentage
     */
    function getFundingProgress() 
        external 
        view 
        returns (uint256 percentage) 
    {
        if (fundingGoal == 0) return 0;
        return (totalFundsRaised * 100) / fundingGoal;
    }
    
    /**
     * @dev Check if deadline has passed
     */
    function isDeadlinePassed() 
        external 
        view 
        returns (bool) 
    {
        return block.timestamp >= deadline;
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() 
        external 
        view 
        returns (uint256) 
    {
        return address(this).balance;
    }
    
    /**
     * @dev Emergency function to deactivate project (only owner)
     */
    function deactivateProject() 
        external 
        onlyOwner 
    {
        isProjectActive = false;
        emit ProjectStatusChanged(false, block.timestamp);
    }
}
