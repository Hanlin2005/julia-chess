using Pkg; Pkg.add("Flux", "CUDA", "cuDNN", "ProgressMeter")
using Flux, Statistics, ProgressMeter
device = CUDA.functional() ? gpu : cpu

