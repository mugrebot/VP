// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

contract YourContract {

uint256 submission_time; //this will be the time that the submission period ends
uint256 voting_time; //this will be the time that the voting period ends

mapping (address => uint256) public funders; //this will be a mapping of the addresses of the funders to the amount of eth they have contributed


mapping (address => mapping(uint256 => uint256)) public votes; //this will be a mapping of the addresses of the funders to the amount of votes they have

address public constant PLATFORM_ADDRESS = 0xcd258fCe467DDAbA643f813141c3560FF6c12518; //this will be the address of the platform

address[] public funderAddresses; //this will be an array of the addresses of the funders making it easier to iterate through them

//create a struct for the submissions
struct Submission {
    address submitter;
    string submission;
    uint256 votes;
}

Submission[] public submissions; //this will be an array of the submissions

mapping (address => bool) public admins; //this will be a mapping of the addresses of the admins to a boolean value of true or false

uint256 public total_votes; //this will be the total number of votes

uint256 public total_funds; //this will be the total amount of funds raised

uint256 public total_rewards; //this will be the total amount of rewards available




constructor () {
    //add as many admins as you need to -- replace msg.sender with the address of the admin(s) for now this means the deployer will be the sole admin
    admins[msg.sender] = true;
    admins[0xcd258fCe467DDAbA643f813141c3560FF6c12518] = true;
}


//create a function to start the submission period
function start_submission_period(uint256 _submission_time) public {
    require(admins[msg.sender] == true, "You are not an admin");
    submission_time = block.timestamp + _submission_time * 1 days;
//submission time will be in days
}

//end the submission period
function end_submission_period() public {
    require(admins[msg.sender] == true, "You are not an admin");
    submission_time = 0;
}

function start_voting_period(uint256 _voting_time) public {
    require(admins[msg.sender] == true, "You are not an admin");
    require (block.timestamp > submission_time, "Submission period has not ended");
    voting_time = block.timestamp + _voting_time * 1 days;
    //voting time also in days
}

function end_voting_period() public {
    require(admins[msg.sender] == true, "You are not an admin");
    voting_time = 0;
}

function addSubmission(address submitter, string memory submissionText) public {
    require(block.timestamp < submission_time, "Submission period has ended");
    Submission memory newSubmission = Submission(submitter, submissionText, 0);
    uint256 newIndex = submissions.length;

    // Add new submission to the end of the array
    submissions.push(newSubmission);

    // Shuffle the new submission into the array
    if (newIndex > 0) {
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % newIndex;
        Submission memory temp = submissions[newIndex];
        submissions[newIndex] = submissions[randomIndex];
        submissions[randomIndex] = temp;
    }
}


//create a function to allow funders to vote for a submission, as well as choose option 1, 2, or 3
function vote(uint _submission, uint amount) public {
    require(block.timestamp < voting_time, "Voting period has ended");
    require(_submission < submissions.length, "Invalid submission");
    require(amount <= funders[msg.sender], "You do not have enough funds to vote this amount");

    submissions[_submission].votes += amount;
    funders[msg.sender] -= amount; // Update funder's balance


    
}

function change_vote(uint _previous_submission, uint _submission, uint amount) public {
    require(block.timestamp < voting_time, "Voting period has ended");
    require(_submission < submissions.length, "Invalid submission");

    submissions[_previous_submission].votes -= amount;
    submissions[_submission].votes += amount;

}



//create a function to allow funders to add more funds to the prize -- this will automatically distribute the new funds to the previous votes
function add_funds() public payable {
    require(block.timestamp < submission_time, "Submission period has ended");
    require(msg.value > 0, "You must send some funds");
    
    // Add this condition to add new funder address to the array
    
    funders[msg.sender] += msg.value;
    //check funderAddresses array to see if the address is already in there
    //if not, add it
    bool funderExists = false;
    for (uint i = 0; i < funderAddresses.length; i++) {
        if (funderAddresses[i] == msg.sender) {
            funderExists = true;
        }
    }
    if (!funderExists) {
        funderAddresses.push(msg.sender);
    }

    total_funds += msg.value;
    total_rewards += (msg.value * 95) / 100; // 95% of the funds raised

}

receive () external payable {
    add_funds();
}

fallback () external payable {

}


//create a function for admins to distribute or refund funds

function distribute() public {
    require(admins[msg.sender] == true, "You are not an admin");
    require(block.timestamp > voting_time, "Voting period has not ended");
    require(total_rewards + total_votes > 0, "There's nothing to distribute");
    require(funderAddresses.length > 0, "There are no funders");

    // Transfer 5% of the total funds to the platform
    uint256 platformDonation = (total_funds * 5) / 100;
    payable(PLATFORM_ADDRESS).transfer(platformDonation);

    // Distribute rewards based on votes
    uint256 remaining_rewards = total_rewards;
    for (uint i = 0; i < submissions.length; i++) {
        uint256 submissionVotes = submissions[i].votes;
        if (total_votes > 0) { // Check for total_votes > 0 to avoid division by zero
            uint256 reward = (total_rewards * submissionVotes) / total_votes;
            payable(submissions[i].submitter).transfer(reward);
            if (remaining_rewards >= reward) {
                remaining_rewards -= reward;
            } else {
                remaining_rewards = 0;
            }
        }
    }
    // Reset the totals
    total_rewards = 0;
    total_votes = 0;
    total_funds = 0;
}

    // Add a new function to use unused votes
function use_unused_votes(uint _submission) public {
    require(admins[msg.sender] == true, "You are not an admin");
    require(block.timestamp < voting_time, "Voting period has ended");
    require(_submission < submissions.length, "Invalid submission");
    require(total_funds - total_votes != 0, "There are no unused votes");
    // Calculate the used admin votes for each submission

    uint256 unused_admin_votes = total_funds - total_votes;

    // Use unused votes for the specified submission
    submissions[_submission].votes += unused_admin_votes;
    total_votes += unused_admin_votes;
}
}



//end the contract with the name VIAPRIZE
