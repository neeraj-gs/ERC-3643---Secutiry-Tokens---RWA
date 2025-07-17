const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting ERC-3643 Security Token Deployment...\n");

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Deployment configuration
  const TOKEN_NAME = "Real Estate Security Token";
  const TOKEN_SYMBOL = "REST";
  const TOKEN_DECIMALS = 18;
  const ONCHAIN_ID = deployer.address; // In production, use actual OnchainID

  console.log("\n📋 Deployment Configuration:");
  console.log(`Token Name: ${TOKEN_NAME}`);
  console.log(`Token Symbol: ${TOKEN_SYMBOL}`);
  console.log(`Token Decimals: ${TOKEN_DECIMALS}`);
  console.log(`OnchainID: ${ONCHAIN_ID}`);

  // Step 1: Deploy ClaimIssuer
  console.log("\n🔐 Step 1: Deploying ClaimIssuer...");
  const ClaimIssuer = await ethers.getContractFactory("ClaimIssuer");
  const claimIssuer = await ClaimIssuer.deploy();
  await claimIssuer.waitForDeployment();
  const claimIssuerAddress = await claimIssuer.getAddress();
  console.log(`✅ ClaimIssuer deployed to: ${claimIssuerAddress}`);

  // Step 2: Deploy IdentityRegistry
  console.log("\n👤 Step 2: Deploying IdentityRegistry...");
  const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
  const identityRegistry = await IdentityRegistry.deploy();
  await identityRegistry.waitForDeployment();
  const identityRegistryAddress = await identityRegistry.getAddress();
  console.log(`✅ IdentityRegistry deployed to: ${identityRegistryAddress}`);

  // Step 3: Deploy Compliance
  console.log("\n📊 Step 3: Deploying Compliance...");
  const Compliance = await ethers.getContractFactory("Compliance");
  const compliance = await Compliance.deploy();
  await compliance.waitForDeployment();
  const complianceAddress = await compliance.getAddress();
  console.log(`✅ Compliance deployed to: ${complianceAddress}`);

  // Step 4: Deploy Token
  console.log("\n🪙 Step 4: Deploying Token...");
  const Token = await ethers.getContractFactory("Token");
  const token = await Token.deploy(
    TOKEN_NAME,
    TOKEN_SYMBOL,
    TOKEN_DECIMALS,
    ONCHAIN_ID,
    identityRegistryAddress,
    complianceAddress
  );
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log(`✅ Token deployed to: ${tokenAddress}`);

  // Step 5: Configure the system
  console.log("\n⚙️  Step 5: System Configuration...");

  // Add claim issuer to identity registry
  console.log("Adding claim issuer to identity registry...");
  await identityRegistry.addClaimIssuer(claimIssuerAddress);

  // Add required claim topics (KYC, AML)
  console.log("Adding claim topics...");
  await identityRegistry.addClaimTopic(1); // KYC
  await identityRegistry.addClaimTopic(2); // AML

  // Bind token to compliance
  console.log("Binding token to compliance...");
  await compliance.bindToken(tokenAddress);

  // Set basic compliance rules
  console.log("Setting compliance rules...");
  await compliance.setMaxTokens(tokenAddress, ethers.parseEther("1000000")); // 1M tokens max
  await compliance.setMaxHolders(tokenAddress, 10000); // 10K holders max

  // Step 6: Display deployment summary
  console.log("\n🎉 Deployment Complete!");
  console.log("=====================================");
  console.log(`ClaimIssuer:     ${claimIssuerAddress}`);
  console.log(`IdentityRegistry: ${identityRegistryAddress}`);
  console.log(`Compliance:      ${complianceAddress}`);
  console.log(`Token:           ${tokenAddress}`);
  console.log("=====================================");

  // Step 7: Verify contracts on Etherscan (if not local)
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("\n🔍 Verifying contracts on Etherscan...");
    
    try {
      await hre.run("verify:verify", {
        address: claimIssuerAddress,
        constructorArguments: [],
      });
      console.log("✅ ClaimIssuer verified");
    } catch (error) {
      console.log("❌ ClaimIssuer verification failed:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: identityRegistryAddress,
        constructorArguments: [],
      });
      console.log("✅ IdentityRegistry verified");
    } catch (error) {
      console.log("❌ IdentityRegistry verification failed:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: complianceAddress,
        constructorArguments: [],
      });
      console.log("✅ Compliance verified");
    } catch (error) {
      console.log("❌ Compliance verification failed:", error.message);
    }

    try {
      await hre.run("verify:verify", {
        address: tokenAddress,
        constructorArguments: [
          TOKEN_NAME,
          TOKEN_SYMBOL,
          TOKEN_DECIMALS,
          ONCHAIN_ID,
          identityRegistryAddress,
          complianceAddress
        ],
      });
      console.log("✅ Token verified");
    } catch (error) {
      console.log("❌ Token verification failed:", error.message);
    }
  }

  // Return deployment addresses for use in tests or other scripts
  return {
    claimIssuer: claimIssuerAddress,
    identityRegistry: identityRegistryAddress,
    compliance: complianceAddress,
    token: tokenAddress,
    deployer: deployer.address
  };
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  }); 