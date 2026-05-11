
using Revise, Infiltrator, BenchmarkTools
import HierarchicalRouting as HR
using HierarchicalRouting,
    HierarchicalRouting.DataFrames,
    HierarchicalRouting.GeometryBasics,
    HierarchicalRouting.AG,
    HierarchicalRouting.Plot.Makie
using HierarchicalRouting: Cluster, MothershipSolution, TenderSolution, Plot
HR.Plot.Makie.inline!(true)

target_path = "data/targets/scenarios/output_slopes_3-10m.geojson";
subset_path = "data/site/Moore_2024-02-14b_v060_rc1.gpkg";
bathy_path = "data/env_constraints/bathy/Cairns-Cooktown_bathy.tif";
wave_disturbance_path = "data/env_disturbances/waves/output_slope_zs_Hs_Tp.geojson";

# problem_moore = load_problem(
#     target_path,
#     subset_path,
#     bathy_path,
#     wave_disturbance_path,
#     (146.175, -16.84),
#     -5.0,
#     -2.0,
#     0.2,    # Weighting mothership
#     0.075,  # Weighting tenders
#     3,
#     2;
#     # debug_mode=false
# );

# Systematically vary weights
weights_ms = collect(0.1:0.1:0.5)
weights_t = collect(0.05:0.01:0.1)
len_weights_ms = length(weights_ms)
len_weights_t = length(weights_t)

sols_weighting = Vector{Tuple{HR.Problem,HR.MSTSolution}}(undef, len_weights_ms * len_weights_t)
waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=6)
# titles = Vector{String}(undef, len_weights_ms * len_weights_t)
using Base.Threads

Threads.@threads for idx in 1:(length(sols_weighting))
    i = fld(idx - 1, len_weights_t) + 1
    j = mod(idx - 1, len_weights_t) + 1
    w_ms = weights_ms[i]
    w_t = weights_t[j]
    @info "Solving index $idx with weights (ms: $w_ms, t: $w_t)"

    problem_w_local = load_problem(
        target_path,
        subset_path,
        bathy_path,
        wave_disturbance_path,
        (146.175, -16.84),
        -5.0,
        -2.0,
        w_ms,
        w_t,
        3,
        2
    )
    sol = HR.solve(
        problem_w_local;
        waypoint_optim_method,
        seed=1234,
        wpt_optim_plot_flag=false,
        cross_cluster_flag=false
    )
    sols_weighting[idx] = (problem_w_local, sol)
end

# for (i, w_ms) in enumerate(weights_ms)
#     for (j, w_t) in enumerate(weights_t)
#         @info "Solving with weights (ms: $w_ms, t: $w_t)"
#         problem_w_local = load_problem(
#             target_path,
#             subset_path,
#             bathy_path,
#             wave_disturbance_path,
#             (146.175, -16.84),
#             -5.0,
#             -2.0,
#             w_ms,
#             w_t,
#             3,
#             2;
#         )
#         sols_weighting[((i-1)*len_weights_t)+j] = (
#             HR.solve(
#                 problem_w_local;
#                 waypoint_optim_method,
#                 seed=1234,
#                 wpt_optim_plot_flag=false,
#                 cross_cluster_flag=false
#             ),
#             w_ms,
#             w_t
#         )
#     end
# end


# Plot all solutions
plots_weighting = Vector{HR.Plot.Figure}(undef, length(sols_weighting))
for (i, (prob, sol)) in enumerate(sols_weighting)
    w_ms, w_t = prob.mothership.weighting, prob.tenders.weighting
    title = "Moore Reef Case Study (ms weight=$(w_ms), t weight=$(w_t))"
    plots_weighting[i] =
        HR.Plot.solution(
            prob,
            sol;
            highlight_critical_path_flag=true,
            title=title,
        )
end
plots_weighting .|> display

for ((prob, sol), fig) in zip(sols_weighting, plots_weighting)
    w_ms, w_t = prob.mothership.weighting, prob.tenders.weighting
    save("outputs/sensitivity/weighting/plot_weighting_moore_w_ms_$(w_ms)_w_t_$(w_t).png", fig)
end

# Create summary table of results
cp_mat = Matrix{Float64}(undef, len_weights_ms, len_weights_t)
for (i, w_ms) in enumerate(weights_ms), (j, w_t) in enumerate(weights_t)
    prob, sol = sols_weighting[(i-1)*len_weights_t+j]
    cp_mat[i, j] = HR.critical_path(sol, prob)
end

# ms_vals = collect(getindex.(sols_weighting, 2))
# t_vals = collect(getindex.(sols_weighting, 3))
df_wide = DataFrame([
    :ms => weights_ms;
    (Symbol("t=$(t)") => cp_mat[:, j] for (j, t) in enumerate(weights_t))...
]...)

df_flipped = DataFrame([:t => weights_t;
    (Symbol("ms=$(ms)") => cp_mat[j, :] for (j, ms) in enumerate(weights_ms))...]...)

################################################
# Extreme weightings
weight_ms_extreme = [0.01, 100]
weight_t_extreme = [100, 0.01]

