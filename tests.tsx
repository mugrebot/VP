import { expect } from "chai";
import { ethers } from "hardhat";
import { YourContract } from "../typechain-types";
import { Contract, BigNumber, Signer } from "ethers";

describe("YourContract", function () {
  let YourContract, yourContract: Contract;

  beforeEach(async function () {
    YourContract = await ethers.getContractFactory("YourContract");
    yourContract = await YourContract.deploy();
    await yourContract.deployed();
  });

  it("should deploy the contract and set the admin", async function () {
    const admin = await yourContract.admins(await yourContract.deployTransaction.from);
    expect(admin).to.be.true;
  });

  // Test start_submission_period function
  it("should start the submission period", async function () {
    await yourContract.start_submission_period(1);
    expect(yourContract.submission_time).to.not.equal(0);
  });

  // Test start_voting_period function
  it("should start the voting period", async function () {
    await yourContract.end_submission_period();
    await yourContract.start_voting_period(1);
    expect(yourContract.voting_time).to.not.equal(0);
  });

  // Test addSubmission function
  it("should add a submission", async function () {
    await yourContract.start_submission_period(1);
    await yourContract.addSubmission("0x232B2a9Bb8EAEC75eb6cF3183717072e7bd33016", "Test submission");
    const submission = await yourContract.submissions(0);
    expect(submission.submitter).to.equal("0x232B2a9Bb8EAEC75eb6cF3183717072e7bd33016");
    expect(submission.submission).to.equal("Test submission");
    expect(submission.votes).to.equal(0);
  });

  // Test add_funds function
  it("should add funds", async function () {
    await yourContract.start_submission_period(1);
    const [_, funder] = await ethers.getSigners();
    await funder.sendTransaction({
      to: yourContract.address,
      value: ethers.utils.parseEther("1.0"),
    });
    const funderBalance = await yourContract.funders(funder.address);
    expect(funderBalance).to.equal(ethers.utils.parseEther("1.0"));
  });

  // Test vote function
  it("should vote for a submission", async function () {
    await yourContract.start_submission_period(1);
    await yourContract.addSubmission("0x232B2a9Bb8EAEC75eb6cF3183717072e7bd33016", "Test submission");

    const [_, funder] = await ethers.getSigners();
    await funder.sendTransaction({
      to: yourContract.address,
      value: ethers.utils.parseEther("1.0"),
    });

    await yourContract.end_submission_period();

    await yourContract.start_voting_period(1);
    await yourContract.connect(funder).vote(0, ethers.utils.parseEther("0.5"));
    const submission = await yourContract.submissions(0);
    expect(submission.votes).to.equal(ethers.utils.parseEther("0.5"));
  });


  // Test change_vote function
  it("should change a vote for a submission", async function () {
    await yourContract.start_submission_period(1);
    await yourContract.addSubmission("0x232B2a9Bb8EAEC75eb6cF3183717072e7bd33016", "Test submission");
    await yourContract.addSubmission("0x232B2a9Bb8EAEC75eb6cF3183717072e7bd33016", "Test submission 2");

    const [_, funder] = await ethers.getSigners();
    await funder.sendTransaction({
      to: yourContract.address,
      value: ethers.utils.parseEther("1.0"),
    });

    await yourContract.end_submission_period();

    const submission1 = await yourContract.submissions(0);
    const submission2 = await yourContract.submissions(1);

    await yourContract.start_voting_period(1);
    await yourContract.connect(funder).vote(0, ethers.utils.parseEther("0.5"));
    await yourContract.connect(funder).change_vote(0, 1, ethers.utils.parseEther("0.25"));

    expect(submission2.votes).to.equal(submission1.votes);
  });

  // Test distribute function
  it("should distribute rewards, donations, and refunds", async function () {
    await yourContract.start_submission_period(1);
    await yourContract.addSubmission("0x232B2a9Bb8EAEC75eb6cF3183717072e7bd33016", "Test submission");

    const [_, funder] = await ethers.getSigners();
    await funder.sendTransaction({
      to: yourContract.address,
      value: ethers.utils.parseEther("1.0"),
    });

    await yourContract.end_submission_period();
    await yourContract.start_voting_period(1);
    await yourContract.connect(funder).vote(0, ethers.utils.parseEther("1.0"));

    await yourContract.end_voting_period();


    //get initial balance of funder and platform
    const initialPlatformBalance = await ethers.provider.getBalance("0xcd258fCe467DDAbA643f813141c3560FF6c12518");

    await yourContract.distribute();

    //get final balance of funder and platform
    const finalPlatformBalance = await ethers.provider.getBalance("0xcd258fCe467DDAbA643f813141c3560FF6c12518");

    expect(finalPlatformBalance > initialPlatformBalance).to.be.true;

  });

  // Test use_unused_votes function
  it("should use unused admin votes", async function () {
    await yourContract.start_submission_period(1);
    await yourContract.addSubmission("0x232B2a9Bb8EAEC75eb6cF3183717072e7bd33016", "Test submission");




    const [_, funder] = await ethers.getSigners();
    await funder.sendTransaction({
      to: yourContract.address,
      value: ethers.utils.parseEther("1.0"),
    });

    await yourContract.end_submission_period();
    await yourContract.start_voting_period(1);
    await yourContract.connect(funder).vote(0, ethers.utils.parseEther("0.5"));

    await yourContract.use_unused_votes(0);

    const submission = await yourContract.submissions(0);

    expect(submission.votes).to.equal(ethers.utils.parseEther("1.5"));



  });
});


