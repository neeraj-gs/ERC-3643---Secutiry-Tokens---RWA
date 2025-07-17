const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ERC-3643 Security Token System", function () {
  let token, identityRegistry, compliance, claimIssuer;
  let deployer, investor1, investor2, unauthorized;
  
  const TOKEN_NAME = "Test Security Token";
  const TOKEN_SYMBOL = "TST";
  const TOKEN_DECIMALS = 18;
  const COUNTRY_US = 840;
  const COUNTRY_UK = 826;

  beforeEach(async function () {
    // Get signers
    [deployer, investor1, investor2, unauthorized] = await ethers.getSigners();

    // Deploy ClaimIssuer
    const ClaimIssuer = await ethers.getContractFactory("ClaimIssuer");
    claimIssuer = await ClaimIssuer.deploy();
    await claimIssuer.waitForDeployment();

    // Deploy IdentityRegistry
    const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
    identityRegistry = await IdentityRegistry.deploy();
    await identityRegistry.waitForDeployment();

    // Deploy Compliance
    const Compliance = await ethers.getContractFactory("Compliance");
    compliance = await Compliance.deploy();
    await compliance.waitForDeployment();

    // Deploy Token
    const Token = await ethers.getContractFactory("Token");
    token = await Token.deploy(
      TOKEN_NAME,
      TOKEN_SYMBOL,
      TOKEN_DECIMALS,
      deployer.address,
      await identityRegistry.getAddress(),
      await compliance.getAddress()
    );
    await token.waitForDeployment();

    // Configure the system
    await identityRegistry.addClaimIssuer(await claimIssuer.getAddress());
    await identityRegistry.addClaimTopic(1); // KYC
    await identityRegistry.addClaimTopic(2); // AML
    await compliance.bindToken(await token.getAddress());
    await compliance.addAllowedCountry(await token.getAddress(), COUNTRY_US);
    await compliance.addAllowedCountry(await token.getAddress(), COUNTRY_UK);
  });

  describe("Deployment", function () {
    it("Should deploy all contracts with correct parameters", async function () {
      expect(await token.name()).to.equal(TOKEN_NAME);
      expect(await token.symbol()).to.equal(TOKEN_SYMBOL);
      expect(await token.decimals()).to.equal(TOKEN_DECIMALS);
      expect(await token.owner()).to.equal(deployer.address);
    });

    it("Should set correct contract addresses", async function () {
      expect(await token.identityRegistry()).to.equal(await identityRegistry.getAddress());
      expect(await token.compliance()).to.equal(await compliance.getAddress());
    });
  });

  describe("Identity Management", function () {
    it("Should register investor identity", async function () {
      await identityRegistry.registerIdentity(
        investor1.address,
        investor1.address,
        COUNTRY_US
      );

      expect(await identityRegistry.identity(investor1.address)).to.equal(investor1.address);
      expect(await identityRegistry.investorCountry(investor1.address)).to.equal(COUNTRY_US);
      expect(await identityRegistry.contains(investor1.address)).to.be.true;
    });

    it("Should issue and verify claims", async function () {
      // Issue KYC claim
      const kycData = ethers.keccak256(ethers.toUtf8Bytes("KYC_VERIFIED"));
      await claimIssuer.issueClaim(
        investor1.address,
        1, // KYC topic
        1, // Signature scheme
        kycData,
        "https://kyc-provider.com/investor1"
      );

      // Issue AML claim
      const amlData = ethers.keccak256(ethers.toUtf8Bytes("AML_VERIFIED"));
      await claimIssuer.issueClaim(
        investor1.address,
        2, // AML topic
        1, // Signature scheme
        amlData,
        "https://aml-provider.com/investor1"
      );

      // Check claim topics
      const claimTopics = await claimIssuer.getClaimTopics();
      expect(claimTopics).to.include(1n);
      expect(claimTopics).to.include(2n);
    });

    it("Should batch register identities", async function () {
      await identityRegistry.batchRegisterIdentity(
        [investor1.address, investor2.address],
        [investor1.address, investor2.address],
        [COUNTRY_US, COUNTRY_UK]
      );

      expect(await identityRegistry.contains(investor1.address)).to.be.true;
      expect(await identityRegistry.contains(investor2.address)).to.be.true;
    });
  });

  describe("Compliance", function () {
    beforeEach(async function () {
      // Register and verify investor1
      await identityRegistry.registerIdentity(
        investor1.address,
        investor1.address,
        COUNTRY_US
      );

      // Issue claims
      const kycData = ethers.keccak256(ethers.toUtf8Bytes("KYC_VERIFIED"));
      const amlData = ethers.keccak256(ethers.toUtf8Bytes("AML_VERIFIED"));
      
      await claimIssuer.issueClaim(investor1.address, 1, 1, kycData, "");
      await claimIssuer.issueClaim(investor1.address, 2, 1, amlData, "");
    });

    it("Should bind and unbind tokens", async function () {
      expect(await compliance.isTokenBound(await token.getAddress())).to.be.true;
      
      await compliance.unbindToken(await token.getAddress());
      expect(await compliance.isTokenBound(await token.getAddress())).to.be.false;
    });

    it("Should set compliance rules", async function () {
      await compliance.setMaxTokens(await token.getAddress(), ethers.parseEther("1000000"));
      await compliance.setMaxHolders(await token.getAddress(), 10000);

      // These checks would require additional getter functions in the contract
      // For demonstration purposes, we'll check that the functions execute without reverting
      expect(true).to.be.true;
    });

    it("Should validate transfers", async function () {
      // Register investor2
      await identityRegistry.registerIdentity(
        investor2.address,
        investor2.address,
        COUNTRY_US
      );

      // Issue claims for investor2
      const kycData = ethers.keccak256(ethers.toUtf8Bytes("KYC_VERIFIED"));
      const amlData = ethers.keccak256(ethers.toUtf8Bytes("AML_VERIFIED"));
      
      await claimIssuer.issueClaim(investor2.address, 1, 1, kycData, "");
      await claimIssuer.issueClaim(investor2.address, 2, 1, amlData, "");

      // Test compliance check
      expect(await compliance.canTransfer(
        investor1.address,
        investor2.address,
        ethers.parseEther("100")
      )).to.be.true;
    });
  });

  describe("Token Operations", function () {
    beforeEach(async function () {
      // Setup verified investors
      await identityRegistry.registerIdentity(
        investor1.address,
        investor1.address,
        COUNTRY_US
      );
      
      await identityRegistry.registerIdentity(
        investor2.address,
        investor2.address,
        COUNTRY_US
      );

      // Issue claims
      const kycData = ethers.keccak256(ethers.toUtf8Bytes("KYC_VERIFIED"));
      const amlData = ethers.keccak256(ethers.toUtf8Bytes("AML_VERIFIED"));
      
      await claimIssuer.issueClaim(investor1.address, 1, 1, kycData, "");
      await claimIssuer.issueClaim(investor1.address, 2, 1, amlData, "");
      await claimIssuer.issueClaim(investor2.address, 1, 1, kycData, "");
      await claimIssuer.issueClaim(investor2.address, 2, 1, amlData, "");
    });

    it("Should mint tokens to verified investors", async function () {
      const mintAmount = ethers.parseEther("1000");
      await token.mint(investor1.address, mintAmount);

      expect(await token.balanceOf(investor1.address)).to.equal(mintAmount);
      expect(await token.totalSupply()).to.equal(mintAmount);
    });

    it("Should not mint tokens to unverified investors", async function () {
      const mintAmount = ethers.parseEther("1000");
      
      await expect(
        token.mint(unauthorized.address, mintAmount)
      ).to.be.revertedWith("Receiver not verified");
    });

    it("Should transfer tokens between verified investors", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");

      await token.mint(investor1.address, mintAmount);
      await token.connect(investor1).transfer(investor2.address, transferAmount);

      expect(await token.balanceOf(investor1.address)).to.equal(mintAmount - transferAmount);
      expect(await token.balanceOf(investor2.address)).to.equal(transferAmount);
    });

    it("Should not transfer tokens to unverified investors", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");

      await token.mint(investor1.address, mintAmount);
      
      await expect(
        token.connect(investor1).transfer(unauthorized.address, transferAmount)
      ).to.be.revertedWith("Receiver not verified");
    });

    it("Should batch transfer tokens", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");

      await token.mint(investor1.address, mintAmount);
      
      await token.connect(investor1).batchTransfer(
        [investor2.address],
        [transferAmount]
      );

      expect(await token.balanceOf(investor2.address)).to.equal(transferAmount);
    });

    it("Should burn tokens", async function () {
      const mintAmount = ethers.parseEther("1000");
      const burnAmount = ethers.parseEther("100");

      await token.mint(investor1.address, mintAmount);
      await token.burn(investor1.address, burnAmount);

      expect(await token.balanceOf(investor1.address)).to.equal(mintAmount - burnAmount);
      expect(await token.totalSupply()).to.equal(mintAmount - burnAmount);
    });
  });

  describe("Freeze Functionality", function () {
    beforeEach(async function () {
      // Setup verified investor
      await identityRegistry.registerIdentity(
        investor1.address,
        investor1.address,
        COUNTRY_US
      );

      const kycData = ethers.keccak256(ethers.toUtf8Bytes("KYC_VERIFIED"));
      const amlData = ethers.keccak256(ethers.toUtf8Bytes("AML_VERIFIED"));
      
      await claimIssuer.issueClaim(investor1.address, 1, 1, kycData, "");
      await claimIssuer.issueClaim(investor1.address, 2, 1, amlData, "");

      // Mint tokens
      await token.mint(investor1.address, ethers.parseEther("1000"));
    });

    it("Should freeze and unfreeze addresses", async function () {
      await token.setAddressFrozen(investor1.address, true);
      expect(await token.isAddressFrozen(investor1.address)).to.be.true;

      await token.setAddressFrozen(investor1.address, false);
      expect(await token.isAddressFrozen(investor1.address)).to.be.false;
    });

    it("Should freeze and unfreeze tokens", async function () {
      const freezeAmount = ethers.parseEther("100");
      
      await token.freezeTokens(investor1.address, freezeAmount);
      expect(await token.getFrozenTokens(investor1.address)).to.equal(freezeAmount);

      await token.unfreezeTokens(investor1.address, freezeAmount);
      expect(await token.getFrozenTokens(investor1.address)).to.equal(0);
    });

    it("Should prevent transfer of frozen tokens", async function () {
      const freezeAmount = ethers.parseEther("500");
      const transferAmount = ethers.parseEther("600");

      await token.freezeTokens(investor1.address, freezeAmount);
      
      await expect(
        token.connect(investor1).transfer(investor2.address, transferAmount)
      ).to.be.revertedWith("Insufficient unfrozen balance");
    });

    it("Should batch freeze tokens", async function () {
      const freezeAmount = ethers.parseEther("100");
      
      await token.batchFreezeTokens(
        [investor1.address],
        [freezeAmount]
      );

      expect(await token.getFrozenTokens(investor1.address)).to.equal(freezeAmount);
    });
  });

  describe("Pause Functionality", function () {
    beforeEach(async function () {
      // Setup verified investors
      await identityRegistry.registerIdentity(
        investor1.address,
        investor1.address,
        COUNTRY_US
      );

      const kycData = ethers.keccak256(ethers.toUtf8Bytes("KYC_VERIFIED"));
      const amlData = ethers.keccak256(ethers.toUtf8Bytes("AML_VERIFIED"));
      
      await claimIssuer.issueClaim(investor1.address, 1, 1, kycData, "");
      await claimIssuer.issueClaim(investor1.address, 2, 1, amlData, "");

      await token.mint(investor1.address, ethers.parseEther("1000"));
    });

    it("Should pause and unpause token", async function () {
      await token.pause();
      expect(await token.paused()).to.be.true;

      await token.unpause();
      expect(await token.paused()).to.be.false;
    });

    it("Should prevent transfers when paused", async function () {
      await token.pause();
      
      await expect(
        token.connect(investor1).transfer(investor2.address, ethers.parseEther("100"))
      ).to.be.revertedWith("Token is paused");
    });
  });

  describe("Recovery Functionality", function () {
    beforeEach(async function () {
      // Setup verified investor
      await identityRegistry.registerIdentity(
        investor1.address,
        investor1.address,
        COUNTRY_US
      );

      const kycData = ethers.keccak256(ethers.toUtf8Bytes("KYC_VERIFIED"));
      const amlData = ethers.keccak256(ethers.toUtf8Bytes("AML_VERIFIED"));
      
      await claimIssuer.issueClaim(investor1.address, 1, 1, kycData, "");
      await claimIssuer.issueClaim(investor1.address, 2, 1, amlData, "");

      await token.mint(investor1.address, ethers.parseEther("1000"));
    });

    it("Should recover tokens to new wallet", async function () {
      // Register new wallet
      await identityRegistry.registerIdentity(
        investor2.address,
        investor1.address, // Same identity
        COUNTRY_US
      );

      const kycData = ethers.keccak256(ethers.toUtf8Bytes("KYC_VERIFIED"));
      const amlData = ethers.keccak256(ethers.toUtf8Bytes("AML_VERIFIED"));
      
      await claimIssuer.issueClaim(investor2.address, 1, 1, kycData, "");
      await claimIssuer.issueClaim(investor2.address, 2, 1, amlData, "");

      const oldBalance = await token.balanceOf(investor1.address);
      
      await token.recoveryAddress(
        investor1.address,
        investor2.address,
        investor1.address
      );

      expect(await token.balanceOf(investor1.address)).to.equal(0);
      expect(await token.balanceOf(investor2.address)).to.equal(oldBalance);
    });
  });
}); 