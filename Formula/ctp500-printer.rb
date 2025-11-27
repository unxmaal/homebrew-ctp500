class Ctp500Printer < Formula
  desc "CUPS printer driver for CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/releases/download/v1.2.5/ctp500-macos-cli-1.2.5.tar.gz"
  sha256 "cd56d760254db0bcada3ee906d576bdbfabf268820efa63cfa446d0001bc2137"
  license "MIT"

  depends_on :macos
  depends_on "shunit2" => :test

  def install
    # CLI binary
    bin.install "bin/ctp500_ble_cli"

    # CUPS backend binary - install to libexec for manual linking
    libexec.install "bin/ctp500_ble_cli" => "ctp500"

    # Helper functions
    (share/"ctp500").install "files/backend_functions.sh"

    # PPD file
    (share/"cups/model").install "files/CTP500.ppd"

    # Default config
    (etc/"ctp500.conf.default").write (buildpath/"files/ctp500.conf").read

    # Docs
    doc.install "README.md"
    doc.install Dir["docs/*.md"]
  end

  def post_install
    # Create user config if it doesn't exist (within Homebrew-managed etc)
    config_file = etc/"ctp500.conf"
    default_config = etc/"ctp500.conf.default"
    
    unless config_file.exist?
      config_file.write default_config.read if default_config.exist?
    end
  end

  def caveats
    <<~EOS
      To complete installation, you must manually install the CUPS backend.
      
      Run the following commands:

        sudo ln -sf #{libexec}/ctp500 /usr/libexec/cups/backend/ctp500
        sudo chown root:_lp /usr/libexec/cups/backend/ctp500
        sudo chmod 700 /usr/libexec/cups/backend/ctp500
        sudo xattr -c /usr/libexec/cups/backend/ctp500
        sudo launchctl stop org.cups.cupsd
        sudo launchctl start org.cups.cupsd

      Then add your printer:

        #{bin}/ctp500_ble_cli scan   # find BLE address

        lpadmin -p CTP500 \\
          -E \\
          -v ctp500://BLE-ADDRESS \\
          -P #{share}/cups/model/CTP500.ppd \\
          -D "CTP500 Thermal Printer" \\
          -L "Local"

      Configuration file location: #{etc}/ctp500.conf
    EOS
  end

  test do
    # Test CLI help
    assert_match "usage", shell_output("#{bin}/ctp500_ble_cli --help", 0)

    # Test backend binary exists and is executable
    assert_predicate libexec/"ctp500", :executable?

    # Test backend outputs expected content (adjust expected exit code if needed)
    output = shell_output("#{libexec}/ctp500 2>&1", 1)
    assert_match "ctp500", output

    # Run unit tests
    ENV["SHUNIT_COLOR"] = "none"
    
    # Copy test files to testpath since we can't modify prefix
    cp_r prefix/"tests/backend", testpath
    
    cd testpath/"backend" do
      system Formula["shunit2"].opt_bin/"shunit2", "test_uri_parsing.sh"
      system Formula["shunit2"].opt_bin/"shunit2", "test_config_parsing.sh"
      system Formula["shunit2"].opt_bin/"shunit2", "test_format_detection.sh"
    end
  end
end