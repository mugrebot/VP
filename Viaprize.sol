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

uint256 public total_refunds; //this will be the total amount of refunds available

uint256 public total_donations; //this will be the total amount of donations to the platform



constructor () {
    //add as many admins as you need to -- replace msg.sender with the address of the admin(s) for now this means the deployer will be the sole admin
    admins[msg.sender] = true;
    admins[0xcd258fCe467DDAbA643f813141c3560FF6c12518] = true;
}

//create a view function for submission time
function get_submission_time() public view returns (uint256) {
    return submission_time;
}

//create a view function for voting time
function get_voting_time() public view returns (uint256) {
    return voting_time;
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
function vote(uint _option, uint _submission, uint amount) public {
    require(block.timestamp < voting_time, "Voting period has ended");
    require(_option == 1 || _option == 2 || _option == 3, "Invalid option");
    require(_submission < submissions.length, "Invalid submission");
    require(votes[msg.sender][_submission] == 0, "You have already voted for this submission");
    require(amount <= funders[msg.sender], "You do not have enough funds to vote this amount");

    uint256 admin_votes = total_votes / 20; // Calculate the 5% voting power for admins
    total_votes -= admin_votes; // Temporarily remove admin votes from the total

    if (_option == 1) {
        submissions[_submission].votes += amount;
        total_votes += amount;
    }
    if (_option == 2) {
        total_donations += amount;
    }
    if (_option == 3) {
        total_refunds += amount;
    }

    votes[msg.sender][_submission] = _option;
    total_votes += admin_votes; // Add admin votes back to the total
    funders[msg.sender] -= amount; // Update funder's balance
}

function change_vote(uint _option, uint _submission, uint amount) public {
    require(block.timestamp < voting_time, "Voting period has ended");
    require(_option == 1 || _option == 2 || _option == 3, "Invalid option");
    require(_submission < submissions.length, "Invalid submission");
    require(votes[msg.sender][_submission] != 0, "You have not voted for this submission");

    uint256 previous_vote = votes[msg.sender][_submission];
    uint256 admin_votes = total_votes / 20; // Calculate the 5% voting power for admins

    // Temporarily remove admin votes from the total
    if (total_votes >= admin_votes) {
        total_votes -= admin_votes;
    }

    // Revert previous vote
    if (previous_vote == 1) {
        if (amount <= submissions[_submission].votes) {
            submissions[_submission].votes -= amount;
            if (total_votes >= amount) {
                total_votes -= amount;
            }
        }
    }
    if (previous_vote == 2) {
        if (amount <= total_donations) {
            total_donations -= amount;
        }
    }
    if (previous_vote == 3) {
        if (amount <= total_refunds) {
            total_refunds -= amount;
        }
    }

    // Apply new vote
    if (_option == 1) {
        submissions[_submission].votes += amount;
        total_votes += amount;
    }
    if (_option == 2) {
        total_donations += amount;
    }
    if (_option == 3) {
        total_refunds += amount;
    }

    // Add back admin votes to the total
    total_votes += admin_votes;

    // Update funder's balance
    uint256 previous_amount = previous_vote * amount;
    if (funders[msg.sender] >= previous_amount) {
        funders[msg.sender] -= previous_amount;
    }
    funders[msg.sender] += amount;

    // Update the vote record
    votes[msg.sender][_submission] = _option;

    // Add admin votes back to the total
    total_votes += admin_votes;
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

    for (uint i = 0; i < submissions.length; i++) {
        if (votes[msg.sender][i] == 1) {
            submissions[i].votes += msg.value;
            total_votes += msg.value;
        }
    }
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
    require(total_rewards + total_votes + total_donations + total_refunds > 0, "There's nothing to distribute");
    require(funderAddresses.length > 0, "There are no funders");

    uint256 admin_votes = total_votes / 20; // Calculate the 5% voting power for admins
    total_donations += admin_votes; // Add admin votes to the total donations

    // Calculate unused votes for admins
    uint256 unused_admin_votes = admin_votes;
    for (uint i = 0; i < submissions.length; i++) {
        // Subtract the votes used by admins for each submission from the total unused votes
        if (votes[msg.sender][i] == 1) {
            if (unused_admin_votes >= submissions[i].votes) {
                unused_admin_votes -= submissions[i].votes;
            } else {
                unused_admin_votes = 0;
            }
        }
    }

    // Add the unused votes to total_donations
    total_donations += unused_admin_votes;

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

    // Transfer donations to the platform
    if (total_donations > 0) {
        payable(PLATFORM_ADDRESS).transfer(total_donations);
    }

    // Distribute refunds based on the proportion of each funder's contribution
    uint256 remaining_refunds = total_refunds;
    for (uint i = 0; i < funderAddresses.length; i++) {
        address funder = funderAddresses[i];
        uint256 funderContribution = funders[funder];
        uint256 refund = (total_refunds * funderContribution) / (total_funds - total_donations - total_rewards);
        if (refund > 0) {
        payable(funder).transfer(refund);
        }
        if (remaining_refunds >= refund) {
            remaining_refunds -= refund;
        } else {
            remaining_refunds = 0;
        }
    }

    // Transfer remaining refunds, if any, to the platform
    if (remaining_refunds > 0) {
        payable(PLATFORM_ADDRESS).transfer(remaining_refunds);
    }


    // Reset the totals
    total_rewards = 0;
    total_votes = 0;
    total_donations = 0;
    total_refunds = 0;
}


    // Add a new function to use unused votes
function use_unused_votes(uint _submission) public {
    require(admins[msg.sender] == true, "You are not an admin");
    require(block.timestamp < voting_time, "Voting period has ended");
    require(_submission < submissions.length, "Invalid submission");

    uint256 admin_votes = total_votes / 20; // Calculate the 5% voting power for admins
    uint256 used_admin_votes = 0;

    // Calculate the used admin votes for each submission
    for (uint i = 0; i < submissions.length; i++) {
        if (votes[msg.sender][i] == 1) {
            used_admin_votes += submissions[i].votes;
        }
    }

    require(used_admin_votes <= admin_votes, "Used admin votes exceed total admin votes");

    uint256 unused_admin_votes = admin_votes - used_admin_votes;

    // Use unused votes for the specified submission
    submissions[_submission].votes += unused_admin_votes;
}
}



//end the contract with the name VIAPRIZE
