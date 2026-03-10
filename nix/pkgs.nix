{ inputs, self, ... }: {
  perSystem = { config, system, compiler, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (_: _: {
            inherit
              spl2c
              squirrel
              yorick
              zoem
              aplus
              afnix
              cfunge
              chef
              dc
              gambas3
              genius
              gpt# Not what you might think ..
              livescript
              extendedGcc# modula2, objc
              nickle
              parser3
              piet
              ratfor
              ;
          }
          )
        ];
      };


      spl2c = with pkgs; stdenv.mkDerivation {
        name = "spl2c";
        enableParallelBuilding = true;
        nativeBuildInputs = [
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
        src = ../vendor/spl-1.2.1.tar.gz;
      };


      squirrel = with pkgs; stdenv.mkDerivation {
        name = "squirrel";
        enableParallelBuilding = true;
        nativeBuildInputs = [
          clang
          cmake
        ];
        src = fetchFromGitHub {
          owner = "albertodemichelis";
          repo = "squirrel";
          rev = "f77074bdd6152d230609146a3d424c6f49e3770f";
          sha256 = "sha256-2Zi2HBBTruKIWHSyGgQsar4wVI5IxrpgF40AR68hHTU=";
        };
      };


      yorick = with pkgs; stdenv.mkDerivation {
        name = "yorick";
        version = "2.2";
        enableParallelBuilding = true;
        nativeBuildInputs = [
          clang
          xorg.libX11
        ];
        src = fetchFromGitHub {
          owner = "llnl";
          repo = "yorick";
          rev = "ea7012c87c379ee8e00ef8e0bde8e53f3fdb8492";
          sha256 = "sha256-gjabbLjVUPX9XrsrxDPTV4kmvd9sWRPmXDw+CRMqqbM=";
        };
        installPhase = ''
          make install
          mv relocate $out
        '';
      };


      cimfomfa = with pkgs; stdenv.mkDerivation {
        name = "cimfomfa";
        nativeBuildInputs = [
          pkg-config
        ];
        src = builtins.fetchurl {
          url = "https://micans.org/cimfomfa/src/cimfomfa-21-341.tar.gz";
          sha256 = "sha256:1w7z65zlk5cawq6c1ikfg304ggvd90p73qsvfk60i8lsiapxh9bw";
        };
      };


      zoem = with pkgs; stdenv.mkDerivation {
        name = "zoem";
        enableParallelBuilding = true;
        nativeBuildInputs = [
          autoreconfHook
          pkg-config
          cimfomfa
        ];
        src = fetchurl {
          url = "http://micans.org/zoem/src/zoem-21-341.tar.gz";
          hash = "sha256-Nw78f5mVcoiPTnIsv/QO+6OVpUNfGS5zTn/4eBCmh2g=";
        };
        postPatch = ''
          substituteInPlace src/version.h --replace-fail char 'extern char'
        '';
        configureFlags = [
          "--prefix=${placeholder "out"}"
        ];
      };

      aplus = with pkgs; stdenv.mkDerivation rec {
        name = "aplus";
        enableParallelBuilding = true;
        buildInputs = [
          xorg.libX11
          libnsl
        ];
        src = fetchFromGitHub {
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
          (fetchurl {
            url = "http://deb.debian.org/debian/pool/main/a/aplus-fsf/aplus-fsf_4.22.1-10.2.diff.gz";
            hash = "sha256-qDmXmqRc2iqv2qWH25jbFgmpxWHYIxR8SenrezyRijY=";
          })
        ];
      };


      afnix = with pkgs; stdenv.mkDerivation {
        name = "afnix";
        enableParallelBuilding = true;
        src = fetchgit {
          url = "https://git.launchpad.net/ubuntu/+source/afnix";
          rev = "0211872b7ae83d87b966022916a7f7e8ac26e6be";
          sha256 = "sha256-YZ4Fiirs/ncvPvhbvq/t8VTMZm7oWrTXRnqdCKpYxOI=";
        };
        nativeBuildInputs = [
          clang
          ncurses
        ];
        configureFlags = [
          "--prefix=${placeholder "out"}"
        ];
        preBuild = ''
          patchShebangs .
        '';
        postPatch = ''
          substituteInPlace cnf/bin/afnix-setup \
            --replace-fail /bin/mkdir mkdir \
            --replace-fail /opt/afnix $out

          substituteInPlace cnf/mak/afnix-unix.mak \
            --replace-fail /usr/bin/ "" \
            --replace-fail /bin/ ""

          substituteInPlace cnf/mak/*.mak \
            --replace-warn "-Werror" ""
        '';
        patches = [
          ./patches/afnix.patch
        ];
        installPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/lib

          mv -t $out/bin/ bld/bin/*
          mv -t $out/lib/ bld/lib/*
        '';
      };


      cfunge =
        let
          oldpkgs = import
            (builtins.fetchGit {
              name = "old-cmake";
              url = "https://github.com/NixOS/nixpkgs/";
              ref = "refs/heads/nixpkgs-unstable";
              rev = "43bd6a318e151cc724dd5071d8bf0e78d7b579da";
            })
            { inherit system; };
        in
        with oldpkgs; stdenv.mkDerivation {
          name = "cfunge";
          enableParallelBuilding = true;
          nativeBuildInputs = with oldpkgs; [
            cmake
            pkg-config
          ];
          cmakeFlags = [
            "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
          ];
          src = ../vendor/cfunge-0.9.0.tar.bz2;
        };

      chef = with pkgs; stdenv.mkDerivation {
        name = "chef";
        enableParallelBuilding = true;
        src = ../vendor/Acme-Chef-1.03.tar.gz;
        preConfigure = ''
          perl Makefile.PL INSTALL_BASE=$out
        '';
        nativeBuildInputs = [
          perl
          makeWrapper
        ];
        postInstall = ''
          for file in $out/bin/* ; do
            wrapProgram $file --suffix PERL5LIB ':' $out/lib/perl5/
          done
        '';
      };

      dc = with pkgs; stdenv.mkDerivation {
        name = "dc";
        enableParallelBuilding = true;
        buildInputs = [
          ed
          texinfo
        ];
        src = builtins.fetchurl {
          url = "http://archive.ubuntu.com/ubuntu/pool/main/b/bc/bc_1.07.1.orig.tar.gz";
          sha256 = "0amh9ik44jfg66csyvf4zz1l878c4755kjndq9j0270akflgrbb2";
        };
      };


      gambas3 =
        let
          oldpkgs = import
            (builtins.fetchGit {
              name = "gambas-pkgs";
              url = "https://github.com/NixOS/nixpkgs/";
              ref = "refs/heads/nixpkgs-unstable";
              rev = "59e940007106305c938332ef60962e672a4281f2";
            })
            { inherit system; };
        in
        with oldpkgs;
        let
          gambas = stdenv.mkDerivation {
            name = "gambas";
            enableParallelBuilding = true;
            src = fetchgit {
              url = "https://git.launchpad.net/ubuntu/+source/gambas3";
              rev = "ff1f5395f6cf92766e2156203a11dee3a474afb3";
              sha256 = "sha256-ayg8IPEiXIw8Qv41VQcN6gq8rz6VH8jYRxupUwL4xu8=";
            };
            buildInputs = [
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
        in
        pkgs.buildFHSEnv {
          name = "gambas3-wrapped";
          runScript = "${gambas.outPath}/bin/gbs3";
          targetPkgs = _: [ gambas ];
        };


      genius = with pkgs; stdenv.mkDerivation {
        name = "genius";
        enableParallelBuilding = true;
        src = builtins.fetchurl {
          url = "https://download.gnome.org/sources/genius/1.0/genius-1.0.27.tar.xz";
          sha256 = "1dbvkrfl663h6fay3984lzndx25ivr9cv2kpc86977jzdg1vfhq2";
        };
        buildInputs = [
          autoreconfHook
          pkg-config
          intltool
          termcap
          readline
          ncurses
          gmp
          mpfr
          glib
          gtk3
        ];
        postPatch = ''
          substituteInPlace Makefile.am --replace-fail "ve gtkextra src" "ve src"
        '';
        configureFlags = [
          "--disable-gnome"
        ];
      };


      gpt = with pkgs; stdenv.mkDerivation {
        name = "gpt";
        enableParallelBuilding = true;
        src = fetchgit {
          url = "https://github.com/gportugol/gpt.git";
          rev = "f324b698c851c9455337043452c52bfd10cb1efa";
          sha256 = "sha256-Igt7TY5A+/66571TY8xQ6eyJyoXhBDr5uFWXODPLP9M=";
        };
        postPatch = ''
          substituteInPlace configure.ac --replace-fail runantlr antlr
        '';
        nativeBuildInputs = [
          autoreconfHook
          antlr2
          libtool
          nasm
          pcre2
          pkg-config
        ];
      };

      livescript =
        let
          src = builtins.fetchGit {
            # Note: This is a fork just adding the package-lock.json file.
            name = "silky-livescript-fork";
            url = "https://github.com/silky/LiveScript";
            rev = "34ec2c6824349dc863116b629a1903ff87d2d86b";
          };
        in
        with pkgs; buildNpmPackage {
          inherit src;
          enableParallelBuilding = true;
          name = "livescript";
          npmDeps = importNpmLock { npmRoot = src; };
          npmConfigHook = pkgs.importNpmLock.npmConfigHook;
          dontNpmBuild = true;
        };


      # Override strategy courtesy of
      # https://github.com/SandaruKasa/quine-relay/blob/nix/nix/gm2.nix
      extendedGcc = (pkgs.gcc.cc.override {
        langObjC = true;
      }).overrideAttrs (prev: {
        configureFlags = pkgs.lib.map
          (
            flag:
            if pkgs.lib.strings.match ".*enable-languages.*" flag != null
            then flag + ",m2"
            else flag
          )
          prev.configureFlags;
        nativeBuildInputs = prev.nativeBuildInputs ++ [ pkgs.flex ];
      });


      nickle = pkgs.stdenv.mkDerivation {
        name = "nickle";
        enableParallelBuilding = true;
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


      parser3 = with pkgs; stdenv.mkDerivation {
        name = "parser3";
        enableParallelBuilding = true;
        src = fetchgit {
          url = "https://github.com/artlebedev/parser3";
          rev = "4271e4587e57d21585d287705b6a4c46fd783896";
          sha256 = "sha256-7eI66bXSe0tERrRhnL+pCU0rhpxY2RcQFg5eLO+0OwY=";
        };
        nativeBuildInputs = [
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


      piet = with pkgs; stdenv.mkDerivation {
        name = "piet";
        enableParallelBuilding = true;
        src = ../vendor/npiet-1.3e.tar.gz;
        nativeBuildInputs = [
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
      };


      ratfor = with pkgs; stdenv.mkDerivation {
        name = "ratfor";
        enableParallelBuilding = true;
        src = fetchgit {
          url = "https://git.launchpad.net/ubuntu/+source/ratfor";
          rev = "fb52ba440705db3448d15a67aa1059fed5fd8393";
          sha256 = "sha256-S3X2NPP+eG59ZPuiVHeZmOMFtF7SQrkmTKPzb+o300U=";
        };
        nativeBuildInputs = [
          pkg-config
          bison
        ];
        configureFlags = [
          "--prefix=${placeholder "out"}"
        ];
      };

    in
    {
      _module.args = { inherit pkgs; };
    };
}
