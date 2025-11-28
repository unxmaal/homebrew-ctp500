class Ctp500Printer < Formula
  desc "CUPS backend + CLI for the CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/releases/download/v1.2.9/ctp500-macos-cli-1.2.9.tar.gz"
  sha256 "77aa56de194c420895bfeab5024047e255faa5cccd7c996a855ba478bfe05b21"
  license "MIT"

  depends_on :macos

  def install
    # Clear quarantine attributes
    system "xattr", "-cr", "."

    cd "ctp500-macos-cli-#{version}" do
      bin.install "bin/ctp500_ble_cli"
      libexec.install "bin/ctp500_ble_cli" => "ctp500"
      (share/"ctp500").install "files/backend_functions.sh"
      (share/"cups/model").install "files/CTP500.ppd"
      (etc/"ctp500").install "files/ctp500.conf"
    end
  end

  def caveats
    <<~EOS
      CUPS backend is not auto-installed
      ==================================

      Homebrew is not allowed to modify system locations like:
        /usr/libexec/cups/backend

      To enable the CTP500 backend for CUPS, you must install it manually:

        sudo ln -sf #{opt_prefix}/libexec/ctp500 /usr/libexec/cups/backend/ctp500
        sudo chown root:_lp /usr/libexec/cups/backend/ctp500   # use 'lp' instead of '_lp' if your system does
        sudo chmod 700 /usr/libexec/cups/backend/ctp500
        sudo xattr -c /usr/libexec/cups/backend/ctp500
        sudo launchctl kickstart -k system/org.cups.cupsd

      Add the printer (replace BLE-ADDRESS with your printer's UUID or MAC):

        lpadmin -p CTP500 -E \\
          -v ctp500://BLE-ADDRESS \\
          -P #{HOMEBREW_PREFIX}/share/cups/model/CTP500.ppd

      Example BLE addresses:
        UUID: ctp500://D210000E-A47D-2971-6819-A5F4189E7B86
        MAC:  ctp500://AA:BB:CC:DD:EE:FF

      Configuration file:
        #{etc}/ctp500/ctp500.conf

      CLI usage (works without CUPS):
        #{bin}/ctp500_ble_cli scan
        #{bin}/ctp500_ble_cli text  --address BLE-ADDRESS --text "hello world"
        #{bin}/ctp500_ble_cli image --address BLE-ADDRESS --file /path/to/image.png

      If CUPS jobs fail:
        - Check the CUPS log:  tail -f /var/log/cups/error_log
        - Test the backend directly:
            DEVICE_URI=ctp500://BLE-ADDRESS \\
              #{opt_prefix}/libexec/ctp500 1 user test 1 "" /path/to/file
    EOS
  end

  test do
    # Basic help output check
    assert_match "usage", shell_output("#{bin}/ctp500_ble_cli --help")

    # Backend binary is present in libexec
    assert_predicate libexec/"ctp500", :exist?
  end
end
