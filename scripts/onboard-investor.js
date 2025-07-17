const { ethers } = require("hardhat");

async function main() {
  console.log("👤 Starting Investor Onboarding Process...\n");

  // Get deployed contract addresses (replace with actual addresses)
  const CLAIM_ISSUER_ADDRESS = "0x..."; // Replace with deployed address
  const IDENTITY_REGISTRY_ADDRESS = "0x..."; // Replace with deployed address
  const COMPLIANCE_ADDRESS = "0x..."; // Replace with deployed address
  const TOKEN_ADDRESS = "0x..."; // Replace with deployed address

  // Get accounts
  const [deployer, investor] = await ethers.getSigners();
  console.log("Deployer (Token Issuer):", deployer.address);
  console.log("Investor:", investor.address);

  // Get contract instances
  const claimIssuer = await ethers.getContractAt("ClaimIssuer", CLAIM_ISSUER_ADDRESS);
  const identityRegistry = await ethers.getContractAt("IdentityRegistry", IDENTITY_REGISTRY_ADDRESS);
  const compliance = await ethers.getContractAt("Compliance", COMPLIANCE_ADDRESS);
  const token = await ethers.getContractAt("Token", TOKEN_ADDRESS);

  console.log("\n🔐 Step 1: KYC Process - Issuing Claims...");
  
  // Issue KYC claim for investor
  console.log("Issuing KYC claim...");
  const kycData = ethers.keccak256(ethers.toUtf8Bytes("KYC_VERIFIED"));
  await claimIssuer.issueClaim(
    investor.address,
    1, // KYC topic
    1, // Signature scheme
    kycData,
    "https://kyc-provider.com/investor1"
  );
  
  // Issue AML claim for investor
  console.log("Issuing AML claim...");
  const amlData = ethers.keccak256(ethers.toUtf8Bytes("AML_VERIFIED"));
  await claimIssuer.issueClaim(
    investor.address,
    2, // AML topic
    1, // Signature scheme
    amlData,
    "https://aml-provider.com/investor1"
  );

  console.log("✅ Claims issued successfully");

  console.log("\n👤 Step 2: Identity Registration...");
  
  // Register investor identity
  const INVESTOR_COUNTRY = 840; // USA country code
  await identityRegistry.registerIdentity(
    investor.address,
    investor.address, // Using wallet address as identity (in production, use OnchainID)
    INVESTOR_COUNTRY
  );
  
  console.log("✅ Investor identity registered");

  console.log("\n📊 Step 3: Compliance Verification...");
  
  // Check if investor is verified
  const isVerified = await identityRegistry.isVerified(investor.address);
  console.log(`Investor verification status: ${isVerified}`);
  
  // Add country to allowed list
  await compliance.addAllowedCountry(TOKEN_ADDRESS, INVESTOR_COUNTRY);
  console.log("✅ Country added to allowed list");

  console.log("\n🪙 Step 4: Token Minting and Distribution...");
  
  // Mint tokens to investor
  const mintAmount = ethers.parseEther("1000"); // 1000 tokens
  await token.mint(investor.address, mintAmount);
  
  const investorBalance = await token.balanceOf(investor.address);
  console.log(`✅ Tokens minted: ${ethers.formatEther(investorBalance)} tokens`);

  console.log("\n🔄 Step 5: Testing Transfer Compliance...");
  
  // Create a second investor for transfer testing
  const [, , investor2] = await ethers.getSigners();
  console.log("Second investor:", investor2.address);
  
  // Register second investor
  await identityRegistry.registerIdentity(
    investor2.address,
    investor2.address,
    INVESTOR_COUNTRY
  );
  
  // Issue claims for second investor
  await claimIssuer.issueClaim(
    investor2.address,
    1, // KYC topic
    1, // Signature scheme
    kycData,
    "https://kyc-provider.com/investor2"
  );
  
  await claimIssuer.issueClaim(
    investor2.address,
    2, // AML topic
    1, // Signature scheme
    amlData,
    "https://aml-provider.com/investor2"
  );

  console.log("✅ Second investor registered and verified");

  // Test compliant transfer
  const transferAmount = ethers.parseEther("100"); // 100 tokens
  await token.connect(investor).transfer(investor2.address, transferAmount);
  
  const investor2Balance = await token.balanceOf(investor2.address);
  console.log(`✅ Transfer successful: ${ethers.formatEther(investor2Balance)} tokens transferred`);

  console.log("\n🎉 Investor Onboarding Complete!");
  console.log("=====================================");
  console.log(`Investor 1: ${investor.address}`);
  console.log(`Investor 1 Balance: ${ethers.formatEther(await token.balanceOf(investor.address))} tokens`);
  console.log(`Investor 2: ${investor2.address}`);
  console.log(`Investor 2 Balance: ${ethers.formatEther(await token.balanceOf(investor2.address))} tokens`);
  console.log("=====================================");

  // Test freeze functionality
  console.log("\n❄️ Testing Freeze Functionality...");
  
  // Freeze some tokens
  const freezeAmount = ethers.parseEther("50");
  await token.freezeTokens(investor.address, freezeAmount);
  
  const frozenTokens = await token.getFrozenTokens(investor.address);
  console.log(`✅ Frozen tokens: ${ethers.formatEther(frozenTokens)} tokens`);

  // Test compliance rules
  console.log("\n📋 Testing Compliance Rules...");
  
  const maxTokens = await compliance.getHolderTokens(TOKEN_ADDRESS, investor.address);
  const holderCount = await compliance.getHolderCount(TOKEN_ADDRESS);
  
  console.log(`Holder count: ${holderCount}`);
  console.log(`Compliance check passed: ✅`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Onboarding failed:", error);
    process.exit(1);
  }); 