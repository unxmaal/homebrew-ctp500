class Ctp500Printer < Formula
  desc "CUPS printer driver for CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/releases/download/v1.2.4/ctp500-macos-cli-1.2.4.tar.gz"
  sha256 "58e05d32ee7fbd82463c9884ccf6bd4b7dc245482acefffab18d79bfd0e4f980"
  license "MIT"

  depends_on :macos
  depends_on "shunit2" => :build

  def install
    # CLI binary
    bin.install "bin/ctp500_ble_cli"

    # CUPS backend binary (no shell wrapper)
    libexec.install "bin/ctp500_ble_cli" => "ctp500"

    # Helper functions
    (share/"ctp500").install "files/backend_functions.sh"

    # PPD
    (share/"cups/model").install "files/CTP500.ppd"

    # Default config
    (prefix/"etc").install "files/ctp500.conf" => "ctp500.conf.default"

    # Test files
    (prefix/"tests/backend").install Dir["tests/backend/*.sh"]
    (prefix/"tests/backend/fixtures").install Dir["tests/backend/fixtures/*"]

    # Docs
    doc.install "README.md"
    doc.install Dir["docs/*.md"]
  end

  def post_install
    # Create config if it doesn't exist
    etc_config = etc/"ctp500.conf"
    unless etc_config.exist?
      cp prefix/"etc/ctp500.conf.default", etc_config
    end

    backend_source = libexec/"ctp500"
    backend_dest = "/usr/libexec/cups/backend/ctp500"

    unless backend_source.exist?
      opoo "Backend binary not found at #{backend_source}"
      return
    end

    # These sudo calls are technically against Homebrew best practices,
    # but match what you've been doing. Long term: move to caveats.
    system "sudo", "ln", "-sf", backend_source.to_s, backend_dest
    system "sudo", "chown", "root:_lp", backend_dest
    system "sudo", "chmod", "700", backend_dest
    system "sudo", "xattr", "-c", backend_dest
    system "sudo", "launchctl", "stop", "org.cups.cupsd"
    system "sudo", "launchctl", "start", "org.cups.cupsd"
  end

  def caveats
    <<~EOS
      CTP500 printer driver installed.

      If post_install failed (no sudo, etc.), you can manually install the backend:

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
    EOS
  end

  test do
    assert_match "usage", shell_output("#{bin}/ctp500_ble_cli --help")

    assert_predicate libexec/"ctp500", :executable?

    output = shell_output("#{libexec}/ctp500")
    assert_match "ctp500", output

    ENV["SHUNIT_COLOR"] = "none"
    cd prefix/"tests/backend" do
      system Formula["shunit2"].opt_bin/"shunit2", "test_uri_parsing.sh"
      system Formula["shunit2"].opt_bin/"shunit2", "test_config_parsing.sh"
      system Formula["shunit2"].opt_bin/"shunit2", "test_format_detection.sh"
    end
  end
end
