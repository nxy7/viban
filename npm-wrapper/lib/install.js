const { downloadBinary } = require("./download");

async function main() {
  try {
    await downloadBinary();
  } catch (err) {
    console.error(`\nFailed to install viban binary: ${err.message}`);
    console.error("\nYou can try running viban later - it will attempt to download on first run.");
    process.exit(0);
  }
}

main();
