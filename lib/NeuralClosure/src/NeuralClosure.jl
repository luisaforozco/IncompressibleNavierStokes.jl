"""
Neural closure modelling tools.
"""
module NeuralClosure

using ComponentArrays: ComponentArray
using IncompressibleNavierStokes
using IncompressibleNavierStokes: Dimension, momentum!, apply_bc_u!, project!
using KernelAbstractions
using Lux
using NNlib
using Observables
using Random
using Tullio
using Zygote

# Must be loaded inside for Tullio to work correctly
using CUDA

include("closure.jl")
include("cnn.jl")
include("fno.jl")
include("training.jl")
include("filter.jl")
include("create_les_data.jl")

export smagorinsky_closure
export cnn, fno, FourierLayer
export train
export mean_squared_error, create_relerr_prior, create_relerr_post
export create_loss_prior, create_loss_post
export create_dataloader_prior, create_dataloader_post
export create_callback, create_les_data, create_io_arrays
export wrappedclosure
export FaceAverage, VolumeAverage, reconstruct, reconstruct!

end