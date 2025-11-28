class Ctp500Printer < Formula
  desc "CUPS backend + CLI for the CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/releases/download/v1.2.6/ctp500-macos-cli-1.2.6.tar.gz"
  sha256 "bf5a268fe721f0f82939134bea01a7ff2cef3dd9572926a66588110611d35d1e"
  license "MIT"

  # No sudo installs, no post_install CUPS manipulation.
  # Formulae may *not* require system modification outside the prefix.

  def install
    # CLI binary
    bin.install "bin/ctp500_ble_cli"

    # Backend binary
    libexec.install "bin/ctp500_ble_cli" => "ctp500"

    # Support files
    (share/"ctp500").install "files/backend_functions.sh"
    (share/"cups/model").install "files/CTP500.ppd"

    # Default config (NOT /etc directly)
    (etc/"ctp500").install "files/ctp500.conf"
  end

  def caveats
    <<~EOS
      Manual CUPS Backend Installation Required
      ========================================

      Homebrew cannot install files into /usr/libexec/cups/backend
      automatically. You must install the backend manually:

        sudo ln -sf #{opt_libexec}/ctp500 /usr/libexec/cups/backend/ctp500
        sudo chown root:_lp /usr/libexec/cups/backend/ctp500
        sudo chmod 700 /usr/libexec/cups/backend/ctp500
        sudo xattr -c /usr/libexec/cups/backend/ctp500
        sudo launchctl kickstart -k system/org.cups.cupsd

      Add the printer:

        lpadmin -p CTP500 -E \\
          -v ctp500://BLE-ADDRESS \\
          -P #{HOMEBREW_PREFIX}/share/cups/model/CTP500.ppd

      Configuration:
        #{etc}/ctp500/ctp500.conf

      CLI Usage:
        ctp500_ble_cli scan
        ctp500_ble_cli text --address BLE-ADDRESS --text "hello"
    EOS
  end

  test do
    # Basic run check
    assert_match "usage", shell_output("#{bin}/ctp500_ble_cli --help")

    # Backend exists in libexec
    assert_predicate libexec/"ctp500", :exist?
  end
end
