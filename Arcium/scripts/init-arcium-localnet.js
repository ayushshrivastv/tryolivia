/**
 * Master Arcium Localnet Initialization Script
 * 
 * Orchestrates the full initialization sequence:
 * 1. Wait for localnet to be ready
 * 2. Check/initialize MXE account
 * 3. Initialize computation definitions
 * 
 * Usage: node Arcium/scripts/init-arcium-localnet.js
 */

const { Connection, PublicKey } = require("@solana/web3.js");
const { execSync } = require("child_process");
const { getMXEAccAddress } = require("@arcium-hq/client");
const fs = require("fs");

const CONNECTION_URL = "http://127.0.0.1:8899";
const MAX_RETRIES = 30;
const RETRY_DELAY_MS = 2000; // 2 seconds

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function checkSolanaLocalnet() {
  console.log("Checking Solana localnet connection...");
  const connection = new Connection(CONNECTION_URL, "confirmed");
  
  for (let i = 0; i < MAX_RETRIES; i++) {
    try {
      const slot = await connection.getSlot();
      console.log(`✅ Solana localnet is ready (slot: ${slot})`);
      return true;
    } catch (error) {
      if (i < MAX_RETRIES - 1) {
        process.stdout.write(".");
        await sleep(RETRY_DELAY_MS);
      } else {
        console.error("\n❌ Failed to connect to Solana localnet");
        console.error("Please ensure Solana localnet is running on port 8899");
        throw error;
      }
    }
  }
}

async function checkArciumContainers() {
  console.log("\nChecking Arcium Docker containers...");
  
  try {
    const output = execSync(
      "docker compose -f Arcium/artifacts/docker-compose-arx-env.yml ps --format json",
      { encoding: "utf-8", stdio: "pipe" }
    );
    
    const containers = output
      .trim()
      .split("\n")
      .filter((line) => line.trim())
      .map((line) => JSON.parse(line));
    
    const runningContainers = containers.filter(
      (c) => c.State === "running"
    );
    
    if (runningContainers.length === 0) {
      console.log("⚠️  No Arcium containers are running");
      console.log("   Starting containers may take some time, especially on ARM64...");
      console.log("   You can check container status with:");
      console.log("   docker compose -f Arcium/artifacts/docker-compose-arx-env.yml ps");
      return false;
    }
    
    console.log(`✅ ${runningContainers.length} Arcium container(s) running`);
    return true;
  } catch (error) {
    console.log("⚠️  Could not check container status (containers may still be starting)");
    return false;
  }
}

async function checkArciumProgram() {
  console.log("\nChecking Arcium program deployment...");
  const connection = new Connection(CONNECTION_URL, "confirmed");
  const arciumProgramId = new PublicKey("BKck65TgoKRokMjQM3datB9oRwJ8rAj2jxPXvHXUvcL6");
  
  try {
    const programInfo = await connection.getAccountInfo(arciumProgramId);
    if (programInfo) {
      console.log("✅ Arcium program is deployed");
      return true;
    } else {
      console.log("❌ Arcium program not found!");
      console.log("   Program ID:", arciumProgramId.toBase58());
      console.log("\n   The Arcium program must be deployed before initialization.");
      console.log("   Please run: arcium localnet");
      console.log("   Or ensure Arcium localnet setup is complete.\n");
      return false;
    }
  } catch (error) {
    console.log("⚠️  Could not check Arcium program:", error.message);
    return false;
  }
}

async function waitForLocalnetReady() {
  console.log("\n=== Step 1: Waiting for Localnet to be Ready ===\n");
  
  await checkSolanaLocalnet();
  const containersRunning = await checkArciumContainers();
  const arciumProgramDeployed = await checkArciumProgram();
  
  if (!containersRunning) {
    console.log("\n⚠️  Warning: Arcium containers may not be fully ready");
    console.log("   The initialization may fail if containers are not running");
    console.log("   Waiting 10 seconds for containers to start...\n");
    await sleep(10000);
  }
  
  if (!arciumProgramDeployed) {
    throw new Error("Arcium program is not deployed. Please run 'arcium localnet' first.");
  }
  
  console.log("\n✅ Localnet appears ready\n");
}

