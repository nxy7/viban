const https = require("https");
const fs = require("fs");
const path = require("path");
const os = require("os");
const { getPlatformTarget } = require("./platform");

const GITHUB_REPO = "nxy7/viban";
const BINARY_NAME = "viban";

function getCacheDir() {
  const homeDir = os.homedir();
  return path.join(homeDir, ".viban", "bin");
}

function getBinaryPath() {
  return path.join(getCacheDir(), BINARY_NAME);
}

function getPackageVersion() {
  const packageJson = require("../package.json");
  return packageJson.version;
}

async function getLatestRelease() {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: "api.github.com",
      path: `/repos/${GITHUB_REPO}/releases/latest`,
      headers: {
        "User-Agent": "viban-npm",
        Accept: "application/vnd.github.v3+json",
      },
    };

    https
      .get(options, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          if (res.statusCode === 404) {
            reject(new Error("No releases found. Please check https://github.com/nxy7/viban/releases"));
            return;
          }
          if (res.statusCode !== 200) {
            reject(new Error(`GitHub API error: ${res.statusCode}`));
            return;
          }
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            reject(new Error("Failed to parse GitHub response"));
          }
        });
      })
      .on("error", reject);
  });
}

async function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(destPath);

    const request = (url) => {
      https
        .get(url, { headers: { "User-Agent": "viban-npm" } }, (res) => {
          if (res.statusCode === 302 || res.statusCode === 301) {
            request(res.headers.location);
            return;
          }

          if (res.statusCode !== 200) {
            reject(new Error(`Download failed: ${res.statusCode}`));
            return;
          }

          const totalSize = parseInt(res.headers["content-length"], 10);
          let downloadedSize = 0;
          let lastPercent = 0;

          res.on("data", (chunk) => {
            downloadedSize += chunk.length;
            const percent = Math.floor((downloadedSize / totalSize) * 100);
            if (percent >= lastPercent + 10) {
              process.stdout.write(`\rDownloading viban... ${percent}%`);
              lastPercent = percent;
            }
          });

          res.pipe(file);

          file.on("finish", () => {
            file.close();
            console.log("\rDownloading viban... done!   ");
            resolve();
          });
        })
        .on("error", (err) => {
          fs.unlink(destPath, () => {});
          reject(err);
        });
    };

    request(url);
  });
}

async function ensureBinary() {
  const binaryPath = getBinaryPath();
  const versionFile = path.join(getCacheDir(), ".version");

  if (fs.existsSync(binaryPath) && fs.existsSync(versionFile)) {
    const cachedVersion = fs.readFileSync(versionFile, "utf8").trim();
    const currentVersion = getPackageVersion();
    if (cachedVersion === currentVersion) {
      return binaryPath;
    }
    console.log(`Updating viban from ${cachedVersion} to ${currentVersion}...`);
  }

  await downloadBinary();
  return binaryPath;
}

async function downloadBinary() {
  const target = getPlatformTarget();
  const version = getPackageVersion();
  const cacheDir = getCacheDir();
  const binaryPath = getBinaryPath();
  const versionFile = path.join(cacheDir, ".version");

  fs.mkdirSync(cacheDir, { recursive: true });

  console.log(`Installing viban ${version} for ${target}...`);

  const release = await getLatestRelease();
  const assetName = `viban-${release.tag_name}-${target}`;
  const asset = release.assets.find((a) => a.name === assetName);

  if (!asset) {
    const available = release.assets.map((a) => a.name).join(", ");
    throw new Error(
      `No binary found for ${target} in release ${release.tag_name}.\nAvailable: ${available}`
    );
  }

  await downloadFile(asset.browser_download_url, binaryPath);

  fs.chmodSync(binaryPath, 0o755);

  fs.writeFileSync(versionFile, version);

  console.log(`Installed viban ${version} to ${binaryPath}`);
}

module.exports = {
  getBinaryPath,
  ensureBinary,
  downloadBinary,
};
