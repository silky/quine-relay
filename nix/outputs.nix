{ inputs, self, ... }:
with inputs; {
  perSystem = { pkgs, config, system, compiler, ... }:
    let
      c = ext: nativeBuildInputs: mkBuildPhase: {
        inherit ext;
        build = prev: outFile: step ext outFile {
          inherit prev nativeBuildInputs;
          buildPhase = mkBuildPhase outFile;
        };
      };

      c' =
        { stdenv ? pkgs.stdenv
        , overrideAttrsFn ? (_: { })
        , doCheck ? true
        }:
        ext:
        nativeBuildInputs:
        mkBuildPhase: {
          inherit ext;
          build = prev: outFile: step ext outFile {
            inherit
              prev
              nativeBuildInputs
              stdenv
              overrideAttrsFn
              doCheck
              ;
            buildPhase = mkBuildPhase outFile;
          };
        };

      # TODO: Don't need this one and "c'".
      step = ext: file:
        { prev
        , nativeBuildInputs
        , buildPhase
        , doCheck ? true
        , stdenv ? pkgs.stdenv
        , overrideAttrsFn ? (_: { })
        }:
        (stdenv.mkDerivation {
          inherit buildPhase nativeBuildInputs;
          name = ext;
          src = "${prev.out}/share";
          installPhase = ''
            mkdir -p $out/share
            mv ${file} $out/share/
          '';
          # Have to remove if we're adding new languages, as we don't
          # generate this file yet.
          inherit doCheck;
          checkPhase = ''
            hash=$(${pkgs.toybox}/bin/sha256sum ${file})
            ${pkgs.toybox}/bin/grep $hash ${../SHA256SUMS}
          '';
        }).overrideAttrs overrideAttrsFn;

      steps' = with drvs; [
        rust
        scala
        guile
        scilab
        sed
        spl
        sl
        squirrel
        sml
        subleq
        surgescript
        swift
        tcl
        tc
        thue
        typescript
        unlambda
        vala
        velato
        verilog
        vim
        vb
        wasm-bin
        wasm-txt
        whitespace
        xslt
        yab
        yorick
        zoem
        zsh
        aplus
        ada
        afnix
        aheui
        algol
        ante
        aspectj
        asymptote
        ats
        awk
        bash
        bc
        beanshell
        befunge
        bcl8
        brainf
        c_
        cpp
        csharp
        chef
        clojure
        cmake
        cobol
        coffeescript
        clisp
        crystal
        d
        dc
        dhall
        elixir
        elisp
        erlang
        execline
        fsharp
        FALSE
        flex
        fish
        forth
        fortran77
        fortran90
        gambas
        gap
        gdb
        genius
        gnuplot
        go
        golfscript
        gport
        grass
        groovy
        gzip
        haskell
        haxe
        icon
        intercal
        jasmin
        java
        javascript
        jq
        jsf
        kotlin
        ksh
        lazyk
        livescript
        llvm
        lolcode
        lua
        m4
        make
        minizinc
        modula2
        msil
        mustache
        nasm
        neko
        nickle
        nim
        objc
        ocaml
        octave
        ook
        pari
        parser3
        pascal
        perl5
        perl6
        php
        piet
        pike
        postscript
        prolog
        spin
        python
        r
        ratfor
        rc
        rexx
      ];


      steps'' = with pkgs.lib.lists;
        zipListsWith
          (a: b: { drv = a; nextExt = b.ext; name = "${a.ext}-to-${b.ext}"; })
          steps'
          # Final output is ruby (rb)
          (drop 1 steps' ++ [{ ext = "rb"; }]);

      # Build up to the nth step of the quine relay. If you pick some n < the
      # largest one, it will just call the output "rb", even though it
      # obviously is not.
      buildUntil = n:
        let
          # Step 1. Ruby builds rust.
          drv0 = pkgs.runCommand "ruby"
            {
              src = ../QR.rb;
              nativeBuildInputs = [ pkgs.ruby ];
            } ''
            mkdir -p $out/share
            ruby $src > $out/share/QR.rs
          '';

          # Step n. Build "this" with the output of the previous
          # step, and produce the next file:
          #
          # n {n-1.out} > n+1.out
          #
          # e.g., effectively something like
          #
          # "rustc ${ruby-to-rust.out} > QR.scala"

          mkDrv = prev: this: this.drv.build prev "QR.${this.nextExt}";
        in
        with pkgs.lib.lists; foldl mkDrv drv0 (take n steps'');


      # A bit hacky; but generate all the indexed step functions, so we can
      # easily build any part, or everything all at once.
      steps = with pkgs.lib;
        let ixd = lists.imap1 (i: x: x // { idx = i; }) steps'';
        in attrsets.genAttrs' ixd (x: nameValuePair x.name (buildUntil x.idx));


      drvs = with pkgs; {
        rust = c "rs" [ rustc ] (outFile: ''
          rustc QR.rs
          ./QR > ${outFile}
        '');

        scala = c "scala" [ scala ] (outFile: ''
          scalac QR.scala
          scala QR > ${outFile}
        '');

        guile = c "scm" [ guile ] (outFile: ''
          guile QR.scm > ${outFile}
        '');

        scilab = c "sci" [ writableTmpDirAsHomeHook scilab-bin ] (outFile: ''
          # Hack: Drop the first line; for some reason it contains a
          # grep warning.
          scilab-cli -nwni -nb -f QR.sci | tail -n +2 > ${outFile}
        '');

        sed = c "sed" [ gnused ] (outFile: ''
          sed -E -f QR.sed QR.sed > ${outFile}
        '');

        spl =
          c "spl" [ spl2c ] (outFile: ''
            spl2c < QR.spl > QR.spl.c
            gcc -z muldefs -o QR \
              -I ./${spl2c.out}/include \
              -L ./${spl2c.out}/lib \
              QR.spl.c \
              -lspl \
              -lm
            ./QR > ${outFile}
          '');

        sl = c "sl" [ slang ] (outFile: ''
          slsh QR.sl > ${outFile}
        '');

        squirrel = c "nut" [ squirrel ] (outFile: ''
          sq QR.nut > ${outFile}
        '');

        sml = c "sml" [ polyml ] (outFile: ''
          polyc -o QR QR.sml
          ./QR > ${outFile}
        '');

        subleq = c "sq" [ ruby ] (outFile: ''
          ruby ${../vendor/subleq.rb} QR.sq > ${outFile}
        '');

        surgescript = c "ss" [ surgescript ] (outFile: ''
          surgescript QR.ss > ${outFile}
        '');

        swift =
          let
            pkgs2505 = import inputs.nixpkgs2505 { inherit system; };
            runSwift = with pkgs2505; writeShellApplication {
              name = "run-swift";
              runtimeInputs = with swiftPackages; [
                swift
                swiftpm
                Foundation
              ];
              text = ''
                export LD_LIBRARY_PATH=${swiftPackages.Dispatch}/lib
                swiftc QR.swift -o QR
                ./QR > "$@"
              '';
            };
          in
          c' { stdenv = pkgs2505.swift.stdenv; } "swift" [ ] (outFile: ''
            ${pkgs.lib.getExe runSwift} ${outFile}
          '');

        tcl = c "tcl" [ tcl ] (outFile: ''
          tclsh QR.tcl > ${outFile}
        '');

        tc = c "tcsh" [ tcsh ] (outFile: ''
          tcsh QR.tcsh > ${outFile}
        '');

        thue = c "t" [ ruby ] (outFile: ''
          ruby ${../vendor/thue.rb} QR.t > ${outFile}
        '');

        typescript = c "ts" [ typescript nodejs ] (outFile: ''
          tsc --outFile QR.ts.js QR.ts
          node QR.ts.js > ${outFile}
        '');

        unlambda = c "unl" [ ruby ] (outFile: ''
          ruby ${../vendor/unlambda.rb} QR.unl > ${outFile}
        '');

        vala = c "vala" [ vala pkg-config gobject-introspection ]
          (outFile: ''
            valac QR.vala -o QR
            ./QR > ${outFile}
          '');

        velato = c "mid" [ mono unzip ] (outFile: ''
          unzip ${../vendor/Velato_0_1.zip}
          mono Vlt.exe /s QR.mid
          mono QR.exe > ${outFile}
        '');

        verilog = c "v" [ iverilog ] (outFile: ''
          iverilog -o QR QR.v
          ./QR -vcd-none > ${outFile}
        '');

        vim = c "vim" [ vim ] (outFile: ''
          vim -EsS QR.vim > ${outFile}
        '');

        vb = c "vb" [ dotnet-sdk ] (outFile: ''
          echo '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><Compile Include="QR.vb" /></ItemGroup></Project>' > tmp.vbproj
          DOTNET_NOLOGO=1 dotnet run --project tmp.vbproj > ${outFile}
        '');

        wasm-bin = c "wasm" [ writableTmpDirAsHomeHook wasmtime ] (outFile: ''
          wasmtime QR.wasm > ${outFile}
        '');

        wasm-txt = c "wat" [ writableTmpDirAsHomeHook wabt wasmtime ] (outFile: ''
          wat2wasm QR.wat -o QR.wat.wasm
          wasmtime QR.wat.wasm > ${outFile}
        '');

        whitespace = c "ws" [ ruby ] (outFile: ''
          ruby ${../vendor/whitespace.rb} QR.ws > ${outFile}
        '');

        xslt = c "xslt" [ libxslt ] (outFile: ''
          xsltproc QR.xslt > ${outFile}
        '');

        yab = c "yab" [ yabasic ] (outFile: ''
          yabasic QR.yab > ${outFile}
        '');

        yorick = c "yorick" [ yorick ] (outFile: ''
          yorick -batch QR.yorick > ${outFile}
        '');

        zoem = c "azm" [ zoem ] (outFile: ''
          zoem -i QR.azm > ${outFile}
        '');

        zsh = c "zsh" [ zsh ] (outFile: ''
          zsh QR.zsh > ${outFile}
        '');

        aplus = c "+" [ aplus ] (outFile: ''
          a+ QR.+ > ${outFile}
        '');

        ada = c "ada" [ gnat ] (outFile: ''
          gnatmake QR.ada -o QR
          ./QR > ${outFile}
        '');

        afnix = c "als" [ afnix ] (outFile: ''
          LD_LIBRARY_PATH=${afnix.out}/lib axi QR.als > ${outFile}
        '');

        aheui = c "aheui" [ ruby ] (outFile: ''
          ruby ${../vendor/aheui.rb} QR.aheui > ${outFile}
        '');

        algol = c "a68" [ algol68g ] (outFile: ''
          a68g QR.a68 > ${outFile}
        '');

        ante = c "ante" [ ruby ] (outFile: ''
          ruby ${../vendor/ante.rb} QR.ante > ${outFile}
        '');

        aspectj = c "aj" [ aspectj jre ] (outFile: ''
          export CLASSPATH="$(find ${aspectj.out}/lib -name "*.jar" | tr $'\n' :):./."
          ajc QR.aj
          java QR > ${outFile}
        '');

        asymptote = c "asy" [ asymptote ] (outFile: ''
          asy QR.asy > ${outFile}
        '');

        ats = c "dats" [ gcc ats2 ] (outFile: ''
          patscc -o QR QR.dats
          ./QR > ${outFile}
        '');

        awk = c "awk" [ ] (outFile: ''
          awk -f QR.awk > ${outFile}
        '');

        bash = c "bash" [ ] (outFile: ''
          bash QR.bash > ${outFile}
        '');

        bc = c "bc" [ bc ] (outFile: ''
          BC_LINE_LENGTH=4000000 bc -q QR.bc > ${outFile}
        '');

        beanshell = c "bsh" [ jre_minimal ] (outFile: ''
          java -cp ${bsh} bsh.Interpreter QR.bsh > ${outFile}
        '');

        befunge = c "bef" [ cfunge ] (outFile: ''
          cfunge QR.bef > ${outFile}
        '');

        bcl8 = c "blc" [ ruby ] (outFile: ''
          ruby ${../vendor/blc.rb} < QR.blc > ${outFile}
        '');

        brainf = c "bf" [ ruby ] (outFile: ''
          ruby ${../vendor/bf.rb} QR.bf > ${outFile}
        '');

        c_ = c "c" [ ] (outFile: ''
          gcc -o QR QR.c
          ./QR > ${outFile}
        '');

        cpp = c "cpp" [ ] (outFile: ''
          g++ -o QR QR.cpp
          ./QR > ${outFile}
        '');

        csharp = c "cs" [ dotnet-sdk ] (outFile: ''
          echo '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><Compile Include="QR.cs" /></ItemGroup></Project>' > tmp.csproj
          DOTNET_NOLOGO=1 dotnet run --project tmp.csproj > ${outFile}
        '');

        chef = c "chef" [ chef ] (outFile: ''
          chef QR.chef > ${outFile}
        '');

        clojure =
          let
            props = {
              overrideAttrsFn = _: {
                # Hack: Use a fixed-output derivation here to allow
                # maven to talk to the internet.
                outputHashAlgo = "sha256";
                outputHashMode = "recursive";
                outputHash = "sha256-x1MsyBbD06t0LSGywyS01glJjmKlKd/H0O9qjXXJ6jM=";
              };
            };
          in
          c' props "clj" [ writableTmpDirAsHomeHook clojure ] (outFile: ''
            clojure QR.clj > ${outFile}
          '');

        cmake = c "cmake" [ ] (outFile: ''
          ${lib.getExe cmake} -P QR.cmake > ${outFile}
        '');

        cobol = c "cob" [ gnucobol.bin ] (outFile: ''
          cobc -O2 -x QR.cob
          ./QR > ${outFile}
        '');

        coffeescript = c "coffee" [ coffeescript ] (outFile: ''
          coffee --nodejs --stack_size=100000 QR.coffee > ${outFile}
        '');

        clisp = c "lisp" [ clisp ] (outFile: ''
          clisp QR.lisp > ${outFile}
        '');

        crystal = c "cr" [ crystal ] (outFile: ''
          crystal QR.cr > ${outFile}
        '');

        d = c "d" [ ldc ] (outFile: ''
          ldc2 --run QR.d > ${outFile}
        '');

        dc = c "dc" [ dc ] (outFile: ''
          dc QR.dc > ${outFile} || true
        '');

        dhall = c "dhall" [ dhall ] (outFile: ''
          dhall text --file QR.dhall > ${outFile}
        '');

        elixir = c "exs" [ elixir ] (outFile: ''
          elixir QR.exs > ${outFile}
        '');

        elisp = c "el" [ emacs ] (outFile: ''
          emacs -Q --script QR.el > ${outFile}
        '');

        erlang = c "erl" [ erlang ] (outFile: ''
          escript QR.erl > ${outFile}
        '');

        execline = c "e" [ execline ] (outFile: ''
          execlineb QR.e > ${outFile}
        '');

        fsharp = c "fsx" [ dotnet-sdk ] (outFile: ''
          echo '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><Compile Include="QR.fsx" /></ItemGroup></Project>' > tmp.fsproj
          DOTNET_NOLOGO=1 dotnet run --project tmp.fsproj > ${outFile}
        '');

        FALSE = c "false" [ ruby ] (outFile: ''
          ruby ${../vendor/false.rb} QR.false > ${outFile}
        '');

        flex = c "fl" [ flex ] (outFile: ''
          flex -o QR.fl.c QR.fl
          gcc -o QR QR.fl.c
          ./QR > ${outFile}
        '');

        fish = c "fish" [ fish ] (outFile: ''
          fish QR.fish > ${outFile}
        '');

        forth = c "fs" [ writableTmpDirAsHomeHook gforth ] (outFile: ''
          gforth QR.fs > ${outFile}
        '');

        fortran77 = c "f" [ gfortran ] (outFile: ''
          gfortran -o QR QR.f
          ./QR > ${outFile}
        '');

        fortran90 = c "f90" [ gfortran ] (outFile: ''
          gfortran -o QR QR.f90
          ./QR > ${outFile}
        '');

        gambas = c "gbs" [ gambas3 ] (outFile: ''
          gambas3-wrapped QR.gbs > ${outFile}
        '');

        gap = c "g" [ pkgs.gap-minimal ] (outFile: ''
          # Gap emits a bunch of comments explaining missing packages; but we
          # don't care.
          gap -q QR.g | tail -n 2 > ${outFile}
        '');

        gdb = c "gdb" [ gdb ] (outFile: ''
          gdb -q -x QR.gdb > ${outFile}
        '');

        genius = c "gel" [ genius ] (outFile: ''
          genius QR.gel > ${outFile}
        '');

        gnuplot = c "plt" [ gnuplot ] (outFile: ''
          gnuplot QR.plt > ${outFile}
        '');

        go = c "go" [ writableTmpDirAsHomeHook go ] (outFile: ''
          go run QR.go > ${outFile}
        '');

        golfscript = c "gs" [ ruby ] (outFile: ''
          ruby ${../vendor/golfscript.rb} QR.gs > ${outFile}
        '');

        gport = c "gpt" [ gpt ] (outFile: ''
          gpt -t QR.c QR.gpt
          gcc -o QR QR.c
          ./QR > ${outFile}
        '');

        grass = c "grass" [ ruby ] (outFile: ''
          ruby ${../vendor/grass.rb} QR.grass > ${outFile}
        '');

        groovy = c "groovy" [ groovy ] (outFile: ''
          groovy QR.groovy > ${outFile}
        '');

        gzip = c "gz" [ gzip ] (outFile: ''
          gzip -cd QR.gz > ${outFile}
        '');

        haskell = c "hs" [ ghc ] (outFile: ''
          ghc QR.hs
          ./QR > ${outFile}
        '');

        haxe = c "hx" [ haxe_4_0 neko ] (outFile: ''
          haxe -main QR -neko QR.n
          neko QR.n > ${outFile}
        '');

        icon = c "icn" [ unicon-lang ] (outFile: ''
          icont -s QR.icn
          ./QR > ${outFile}
        '');

        intercal = c "i" [ intercal pkg-config ] (outFile: ''
          ick -bfOc QR.i
          gcc -std=c99 QR.c -I ${intercal.out}/include/ick-* -o QR -lick
          ./QR > ${outFile}
        '');

        jasmin = c "j" [ jasmin jre_minimal ] (outFile: ''
          jasmin QR.j
          java QR > ${outFile}
        '');

        java = c "java" [ jdk ] (outFile: ''
          javac QR.java
          java QR > ${outFile}
        '');

        javascript = c "js" [ nodejs ] (outFile: ''
          node QR.js > ${outFile}
        '');

        jq = c "jq" [ jq ] (outFile: ''
          jq -r -n -f QR.jq > ${outFile}
        '');

        jsf = c "jsfuck" [ nodejs ] (outFile: ''
          node --stack_size=100000 QR.jsfuck > ${outFile}
        '');

        kotlin = c "kt" [ kotlin ] (outFile: ''
          kotlinc QR.kt -include-runtime -d QR.jar
          kotlin QR.jar > ${outFile}
        '');

        ksh = c "ksh" [ ksh ] (outFile: ''
          ksh QR.ksh > ${outFile}
        '');

        lazyk = c "lazy" [ ] (outFile: ''
          gcc ${../vendor/lazyk.c} -o lazyk
          ./lazyk QR.lazy > ${outFile}
        '');

        livescript = c "ls" [ livescript ] (outFile: ''
          lsc QR.ls > ${outFile}
        '');

        llvm = c "ll" [ llvmPackages_20.libllvm ] (outFile: ''
          llvm-as QR.ll
          lli QR.bc > ${outFile}
        '');

        lolcode = c "lol" [ lolcode ] (outFile: ''
          lolcode-lci QR.lol > ${outFile}
        '');

        lua = c "lua" [ lua ] (outFile: ''
          lua QR.lua > ${outFile}
        '');

        m4 = c "m4" [ gnum4 ] (outFile: ''
          m4 QR.m4 > ${outFile}
        '');

        make = c "mk" [ gnumake ] (outFile: ''
          make -f QR.mk > ${outFile}
        '');

        minizinc = c "mzn" [ minizinc ] (outFile: ''
          minizinc --solver COIN-BC --soln-sep "" QR.mzn > ${outFile}
        '');

        modula2 = c "mod" [ extendedGcc ] (outFile: ''
          gm2 -fiso QR.mod -o QR -B ${gcc.libc_lib}/lib
          ./QR > ${outFile}
        '');

        msil = c "il" [ mono ] (outFile: ''
          ilasm QR.il
          mono QR.exe > ${outFile}
        '');

        # Hack: We are missing a final newline for the hashes to match.
        mustache = c "mustache" [ mustache-go ] (outFile: ''
          mustache QR.mustache QR.mustache > ${outFile}
          echo >> ${outFile}
        '');

        nasm = c "asm" [ nasm ] (outFile: ''
          nasm -felf QR.asm -o QR.o
          ld -m elf_i386 -o QR QR.o
          ./QR > ${outFile}
        '');

        neko = c "neko" [ neko ] (outFile: ''
          nekoc QR.neko
          neko QR.n > ${outFile}
        '');

        nickle = c "5c" [ nickle ] (outFile: ''
          nickle QR.5c > ${outFile}
        '');

        nim = c "nim" [ writableTmpDirAsHomeHook nim ] (outFile: ''
          nim compile QR.nim
          ./QR > ${outFile}
        '');

        objc = c "m" [ (wrapCC extendedGcc) ] (outFile: ''
          gcc -o QR QR.m
          ./QR > ${outFile}
        '');

        ocaml = c "ml" [ ocaml ] (outFile: ''
          ocaml QR.ml > ${outFile}
        '');

        octave = c "octave" [ octave ] (outFile: ''
          octave -qf QR.octave > ${outFile}
        '');

        ook = c "ook" [ ruby ] (outFile: ''
          ruby ${../vendor/ook-to-bf.rb} QR.ook QR.ook.bf
          ruby ${../vendor/bf.rb} QR.ook.bf > ${outFile}
        '');

        pari = c "gp" [ pari ] (outFile: ''
          gp -f -q QR.gp > ${outFile}
        '');

        parser3 = c "p" [ parser3 ] (outFile: ''
          parser3 QR.p > ${outFile}
        '');

        pascal = c "pas" [ fpc ] (outFile: ''
          fpc QR.pas
          ./QR > ${outFile}
        '');

        perl5 = c "pl" [ perl ] (outFile: ''
          perl QR.pl > ${outFile}
        '');

        perl6 = c "pl6" [ rakudo ] (outFile: ''
          perl6 QR.pl6 > ${outFile}
        '');

        php = c "php" [ php ] (outFile: ''
          php QR.php > ${outFile}
        '');

        piet = c "png" [ piet ] (outFile: ''
          npiet QR.png > ${outFile}
        '');

        pike = c "pike" [ pike ] (outFile: ''
          pike QR.pike > ${outFile}
        '');

        postscript = c "ps" [ ghostscript ] (outFile: ''
          gs -dNODISPLAY -q QR.ps > ${outFile}
        '');

        prolog = c "prolog" [ swi-prolog ] (outFile: ''
          swipl -q -t qr -f QR.prolog > ${outFile}
        '');

        spin = c "pr" [ spin ] (outFile: ''
          spin -T QR.pr > ${outFile}
        '');

        python = c "py" [ python3 ] (outFile: ''
          python QR.py > ${outFile}
        '');

        r = c "R" [ R ] (outFile: ''
          R -s -f QR.R > ${outFile}
        '');

        ratfor = c "ratfor" [ ratfor gfortran ] (outFile: ''
          ratfor -o QR.ratfor.f QR.ratfor
          gfortran -o QR QR.ratfor.f
          ./QR > ${outFile}
        '');

        rc = c "rc" [ rc ] (outFile: ''
          rc QR.rc > ${outFile}
        '');

        rexx = c "rexx" [ regina ] (outFile: ''
          rexx QR.rexx > ${outFile}
        '');
      };
    in
    {
      packages = {
        # Make a meta-package that contains all the outputs; this makes for
        # easy inspection.
        default = pkgs.linkFarm "quine-relay" (
          pkgs.lib.mapAttrs'
            (_: drv:
              pkgs.lib.nameValuePair drv.name drv
            )
            steps
        );
      } // steps;
    };
}