async function initializeMXE() {
  console.log("\n=== Step 2: Initialize MXE Account ===\n");
  
  try {
    const result = execSync("node Arcium/scripts/init-mxe.js", {
      encoding: "utf-8",
      stdio: "inherit",
    });
    console.log("\n✅ MXE initialization step completed\n");
    return true;
  } catch (error) {
    console.error("\n❌ MXE initialization failed");
    throw error;
  }
}

async function initializeCompDefs() {
  console.log("\n=== Step 3: Initialize Computation Definitions ===\n");
  
  try {
    const result = execSync("node Arcium/scripts/init-comp-defs.js", {
      encoding: "utf-8",
      stdio: "inherit",
    });
    console.log("\n✅ Computation definitions initialization step completed\n");
    return true;
  } catch (error) {
    console.error("\n❌ Computation definitions initialization failed");
    throw error;
  }
}

async function verifyInitialization() {
  console.log("\n=== Step 4: Verification ===\n");
  
  const connection = new Connection(CONNECTION_URL, "confirmed");
  const programId = new PublicKey("EFgvReNjDSd4vyW5GcGqY5rRrzQVVoTWYNu1yDqcxWeA");
  const mxeAddress = getMXEAccAddress(programId);
  
  try {
    const mxeInfo = await connection.getAccountInfo(mxeAddress);
    if (mxeInfo) {
      console.log("✅ MXE account verified:", mxeAddress.toBase58());
    } else {
      console.log("⚠️  MXE account not found");
      return false;
    }
    
    // Check computation definitions
    const { getCompDefAccOffset, getCompDefAccAddress } = require("@arcium-hq/client");
    const compDefNames = ["initialize_market", "place_bet", "distribute_rewards"];
    
    let allFound = true;
    for (const name of compDefNames) {
      const offset = getCompDefAccOffset(name);
      const compDefAddress = getCompDefAccAddress(programId, offset.readUInt32LE());
      const compDefInfo = await connection.getAccountInfo(compDefAddress);
      
      if (compDefInfo) {
        console.log(`✅ ${name} CompDef verified`);
      } else {
        console.log(`⚠️  ${name} CompDef not found`);
        allFound = false;
      }
    }
    
    return allFound;
  } catch (error) {
    console.error("❌ Verification failed:", error.message);
    return false;
  }
}

async function main() {
  console.log("╔══════════════════════════════════════════════════════════╗");
  console.log("║   Arcium Localnet Master Initialization Script         ║");
  console.log("╚══════════════════════════════════════════════════════════╝");
  console.log();
  
  try {
    // Step 1: Wait for localnet
    await waitForLocalnetReady();
    
    // Step 2: Initialize MXE
    await initializeMXE();
    
    // Step 3: Initialize Computation Definitions
    await initializeCompDefs();
    
    // Step 4: Verify
    const verified = await verifyInitialization();
    
    console.log("\n╔══════════════════════════════════════════════════════════╗");
    if (verified) {
      console.log("║   ✅ Initialization Complete and Verified!              ║");
    } else {
      console.log("║   ⚠️  Initialization Complete (some verification failed)  ║");
    }
    console.log("╚══════════════════════════════════════════════════════════╝");
    console.log();
    
    process.exit(0);
  } catch (error) {
    console.error("\n╔══════════════════════════════════════════════════════════╗");
    console.error("║   ❌ Initialization Failed                               ║");
    console.error("╚══════════════════════════════════════════════════════════╝");
    console.error("\nError:", error.message);
    console.error("\nTroubleshooting:");
    console.error("1. Ensure Solana localnet is running: solana-test-validator");
    console.error("2. Ensure Arcium containers are running");
    console.error("3. Check container logs: docker compose -f Arcium/artifacts/docker-compose-arx-env.yml logs");
    console.error("4. Try running initialization steps individually:");
    console.error("   - node Arcium/scripts/init-mxe.js");
    console.error("   - node Arcium/scripts/init-comp-defs.js");
    console.error();
    process.exit(1);
  }
}

main();

