# TODO
#
# - [x] Add check step for the hash
# - [x] Pin all the commits of the git checkouts
# - [ ] Minimise dependencies
# - [ ] Remove `autoreconfHook` from any place where we do NOT modify the
#       configure stuff.
# - [ ] Refactor as list
#       - Simplify `buildPhase` as list
# - [ ] Push everything to silky cachix
# - [ ] (maybe) minimise patches
# - [ ] (maybe) Add Nix as the 129th language
# - [ ] Comment here: https://github.com/NixOS/nixpkgs/issues/131492
{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs2511.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs2505.url = "github:nixos/nixpkgs/nixos-25.05";
  };

  outputs = inputs: with inputs;
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgs2511 = import nixpkgs2511 { inherit system; };
        pkgs2505 = import nixpkgs2505 { inherit system; };

        step = file: { name, prev, inputs, buildPhase, doCheck ? true }: pkgs.stdenv.mkDerivation {
          inherit name;
          src = "${prev.out}/share";
          nativeBuildInputs = inputs;
          inherit buildPhase;
          installPhase = ''
            mkdir -p $out/share
            mv ${file} $out/share/
          '';
          doCheck = doCheck;
          checkPhase = ''
            hash=$(${pkgs.toybox}/bin/sha256sum ${file})
            ${pkgs.toybox}/bin/grep $hash ${./SHA256SUMS}
          '';
        };
      in
      {
        packages = rec {
          inherit m2;

          ruby-to-rs = pkgs.stdenv.mkDerivation {
            name = "ruby-to-rs";
            srcs = [ ./QR.rb ];
            unpackPhase = ''
              for srcFile in $srcs; do
                cp $srcFile $(stripHash $srcFile)
              done
            '';
            nativeBuildInputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby QR.rb > QR.rs
            '';
            installPhase = ''
              mkdir -p $out/share
              mv QR.rs $out/share/
            '';
          };

          rs-to-scala = step "QR.scala" {
            name = "rs-to-scala";
            prev = ruby-to-rs;
            inputs = [ pkgs.rustc ];
            buildPhase = "rustc QR.rs && ./QR > QR.scala";
          };

          scala-to-guile = step "QR.scm" {
            name = "scale-to-guile";
            prev = rs-to-scala;
            inputs = [ pkgs.scala ];
            buildPhase = ''
              scalac QR.scala && scala QR > QR.scm
            '';
          };

          guile-to-scilab = step "QR.sci" {
            name = "guile-to-scilab";
            prev = scala-to-guile;
            inputs = [ pkgs.guile ];
            buildPhase = ''
              guile QR.scm > QR.sci
            '';
          };

          scilab-to-sed = step "QR.sed" {
            name = "scilab-to-sed";
            prev = guile-to-scilab;
            inputs = [ pkgs.scilab-bin ];
            buildPhase = ''
              export SCI=${pkgs.scilab-bin.out}/share/scilab

              # Hack: Set HOME, as scilib insists that it exists.
              export HOME=$(pwd)

              scilab-cli -nwni -nb -f QR.sci > QR.sed.t

              # Hack: Drop the first line; for some reason it contains a
              # grep warning.
              tail -n +2 QR.sed.t > QR.sed
            '';
          };

          sed-to-spl = step "QR.spl" {
            name = "sed-to-spl";
            prev = scilab-to-sed;
            inputs = [ pkgs.gnused ];
            buildPhase = ''
              sed -E -f QR.sed QR.sed > QR.spl
            '';
          };

          spl-to-sl =
            let
              # This step as it takes a little while to run (about a minute),
              # so we don't want to re-run if we don't need to.
              spl-c-file = step "QR.spl.c" {
                name = "produce spl.c file";
                prev = sed-to-spl;
                inputs = [ spl2c ];
                buildPhase = ''
                  spl2c < ${sed-to-spl.out}/share/QR.spl > QR.spl.c
                '';
                # No hash check; this isn't a "real" step.
                doCheck = false;
              };

              spl2c = pkgs.stdenv.mkDerivation {
                name = "spl2c";
                nativeBuildInputs = with pkgs; [
                  bison
                  flex
                ];
                buildPhase = ''
                  make spl2c CCFLAGS="-O0 -g -Wall"
                '';
                installPhase = ''
                  make install
                  mv spl $out
                '';
                src = ./vendor/spl-1.2.1.tar.gz;
              };

            in
            pkgs.stdenv.mkDerivation {
              name = "spl-to-sl";
              src = spl-c-file.out;
              buildInputs = [ spl2c pkgs.glibc pkgs.gcc ];
              buildPhase = ''
                gcc -z muldefs -o QR \
                  -I ./${spl2c.out}/include \
                  -L ./${spl2c.out}/lib \
                  share/QR.spl.c \
                  -lspl \
                  -lm

                ./QR > QR.sl
              '';
              installPhase = ''
                mkdir -p $out/share
                mv QR.sl $out/share/
              '';
            };

          sl-to-squirrel = step "QR.nut" {
            name = "squirrel-to-sml";
            prev = spl-to-sl;
            inputs = [ pkgs.slang ];
            buildPhase = ''
              slsh QR.sl > QR.nut
            '';
          };

          squirrel-to-sml =
            let
              squirrel = pkgs.stdenv.mkDerivation {
                name = "squirrel";
                version = "3.2";
                nativeBuildInputs = with pkgs; [
                  clang
                  cmake
                ];
                src = pkgs.fetchFromGitHub {
                  owner = "albertodemichelis";
                  repo = "squirrel";
                  rev = "master";
                  sha256 = "sha256-2Zi2HBBTruKIWHSyGgQsar4wVI5IxrpgF40AR68hHTU=";
                };
              };
            in
            step "QR.sml" {
              name = "squirrel-to-sml";
              prev = sl-to-squirrel;
              inputs = [ squirrel ];
              buildPhase = ''
                sq QR.nut > QR.sml
              '';
            };

          sml-to-polyml = step "QR.sq" {
            name = "sml-to-polyml";
            prev = squirrel-to-sml;
            inputs = [ pkgs.polyml ];
            buildPhase = ''
              polyc -o QR QR.sml
              ./QR > QR.sq
            '';
          };

          polyml-to-subleq = step "QR.ss" {
            name = "polyml-to-subleq";
            prev = sml-to-polyml;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${./vendor/subleq.rb} QR.sq > QR.ss
            '';
          };

          subleq-to-surgescript = step "QR.swift" {
            name = "subleq-to-surgescript";
            prev = polyml-to-subleq;
            inputs = [ pkgs.surgescript ];
            buildPhase = ''
              surgescript QR.ss > QR.swift
            '';
          };

          surgescript-to-swift = pkgs2505.swift.stdenv.mkDerivation {
            name = "surgescript-to-swift";
            src = "${subleq-to-surgescript.out}/share";
            buildInputs = with pkgs2505.swiftPackages; [
              swift
              swiftpm
              Foundation
            ];
            buildPhase = ''
              # https://github.com/NixOS/nixpkgs/issues/311565
              export LD_LIBRARY_PATH=${pkgs2505.swiftPackages.Dispatch}/lib;
              swiftc QR.swift
              ./QR > QR.tcl
            '';
            installPhase = ''
              mkdir -p $out/share
              mv QR.tcl $out/share/
            '';
          };

          tcl-to-tc = step "QR.tcsh" {
            name = "tcl-to-tc";
            prev = surgescript-to-swift;
            inputs = [ pkgs.tcl ];
            buildPhase = ''
              tclsh QR.tcl > QR.tcsh
            '';
          };

          tc-to-thue = step "QR.t" {
            name = "tc-to-thue";
            prev = tcl-to-tc;
            inputs = [ pkgs.tcsh ];
            buildPhase = ''
              tcsh QR.tcsh > QR.t
            '';
          };

          thue-to-ts = step "QR.ts" {
            name = "thue-to-ts";
            prev = tc-to-thue;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${vendor/thue.rb} QR.t > QR.ts
            '';
          };

          ts-to-unlambda = step "QR.unl" {
            name = "ts-to-unlambda";
            prev = thue-to-ts;
            inputs = [
              pkgs.typescript
              pkgs.nodejs
            ];
            buildPhase = ''
              tsc --outFile QR.ts.js QR.ts
              node QR.ts.js > QR.unl
            '';
          };

          unlambda-to-vala = step "QR.vala" {
            name = "unlambda-to-vala";
            prev = ts-to-unlambda;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${vendor/unlambda.rb} QR.unl > QR.vala
            '';
          };

          vala-to-velato = step "QR.mid" {
            name = "vala-to-velato";
            prev = unlambda-to-vala;
            inputs = with pkgs; [
              vala
              pkg-config
              gobject-introspection
            ];

            buildPhase = ''
              valac QR.vala
              ./QR > QR.mid
            '';
          };

          velato-to-verilog = step "QR.v" {
            name = "velato-to-verilog";
            prev = vala-to-velato;
            inputs = [ pkgs.mono pkgs.unzip ];
            buildPhase = ''
              unzip ${vendor/Velato_0_1.zip}
              mono Vlt.exe /s QR.mid
              mono QR.exe > QR.v
            '';
          };

          verilog-to-vim = step "QR.vim" {
            name = "verilog-to-vim";
            prev = velato-to-verilog;
            inputs = [ pkgs.iverilog ];
            buildPhase = ''
              iverilog -o QR QR.v
              ./QR -vcd-none > QR.vim
            '';
          };

          vim-to-vb = step "QR.vb" {
            name = "vim-to-vb";
            prev = verilog-to-vim;
            inputs = [ pkgs.vim ];
            buildPhase = ''
              vim -EsS QR.vim > QR.vb
            '';
          };

          vb-to-wasm-bin = step "QR.wasm" {
            name = "vb-to-wasm-bin";
            prev = vim-to-vb;
            inputs = [ pkgs.dotnet-sdk ];
            buildPhase = ''
              echo '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><Compile Include="QR.vb" /></ItemGroup></Project>' > tmp.vbproj
              DOTNET_NOLOGO=1 dotnet run --project tmp.vbproj > QR.wasm
            '';
          };

          wasm-bin-to-wasm-text = step "QR.wat" {
            name = "wasm-bin-to-wasm-text";
            prev = vb-to-wasm-bin;
            inputs = [ pkgs.wasmtime ];
            buildPhase = ''
              export HOME=$(pwd)
              wasmtime QR.wasm > QR.wat
            '';
          };

          wasm-text-to-whitespace = step "QR.ws" {
            name = "wasm-text-to-whitespace";
            prev = wasm-bin-to-wasm-text;
            inputs = with pkgs; [
              wabt
              wasmtime
            ];
            buildPhase = ''
              export HOME=$(pwd)
              wat2wasm QR.wat -o QR.wat.wasm
              wasmtime QR.wat.wasm > QR.ws
            '';
          };

          whitespace-to-xslt = step "QR.xslt" {
            name = "whitespace-to-xslt";
            prev = wasm-text-to-whitespace;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${vendor/whitespace.rb} QR.ws > QR.xslt
            '';
          };

          xslt-to-yab = step "QR.yab" {
            name = "xslt-to-tab";
            prev = whitespace-to-xslt;
            inputs = [ pkgs.libxslt ];
            buildPhase = ''
              xsltproc QR.xslt > QR.yab
            '';
          };

          yab-to-yorick = step "QR.yorick" {
            name = "yab-to-yorick";
            prev = xslt-to-yab;
            inputs = [ pkgs.yabasic ];
            buildPhase = ''
              yabasic QR.yab > QR.yorick
            '';
          };

          yorick-to-zoem =
            let
              yorick = pkgs.stdenv.mkDerivation {
                name = "yorick";
                version = "2.2";
                nativeBuildInputs = with pkgs; [
                  clang
                  xorg.libX11
                ];
                # https://github.com/llnl/yorick
                src = pkgs.fetchFromGitHub {
                  owner = "llnl";
                  repo = "yorick";
                  rev = "master";
                  sha256 = "sha256-gjabbLjVUPX9XrsrxDPTV4kmvd9sWRPmXDw+CRMqqbM=";
                };
                installPhase = ''
                  make install
                  mv relocate $out
                '';
              };
            in
            step "QR.azm" {
              name = "yorick-to-zoem";
              prev = yab-to-yorick;
              inputs = [ yorick ];
              buildPhase = ''
                yorick -batch QR.yorick > QR.azm
              '';
            };

          zoem-to-zsh =
            let
              cimfomfa = pkgs.stdenv.mkDerivation {
                name = "zoem";
                nativeBuildInputs = with pkgs; [
                  pkg-config
                ];
                src = builtins.fetchurl {
                  url = "https://micans.org/cimfomfa/src/cimfomfa-21-341.tar.gz";
                  sha256 = "sha256:1w7z65zlk5cawq6c1ikfg304ggvd90p73qsvfk60i8lsiapxh9bw";
                };
              };

              zoem = pkgs.stdenv.mkDerivation {
                name = "zoem";
                nativeBuildInputs = with pkgs; [
                  autoreconfHook
                  pkg-config
                  cimfomfa
                ];

                src = pkgs.fetchgit {
                  url = "https://git.launchpad.net/ubuntu/+source/zoem";
                  rev = "3c9b5c00e429e02180d54498cde862e3823b1079";
                  sha256 = "sha256-Go5Sfond2+XYyLzcchkD/JJv/e4PGg1et3F4Km6PV4c=";
                };

                patches = [
                  "./debian/patches/gcc-10.patch"
                  ./vendor/zoem.patch
                ];

                preBuild = ''
                  mkdir $out
                '';

                configureFlags = [
                  "--prefix=${placeholder "out"}"
                ];
              };
            in
            step "QR.zsh" {
              name = "zoem-to-zsh";
              prev = yorick-to-zoem;
              inputs = [ zoem ];
              buildPhase = ''
                zoem -i QR.azm > QR.zsh
              '';
            };

          zsh-to-aplus =
            step "QR.+" {
              name = "zsh-to-aplus";
              prev = zoem-to-zsh;
              inputs = [ pkgs.zsh ];
              buildPhase = ''
                zsh QR.zsh > QR.+
              '';
            };

          aplus-to-ada =
            let
              aplus = pkgs2511.stdenv.mkDerivation rec {
                name = "aplus";
                buildInputs = with pkgs2511; [
                  xorg.libX11
                  libnsl
                ];
                src = pkgs.fetchFromGitHub {
                  owner = "rdm";
                  repo = "aplus-fsf";
                  rev = "a3a256b5f2a65d41c40db38c21f1c6e3c1a92117";
                  hash = "sha256-eYS6edxYzGUx1KrqAdsGkjnD4in4HpeGF1MC8JZxCs8=";
                };
                CFLAGS = [
                  "-fpermissive"
                  "-Wno-error=format-security"
                  "-Wno-error=implicit-int"
                  "-Wno-error=implicit-function-declaration"
                ];
                CXXFLAGS = CFLAGS;
                postConfigure = ''
                  find -name Makefile -exec sed 's/X_LIBS = -L -lX11/X_LIBS = -lX11/' -i {} \;
                '';
                patches = [
                  (pkgs.fetchurl {
                    url = "http://deb.debian.org/debian/pool/main/a/aplus-fsf/aplus-fsf_4.22.1-10.2.diff.gz";
                    hash = "sha256-qDmXmqRc2iqv2qWH25jbFgmpxWHYIxR8SenrezyRijY=";
                  })
                ];
              };
            in
            step "qr.adb" {
              name = "aplus-to-ada";
              prev = zsh-to-aplus;
              inputs = [ aplus ];
              buildPhase = ''
                a+ QR.+ > qr.adb
              '';
            };

          ada-to-afnix = step "QR.als" {
            name = "ada-to-afnix";
            prev = aplus-to-ada;
            inputs = [ pkgs.gnat ];
            buildPhase = ''
              gnatmake qr.adb
              ./qr > QR.als
            '';
          };

          afnix-to-aheui =
            let
              afnix = with pkgs; stdenv.mkDerivation {
                name = "afnix";
                src = pkgs.fetchgit {
                  url = "https://git.launchpad.net/ubuntu/+source/afnix";
                  rev = "0211872b7ae83d87b966022916a7f7e8ac26e6be";
                  sha256 = "sha256-YZ4Fiirs/ncvPvhbvq/t8VTMZm7oWrTXRnqdCKpYxOI=";
                };
                nativeBuildInputs = [
                  gcc13
                  ncurses
                  dpkg
                ];
                configureFlags = [
                  "--prefix=${placeholder "out"}"
                ];
                patches = [
                  ./vendor/afnix.patch
                ];
                installPhase = ''
                  mkdir -p $out/bin
                  mkdir -p $out/lib

                  mv -t $out/bin/ bld/bin/*
                  mv -t $out/lib/ bld/lib/*
                '';
              };
            in
            step "QR.aheui" {
              name = "afnix-to-aheui";
              prev = ada-to-afnix;
              inputs = [ afnix ];
              buildPhase = ''
                LD_LIBRARY_PATH=${afnix.out}/lib axi QR.als > QR.aheui
              '';
            };

          aheui-to-algol = step "QR.a68" {
            name = "aheui-to-algol";
            prev = afnix-to-aheui;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${vendor/aheui.rb} QR.aheui > QR.a68
            '';
          };

          algol-to-ante = step "QR.ante" {
            name = "algol-to-ante";
            prev = aheui-to-algol;
            inputs = [ pkgs.algol68g ];
            buildPhase = ''
              a68g QR.a68 > QR.ante
            '';
          };

          ante-to-aspectj = step "QR.aj" {
            name = "ante-to-aspectj";
            prev = algol-to-ante;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${vendor/ante.rb} QR.ante > QR.aj
            '';
          };

          aspectj-to-asymptote = step "QR.asy" {
            name = "aspectj-to-asymptote";
            prev = ante-to-aspectj;
            inputs = with pkgs; [
              aspectj
              jre
            ];
            buildPhase = ''
              export CLASSPATH="$(find ${pkgs.aspectj.out}/lib -name "*.jar" | tr $'\n' :):./."
              ajc QR.aj
              java QR > QR.asy
            '';
          };

          asymptote-to-ats = step "QR.dats" {
            name = "asymptote-to-ats";
            prev = aspectj-to-asymptote;
            inputs = [ pkgs.asymptote ];
            buildPhase = ''
              asy QR.asy > QR.dats
            '';
          };

          ats-to-awk = step "QR.awk" {
            name = "ats-to-awk";
            prev = asymptote-to-ats;
            inputs = [ pkgs.ats2 ];
            buildPhase = ''
              patscc -o QR QR.dats
              ./QR > QR.awk
            '';
          };

          awk-to-bash = step "QR.bash" {
            name = "awk-to-bash";
            prev = ats-to-awk;
            inputs = [ pkgs.gawk ];
            buildPhase = ''
              awk -f QR.awk > QR.bash
            '';
          };

          bash-to-bc = step "QR.bc" {
            name = "bash-to-bc";
            prev = awk-to-bash;
            inputs = [ ];
            buildPhase = ''
              bash QR.bash > QR.bc
            '';
          };

          bc-to-beanshell = step "QR.bsh" {
            name = "bc-to-beanshell";
            prev = bash-to-bc;
            inputs = [ pkgs.bc ];
            buildPhase = ''
              BC_LINE_LENGTH=4000000 bc -q QR.bc > QR.bsh
            '';
          };

          beanshell-to-befunge = step "QR.bef" {
            name = "bc-to-beanshell";
            prev = bc-to-beanshell;
            inputs = [
              pkgs.jre_minimal
            ];
            buildPhase = ''
              java -cp ${pkgs.bsh} bsh.Interpreter QR.bsh > QR.bef
            '';
          };

          befunge-to-bcl8 =
            let
              oldpkgs = import
                (builtins.fetchGit {
                  name = "old-cmake";
                  url = "https://github.com/NixOS/nixpkgs/";
                  ref = "refs/heads/nixpkgs-unstable";
                  rev = "43bd6a318e151cc724dd5071d8bf0e78d7b579da";
                })
                { inherit system; };

              cfunge = oldpkgs.stdenv.mkDerivation {
                name = "cfunge";
                nativeBuildInputs = with oldpkgs; [
                  cmake
                  pkg-config
                ];
                cmakeFlags = [
                  "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
                ];
                src = ./vendor/cfunge-0.9.0.tar.bz2;
              };
            in
            step "QR.blc" {
              name = "befunge-to-bcl8";
              prev = beanshell-to-befunge;
              inputs = [ cfunge ];
              buildPhase = ''
                cfunge QR.bef > QR.blc
              '';
            };

          bcl8-to-brainf = step "QR.bf" {
            name = "bcl8-to-brainf";
            prev = befunge-to-bcl8;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${vendor/blc.rb} < QR.blc > QR.bf
            '';
          };

          brainf-to-c = step "QR.c" {
            name = "brainf-to-c";
            prev = bcl8-to-brainf;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${vendor/bf.rb} QR.bf > QR.c
            '';
          };

          c-to-cpp = step "QR.cpp" {
            name = "c-to-cpp";
            prev = brainf-to-c;
            inputs = [ pkgs.gcc ];
            buildPhase = ''
              gcc -o QR QR.c
              ./QR > QR.cpp
            '';
          };

          cpp-to-csharp = step "QR.cs" {
            name = "c-to-cpp";
            prev = c-to-cpp;
            inputs = [ pkgs.gcc ];
            buildPhase = ''
              g++ -o QR QR.cpp
              ./QR > QR.cs
            '';
          };

          csharp-to-chef = step "QR.chef" {
            name = "csharp-to-chef";
            prev = cpp-to-csharp;
            inputs = [ pkgs.dotnet-sdk ];
            buildPhase = ''
                      echo '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><Compile Include="QR.cs" /></ItemGroup></Project>' > tmp.csproj &&
              DOTNET_NOLOGO=1 dotnet run --project tmp.csproj > QR.chef
            '';
          };

          chef-to-clojure =
            let
              chef = pkgs.stdenv.mkDerivation {
                name = "chef";
                src = ./vendor/Acme-Chef-1.03.tar.gz;
                # buildInputs = [ pkgs.perl ];
                propagatedBuildInputs = [ pkgs.perl ];
                buildPhase = ''
                  perl Makefile.PL INSTALL_BASE=$out
                  make
                '';
                installPhase = ''
                  make install
                '';
              };
            in
            step "QR.clj" {
              name = "chef-to-clojure";
              prev = csharp-to-chef;
              inputs = [ chef ];
              buildPhase = ''
                export PERL5LIB=${chef.out}/lib/perl5
                compilechef QR.chef QR.chef.pl
                perl QR.chef.pl > QR.clj
              '';
            };

          clojure-to-cmake = pkgs.stdenv.mkDerivation {
            name = "clojure-to-cmake";
            src = "${chef-to-clojure.out}/share";
            buildInputs = [ pkgs.clojure ];
            buildPhase = ''
              export HOME="$(mktemp -d)"
              clojure QR.clj > QR.cmake
            '';
            installPhase = ''
              mkdir -p $out/share
              mv QR.cmake $out/share/
            '';
            # Hack: Use a fixed-output-derivation here to maven can talk to the internet.
            outputHashAlgo = "sha256";
            outputHashMode = "recursive";
            outputHash = "sha256-x1MsyBbD06t0LSGywyS01glJjmKlKd/H0O9qjXXJ6jM=";
          };

          # Note: We go back to `mkDerivation` here explicitly, as it
          # does a lot when it seems that `cmake` exists, and we need to
          # disable that.
          cmake-to-cobol = pkgs.stdenv.mkDerivation {
            name = "cmake-to-cobol";
            src = "${clojure-to-cmake.out}/share";
            buildInputs = [ pkgs.cmake ];
            dontConfigure = true;
            buildPhase = ''
              cmake -P QR.cmake > QR.cob
            '';
            installPhase = ''
              mkdir -p $out/share
              cp QR.cob $out/share/
            '';
          };

          cobol-to-coffeescript = step "QR.coffee" {
            name = "cobol-to-coffeescript";
            prev = cmake-to-cobol;

            # Just use the exe direct; it seems the packages
            # output is a bit odd.
            inputs = [ ];

            buildPhase = ''
              ${pkgs.lib.getExe pkgs.gnucobol} -O2 -x QR.cob
              ./QR > QR.coffee
            '';
          };

          coffeescript-to-clisp = step "QR.lisp" {
            name = "coffeescript-to-clisp";
            prev = cobol-to-coffeescript;
            inputs = [
              pkgs.coffeescript
            ];
            buildPhase = ''
              coffee --nodejs --stack_size=100000 QR.coffee > QR.lisp
            '';
          };

          clisp-to-crystal = step "QR.cr" {
            name = "clisp-to-crystal";
            prev = coffeescript-to-clisp;
            inputs = [ pkgs.clisp ];
            buildPhase = ''
              clisp QR.lisp > QR.cr
            '';
          };

          crystal-to-d = step "QR.d" {
            name = "crystal-to-d";
            prev = clisp-to-crystal;
            inputs = [ pkgs.crystal ];
            buildPhase = ''
              crystal QR.cr > QR.d
            '';
          };

          d-to-dc = step "QR.dc" {
            name = "d-to-dc";
            prev = crystal-to-d;
            inputs = [ ];
            # Note: We're using a different compiler, so the arguments are
            # different but the result is the same.
            buildPhase = ''
              ${pkgs.lib.getExe pkgs.ldc} --run QR.d > QR.dc
            '';
          };

          dc-to-dhall =
            let
              dc = pkgs.stdenv.mkDerivation {
                name = "dc";
                buildInputs = with pkgs; [
                  ed
                  gcc
                  pkg-config
                  texinfo
                ];
                src = builtins.fetchurl {
                  url = "http://archive.ubuntu.com/ubuntu/pool/main/b/bc/bc_1.07.1.orig.tar.gz";
                  sha256 = "0amh9ik44jfg66csyvf4zz1l878c4755kjndq9j0270akflgrbb2";
                };
              };
            in
            step "QR.dhall" {
              name = "dc-to-dhall";
              prev = d-to-dc;
              inputs = [ dc ];
              buildPhase = ''
                dc QR.dc > QR.dhall || true
              '';
            };

          dhall-to-elixir = step "QR.exs" {
            name = "dhall-to-elixir";
            prev = dc-to-dhall;
            inputs = [ pkgs.dhall ];
            buildPhase = ''
              dhall text --file QR.dhall > QR.exs
            '';
          };

          elixir-to-elisp = step "QR.el" {
            name = "elixir-to-elisp";
            prev = dhall-to-elixir;
            inputs = [ pkgs.elixir ];
            buildPhase = ''
              elixir QR.exs > QR.el
            '';
          };

          elisp-to-erlang = step "QR.erl" {
            name = "elisp-to-erlang";
            prev = elixir-to-elisp;
            inputs = [ pkgs.emacs ];
            buildPhase = ''
              emacs -Q --script QR.el > QR.erl
            '';
          };

          erlang-to-execline = step "QR.e" {
            name = "erlang-to-execline";
            prev = elisp-to-erlang;
            inputs = [ pkgs.erlang ];
            buildPhase = ''
              escript QR.erl > QR.e
            '';
          };

          execline-to-fsharp = step "QR.fsx" {
            name = "execline-to-fsharp";
            prev = erlang-to-execline;
            inputs = [ pkgs.execline ];
            buildPhase = ''
              execlineb QR.e > QR.fsx
            '';
          };

          fsharp-to-FALSE = step "QR.false" {
            name = "fsharp-to-FALSE";
            prev = execline-to-fsharp;
            inputs = [ pkgs.dotnet-sdk ];
            buildPhase = ''
              echo '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><Compile Include="QR.fsx" /></ItemGroup></Project>' > tmp.fsproj &&
              DOTNET_NOLOGO=1 dotnet run --project tmp.fsproj > QR.false
            '';
          };

          FALSE-to-flex = step "QR.fl" {
            name = "FALSE-to-flex";
            prev = fsharp-to-FALSE;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${vendor/false.rb} QR.false > QR.fl
            '';
          };

          flex-to-fish = step "QR.fish" {
            name = "flex-to-fish";
            prev = FALSE-to-flex;
            inputs = with pkgs; [ flex gcc ];
            buildPhase = ''
              flex -o QR.fl.c QR.fl
              gcc -o QR QR.fl.c
              ./QR > QR.fish
            '';
          };

          fish-to-forth = step "QR.fs" {
            name = "fish-to-forth";
            prev = flex-to-fish;
            inputs = [ pkgs.fish ];
            buildPhase = ''
              fish QR.fish > QR.fs
            '';
          };

          forth-to-fortran77 = step "QR.f" {
            name = "forth-to-fortran77";
            prev = fish-to-forth;
            inputs = [ pkgs.gforth ];
            buildPhase = ''
              export HOME="$(mktemp -d)"
              gforth QR.fs > QR.f
            '';
          };

          fortran77-to-fortran90 = step "QR.f90" {
            name = "fortran77-to-fortran90";
            prev = forth-to-fortran77;
            inputs = [ pkgs.gfortran ];
            buildPhase = ''
              gfortran -o QR QR.f
              ./QR > QR.f90
            '';
          };

          fortran90-to-gambas = step "QR.gbs" {
            name = "fortran90-to-gambas";
            prev = fortran77-to-fortran90;
            inputs = [ pkgs.gfortran ];
            buildPhase = ''
              gfortran -o QR QR.f90
              ./QR > QR.gbs
            '';
          };

          gambas-to-gap =
            let
              oldpkgs = import
                (builtins.fetchGit {
                  name = "gambas-pkgs";
                  url = "https://github.com/NixOS/nixpkgs/";
                  ref = "refs/heads/nixpkgs-unstable";
                  rev = "59e940007106305c938332ef60962e672a4281f2";
                })
                { inherit system; };

              gambas = oldpkgs.stdenv.mkDerivation {
                name = "gambas";
                src = pkgs.fetchgit {
                  url = "https://git.launchpad.net/ubuntu/+source/gambas3";
                  rev = "ff1f5395f6cf92766e2156203a11dee3a474afb3";
                  sha256 = "sha256-ayg8IPEiXIw8Qv41VQcN6gq8rz6VH8jYRxupUwL4xu8=";
                };
                buildInputs = with oldpkgs; [
                  autoreconfHook
                  gcc
                  curl
                  gmime
                  gmp
                  gnum4
                  gsl
                  libffi
                  libtool
                  libxml2
                  ncurses
                  libnotify
                  pcre2
                  pkgconfig
                  zlib
                  zstd
                ];
                preConfigure = ''
                  patchShebangs .
                '';
                configureFlags = [
                  "--prefix=${placeholder "out"}"
                  "-C"
                  "--disable-sqlite2"
                  "--disable-qt4"
                  "--disable-pdf"
                  "--disable-qt5webkit"
                  "--disable-gtkopengl"
                ];
              };

              # Gambas expects `/usr/bin/...` in a _lot_ of places.
              gambas-wrapped = pkgs.buildFHSEnv {
                name = "gambas3-wrapped";
                runScript = "${gambas.outPath}/bin/gbs3";
                targetPkgs = _: [ gambas ];
              };
            in
            step "QR.g" {
              name = "gambas-to-gap";
              prev = fortran90-to-gambas;
              inputs = [ gambas-wrapped ];
              buildPhase = ''
                gambas3-wrapped QR.gbs > QR.g
              '';
            };

          gap-to-gdb = step "QR.gdb" {
            name = "gap-to-gdb";
            prev = gambas-to-gap;
            inputs = [ pkgs.gap-minimal ];
            buildPhase = ''
              gap -q QR.g > QR.gdb
            '';
            # Gap emits a bunch of comments explaining
            # missing packages; but we don't care.
            doCheck = false;
          };

          gdb-to-genius = step "QR.gel" {
            name = "gdb-to-genius";
            prev = gap-to-gdb;
            inputs = [ pkgs.gdb ];
            buildPhase = ''
              gdb -q -x QR.gdb > QR.gel
            '';
          };

          genius-to-gnuplot =
            let
              genius = pkgs.stdenv.mkDerivation {
                name = "genius";
                src = builtins.fetchurl {
                  url = "https://download.gnome.org/sources/genius/1.0/genius-1.0.27.tar.xz";
                  sha256 = "1dbvkrfl663h6fay3984lzndx25ivr9cv2kpc86977jzdg1vfhq2";
                };

                buildInputs = with pkgs; [
                  autoreconfHook
                  gcc
                  pkg-config
                  intltool
                  termcap
                  readline
                  ncurses
                  gmp
                  mpfr
                  glib
                  gtk3 # Shouldn't be needed.
                ];
                patches = [
                  ./vendor/genius.patch
                ];
                configureFlags = [
                  "--disable-gnome"
                ];
              };
            in
            step "QR.plt" {
              name = "genius-to-gnuplot";
              prev = gdb-to-genius;
              inputs = [ genius ];
              buildPhase = ''
                genius QR.gel > QR.plt
              '';
            };

          gnuplot-to-go = step "QR.go" {
            name = "genius-to-gnuplot";
            prev = genius-to-gnuplot;
            inputs = [ pkgs.gnuplot ];
            buildPhase = ''
              gnuplot QR.plt > QR.go
            '';
          };

          go-to-golfscript = step "QR.gs" {
            name = "go-to-golfscript";
            prev = gnuplot-to-go;
            inputs = [ pkgs.go ];
            buildPhase = ''
              export HOME="$(mktemp -d)"
              go run QR.go > QR.gs
            '';
          };

          golfscript-to-gport = step "QR.gpt" {
            name = "golfscript-to-gport";
            prev = go-to-golfscript;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${./vendor/golfscript.rb} QR.gs > QR.gpt
            '';
          };

          gport-to-grass =
            let
              gpt = pkgs.stdenv.mkDerivation {
                name = "gpt";
                src = pkgs.fetchgit {
                  url = "https://github.com/gportugol/gpt.git";
                  rev = "f324b698c851c9455337043452c52bfd10cb1efa";
                  sha256 = "sha256-Igt7TY5A+/66571TY8xQ6eyJyoXhBDr5uFWXODPLP9M=";
                };
                patches = [ ./vendor/gpt.patch ];
                nativeBuildInputs = with pkgs; [
                  antlr2
                  autoreconfHook
                  gcc
                  libtool
                  nasm
                  pcre2
                  pkg-config
                ];
              };
            in
            step "QR.grass" {
              name = "gport-to-grass";
              prev = golfscript-to-gport;
              inputs = [ gpt ];
              buildPhase = ''
                gpt -t QR.c QR.gpt
                gcc -o QR QR.c
                ./QR > QR.grass
              '';
            };

          grass-to-groovy = step "QR.groovy" {
            name = "grass-to-groovy";
            prev = gport-to-grass;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${./vendor/grass.rb} QR.grass > QR.groovy
            '';
          };

          groovy-to-gzip = step "QR.gz" {
            name = "groovy-to-gzip";
            prev = grass-to-groovy;
            inputs = [ pkgs.groovy ];
            buildPhase = ''
              groovy QR.groovy > QR.gz
            '';
          };

          gzip-to-haskell = step "QR.hs" {
            name = "gzip-to-haskell";
            prev = groovy-to-gzip;
            inputs = [ pkgs.gzip ];
            buildPhase = ''
              gzip -cd QR.gz > QR.hs
            '';
          };

          haskell-to-haxe = step "QR.hx" {
            name = "haskell-to-haxe";
            prev = gzip-to-haskell;
            inputs = [ pkgs.ghc ];
            buildPhase = ''
              ghc QR.hs
              ./QR > QR.hx
            '';
          };

          haxe-to-icon = step "QR.icn" {
            name = "haxe-to-icon";
            prev = haskell-to-haxe;
            inputs = with pkgs; [ haxe_4_0 neko ];
            buildPhase = ''
              haxe -main QR -neko QR.n
              neko QR.n > QR.icn
            '';
          };

          icon-to-intercal = step "QR.i" {
            name = "icon-to-intercal";
            prev = haxe-to-icon;
            # Note: Not exactly icon; the newer one that compiles.
            inputs = [ pkgs.unicon-lang ];
            buildPhase = ''
              icont -s QR.icn
              ./QR > QR.i
            '';
          };

          intercal-to-jasmin =
            let
              oldpkgs = import
                (builtins.fetchGit {
                  name = "gcc11-pkgs";
                  url = "https://github.com/NixOS/nixpkgs/";
                  rev = "55070e598e0e03d1d116c49b9eff322ef07c6ac6";
                })
                { inherit system; };
            in
            step "QR.j" {
              name = "intercal-to-jasmin";
              prev = icon-to-intercal;
              inputs = with oldpkgs; [ intercal gcc pkgconfig ];
              buildPhase = ''
                ick -bfOc QR.i
                gcc -std=c99 QR.c -I ${oldpkgs.intercal.out}/include/ick-* -o QR -lick
                ./QR > QR.j
              '';
            };

          jasmin-to-java = step "QR.java" {
            name = "jasmin-to-java";
            prev = intercal-to-jasmin;
            inputs = with pkgs; [ jasmin jre_minimal ];
            buildPhase = ''
              jasmin QR.j
              java QR > QR.java
            '';
          };

          java-to-javascript = step "QR.js" {
            name = "java-to-javascript";
            prev = jasmin-to-java;
            inputs = [ pkgs.jdk ];
            buildPhase = ''
              javac QR.java
              java QR > QR.js
            '';
          };

          javascript-to-jq = step "QR.jq" {
            name = "javascript-to-jq";
            prev = java-to-javascript;
            inputs = [ pkgs.nodejs ];
            buildPhase = ''
              node QR.js > QR.jq
            '';
          };

          jq-to-jsf = step "QR.jsfuck" {
            name = "jq-to-jsf";
            prev = javascript-to-jq;
            inputs = [ pkgs.jq ];
            buildPhase = ''
              jq -r -n -f QR.jq > QR.jsfuck
            '';
          };

          jsf-to-kotlin = step "QR.kt" {
            name = "jsf-to-kotlin";
            prev = jq-to-jsf;
            inputs = [ pkgs.nodejs ];
            buildPhase = ''
              node --stack_size=100000 QR.jsfuck > QR.kt
            '';
          };

          kotlin-to-ksh = step "QR.ksh" {
            name = "kotlin-to-ksh";
            prev = jsf-to-kotlin;
            inputs = [ pkgs.kotlin ];
            buildPhase = ''
              kotlinc QR.kt -include-runtime -d QR.jar
              kotlin QR.jar > QR.ksh
            '';
          };

          ksh-to-lazyk = step "QR.lazy" {
            name = "ksh-to-lazyk";
            prev = kotlin-to-ksh;
            inputs = [ pkgs.ksh ];
            buildPhase = ''
              ksh QR.ksh > QR.lazy
            '';
          };

          lazyk-to-livescript = step "QR.ls" {
            name = "lazyk-to-livescript";
            prev = ksh-to-lazyk;
            inputs = [ pkgs.gcc ];
            buildPhase = ''
              gcc ${vendor/lazyk.c} -o lazyk
              ./lazyk QR.lazy > QR.ls
            '';
          };

          livescript-to-llvm =
            let
              src = builtins.fetchGit {
                # Note: This is a fork just adding the package-lock.json file.
                name = "silky-livescript-fork";
                url = "https://github.com/silky/LiveScript";
                rev = "34ec2c6824349dc863116b629a1903ff87d2d86b";
              };
              livescript = pkgs.buildNpmPackage {
                inherit src;
                name = "livescript";
                npmDeps = pkgs.importNpmLock { npmRoot = src; };
                npmConfigHook = pkgs.importNpmLock.npmConfigHook;
                dontNpmBuild = true;
              };
            in
            step "QR.ll" {
              name = "livescript-to-llvm";
              prev = lazyk-to-livescript;
              inputs = [ livescript ];
              buildPhase = ''
                lsc QR.ls > QR.ll
              '';
            };

          llvm-to-lolcode = step "QR.lol" {
            name = "llvm-to-lolcode";
            prev = livescript-to-llvm;
            inputs = [ pkgs.llvmPackages_20.libllvm ];
            buildPhase = ''
              llvm-as QR.ll
              lli QR.bc > QR.lol
            '';
          };

          lolcode-to-lua = step "QR.lua" {
            name = "lolcode-to-lua";
            prev = llvm-to-lolcode;
            inputs = [ pkgs.lolcode ];
            buildPhase = ''
              lolcode-lci QR.lol > QR.lua
            '';
          };

          lua-to-m4 = step "QR.m4" {
            name = "lua-to-m4";
            prev = lolcode-to-lua;
            inputs = [ pkgs.lua ];
            buildPhase = ''
              lua QR.lua > QR.m4
            '';
          };

          m4-to-make = step "QR.mk" {
            name = "m4-to-make";
            prev = lua-to-m4;
            inputs = [ pkgs.gnum4 ];
            buildPhase = ''
              m4 QR.m4 > QR.mk
            '';
          };

          make-to-minizinc = step "QR.mzn" {
            name = "make-to-minizinc";
            prev = m4-to-make;
            inputs = [ pkgs.gnumake ];
            buildPhase = ''
              make -f QR.mk > QR.mzn
            '';
          };

          minizinc-to-modula2 = step "QR.mod" {
            name = "make-to-minizinc";
            prev = make-to-minizinc;
            inputs = [ pkgs.minizinc ];
            buildPhase = ''
              minizinc --solver COIN-BC --soln-sep "" QR.mzn > QR.mod
            '';
          };

          modula2-to-msil =
            let
              # Very nice: https://github.com/SandaruKasa/quine-relay/blob/nix/nix/gm2.nix
              gm2 = (pkgs.gcc.cc.override {
                name = "gm2";
                langCC = true;
                langC = true;
                enableLTO = true;
              }).overrideAttrs (prev: {
                configureFlags = pkgs.lib.map
                  (
                    flag: if pkgs.lib.strings.match ".*enable-languages.*" flag != null then flag + ",m2" else flag
                  )
                  prev.configureFlags;
                nativeBuildInputs = prev.nativeBuildInputs ++ [ pkgs.flex ];
              });
            in
            step "QR.il" {
              name = "modula2-to-msil";
              prev = minizinc-to-modula2;
              inputs = [ gm2 ];
              buildPhase = ''
                gm2 -fiso QR.mod -o QR -B ${pkgs.gcc.libc_lib}/lib
                ./QR > QR.il
              '';
            };

          msil-to-mustache = step "QR.mustache" {
            name = "msil-to-mustache";
            prev = modula2-to-msil;
            inputs = [ pkgs.mono ];
            buildPhase = ''
              ilasm QR.il
              mono QR.exe > QR.mustache
            '';
          };

          mustache-to-nasm = step "QR.asm" {
            name = "mustache-to-nasm";
            prev = msil-to-mustache;
            inputs = [ pkgs.mustache-go ];
            buildPhase = ''
              mustache QR.mustache QR.mustache > QR.asm
            '';
            doCheck = false;
          };

          nasm-to-neko = step "QR.neko" {
            name = "nasm-to-neko";
            prev = mustache-to-nasm;
            inputs = [ pkgs.nasm ];
            buildPhase = ''
              nasm -felf QR.asm
              ld -m elf_i386 -o QR QR.o
              ./QR > QR.neko
            '';
          };

          neko-to-nickle = step "QR.5c" {
            name = "neko-to-nickle";
            prev = nasm-to-neko;
            inputs = [ pkgs.neko ];
            buildPhase = ''
              nekoc QR.neko
              neko QR.n > QR.5c
            '';
          };

          nickle-to-nim =
            let
              nickle = pkgs.stdenv.mkDerivation {
                name = "nickle";
                src = pkgs.fetchgit {
                  url = "https://git.launchpad.net/ubuntu/+source/nickle";
                  rev = "fc89f7bbf76fde65d9700eb648f025f3e84686fe";
                  sha256 = "sha256-WjPnT27hHoNFIxVCbSrxmRD6PyPMTZ42gAw4vC80smM=";
                };
                nativeBuildInputs = with pkgs; [
                  meson
                  gcc
                  bc
                  gmp
                  byacc
                  flex
                  bison
                  ninja
                ];
              };
            in
            step "QR.nim"
              {
                name = "nickle-to-nim";
                prev = neko-to-nickle;
                inputs = [ nickle ];
                buildPhase = ''
                  nickle QR.5c > QR.nim
                '';
              };

          nim-to-objc = step "QR.m" {
            name = "nim-to-objc";
            prev = nickle-to-nim;
            inputs = [ pkgs.nim ];
            buildPhase = ''
              export HOME="$(mktemp -d)"
              nim compile QR.nim
              ./QR > QR.m
            '';
          };

          objc-to-ocaml =
            let
              # Pray for us.
              gccWithObjc = pkgs.wrapCC (pkgs.gcc.cc.override {
                langObjC = true;
              });
            in
            step "QR.ml" {
              name = "objc-to-ocaml";
              prev = nim-to-objc;
              inputs = [ gccWithObjc ];
              buildPhase = ''
                gcc -o QR QR.m
                ./QR > QR.ml
              '';
            };

          ocaml-to-octave = step "QR.octave" {
            name = "ocaml-to-octave";
            prev = objc-to-ocaml;
            inputs = [ pkgs.ocaml ];
            buildPhase = ''
              ocaml QR.ml > QR.octave
            '';
          };

          octave-to-ook = step "QR.ook" {
            name = "octave-to-ook";
            prev = ocaml-to-octave;
            inputs = [ pkgs.octave ];
            buildPhase = ''
              octave -qf QR.octave > QR.ook
            '';
          };

          ook-to-pari = step "QR.gp" {
            name = "ook-to-pari";
            prev = octave-to-ook;
            inputs = [ pkgs.ruby ];
            buildPhase = ''
              ruby ${./vendor/ook-to-bf.rb} QR.ook QR.ook.bf
              ruby ${./vendor/bf.rb} QR.ook.bf > QR.gp
            '';
          };

          pari-to-parser3 = step "QR.p" {
            name = "pari-to-parser3";
            prev = ook-to-pari;
            inputs = [ pkgs.pari ];
            buildPhase = ''
              gp -f -q QR.gp > QR.p
            '';
          };

          parser3-to-pascal =
            let
              parser3 = pkgs.stdenv.mkDerivation {
                name = "parser3";
                src = pkgs.fetchgit {
                  url = "https://github.com/artlebedev/parser3";
                  rev = "4271e4587e57d21585d287705b6a4c46fd783896";
                  sha256 = "sha256-7eI66bXSe0tERrRhnL+pCU0rhpxY2RcQFg5eLO+0OwY=";
                };
                nativeBuildInputs = with pkgs; [
                  boehmgc
                  pcre
                ];
                preConfigure = ''
                  patchShebangs .
                '';
                configureFlags = [
                  "--prefix=${placeholder "out"}"
                ];
              };
            in
            step "QR.pas" {
              name = "parser3-to-pascal";
              prev = pari-to-parser3;
              inputs = [ parser3 ];
              buildPhase = ''
                parser3 QR.p > QR.pas
              '';
            };

          pascal-to-perl5 = step "QR.pl" {
            name = "pascal-to-perl5";
            prev = parser3-to-pascal;
            inputs = [ pkgs.fpc ];
            buildPhase = ''
              fpc QR.pas
              ./QR > QR.pl
            '';
          };

          perl5-to-perl6 = step "QR.pl6" {
            name = "perl5-to-perl6";
            prev = pascal-to-perl5;
            inputs = [ pkgs.perl ];
            buildPhase = ''
              perl QR.pl > QR.pl6
            '';
          };

          perl6-to-php = step "QR.php" {
            name = "perl6-to-php";
            prev = perl5-to-perl6;
            inputs = [ pkgs.rakudo ];
            buildPhase = ''
              perl6 QR.pl6 > QR.php
            '';
          };

          php-to-piet = step "QR.png" {
            name = "php-to-piet";
            prev = perl6-to-php;
            inputs = [ pkgs.php ];
            buildPhase = ''
              php QR.php > QR.png
            '';
          };

          piet-to-pike =
            let
              piet = pkgs.stdenv.mkDerivation {
                name = "piet";

                nativeBuildInputs = with pkgs; [
                  gd
                  groff
                  libpng
                ];

                env.NIX_CFLAGS_COMPILE =
                  toString [
                    "--std=c99"
                    "-Wno-implicit-function-declaration"
                    "-Wno-int-conversion"
                  ];

                configureFlags = [
                  "--prefix=${placeholder "out"}"
                ];

                buildPhase = ''
                  make
                '';

                installPhase = ''
                  make install
                '';

                src = ./vendor/npiet-1.3e.tar.gz;
              };
            in
            step "QR.pike" {
              name = "piet-to-pike";
              prev = php-to-piet;
              inputs = [ piet ];
              buildPhase = ''
                npiet QR.png > QR.pike
              '';
            };

          pike-to-postscript = step "QR.ps" {
            name = "pike-to-postscript";
            prev = piet-to-pike;
            inputs = [ pkgs.pike ];
            buildPhase = ''
              pike QR.pike > QR.ps
            '';
          };

          postscript-to-prolog = step "QR.prolog" {
            name = "postscript-to-prolog";
            prev = pike-to-postscript;
            inputs = [ pkgs.ghostscript ];
            buildPhase = ''
              gs -dNODISPLAY -q QR.ps > QR.prolog
            '';
          };

          prolog-to-spin = step "QR.pr" {
            name = "prolog-to-spin";
            prev = postscript-to-prolog;
            inputs = [ pkgs.swi-prolog ];
            buildPhase = ''
              swipl -q -t qr -f QR.prolog > QR.pr
            '';
          };

          spin-to-python = step "QR.py" {
            name = "spin-to-python";
            prev = prolog-to-spin;
            inputs = [ pkgs.spin ];
            buildPhase = ''
              spin -T QR.pr > QR.py
            '';
          };

          python-to-r = step "QR.r" {
            name = "python-to-r";
            prev = spin-to-python;
            inputs = [ pkgs.python3 ];
            buildPhase = ''
              python3 QR.py > QR.r
            '';
          };

          r-to-ratfor = step "QR.ratfor" {
            name = "r-to-ratfor";
            prev = python-to-r;
            inputs = [ pkgs.R ];
            buildPhase = ''
              R --slave -f QR.r > QR.ratfor
            '';
          };

          ratfor-to-rc =
            let
              ratfor = pkgs.stdenv.mkDerivation {
                name = "ratfor";
                src = pkgs.fetchgit {
                  url = "https://git.launchpad.net/ubuntu/+source/ratfor";
                  rev = "fb52ba440705db3448d15a67aa1059fed5fd8393";
                  sha256 = "sha256-S3X2NPP+eG59ZPuiVHeZmOMFtF7SQrkmTKPzb+o300U=";
                };
                nativeBuildInputs = with pkgs; [
                  pkg-config
                  gcc
                  bison
                ];
                configureFlags = [
                  "--prefix=${placeholder "out"}"
                ];
              };
            in
            step "QR.rc" {
              name = "ratfor-to-rc";
              prev = r-to-ratfor;
              inputs = [ ratfor pkgs.gfortran ];
              buildPhase = ''
                ratfor -o QR.ratfor.f QR.ratfor
                gfortran -o QR QR.ratfor.f
                ./QR > QR.rc
              '';
            };

          rc-to-rexx =
            let
              oldpkgs = import
                (builtins.fetchGit {
                  url = "https://github.com/NixOS/nixpkgs/";
                  ref = "refs/heads/nixpkgs-unstable";
                  rev = "d1c3fea7ecbed758168787fe4e4a3157e52bc808";
                })
                { inherit system; };
            in
            step "QR.rexx" {
              name = "rc-to-rexx";
              prev = ratfor-to-rc;
              inputs = [ oldpkgs.rc ];
              buildPhase = ''
                rc QR.rc > QR.rexx
              '';
            };

          rexx-to-ruby = step "QR2.rb" {
            name = "rexx-to-ruby";
            prev = rc-to-rexx;
            inputs = [ pkgs.regina ];
            buildPhase = ''
              rexx ./QR.rexx > QR2.rb
            '';
          };

          default = rexx-to-ruby;
        };
      }
    );
}
