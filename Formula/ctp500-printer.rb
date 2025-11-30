class Ctp500Printer < Formula
  desc "CUPS backend for the CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/archive/refs/tags/v1.4.2.tar.gz"
  sha256 "5ea2a6c8206e634420a19263edf4326ef15f93e1e83aa86032ed12001c62de58"
  license "MIT"

  depends_on :macos
  depends_on "python@3.11"

  def install
    # Install Python deps into keg-local site-packages
    ENV.prepend_create_path "PYTHONPATH", lib/"python3.11/site-packages"
    system "python3.11", "-m", "pip", "install",
           "--target=#{lib}/python3.11/site-packages",
           "bleak>=0.21.0", "pillow>=10.0.0"

    # Install backend script
    libexec.install "files/ctp500.py" => "ctp500"
    chmod 0755, libexec/"ctp500"

    # Install PPD + config
    (share/"cups/model").install "files/CTP500.ppd"
    (etc/"ctp500").install "files/ctp500.conf"
  end

  def caveats
    <<~EOS
      CUPS backend setup
      ==================

      Homebrew cannot install into /usr/libexec/cups/backend automatically.

      Install backend manually (must be a real file, not a symlink):

        sudo cp #{opt_libexec}/ctp500 /usr/libexec/cups/backend/ctp500
        sudo chown root:_lp /usr/libexec/cups/backend/ctp500
        sudo chmod 755 /usr/libexec/cups/backend/ctp500
        sudo xattr -c /usr/libexec/cups/backend/ctp500
        sudo launchctl kickstart -k system/org.cups.cupsd

      Add the printer:

        lpadmin -p CTP500 -E \\
          -v ctp500://BLE-ADDRESS \\
          -P #{HOMEBREW_PREFIX}/share/cups/model/CTP500.ppd

      Config file:
        #{etc}/ctp500/ctp500.conf

      Backend test:
        DEVICE_URI=ctp500://BLE-ADDRESS \\
          #{opt_libexec}/ctp500 1 user test 1 "" /path/to/file
    EOS
  end

  test do
    assert_predicate libexec/"ctp500", :exist?
    assert_match "ctp500", shell_output("#{libexec}/ctp500")
  end
end

