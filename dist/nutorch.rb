# Nutorch Homebrew formula (issue 0011). The committed sha256 below is a
# LAST-KNOWN value: a tarball of HEAD contains this file, so a committed
# sha can never match a re-archive of its own commit. For the hermetic
# local test, scripts/make-source-tarball.sh regenerates the tarball and
# patches the fresh sha in-place. Experiment 3 swaps `url` to
# https://github.com/nutorch/nutorch/archive/refs/tags/v0.1.0.tar.gz in
# the tap repo (no self-reference there).
class Nutorch < Formula
  desc "GPU tensor daemon and CLI for any shell (Apple-silicon MPS, PyTorch-powered)"
  homepage "https://github.com/nutorch/nutorch"
  url "file:///tmp/nutorch-src/nutorch-0.1.0.tar.gz"
  version "0.1.0"
  sha256 "063bc16ec5d548c1022f3edec0f524198789d9b2d29ecf4aa1a38f791a28e749"
  license "Apache-2.0"

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
    # The measured dylib closure (issue 0011 exp 1; mirrors
    # scripts/install.sh): libtorch/libtorch_cpu/libc10 are direct @rpath
    # links; libomp is REQUIRED transitively via libtorch_cpu.
    %w[libtorch.dylib libtorch_cpu.dylib libc10.dylib libomp.dylib].each do |dylib|
      (libexec/"libtorch/lib").install wheel_stage/"torch/lib/#{dylib}"
    end
    pkgshare.install "nutorch.nu"
  end

  test do
    # GPU-free by design: --version short-circuits before the MPS gate.
    assert_match "nutorch #{version}", shell_output("#{bin}/torch --version")
    assert_match "nutorch #{version}", shell_output("#{bin}/nutorchd --version")
    ops = JSON.parse(shell_output("#{bin}/torch ops --json"))
    assert ops.length > 100, "op table suspiciously small"
  end
end
