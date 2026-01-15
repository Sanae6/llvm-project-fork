with import <nixpkgs> {};

let
  builddir = "build";
  installdir = "install";
  gccForLibs = gcc13;
  stdenv = gcc13Stdenv;
  dynLinker = lib.fileContents "${stdenv.cc}/nix-support/dynamic-linker";
  libcFlags = [
    "-L ${stdenv.cc.libc}/lib"
    "-B ${stdenv.cc.libc}/lib"
    ];

  # The string version of just the gcc flags for NIX_LDFLAGS
  nixLd = lib.concatStringsSep " " [
    "-L ${gccForLibs}/lib"
    "-L ${gccForLibs}/lib/gcc/${targetPlatform.config}/${gccForLibs.version}"
  ];

  gccFlags = [
    "-B ${gccForLibs}/lib/gcc/${targetPlatform.config}/${gccForLibs.version}"
    "${nixLd}"
    ];

  flags = lib.concatStringsSep " " ([
      "-Wno-unused-command-line-argument"
      "-Wl,--dynamic-linker=${dynLinker}"
    ] ++ gccFlags ++ libcFlags);

  # For building clang itself, we're just using the compiler wrapper and we
  # don't need to inject any flags of our own.
  cmakeFlags = [
    "-DGCC_INSTALL_PREFIX=${gcc13}"
    "-DC_INCLUDE_DIRS=${stdenv.cc.libc.dev}/include"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_INSTALL_PREFIX=${installdir}"
    "-DLLVM_INSTALL_TOOLCHAIN_ONLY=ON"
    "-DLLVM_ENABLE_PROJECTS=clang"
    "-DLLVM_TARGETS_TO_BUILD=Colossus"
    "-DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=Colossus"
  ];

  # For configuring a build of LLVM runtimes however, we do need to inject the
  # extra flags.
  cmakeRuntimeFlags = lib.concatStringsSep " " [
    "-DCMAKE_CXX_FLAGS=\"${flags}\""
    "-DLIBCXX_TEST_COMPILER_FLAGS=\"${flags}\""
    "-DLIBCXX_TEST_LINKER_FLAGS=\"${flags}\""
    "-DLLVM_ENABLE_RUNTIMES='libcxx;libcxxabi'"
  ];

  cmakeCmd = lib.concatStringsSep " " [
    "export CC=${stdenv.cc}/bin/gcc; export CXX=${stdenv.cc}/bin/g++;"
    "${cmakeCurses}/bin/cmake -B ${builddir} -S llvm"
    "${lib.concatStringsSep " " cmakeFlags}"
  ];

  cmakeRtCmd = lib.concatStringsSep " " [
    "export CC=${builddir}/bin/clang; export CXX=${builddir}/bin/clang++;"
    "${cmakeCurses}/bin/cmake -B ${builddir}-rt -S runtimes"
    "${cmakeRuntimeFlags}"
  ];

in stdenv.mkDerivation {

  name = "llvm-dev-env";

  buildInputs = [
    bashInteractive
    cmakeCurses
    llvmPackages_latest.llvm
  ];

  # where to find libgcc
  NIX_LDFLAGS = "${nixLd}";

  # teach clang about C startup file locations
  CFLAGS = "${flags}";
  CXXFLAGS = "${flags}";

  inherit cmakeFlags cmakeRuntimeFlags;

  cmake=cmakeCmd;
  cmakeRt=cmakeRtCmd;
}
