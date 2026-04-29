{ bash, fetchurl, installShellFiles, lib, stdenv, stdenvNoCC, symlinkJoin }:

let
  manifest = builtins.fromJSON (builtins.readFile ./package-manifest.json);
  packageVersion =
    manifest.package.version
    + lib.optionalString (manifest.package ? packageRevision) "-r${toString manifest.package.packageRevision}";
  licenseMap = {
    "MIT" = lib.licenses.mit;
    "Apache-2.0" = lib.licenses.asl20;
    "SEE LICENSE IN README.md" = lib.licenses.unfree;
  };
  resolvedLicense =
    if builtins.hasAttr manifest.meta.licenseSpdx licenseMap
    then licenseMap.${manifest.meta.licenseSpdx}
    else lib.licenses.unfree;
  platformDist =
    manifest.dist.platforms.${stdenv.hostPlatform.system}
      or (throw "unsupported platform for ${manifest.binary.name}: ${stdenv.hostPlatform.system}");
  targetTriple = platformDist.targetTriple;
  aliasSpecs = map (
    alias:
    if builtins.isString alias then
      {
        name = alias;
        args = [ ];
      }
    else
      alias
  ) (manifest.binary.aliases or [ ]);
  renderAliasArgs = args: lib.concatMapStringsSep " " lib.escapeShellArg args;
  aliasOutputLinks = lib.concatMapStrings
    (
      alias:
      ''
        mkdir -p "${"$" + alias.name}/bin"
        cat > "${"$" + alias.name}/bin/${alias.name}" <<EOF
#!${lib.getExe bash}
exec "$out/bin/${manifest.binary.name}" ${renderAliasArgs alias.args} "\$@"
EOF
        chmod +x "${"$" + alias.name}/bin/${alias.name}"
      ''
    )
    aliasSpecs;
  basePackage = stdenvNoCC.mkDerivation {
    pname = manifest.package.repo;
    version = packageVersion;
    src = fetchurl {
      url = platformDist.url;
      hash = platformDist.hash;
    };
    sourceRoot = "package";
    dontBuild = true;
    nativeBuildInputs = [ installShellFiles ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/${manifest.binary.name}/vendor" "$out/bin"
      cp -RL "vendor/${targetTriple}" "$out/share/${manifest.binary.name}/vendor/${targetTriple}"
      cat > "$out/bin/${manifest.binary.name}" <<EOF
#!${lib.getExe bash}
export PATH="$out/share/${manifest.binary.name}/vendor/${targetTriple}/path\''${PATH:+:\$PATH}"
exec "$out/share/${manifest.binary.name}/vendor/${targetTriple}/codex/${manifest.binary.name}" "\$@"
EOF
      chmod +x "$out/bin/${manifest.binary.name}"
      installShellCompletion --cmd ${manifest.binary.name} \
        --bash <("$out/bin/${manifest.binary.name}" completion bash) \
        --fish <("$out/bin/${manifest.binary.name}" completion fish) \
        --zsh <("$out/bin/${manifest.binary.name}" completion zsh)
      runHook postInstall
    '';
    meta = with lib; {
      description = manifest.meta.description;
      homepage = manifest.meta.homepage;
      license = resolvedLicense;
      mainProgram = manifest.binary.name;
      platforms = platforms.linux ++ platforms.darwin;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };
in
symlinkJoin {
  pname = manifest.binary.name;
  version = packageVersion;
  name = "${manifest.binary.name}-${packageVersion}";
  outputs = [ "out" ] ++ map (alias: alias.name) aliasSpecs;
  paths = [ basePackage ];
  postBuild = ''
    ${aliasOutputLinks}
  '';
  meta = basePackage.meta;
}
