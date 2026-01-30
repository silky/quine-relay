{ inputs, self, ... }:
with inputs; {
  perSystem = { pkgs, config, system, compiler, ... }:
    let
      c = out: inputs: cmd: pkgs.runCommand out
        {
          nativeBuildInputs = inputs;
        }
        cmd;

      steps = with pkgs; rec {
        ruby-to-rust = c "QR.rs" [ ruby ] ''
          ruby ${../QR.rb} > $out
        '';

        rust-to-scala = c "QR.scala" [ gcc rustc ] ''
          rustc ${ruby-to-rust} -o QR
          ./QR > $out
        '';

        scala-to-guile = c "QR.scm" [ scala ] ''
          scalac ${rust-to-scala}
          scala QR > $out
        '';

        guile-to-scilab = c "QR.sci" [ guile ] ''
          guile ${scala-to-guile} > $out
        '';

        scilab-to-sed = c "QR.sed" [ writableTmpDirAsHomeHook scilab-bin ] ''
          # Hack: Drop the first line; for some reason it contains a
          # grep warning.
          scilab-cli -nwni -nb -f  ${guile-to-scilab} | tail -n +2 > $out
        '';

        sed-to-spl = c "QR.spl" [ gnused ] ''
          sed -E -f ${scilab-to-sed} ${scilab-to-sed} > $out
        '';

        spl-to-sl =
          let QR-spl-c = c "QR.spl.c" [ spl2c ] "spl2c < ${sed-to-spl} > $out";
          in c "QR.sl" [ spl2c glibc gcc ] ''
            gcc -z muldefs -o QR \
              -I ./${spl2c.out}/include \
              -L ./${spl2c.out}/lib \
              ${QR-spl-c} \
              -lspl \
              -lm
            ./QR > $out
          '';

        sl-to-squirrel = c "QR.nut" [ slang ] ''
          slsh ${spl-to-sl} > $out
        '';

        squirrel-to-sml = c "QR.sml" [ squirrel ] ''
          sq ${sl-to-squirrel} > $out
        '';

        sml-to-subleq = c "QR.sq" [ polyml gcc ] ''
          polyc -o QR ${squirrel-to-sml}
          ./QR > $out
        '';

        subleq-to-surgescript = c "QR.ss" [ ruby ] ''
          ruby ${../vendor/subleq.rb} ${sml-to-subleq} > $out
        '';

        surgescript-to-swift = c "QR.swift" [ surgescript ] ''
          surgescript ${subleq-to-surgescript} > $out
        '';

        swift-to-tcl =
          let pkgs2505 = import inputs.nixpkgs2505 { inherit system; };
          in with pkgs2505; runCommandWith
            {
              name = "QR.tcl";
              stdenv = swift.stdenv;
              derivationArgs = {
                nativeBuildInputs = with swiftPackages; [
                  swift
                  swiftpm
                  Foundation
                ];
              };
            } ''
            export LD_LIBRARY_PATH=${pkgs2505.swiftPackages.Dispatch}/lib
            swiftc ${surgescript-to-swift} -o QR
            ./QR > $out
          '';

        tcl-to-tc = c "QR.tcsh" [ tcl ] ''
          tclsh ${swift-to-tcl} > $out
        '';

        tc-to-thue = c "QR.t" [ tcsh ] ''
          tcsh ${tcl-to-tc} > $out
        '';

        thue-to-ts = c "QR.ts" [ ruby ] ''
          ruby ${../vendor/thue.rb} ${tc-to-thue} > $out
        '';

        ts-to-unlambda = c "QR.unl" [ typescript nodejs ] ''
          tsc --outFile QR.ts.js ${thue-to-ts}
          node QR.ts.js > $out
        '';

        unlambda-to-vala = c "QR.vala" [ ruby ] ''
          ruby ${../vendor/unlambda.rb} ${ts-to-unlambda} > $out
        '';

        vala-to-velato = c "QR.mid" [ gcc vala pkg-config gobject-introspection ] ''
          valac ${unlambda-to-vala} -o QR
          ./QR > $out
        '';

        velato-to-verilog = c "QR.v" [ mono unzip ] ''
          unzip ${../vendor/Velato_0_1.zip}
          cp ${vala-to-velato} QR.mid
          chmod 777 QR.mid
          mono Vlt.exe /s QR.mid
          mono QR.exe > $out
        '';

        verilog-to-vim = c "QR.vim" [ iverilog ] ''
          iverilog -o QR ${velato-to-verilog}
          ./QR -vcd-none > $out
        '';

        vim-to-vb = c "QR.vb" [ vim ] ''
          vim -EsS ${verilog-to-vim} > $out
        '';

        vb-to-wasm-bin = c "QR.wasm" [ dotnet-sdk ] ''
          echo '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><Compile Include="${vim-to-vb}" /></ItemGroup></Project>' > tmp.vbproj
          DOTNET_NOLOGO=1 dotnet run --project tmp.vbproj > $out
        '';

        wasm-bin-to-wasm-text = c "QR.wat" [ writableTmpDirAsHomeHook wasmtime ] ''
          wasmtime ${vb-to-wasm-bin} > $out
        '';

        wasm-text-to-whitespace = c "QR.ws" [ writableTmpDirAsHomeHook wabt wasmtime ] ''
          wat2wasm ${wasm-bin-to-wasm-text} -o QR.wat.wasm
          wasmtime QR.wat.wasm > $out
        '';

        whitespace-to-xslt = c "QR.xslt" [ ruby ] ''
          ruby ${../vendor/whitespace.rb} ${wasm-text-to-whitespace} > $out
        '';

        xslt-to-yab = c "QR.yab" [ libxslt ] ''
          cp ${whitespace-to-xslt} QR.xslt
          xsltproc QR.xslt > $out
        '';

        yab-to-yorick = c "QR.yorick" [ yabasic ] ''
          yabasic ${xslt-to-yab} > $out
        '';

        yorick-to-zoem = c "QR.azm" [ yorick ] ''
          yorick -batch ${yab-to-yorick} > $out
        '';

        zoem-to-zsh = c "QR.zsh" [ zoem ] ''
          zoem -i ${yorick-to-zoem} > $out
        '';

        zsh-to-aplus = c "QR.+" [ zsh ] ''
          zsh ${zoem-to-zsh} > $out
        '';

        aplus-to-ada = c "QR.adb" [ aplus ] ''
          a+ ${zsh-to-aplus} > $out
        '';

        ada-to-afnix = c "QR.als" [ gnat ] ''
          gnatmake ${aplus-to-ada} -o QR
          ./QR > $out
        '';

        afnix-to-aheui = c "QR.aheui" [ afnix ] ''
          LD_LIBRARY_PATH=${afnix.out}/lib axi ${ada-to-afnix} > $out
        '';

        aheui-to-algol = c "QR.a68" [ ruby ] ''
          ruby ${../vendor/aheui.rb} ${afnix-to-aheui} > $out
        '';

        algol-to-ante = c "QR.ante" [ algol68g ] ''
          a68g ${aheui-to-algol} > $out
        '';

        ante-to-aspectj = c "QR.aj" [ ruby ] ''
          ruby ${../vendor/ante.rb} ${algol-to-ante} > $out
        '';

        aspectj-to-asymptote = c "QR.asy" [ aspectj jre ] ''
          export CLASSPATH="$(find ${aspectj.out}/lib -name "*.jar" | tr $'\n' :):./."
          cp ${ante-to-aspectj} QR.aj
          ajc QR.aj
          java QR > $out
        '';

        asymptote-to-ats = c "QR.dats" [ asymptote ] ''
          asy ${aspectj-to-asymptote} > $out
        '';

        ats-to-awk = c "QR.awk" [ gcc ats2 ] ''
          patscc -o QR ${asymptote-to-ats}
          ./QR > $out
        '';

        awk-to-bash = c "QR.bash" [ ] ''
          awk -f ${ats-to-awk} > $out
        '';

        bash-to-bc = c "QR.bc" [ ] ''
          bash ${awk-to-bash} > $out
        '';

        bc-to-beanshell = c "QR.bsh" [ bc ] ''
          BC_LINE_LENGTH=4000000 bc -q ${bash-to-bc} > $out
        '';

        beanshell-to-befunge = c "QR.bef" [ jre_minimal ] ''
          java -cp ${bsh} bsh.Interpreter ${bc-to-beanshell} > $out
        '';

        befunge-to-bcl8 = c "QR.blc" [ cfunge ] ''
          cfunge ${beanshell-to-befunge} > $out
        '';

        bcl8-to-brainf = c "QR.bf" [ ruby ] ''
          ruby ${../vendor/blc.rb} < ${befunge-to-bcl8} > $out
        '';

        brainf-to-c = c "QR.c" [ ruby ] ''
          ruby ${../vendor/bf.rb} ${bcl8-to-brainf} > $out
        '';

        c-to-cpp = c "QR.cpp" [ gcc ] ''
          gcc -o QR ${brainf-to-c}
          ./QR > $out
        '';

        cpp-to-csharp = c "QR.cs" [ gcc ] ''
          g++ -o QR ${c-to-cpp}
          ./QR > $out
        '';

        csharp-to-chef = c "QR.chef" [ dotnet-sdk ] ''
          echo '<Project
          Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><Compile Include="${cpp-to-csharp}" /></ItemGroup></Project>' > tmp.csproj &&
              DOTNET_NOLOGO=1 dotnet run --project tmp.csproj > $out
        '';

        chef-to-clojure = c "QR.clj" [ chef ] ''
          chef ${csharp-to-chef} > $out
        '';

        clojure-to-cmake = (c "QR.cmake" [ writableTmpDirAsHomeHook clojure ] ''
          clojure ${chef-to-clojure} > $out
        '').overrideAttrs (_: {
          # Hack: Use a fixed-output derivation here to allow
          # maven to talk to the internet.
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-RlzODPFerW5fQ7jlfOxcZs3KeH+wvmMYcgXQ55/LsVQ=";
        });

        cmake-to-cobol = c "QR.cob" [ cmake ] ''
          cmake -P ${clojure-to-cmake} > $out
        '';

        cobol-to-coffeescript = c "QR.coffee" [ gcc gnucobol.bin ] ''
          cp ${cmake-to-cobol} QR.cob
          cobc -O2 -x QR.cob
          ./QR > $out
        '';

        coffeescript-to-clisp = c "QR.lisp" [ coffeescript ] ''
          coffee --nodejs --stack_size=100000 ${cobol-to-coffeescript} > $out
        '';

        clisp-to-crystal = c "QR.cr" [ clisp ] ''
          clisp ${coffeescript-to-clisp} > $out
        '';

        crystal-to-d = c "QR.d" [ crystal ] ''
          crystal ${clisp-to-crystal} > $out
        '';

        d-to-dc = c "QR.dc" [ ldc ] ''
          cp ${crystal-to-d} QR.d
          ldc2 --run QR.d > $out
        '';

        dc-to-dhall = c "QR.dhall" [ dc ] ''
          dc ${d-to-dc} > $out || true
        '';

        dhall-to-elixir = c "QR.exs" [ dhall ] ''
          dhall text --file ${dc-to-dhall} > $out
        '';

        elixir-to-elisp = c "QR.el" [ elixir ] ''
          elixir ${dhall-to-elixir} > $out
        '';

        elisp-to-erlang = c "QR.erl" [ emacs ] ''
          emacs -Q --script ${elixir-to-elisp} > $out
        '';

        erlang-to-execline = c "QR.e" [ erlang ] ''
          escript ${elisp-to-erlang} > $out
        '';

        execline-to-fsharp = c "QR.fsx" [ execline ] ''
          execlineb ${erlang-to-execline} > $out
        '';

        fsharp-to-FALSE = c "QR.false" [ dotnet-sdk ] ''
          echo '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup><ItemGroup><Compile Include="${execline-to-fsharp}" /></ItemGroup></Project>' > tmp.fsproj
          DOTNET_NOLOGO=1 dotnet run --project tmp.fsproj | tail -n +3 > $out
        '';

        FALSE-to-flex = c "QR.fl" [ ruby ] ''
          ruby ${../vendor/false.rb} ${fsharp-to-FALSE} > $out
        '';

        flex-to-fish = c "QR.fish" [ flex gcc ] ''
          flex -o QR.fl.c ${FALSE-to-flex}
          gcc -o QR QR.fl.c
          ./QR > $out
        '';

        fish-to-forth = c "QR.fs" [ fish ] ''
          fish ${flex-to-fish} > $out
        '';

        forth-to-fortran77 = c "QR.f" [ writableTmpDirAsHomeHook gforth ] ''
          gforth ${fish-to-forth} > $out
        '';

        fortran77-to-fortran90 = c "QR.f90" [ gfortran ] ''
          gfortran -o QR ${forth-to-fortran77}
          ./QR > $out
        '';

        fortran90-to-gambas = c "QR.gbs" [ gfortran ] ''
          gfortran -o QR ${fortran77-to-fortran90}
          ./QR > $out
        '';

        gambas-to-gap = c "QR.g" [ gambas3 ] ''
          gambas3-wrapped ${fortran90-to-gambas} > $out
        '';

        gap-to-gdb = c "QR.gap" [ pkgs.gap-minimal ] ''
          # Gap emits a bunch of comments explaining missing packages; but we
          # don't care.
          gap -q ${gambas-to-gap} | tail -n 2 > $out
        '';

        gdb-to-genius = c "QR.gel" [ gdb ] ''
          gdb -q -x ${gap-to-gdb} > $out
        '';

        genius-to-gnuplot = c "QR.plt" [ genius ] ''
          genius ${gdb-to-genius} > $out
        '';

        gnuplot-to-go = c "QR.go" [ gnuplot ] ''
          gnuplot ${genius-to-gnuplot} > $out
        '';

        go-to-golfscript = c "QR.gs" [ writableTmpDirAsHomeHook go ] ''
          go run ${gnuplot-to-go} > $out
        '';

        golfscript-to-gport = c "QR.gpt" [ ruby ] ''
          ruby ${../vendor/golfscript.rb} ${go-to-golfscript} > $out
        '';

        gport-to-grass = c "QR.grass" [ gcc gpt ] ''
          gpt -t QR.c ${golfscript-to-gport}
          gcc -o QR QR.c
          ./QR > $out
        '';

        grass-to-groovy = c "QR.groovy" [ ruby ] ''
          ruby ${../vendor/grass.rb} ${gport-to-grass} > $out
        '';

        groovy-to-gzip = c "QR.gz" [ groovy ] ''
          groovy ${grass-to-groovy} > $out
        '';

        gzip-to-haskell = c "QR.hs" [ gzip ] ''
          gzip -cd ${groovy-to-gzip} > $out
        '';

        haskell-to-haxe = c "QR.hx" [ ghc ] ''
          cp ${gzip-to-haskell} QR.hs
          ghc QR.hs
          ./QR > $out
        '';

        haxe-to-icon = c "QR.icn" [ haxe_4_0 neko ] ''
          cp ${haskell-to-haxe} QR.hx
          haxe -main QR -neko QR.n
          neko QR.n > $out
        '';

        icon-to-intercal = c "QR.i" [ unicon-lang ] ''
          cp ${haxe-to-icon} QR.icn
          icont -s QR.icn
          ./QR > $out
        '';

        intercal-to-jasmin = c "QR.j" [ intercal gcc pkg-config ] ''
          cp ${icon-to-intercal} QR.i
          ick -bfOc QR.i
          gcc -std=c99 QR.c -I ${intercal.out}/include/ick-* -o QR -lick
          ./QR > $out
        '';

        jasmine-to-java = c "QR.java" [ jasmin jre_minimal ] ''
          cp ${intercal-to-jasmin} QR.j
          jasmin QR.j
          java QR > $out
        '';

        java-to-javascript = c "QR.js" [ jdk ] ''
          cp ${jasmine-to-java} QR.java
          javac QR.java
          java QR > $out
        '';

        javascript-to-jq = c "QR.jq" [ nodejs ] ''
          node ${java-to-javascript} > $out
        '';

        jq-to-jsf = c "QR.jsfuck" [ jq ] ''
          jq -r -n -f ${javascript-to-jq} > $out
        '';

        jsf-to-kotlin = c "QR.kt" [ nodejs ] ''
          node --stack_size=100000 ${jq-to-jsf} > $out
        '';

        kotlin-to-ksh = c "QR.ksh" [ kotlin ] ''
          kotlinc ${jsf-to-kotlin} -include-runtime -d QR.jar
          kotlin QR.jar > $out
        '';

        ksh-to-lazyk = c "QR.lazy" [ ksh ] ''
          ksh ${kotlin-to-ksh} > $out
        '';

        lazyk-to-livescript = c "QR.ls" [ gcc ] ''
          gcc ${../vendor/lazyk.c} -o lazyk
          ./lazyk ${ksh-to-lazyk} > $out
        '';

        livescript-to-llvm = c "QR.ll" [ livescript ] ''
          lsc ${lazyk-to-livescript} > $out
        '';

        llvm-to-lolcode = c "QR.lol" [ llvmPackages_20.libllvm ] ''
          cp ${livescript-to-llvm} QR.ll
          llvm-as QR.ll
          lli QR.bc > $out
        '';

        lolcode-to-lua = c "QR.lua" [ lolcode ] ''
          lolcode-lci ${llvm-to-lolcode} > $out
        '';

        lua-to-m4 = c "QR.m4" [ lua ] ''
          lua ${lolcode-to-lua} > $out
        '';

        m4-to-make = c "QR.mk" [ gnum4 ] ''
          m4 ${lua-to-m4} > $out
        '';

        make-to-minizinc = c "QR.mzn" [ gnumake ] ''
          make -f ${m4-to-make} > $out
        '';

        minizinc-to-modula2 = c "QR.mod" [ minizinc ] ''
          minizinc --solver COIN-BC --soln-sep "" ${make-to-minizinc} > $out
        '';

        modula2-to-msil = c "QR.il" [ gcc extendedGcc ] ''
          cp ${minizinc-to-modula2} QR.mod
          gm2 -fiso QR.mod -o QR -B ${gcc.libc_lib}/lib
          ./QR > $out
        '';

        msil-to-mustache = c "QR.mustache" [ mono ] ''
          cp ${modula2-to-msil} QR.il
          ilasm QR.il
          mono QR.exe > $out
        '';

        mustache-to-nasm = c "QR.asm" [ mustache-go ] ''
          mustache ${msil-to-mustache} ${msil-to-mustache} > $out
        '';

        nasm-to-neko = c "QR.neko" [ gcc nasm ] ''
          nasm -felf ${mustache-to-nasm} -o QR.o
          ld -m elf_i386 -o QR QR.o
          ./QR > $out
        '';

        neko-to-nickle = c "QR.5c" [ neko ] ''
          cp ${nasm-to-neko} QR.neko
          nekoc QR.neko
          neko QR.n > $out
        '';

        nickle-to-nim = c "QR.nim" [ nickle ] ''
          nickle ${neko-to-nickle} > $out
        '';

        nim-to-objc = c "QR.m" [ writableTmpDirAsHomeHook nim ] ''
          cp ${nickle-to-nim} QR.nim
          nim compile QR.nim
          ./QR > $out
        '';

        objc-to-ocaml = c "QR.ml" [ (wrapCC extendedGcc) ] ''
          gcc -o QR ${nim-to-objc}
          ./QR > $out
        '';

        ocaml-to-octave = c "QR.octave" [ ocaml ] ''
          ocaml ${objc-to-ocaml} > $out
        '';
      };
    in
    {
      packages = {
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
