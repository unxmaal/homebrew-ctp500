class Ctp500Printer < Formula
  desc "CUPS printer driver for CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/releases/download/v1.2.1/ctp500-macos-cli-1.2.1.tar.gz"
  sha256 "1194590f36d9aeda04d41a0f12222b4f6a63f886c3b83baf0fb0ac3e652b562a"
  license "MIT"

  depends_on :macos
  depends_on "shunit2" => :build  # For running tests during install

  def install
    # Install pre-built binary as CLI tool
    bin.install "bin/ctp500_ble_cli"

    # Install binary as CUPS backend (NO shell wrapper - binary is the backend)
    libexec.install "bin/ctp500_ble_cli" => "ctp500"

    # Install helper functions
    (share/"ctp500").install "files/backend_functions.sh"

    # Install PPD file
    (share/"cups/model").install "files/CTP500.ppd"

    # Install default config
    (prefix/"etc").install "files/ctp500.conf" => "ctp500.conf.default"

    # Install test files (for brew test)
    (prefix/"tests/backend").install Dir["tests/backend/*.sh"]
    (prefix/"tests/backend/fixtures").install Dir["tests/backend/fixtures/*"]

    # Install documentation
    doc.install "README.md"
    doc.install Dir["docs/*.md"]
  end

  def post_install
    # Create config if it doesn't exist
    etc_config = etc/"ctp500.conf"
    unless etc_config.exist?
      cp prefix/"etc/ctp500.conf.default", etc_config
    end

    # MANDATORY: Install CUPS backend with correct permissions
    backend_source = libexec/"ctp500"
    backend_dest = "/usr/libexec/cups/backend/ctp500"

    unless backend_source.exist?
      opoo "Backend binary not found at #{backend_source}"
      return
    end

    # Create symlink to backend
    system "sudo", "ln", "-sf", backend_source.to_s, backend_dest

    # Set correct ownership and permissions (CRITICAL for CUPS)
    # IMPORTANT: Must be root:_lp (the CUPS backend user), NOT root:wheel
    # Use 700 permissions (safer for SIP/CUPS sandbox)
    system "sudo", "chown", "root:_lp", backend_dest
    system "sudo", "chmod", "700", backend_dest

    # Remove extended attributes that block CUPS execution
    system "sudo", "xattr", "-c", backend_dest

    # Reload CUPS daemon to recognize new backend
    system "sudo", "launchctl", "stop", "org.cups.cupsd"
    system "sudo", "launchctl", "start", "org.cups.cupsd"

    puts "✔ CUPS backend installed to #{backend_dest}"
    puts "✔ Ownership: root:_lp, Permissions: 700"
    puts "✔ Extended attributes removed"
    puts "✔ CUPS daemon restarted"
  end

  def caveats
    <<~EOS
      CTP500 printer driver installed successfully!

      Setup Instructions:
      ===================

      IMPORTANT: First, enable the CUPS backend (requires sudo):

      sudo ln -sf #{libexec}/ctp500 /usr/libexec/cups/backend/ctp500
      sudo chown root:wheel /usr/libexec/cups/backend/ctp500
      sudo chmod 755 /usr/libexec/cups/backend/ctp500
      sudo launchctl stop org.cups.cupsd
      sudo launchctl start org.cups.cupsd

      Then configure your printer:

      1. Turn on your CTP500 printer's Bluetooth

      2. Find your printer's BLE address:
         #{bin}/ctp500_ble_cli scan

      3. Add the printer to CUPS (replace BLE-ADDRESS with your printer's address):
         lpadmin -p CTP500 \\
           -E \\
           -v ctp500://BLE-ADDRESS \\
           -P #{share}/cups/model/CTP500.ppd \\
           -D "CTP500 Thermal Printer" \\
           -L "Local"

         Example BLE addresses:
         - UUID format: ctp500://D210000E-A47D-2971-6819-A5F4389E7B86
         - MAC format:  ctp500://AA:BB:CC:DD:EE:FF

      4. Set as default printer (optional):
         lpadmin -d CTP500

      5. Test printing:
         echo "Hello, World!" | lp -d CTP500
         lp -d CTP500 /path/to/image.png

      Configuration:
      ==============
      - Config file: #{etc}/ctp500.conf
      - PPD file: #{share}/cups/model/CTP500.ppd
      - Backend: /usr/libexec/cups/backend/ctp500

      Advanced Usage:
      ===============
      The CLI tool can also be used standalone:

      # Print text
      #{bin}/ctp500_ble_cli text \\
        --address BLE-ADDRESS \\
        --text "Hello, World!"

      # Print image
      #{bin}/ctp500_ble_cli image \\
        --address BLE-ADDRESS \\
        --file /path/to/image.png

      # Check printer status
      #{bin}/ctp500_ble_cli status --address BLE-ADDRESS

      Note: This package uses a PyInstaller binary with deep code signing
      and Bluetooth entitlements for CUPS daemon compatibility.

      Troubleshooting:
      ================
      - Check logs: tail -f /var/log/cups/error_log
      - Verify backend: ls -l /usr/libexec/cups/backend/ctp500
      - Test backend: DEVICE_URI=ctp500://YOUR-ADDRESS #{libexec}/ctp500 1 user test 1 "" /path/to/file

      For more information, visit: #{homepage}
    EOS
  end

  test do
    # Test that the binary exists and runs
    assert_match "usage:", shell_output("#{bin}/ctp500_ble_cli --help")

    # Test that backend script exists and is executable
    assert_predicate libexec/"ctp500", :executable?

    # Test backend discovery mode
    output = shell_output("#{libexec}/ctp500")
    assert_match "ctp500", output

    # Run unit tests for backend functions
    ENV["SHUNIT_COLOR"] = "none"
    cd prefix/"tests/backend" do
      system "/opt/homebrew/bin/shunit2", "test_uri_parsing.sh"
      system "/opt/homebrew/bin/shunit2", "test_config_parsing.sh"
      system "/opt/homebrew/bin/shunit2", "test_format_detection.sh"
    end
  end
end
