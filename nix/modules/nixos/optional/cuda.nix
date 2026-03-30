# System-level CUDA toolkit and libraries
#
# Provides CUDA development tools and runtime libraries system-wide.
# This does NOT set nixpkgs.config.cudaSupport = true globally, which would
# force a rebuild of every package that checks that flag (PyTorch, JAX, etc.).
# Instead, per-package CUDA overrides should be applied in user environments
# or dev shells where needed.
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # -- Core toolkit --
    # The full CUDA toolkit (nvcc, nvprof, cuda-gdb, etc.)
    cudaPackages.cudatoolkit

    # CUDA runtime API library
    cudaPackages.cuda_cudart

    # NVIDIA CUDA Compiler (standalone, for use outside the toolkit tree)
    cudaPackages.cuda_nvcc

    # CUDA runtime compilation library (JIT kernel compilation)
    cudaPackages.cuda_nvrtc

    # -- Deep learning libraries --
    # cuDNN -- GPU-accelerated primitives for deep neural networks
    cudaPackages.cudnn

    # NCCL -- multi-GPU and multi-node collective communication
    cudaPackages.nccl

    # cuTENSOR -- GPU-accelerated tensor linear algebra
    cudaPackages.cutensor

    # -- Math libraries --
    # cuBLAS -- GPU-accelerated BLAS (matrix multiply, etc.)
    cudaPackages.libcublas

    # cuSPARSE -- GPU-accelerated sparse matrix operations
    cudaPackages.libcusparse

    # cuRAND -- GPU-accelerated random number generation
    cudaPackages.libcurand

    # cuFFT -- GPU-accelerated Fast Fourier Transform
    cudaPackages.libcufft

    # cuSOLVER -- GPU-accelerated dense and sparse direct solvers
    cudaPackages.libcusolver

    # nvJitLink -- runtime linker for CUDA device code
    cudaPackages.libnvjitlink

    # -- Monitoring --
    # nvtop -- GPU process monitor (supports NVIDIA, AMD, Intel)
    nvtopPackages.full
  ];

  # Set environment variables so build tools and libraries can find CUDA.
  environment.variables = {
    # Standard path that CMake, setuptools, and other build systems look for
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";

    # Extra linker flags -- some packages need an explicit -L path to find
    # CUDA runtime stubs (libcuda.so) and driver libraries.
    EXTRA_LDFLAGS = "-L/lib -L${pkgs.cudaPackages.cudatoolkit}/lib";
  };
}
