{
  stdenv,
  fetchFromGitHub,
  fetchYarnDeps,
  yarnConfigHook,
  yarnBuildHook,
  yarnInstallHook,
  nodejs,
  lib,
}:

stdenv.mkDerivation rec {
  pname = "salesforce-cli";
  version = "2.135.6";

  src = fetchFromGitHub {
    owner = "salesforcecli";
    repo = "cli";
    rev = version;
    hash = "sha256-961XGVzqT3GtD+IINwiDr/MQKq2BXDA/i2/pZKHoxX0=";
  };

  offlineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-5hyFNbAyOUoPMet12z9Eo+BTY7L8R7qC82Vakntj8pc=";
  };

  nativeBuildInputs = [
    nodejs
    yarnConfigHook
    yarnBuildHook
    yarnInstallHook
  ];

  meta = {
    description = "Salesforce CLI";
    mainProgram = "sf";
    license = lib.licenses.bsd3;
  };
}
