const os = require("os");

function getPlatformTarget() {
  const platform = os.platform();
  const arch = os.arch();

  if (platform === "darwin" && arch === "arm64") {
    return "macos_arm";
  }

  if (platform === "linux" && arch === "x64") {
    return "linux_intel";
  }

  const supported = [
    "  - macOS ARM64 (Apple Silicon)",
    "  - Linux x64",
  ];

  throw new Error(
    `Unsupported platform: ${platform} ${arch}\n\nSupported platforms:\n${supported.join("\n")}`
  );
}

module.exports = { getPlatformTarget };
