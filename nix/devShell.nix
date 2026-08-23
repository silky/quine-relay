{ inputs, self, ... }: {
  perSystem = { pkgs, config, system, compiler, ... }:
    let
      ourRuby = pkgs.ruby_4_0.withPackages (ps: with ps; [
        rake
        cairo
        gdk_pixbuf2
        irb
      ]);

      chunky_png = pkgs.buildRubyGem rec {
        name = "${gemName}-${version}";
        gemName = "chunky_png";
        version = "1.4.0";
        propagatedBuildInputs = with pkgs.rubyPackages_4_0; [
          rake
          rspec
          standard
          yard
        ];
        source.sha256 = "sha256-idWzG1XAz02jz4mitOvDF42Kvoy68Rah26lWaFAv3P4=";
      };

      rsvg2 = pkgs.buildRubyGem rec {
        name = "${gemName}-${version}";
        gemName = "rsvg2";
        version = "4.3.4";
        nativeBuildInputs = with pkgs; [
          librsvg
          pkg-config
        ];
        propagatedBuildInputs = with pkgs.rubyPackages_4_0; [
          rake
          gdk_pixbuf2
          cairo-gobject
        ];
        source.sha256 = "sha256-U1rD8UFz/bCOStozKGnykt9yVBkkJDbu2l3kavd7xFM=";
      };
    in
    {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          ourRuby
            rsvg2
            chunky_png

          advancecomp
          optipng
          wabt
        ];

        SKIP_FONT_CHECK = 1;
      };
    };
}
