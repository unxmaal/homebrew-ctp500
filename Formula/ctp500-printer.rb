class Ctp500Printer < Formula
  desc "CUPS printer driver for CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/releases/download/v1.0.0/ctp500-macos-cli-1.0.0.tar.gz"
  sha256 "82d23cdaf18d6bbe872128771c3bb2811aeee225569361d03f71733c544ff8b8"
  license "MIT"

  depends_on :macos
  depends_on "shunit2" => :build  # For running tests during install

  def install
    # Install the CLI binary
    bin.install "bin/ctp500_ble_cli"

    # Install backend script to libexec (CUPS backends dir)
    libexec.install "files/ctp500"

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

    # Create symlink in CUPS backend directory
    cups_backend_dir = Pathname.new("/usr/libexec/cups/backend")
    if cups_backend_dir.exist?
      cups_backend = cups_backend_dir/"ctp500"
      unless cups_backend.exist?
        ohai "Creating CUPS backend symlink..."
        system "sudo", "ln", "-sf", libexec/"ctp500", cups_backend
        system "sudo", "chmod", "0755", cups_backend
      end
    else
      opoo "CUPS backend directory not found at #{cups_backend_dir}"
      opoo "You may need to manually create a symlink:"
      puts "  sudo ln -sf #{libexec}/ctp500 /usr/libexec/cups/backend/ctp500"
    end

    # Restart CUPS to pick up new backend
    ohai "Restarting CUPS..."
    system "sudo", "launchctl", "stop", "org.cups.cupsd"
    system "sudo", "launchctl", "start", "org.cups.cupsd"
  end

  def caveats
    <<~EOS
      CTP500 printer driver installed successfully!

      Setup Instructions:
      ===================

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
      The CLI binary can also be used standalone:

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