for w_ms in weight_ms_extreme
    for w_t in weight_t_extreme
        @info "Solving with extreme weights (ms: $w_ms, t: $w_t)"
        problem_w_local = load_problem(
            target_path,
            subset_path,
            bathy_path,
            wave_disturbance_path,
            (146.175, -16.84),
            -5.0,
            -2.0,
            w_ms,
            w_t,
            3,
            2;
            # debug_mode=false
        )
        sol_extreme = HR.solve(
            problem_w_local;
            waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=5),
            seed=1234,
            time_limit=100.0,
            do_improve=true,
        )
        fig = HR.Plot.solution(
            problem_w_local,
            sol_extreme;
            highlight_critical_path_flag=true,
            title="Moore Reef Case Study (ms weight=$w_ms, t weight=$w_t)"
        )
        display(fig)
        save("outputs/sensitivity/weighting/extremes/plot_weighting_moore_extreme_w_ms$(w_ms)_w_t$(w_t).png", fig)
    end
end

################################################
target_path_alt = "data/targets/scenarios/subset_b_t.geojson"; #reefguide_output_100x20.geojson";
subset_path_alt = "data/site/batt_tongue.gpkg";
bathy_path = "data/env_constraints/bathy/Cairns-Cooktown_bathy.tif";
wave_disturbance_path_alt = "data/env_disturbances/waves/zonal_Hs_CC_x_reefguide_polys.geojson";

problem_alt = load_problem(
    target_path_alt,
    subset_path_alt,
    bathy_path,
    wave_disturbance_path_alt,
    (145.6, -16.35),
    -5.0,
    -2.0,
    0.2,    # Weighting mothership
    0.075,  # Weighting tenders
    3,
    2;
    # debug_mode=false
);

# Systematically vary weights
weights_ms = collect(0.1:0.1:0.5)
weights_t = collect(0.05:0.01:0.1)
len_weights_t = length(weights_t)
sols_weighting_alt = Vector{Tuple{HR.MSTSolution,Float64,Float64}}(undef, length(weights_ms) * len_weights_t)
waypoint_optim_method_alt = HR.Optim.ParticleSwarm(n_particles=4)

for (i, w_ms) in enumerate(weights_ms)
    for (j, w_t) in enumerate(weights_t)
        @info "Solving with weights (ms: $w_ms, t: $w_t)"
        problem_w_local = load_problem(
            target_path_alt,
            subset_path_alt,
            bathy_path,
            wave_disturbance_path_alt,
            (145.6, -16.35),
            -5.0,
            -2.0,
            w_ms,
            w_t,
            3,
            2;
            # debug_mode=false
        )
        sols_weighting_alt[((i-1)*len_weights_t)+j] = (
            HR.solve(
                problem_w_local;
                waypoint_optim_method=waypoint_optim_method_alt,
                seed=1234,
                time_limit=600.0,
                wpt_optim_plot_flag=true,
                cross_cluster_flag=false
            ),
            w_ms,
            w_t
        )
    end
end

titles_alt = ["Batt & Tongue Reefs Case Study (ms weight=$(w_ms), t weight=$(w_t))" for (_, w_ms, w_t) in sols_weighting_alt]
# Plot all solutions
plots_weighting_alt = Vector{HR.Plot.Figure}(undef, length(sols_weighting_alt))
for (i, ((sol, w_ms, w_t), title)) in enumerate(zip(sols_weighting_alt, titles_alt))
    plots_weighting_alt[i] =
        HR.Plot.solution(
            problem_alt,
            sol;
            highlight_critical_path_flag=true,
            title="$title",
            size=(700, 490)
        ) #|> display
end

for ((_, w_ms, w_t), p) in zip(sols_weighting_alt, plots_weighting_alt)
    save("outputs/sensitivity/weighting/plot_weighting_batt_tongue_w_ms$(w_ms)_w_t$(w_t).png", p)
end

# Create summary table of results
cp_mat = Matrix{Float64}(undef, length(weights_ms), len_weights_t)
for (i, w_ms) in enumerate(weights_ms), (j, w_t) in enumerate(weights_t)
    cp_mat[i, j] = HR.critical_path(sols_weighting_alt[(i-1)*len_weights_t+j][1], (w_ms, w_t))
end

# ms_vals = collect(getindex.(sols_weighting, 2))
# t_vals = collect(getindex.(sols_weighting, 3))
df_wide = DataFrame([
    :ms => weights_ms;
    (Symbol("t=$(t)") => cp_mat[:, j] for (j, t) in enumerate(weights_t))...
]...)

df_flipped = DataFrame([:t => weights_t;
    (Symbol("ms=$(ms)") => cp_mat[j, :] for (j, ms) in enumerate(weights_ms))...]...)

################################################
# Extreme weightings
weight_ms_extreme = [0.01, 100]
weight_t_extreme = [100, 0.01]

