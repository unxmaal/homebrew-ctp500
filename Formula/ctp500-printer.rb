class Ctp500Printer < Formula
  desc "CUPS backend for the CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/archive/refs/tags/v1.4.1.tar.gz"
  sha256 "6c36a04bc21be2add1f0e76a2cb870589fb49a073390e0999d7fbf97ad00341b"
  license "MIT"

  depends_on :macos
  depends_on "python@3.11"

  def install
    # Install Python dependencies to lib/python3.11/site-packages
    ENV.prepend_create_path "PYTHONPATH", lib/"python3.11/site-packages"
    system "python3.11", "-m", "pip", "install", "--target=#{lib}/python3.11/site-packages",
           "bleak>=0.21.0", "pillow>=10.0.0"

    # Install support files
    (share/"cups/model").install "files/CTP500.ppd"
    (etc/"ctp500").install "files/ctp500.conf"

    # Install Python backend script
    (libexec).install "files/ctp500.py" => "ctp500"
    chmod 0755, libexec/"ctp500"
  end

  def caveats
    <<~EOS
      CUPS backend setup
      ==================

      To enable the CTP500 backend for CUPS (copy, not symlink, due to AMFI):

        sudo cp #{opt_prefix}/libexec/ctp500 /usr/libexec/cups/backend/ctp500
        sudo chown root:_lp /usr/libexec/cups/backend/ctp500
        sudo chmod 755 /usr/libexec/cups/backend/ctp500
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

      If CUPS jobs fail:
        - Check the CUPS log:  tail -f /var/log/cups/error_log
        - Test the backend directly:
            DEVICE_URI=ctp500://BLE-ADDRESS \\
              #{opt_prefix}/libexec/ctp500 1 user test 1 "" /path/to/file
    EOS
  end

  test do
    # Backend script is present in libexec
    assert_predicate libexec/"ctp500", :exist?

    # Backend responds to discovery mode
    assert_match "ctp500", shell_output("#{libexec}/ctp500")
  end
end
