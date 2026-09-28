{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
  makeWrapper,
}:
let
  python = python3.withPackages (p: [
    p.flask
    p.gevent
    p.matplotlib
    p.requests
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "ctcache";
  version = "2026-09-15";
  src = fetchFromGitHub {
    owner = "matus-chochlik";
    repo = "ctcache";
    rev = "857b14271d3ded5511c2e6a60f2dc20c1e4b5680";
    hash = "sha256-e9j7RUU26WHFXKMAYsDUeHXBAsat0Uk6FxlyBlOyoQ0=";
  };
  patches = [ ./server.patch ];
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin $out/share/ctcache
    cp -r src static $out/share/ctcache/
    makeWrapper ${python}/bin/python $out/bin/clang-tidy-cache-server \
      --add-flags $out/share/ctcache/src/ctcache/clang_tidy_cache_server.py \
      --set MPLBACKEND Agg
    makeWrapper ${python}/bin/python $out/bin/clang-tidy-cache \
      --add-flags $out/share/ctcache/src/ctcache/clang_tidy_cache.py
  '';
  meta.license = lib.licenses.boost;
}
