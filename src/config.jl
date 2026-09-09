using StaticArrays
using GLMakie

include("structs.jl")


function generate_rays(;
    n_rays=10_000,
    half_cone_angle=π / 6, # 30-degree spread around central axis
    light_source=SVector(0.0, 0.0, 5.0)
)
    rays = Vector{Ray}(undef, n_rays)
    golden_ratio = (1 + sqrt(5)) / 2

    cos_theta_max = cos(half_cone_angle)

    for i in 1:n_rays
        # Uniform area distribution over the cone cap
        cos_theta = 1.0 - (i - 0.5) / n_rays * (1.0 - cos_theta_max)
        sin_theta = sqrt(1.0 - cos_theta^2)

        # Full 360-degree azimuthal sweep
        phi = 2 * π * i / golden_ratio

        # Direction pointing DOWN along -Z towards (0, 0, 0)
        dir = SVector(
            sin_theta * cos(phi),
            sin_theta * sin(phi),
            -cos_theta  # Negative Z ensures it goes downwards
        )

        rays[i] = Ray(light_source, dir)
    end

    return rays
end

sphere_obj = OpticalSphere(Point3f(0, 0, 2), 2.0f0, 1.5)

LIGHT_SOURCE = SVector(0.0, 0.0, 5.0)

ray_length = 8.0
