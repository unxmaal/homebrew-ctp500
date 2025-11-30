class Ctp500Printer < Formula
  desc "CUPS backend for the CTP500 BLE thermal receipt printer"
  homepage "https://github.com/unxmaal/ctp500-macos-cli"
  url "https://github.com/unxmaal/ctp500-macos-cli/releases/download/v1.4.4/ctp500-macos-cli-1.4.4.tar.gz"
  sha256 "762b42a7a445894a9fd792122630bd853b1528a04940ea969f62a0a446107fbc"
  license "MIT"

  depends_on :macos
  depends_on "python@3.11"

  def install
    # Install Python dependencies
    ENV.prepend_create_path "PYTHONPATH", lib/"python3.11/site-packages"
    system "python3.11", "-m", "pip", "install",
           "--target=#{lib}/python3.11/site-packages",
           "bleak>=0.21.0", "pillow>=10.0.0"

    # Install support files
    (share/"cups/model").install "files/CTP500.ppd"
    (etc/"ctp500").install "files/ctp500.conf"

    #
    # *** CRITICAL CHANGE ***
    # Re-emit backend script LOCALLY during install.
    #
    backend = libexec/"ctp500"
    backend.write <<~EOS
      #!/usr/bin/env python3.11
      import sys
      from pathlib import Path

      sys.path.insert(0, "#{lib}/python3.11/site-packages")
      from ctp500_backend import main

      if __name__ == "__main__":
          main()
    EOS

    chmod 0755, backend
  end

  def caveats
    <<~EOS
      Install the backend into CUPS:

        sudo cp #{opt_libexec}/ctp500 /usr/libexec/cups/backend/ctp500
        sudo chown root:_lp /usr/libexec/cups/backend/ctp500
        sudo chmod 755 /usr/libexec/cups/backend/ctp500
        sudo launchctl kickstart -k system/org.cups.cupsd

      No provenance remains, because backend was built locally.
    EOS
  end

  test do
    assert_predicate libexec/"ctp500", :exist?
  end
end
