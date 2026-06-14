# Nutorch Homebrew formula (issue 0011). This is the source of truth; the
# published copy lives in the tap repo (nutorch/homebrew-nutorch) with a
# bottle block appended at release time. The url points at the immutable
# source-tarball asset on the GitHub Release (scripts/make-source-tarball.sh
# builds it from the tag) — never at GitHub's regenerable /archive/ tarballs.
class Nutorch < Formula
  desc "GPU tensor daemon and CLI for any shell (Apple-silicon MPS, PyTorch-powered)"
  homepage "https://github.com/nutorch/nutorch"
  url "https://github.com/nutorch/nutorch/releases/download/v1.0.0/nutorch-1.0.0.tar.gz"
  sha256 "3619bc009757ba89ac79f142ba14583281959d494aa366cc08a094905855483f"
  license "MIT"

  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on :macos

  # libtorch comes from the official PyTorch wheel on PyPI — immutable,
  # hash-pinned, version-locked to tch 0.24.0's required 2.11.0. Any one
  # arm64 wheel works: build and runtime both use this same staged wheel,
  # and the Python-specific dylib is dropped below.
  resource "libtorch" do
    url "https://files.pythonhosted.org/packages/ac/f2/c1690994afe461aae2d0cac62251e6802a703dec0a6c549c02ecd0de92a9/torch-2.11.0-cp310-cp310-macosx_11_0_arm64.whl",
        using: :nounzip
    sha256 "2c0d7fcfbc0c4e8bb5ebc3907cbc0c6a0da1b8f82b1fc6e14e914fa0b9baf74e"
  end

  def install
    # Stage the whole wheel: torch-sys needs include/ AND lib/ at build
    # time. The repo's .cargo/config.toml force-pins LIBTORCH=.libtorch
    # (relative), so a symlink at the buildpath root makes the pinned
    # build work under brew unchanged — the bootstrap.sh trick, sans venv.
    wheel_stage = buildpath/"libtorch-wheel"
    resource("libtorch").stage do
      system "unzip", "-q", Dir["*.whl"].first, "-d", wheel_stage
    end
    ln_s wheel_stage/"torch", buildpath/".libtorch"

    system "cargo", "build", "--release"

    bin.install "target/release/torch", "target/release/nutorchd"
    bin.install_symlink "torch" => "nutorch"
    # The measured dylib closure (issue 0011 exp 1; mirrors
    # scripts/install.sh): libtorch/libtorch_cpu/libc10 are direct @rpath
    # links; libomp is REQUIRED transitively via libtorch_cpu.
    %w[libtorch.dylib libtorch_cpu.dylib libc10.dylib libomp.dylib].each do |dylib|
      (libexec/"libtorch/lib").install wheel_stage/"torch/lib/#{dylib}"
    end
    pkgshare.install "nutorch.nu"
    # Zero-config Nushell: nu sources every .nu file in its vendor
    # autoload dirs, and brew-built nu pins that list to HOMEBREW_PREFIX.
    # The opt path stays valid across upgrades.
    (share/"nushell/vendor/autoload/nutorch.nu").write <<~EOS
      use "#{opt_pkgshare}/nutorch.nu" *
    EOS
  end

  test do
    # GPU-free by design: --version short-circuits before the MPS gate.
    assert_match "nutorch #{version}", shell_output("#{bin}/torch --version")
    assert_match "nutorch #{version}", shell_output("#{bin}/nutorchd --version")
    assert_match "nutorch #{version}", shell_output("#{bin}/nutorch --version")
    ops = JSON.parse(shell_output("#{bin}/torch ops --json"))
    assert ops.length > 100, "op table suspiciously small"
    assert_path_exists share/"nushell/vendor/autoload/nutorch.nu"
  end
end
