class Ctp500Printer < Formula
  desc "CUPS driver + CLI for CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/releases/download/v1.2.3/ctp500-macos-cli-1.2.3.tar.gz"
  sha256 "6626b47c1161f0d951ba9602be6cc18bf51c8dd7e979d39882159e7763cca8c4"
  license "MIT"

  depends_on :macos
  depends_on "shunit2" => :build

  def install
    # Install CLI
    bin.install "bin/ctp500_ble_cli"

    # Install backend binary (renamed to ctp500 for CUPS)
    libexec.install "bin/ctp500_ble_cli" => "ctp500"

    # Install helper scripts + PPD
    (share/"ctp500").install "files/backend_functions.sh"
    (share/"cups/model").install "files/CTP500.ppd"

    # Config
    (etc/"ctp500.conf.default").install "files/ctp500.conf"

    # Tests & docs
    (pkgshare/"tests/backend").install Dir["tests/backend/*.sh"]
    (pkgshare/"tests/backend/fixtures").install Dir["tests/backend/fixtures/*"]
    doc.install "README.md"
    doc.install Dir["docs/*.md"]
  end

  def post_install
    # Install default config if missing
    config = etc/"ctp500.conf"
    cp etc/"ctp500.conf.default", config unless config.exist?

    backend_src = libexec/"ctp500"
    backend_dst = "/usr/libexec/cups/backend/ctp500"

    unless backend_src.exist?
      opoo "Backend not found at #{backend_src}"
      return
    end

    # Install backend where CUPS can execute it
    system "sudo", "ln", "-sf", backend_src.to_s, backend_dst

    # Correct CUPS backend ownership/permissions
    system "sudo", "chown", "root:_lp", backend_dst
    system "sudo", "chmod", "700", backend_dst
    system "sudo", "xattr", "-c", backend_dst

    # Restart daemon
    system "sudo", "launchctl", "kickstart", "-k", "system/org.cups.cupsd"

    puts "✓ Installed CUPS backend → #{backend_dst}"
    puts "✓ Permissions root:_lp 700"
  end

  def caveats
    <<~EOS
      The CTP500 CUPS backend has been installed.

      The backend has already been linked and permissions applied.

      To add the printer:

        lpadmin -p CTP500 \\
          -E \\
          -v ctp500://YOUR-BLE-ADDRESS \\
          -P #{share}/cups/model/CTP500.ppd

      Example BLE address:
        ctp500://D210000E-A47D-2971-6819-A5F4189E7B86

      Test:
        echo "Hello" | lp -d CTP500

      Logs:
        tail -f /var/log/cups/error_log

      Backend:
        /usr/libexec/cups/backend/ctp500
    EOS
  end

  test do
    assert_match "usage", shell_output("#{bin}/ctp500_ble_cli --help")
    assert_predicate libexec/"ctp500", :executable?

    ENV["SHUNIT_COLOR"] = "none"
    cp_r pkgshare/"tests", testpath/"tests"
    system "shunit2", "tests/backend/test_uri_parsing.sh"
  end
end
