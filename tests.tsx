import { expect } from "chai";
import { ethers } from "hardhat";
import { Viaprize } from "../typechain-types";

import { Contract, BigNumber, Signer } from "ethers";

describe("Viaprize", () => {
  let Viaprize: Contract;
  let owner: Signer;
  let admin1: Signer;
  let funder1: Signer;
  let funder2: Signer;
  let submitter1: Signer;
  let submitter2: Signer;

  beforeEach(async () => {
    const ViaprizeFactory = await ethers.getContractFactory("Viaprize");
    [owner, admin1, funder1, funder2, submitter1, submitter2] = await ethers.getSigners();
    Viaprize = await ViaprizeFactory.deploy();
    await Viaprize.deployed();
  });

  it("should set the owner as an admin", async () => {
    expect(await Viaprize.admins(await owner.getAddress())).to.equal(true);
  });

  it("should allow an admin to start the submission period", async () => {
    await Viaprize.connect(admin1).start_submission_period(5);
    const submissionTime = await Viaprize.submission_time();
    expect(submissionTime).to.be.gt(0);
  });

  it("should allow an admin to start the voting period after the submission period", async () => {
    await Viaprize.connect(admin1).start_submission_period(1);
    await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
    await ethers.provider.send("evm_mine", []); // Mine the next block
    await Viaprize.connect(admin1).start_voting_period(1);
    const votingTime = await Viaprize.voting_time();
    expect(votingTime).to.be.gt(await Viaprize.submission_time());
  });

  it("should allow a user to submit during the submission period", async () => {
    await Viaprize.connect(admin1).start_submission_period(1);
    await Viaprize.connect(submitter1).addSubmission(await submitter1.getAddress(), "Submission 1");
    const submission = await Viaprize.submissions(0);
    expect(submission.submitter).to.equal(await submitter1.getAddress());
    expect(submission.submission).to.equal("Submission 1");
  });

  it("should not allow a user to submit after the submission period", async () => {
    await Viaprize.connect(admin1).start_submission_period(1);
    await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
    await ethers.provider.send("evm_mine", []); // Mine the next block
    await expect(
      Viaprize.connect(submitter1).addSubmission(await submitter1.getAddress(), "Submission 1"),
    ).to.be.revertedWith("Submission period is over");
  });

  it("should allow a user to vote during the voting period", async () => {
    await Viaprize.connect(admin1).start_submission_period(1);
    await Viaprize.connect(submitter1).addSubmission(await submitter1.getAddress(), "Submission 1");
    await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
    await ethers.provider.send("evm_mine", []); // Mine the next block
    await Viaprize.connect(admin1).start_voting_period(1);
    await Viaprize.connect(submitter2).vote(0);
    const submission = await Viaprize.submissions(0);
    expect(submission.votes).to.equal(1);
  });

  it("should not allow a user to vote after the voting period", async () => {
    await Viaprize.connect(admin1).start_submission_period(1);
    await Viaprize.connect(submitter1).addSubmission(await submitter1.getAddress(), "Submission 1");
    await ethers.provider.send("evm_increaseTime", [86400 * 2]); // Increase time by 2 days
    await ethers.provider.send("evm_mine", []); // Mine the next block
    await Viaprize.connect(admin1).start_voting_period(1);
    await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
    await ethers.provider.send("evm_mine", []); // Mine the next block
    await expect(Viaprize.connect(submitter2).vote(0)).to.be.revertedWith("Voting period is over");
  });

  it("should allow a user to fund the prize pool", async () => {
    await Viaprize.connect(funder1).fund({ value: ethers.utils.parseEther("1") });
    const prizePool = await Viaprize.prize_pool();
    expect(prizePool).to.equal(ethers.utils.parseEther("1"));
  });

  it("should calculate and distribute rewards after the voting period", async () => {
    await Viaprize.connect(admin1).start_submission_period(1);
    await Viaprize.connect(submitter1).addSubmission(await submitter1.getAddress(), "Submission 1");
    await Viaprize.connect(submitter2).addSubmission(await submitter2.getAddress(), "Submission 2");
    await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
    await ethers.provider.send("evm_mine", []); // Mine the next block
    await Viaprize.connect(admin1).start_voting_period(1);
    await Viaprize.connect(submitter1).vote(1); // submitter1 votes for submitter2's submission
    await Viaprize.connect(submitter2).vote(0); // submitter2 votes for submitter1's submission
    await ethers.provider.send("evm_increaseTime", [86400]); // Increase time by 1 day
    await ethers.provider.send("evm_mine", []); // Mine the next block
    await Viaprize.connect(funder1).fund({ value: ethers.utils.parseEther("1") });
    await Viaprize.connect(admin1).end_voting_period();
    const submitter1Balance = await Viaprize.balanceOf(await submitter1.getAddress());
    const submitter2Balance = await Viaprize.balanceOf(await submitter2.getAddress());
    expect(submitter1Balance).to.equal(ethers.utils.parseEther("0.5"));
    expect(submitter2Balance).to.equal(ethers.utils.parseEther("0.5"));
  });
});
