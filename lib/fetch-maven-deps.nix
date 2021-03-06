# https://github.com/NixOS/nixpkgs/pull/83725

# Perform fake build to make a fixed-output derivation out of the dependencies required for build.
# Afterwards build with ('maven.repo.local' must be writable so copy it out of nix store):
#   mvn package --offline -Dmaven.repo.local=$(cp -dpR ${deps}/.m2 ./ && chmod +w -R .m2 && pwd)/.m2
{ stdenv, maven }:

{ src
, sha256
, nativeBuildInputs ? [ maven ]
, mavenFlags ? ""
, ...
}@args:

stdenv.mkDerivation ({
  name = if args ? name then "${args.name}-maven-deps"
  else if args ? pname && args ? version then "${args.pname}-${args.version}-maven-deps"
  else "maven-deps";

  inherit src nativeBuildInputs;

  buildPhase = ''
    RETRIES=10
    while mvn package -Dmaven.repo.local=$out/.m2 ${mavenFlags} -Dmaven.wagon.rto=5000; [ $? = 1 ]; do
      if [ $RETRIES -le 0 ]; then
        echo "timed out too many times, aborting"
        exit 1
      fi
      RETRIES=$((RETRIES - 1))
      echo "timeout, restart maven to continue downloading"
    done
  '';
  # keep only *.{pom,jar,sha1,nbm} and delete all ephemeral files with lastModified timestamps inside
  installPhase = ''find $out/.m2 -type f -regex '.+\(\.lastUpdated\|resolver-status\.properties\|_remote\.repositories\)' -delete'';
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = sha256;
} // (removeAttrs args ["name" "pname" "version"]))
