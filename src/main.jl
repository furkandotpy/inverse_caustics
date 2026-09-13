using LinearAlgebra
using StaticArrays
using GLMakie

include("gui.jl")
include("config.jl")
include("structs.jl")
include("raymarching.jl")

rays = generate_rays()

flattened_rays = flattenRays(rays)

hit_points = collect_intersections(rays, sphere_obj)
drawScene(flattened_rays, hit_points)
