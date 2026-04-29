const manifestPath = "nix/package-manifest.json";
const manifestFile = Bun.file(manifestPath);
const manifest = await manifestFile.json();
const packageJsonPath = "package.json";
const packageJson = await Bun.file(packageJsonPath).json();

async function fetchRegistry(packageName: string) {
  const url = `https://registry.npmjs.org/${encodeURIComponent(packageName)}`;
  const response = await fetch(url, { headers: { accept: "application/json" } });
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}: ${response.status} ${response.statusText}`);
  }
  return response.json();
}

const registry = await fetchRegistry(manifest.package.npmName);
const latestTag = registry["dist-tags"]?.latest;
if (!latestTag) throw new Error(`No latest dist-tag found for ${manifest.package.npmName}`);

const latest = registry.versions?.[latestTag];
if (!latest) throw new Error(`No version payload found for ${manifest.package.npmName}@${latestTag}`);

const binEntries = Object.entries(latest.bin ?? {});
if (binEntries.length === 0) throw new Error(`No bin entry found for ${manifest.package.npmName}@${latestTag}`);

const [binName, entrypoint] = binEntries[0];
const version = latest.version;

manifest.stubbed = false;
manifest.package.version = version;
manifest.binary.upstreamName = binName;
manifest.binary.entrypoint = entrypoint;
manifest.dist.url = latest.dist.tarball;
manifest.dist.hash = latest.dist.integrity;
manifest.meta.description = latest.description ?? manifest.meta.description;
manifest.meta.homepage = latest.homepage ?? registry.homepage ?? `https://www.npmjs.com/package/${manifest.package.npmName}`;
manifest.meta.licenseSpdx = latest.license ?? manifest.meta.licenseSpdx ?? "unfree";

// Codex platform packages are versioned as @openai/codex@VERSION-linux-x64 (same npm package, platform-specific version tag)
const platformSuffixes: Record<string, string> = {
  "x86_64-linux": "linux-x64",
  "aarch64-linux": "linux-arm64",
  "x86_64-darwin": "darwin-x64",
  "aarch64-darwin": "darwin-arm64",
};
for (const [platformKey, platformEntry] of Object.entries(manifest.dist.platforms ?? {}) as [string, any][]) {
  const suffix = platformSuffixes[platformKey];
  if (!suffix) continue;
  const platformVersion = `${version}-${suffix}`;
  const pkgVersion = registry.versions?.[platformVersion];
  if (!pkgVersion) {
    console.warn(`Warning: ${manifest.package.npmName}@${platformVersion} not found in registry, keeping existing hash`);
    continue;
  }
  manifest.dist.platforms[platformKey] = {
    ...platformEntry,
    url: pkgVersion.dist.tarball,
    hash: pkgVersion.dist.integrity,
  };
}

packageJson.dependencies ??= {};
packageJson.dependencies[manifest.package.npmName] = version;

await Bun.write(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
await Bun.write(packageJsonPath, `${JSON.stringify(packageJson, null, 2)}\n`);

console.log(
  JSON.stringify(
    {
      package: manifest.package.npmName,
      version,
      platforms: Object.fromEntries(
        Object.entries(manifest.dist.platforms ?? {}).map(([k, v]: [string, any]) => [k, v.url]),
      ),
    },
    null,
    2,
  ),
);