for w_ms in weight_ms_extreme
    for w_t in weight_t_extreme
        @info "Solving with extreme weights (ms: $w_ms, t: $w_t)"
        problem_w_local = load_problem(
            target_path,
            subset_path,
            bathy_path,
            wave_disturbance_path,
            (146.175, -16.84),
            -5.0,
            -2.0,
            w_ms,
            w_t,
            3,
            2;
            # debug_mode=false
        )
        sol_extreme = HR.solve(
            problem_w_local;
            waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=5),
            seed=1234,
            time_limit=600.0,
            wpt_optim_plot_flag=true,
            cross_cluster_flag=false
        )
        fig = HR.Plot.solution(
            problem_w_local,
            sol_extreme;
            highlight_critical_path_flag=true,
            title="Moore Reef Case Study (ms weight=$w_ms, t weight=$w_t)"
        )
        display(fig)
        save("outputs/sensitivity/weighting/extremes/plot_weighting_moore_extreme_w_ms$(w_ms)_w_t$(w_t).png", fig)
    end
end



#################################################
# Variance in MS: speed ∝ 1/(no. tenders)
# Slow ms can carry many tenders vs
# Fast ms can carry few tenders


problem_moore = load_problem(
    target_path,
    subset_path,
    bathy_path,
    wave_disturbance_path,
    (146.175, -16.84),
    -5.0,
    -2.0,
    0.2,    # Weighting mothership
    0.075,  # Weighting tenders
    3,
    2;
    # debug_mode=false
);

# Systematically vary MOTHERSHIP weight with NO. TENDERS
weights_ms = collect(0.1:0.1:0.5)
# weights_t = collect(0.05:0.01:0.1)
len_weights_t = length(weights_t)
no_tenders = collect(1:6)
sols_weighting = Vector{Tuple{HR.MSTSolution,Float64,Float64}}(undef, length(weights_ms) * len_weights_t)

# for (i, w_ms) in enumerate(weights_ms)
#     for (j, w_t) in enumerate(weights_t)
#         @info "Solving with weights (ms: $w_ms, t: $w_t)"
#         problem_w_local = load_problem(
#             target_path,
#             subset_path,
#             bathy_path,
#             wave_disturbance_path,
#             (146.175, -16.84),
#             -5.0,
#             -2.0,
#             w_ms,
#             w_t,
#             3,
#             2;
#             # debug_mode=false
#         )
#         sols_weighting[((i-1)*len_weights_t)+j] = (
#             HR.solve(
#                 problem_w_local;
#                 waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=5),
#                 seed=1234,
#                 time_limit=200.0,
#             ),
#             w_ms,
#             w_t
#         )
#     end
# end

# titles = ["Moore Reef Case Study (ms weight=$(w_ms), t weight=$(w_t))" for (_, w_ms, w_t) in sols_weighting]
# # Plot all solutions
# plots_weighting = Vector{HR.Plot.Figure}(undef, length(sols_weighting))
# for (i, ((sol, w_ms, w_t), title)) in enumerate(zip(sols_weighting, titles))
#     plots_weighting[i] =
#         HR.Plot.solution(
#             problem_moore,
#             sol;
#             highlight_critical_path_flag=true,
#             title="$title",
#         ) #|> display
# end

# for ((_, w_ms, w_t), p) in zip(sols_weighting, plots_weighting)
#     save("outputs/sensitivity/weighting/plot_weighting_moore_w_ms$(w_ms)_w_t$(w_t).png", p)
# end

# # Create summary table of results
# cp_mat = Matrix{Float64}(undef, length(weights_ms), len_weights_t)
# for (i, w_ms) in enumerate(weights_ms), (j, w_t) in enumerate(weights_t)
#     cp_mat[i, j] = HR.critical_path(sols_weighting[(i-1)*len_weights_t+j][1], (w_ms, w_t))
# end



# weights_ms = (problem_moore_ms.mothership.weighting, problem_moore_ms.tenders.weighting)
# weights_t = (problem_moore_t.mothership.weighting, problem_moore_t.tenders.weighting)

# waypoint_optim_method = HR.SAMIN(ns=1)

# ms_h = HR.solve(problem_moore_ms, k=8; waypoint_optim_method, seed=1234);
# t_h = HR.solve(problem_moore_t, k=8; waypoint_optim_method, seed=1234);

# fig_ms_h = HR.Plot.solution(
#     problem_moore_ms,
#     ms_h,
#     highlight_critical_path_flag=true
# )
# fig_t_h = HR.Plot.solution(
#     problem_moore_t,
#     t_h,
#     highlight_critical_path_flag=true
# )


# # solution = HR.solve(problem, k=8, seed=1234);
# # solution_opt = HR.solve(problem, k=8; waypoint_optim_method, seed=1234);
# solution_multi_disturbed = HR.solve(problem;
#     k=8, disturbance_clusters=Set([4, 7]), seed=1234);
# solution_multi_disturbed_opt = HR.solve(problem;
#     k=8, disturbance_clusters=Set([4, 7]), waypoint_optim_method, seed=1234);

# HR.Plot.solution(
#     problem,
#     solution_multi_disturbed;
#     title="Solution (Disturbed after clusters 4, 7) without waypoint optimization",
#     highlight_critical_path_flag=true
# )
# HR.Plot.solution(
#     problem,
#     solution_multi_disturbed_opt;
#     title="Solution (Disturbed after clusters 4, 7) with waypoint optimization",
#     highlight_critical_path_flag=true
# )
