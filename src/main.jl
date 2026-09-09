using LinearAlgebra
using StaticArrays
using GLMakie

include("gui.jl")
include("config.jl")
include("structs.jl")

rays = generate_rays()

flattened_rays = flattenRays(rays)

drawScene(flattened_rays)

