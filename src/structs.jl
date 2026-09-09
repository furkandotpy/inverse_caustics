struct Ray
    origin::SVector{3,Float64}
    direction::SVector{3,Float64}
end

struct OpticalSphere
    center::Point3f
    radius::Float32
    IOR::Float64
end
