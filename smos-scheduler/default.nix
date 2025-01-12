{ mkDerivation, aeson, autodocodec, autodocodec-yaml, autoexporter
, base, bytestring, conduit, containers, cron, dirforest, envparse
, fuzzy-time, genvalidity, genvalidity-containers, genvalidity-path
, genvalidity-sydtest, genvalidity-sydtest-aeson, genvalidity-text
, genvalidity-time, hashable, lib, megaparsec, mtl
, optparse-applicative, path, path-io, pretty-relative-time
, QuickCheck, safe, safe-coloured-text-terminfo, smos-data
, smos-data-gen, smos-query, smos-report, smos-report-gen, sydtest
, sydtest-discover, text, time, unliftio, validity, validity-text
, yaml
}:
mkDerivation {
  pname = "smos-scheduler";
  version = "0.6.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson autodocodec base bytestring conduit containers cron envparse
    fuzzy-time hashable megaparsec mtl optparse-applicative path
    path-io pretty-relative-time safe safe-coloured-text-terminfo
    smos-data smos-query smos-report text time unliftio validity
    validity-text yaml
  ];
  libraryToolDepends = [ autoexporter ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [
    autodocodec autodocodec-yaml base containers cron dirforest
    genvalidity genvalidity-containers genvalidity-path
    genvalidity-sydtest genvalidity-sydtest-aeson genvalidity-text
    genvalidity-time mtl path path-io QuickCheck smos-data
    smos-data-gen smos-query smos-report smos-report-gen sydtest text
    time
  ];
  testToolDepends = [ sydtest-discover ];
  license = lib.licenses.mit;
  mainProgram = "smos-scheduler";
}
