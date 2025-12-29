#!/usr/bin/env node

const { spawn } = require("child_process");
const path = require("path");
const { getBinaryPath, ensureBinary } = require("../lib/download");

async function main() {
  try {
    const binaryPath = await ensureBinary();

    const child = spawn(binaryPath, process.argv.slice(2), {
      stdio: "inherit",
      env: process.env,
    });

    child.on("error", (err) => {
      console.error(`Failed to start viban: ${err.message}`);
      process.exit(1);
    });

    child.on("close", (code) => {
      process.exit(code ?? 0);
    });
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
}

main();
