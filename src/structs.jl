using StaticArrays
using GLMakie


struct Ray
    origin::SVector{3,Float64}
    direction::SVector{3,Float64}
end


struct OpticalSphere
    center::Point3f
    radius::Float64
    IOR::Float64
end

