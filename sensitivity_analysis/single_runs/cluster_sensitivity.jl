
using Revise, Infiltrator, BenchmarkTools
import HierarchicalRouting as HR
using HierarchicalRouting,
    HierarchicalRouting.DataFrames,
    HierarchicalRouting.GeometryBasics,
    HierarchicalRouting.AG,
    HierarchicalRouting.Plot.Makie
using HierarchicalRouting: Cluster, MothershipSolution, TenderSolution, Plot

target_path = "data/targets/scenarios/output_slopes_3-10m.geojson";
subset_path = "data/site/Moore_2024-02-14b_v060_rc1.gpkg";
bathy_path = "data/env_constraints/bathy/Cairns-Cooktown_bathy.tif";
wave_disturbance_path = "data/env_disturbances/waves/output_slope_zs_Hs_Tp.geojson";

problem = load_problem(
    target_path,
    subset_path,
    bathy_path,
    wave_disturbance_path,
    (146.175, -16.84),
    -5.0, # -10.0, # -2.5, #
    -2.0, # -5.0, # -1.0, #
    0.2, #5.0,
    0.075, #2.0,
    3,
    2;
    # debug_mode=true
);
no_pts = length(problem.targets.points.geometry)
waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=6)
cluster_iterations = vcat(3:10, 12:2:no_pts)
sols_clusts_moore = Vector{Tuple{HR.MSTSolution,Int}}(undef, length(cluster_iterations))
using Base.Threads
Threads.@threads for i in eachindex(cluster_iterations)
    nc = cluster_iterations[i]
    @info "Solving with $(nc) clusters"
    sol = (HR.solve(
        problem;
        k=nc,
        waypoint_optim_method,
        seed=1234,
        wpt_optim_plot_flag=false,
        cross_cluster_flag=false,
        soln_progress_plot_flag=false
        #! Set min_iters::Int=20 in solve_problem.jl to improve comp time
    ))
    sols_clusts_moore[i] = (sol, nc)
end
# for (i, nc) in enumerate(cluster_iterations)
#     @info "Solving with $(nc) clusters"
#     sols_clusts_moore[i] = (
#         HR.solve(
#             problem;
#             k=nc,
#             waypoint_optim_method,
#             seed=1234,
#             wpt_optim_plot_flag=false,
#             cross_cluster_flag=false,
#             soln_progress_plot_flag=false
#             # min_iters::Int=20
#         ),
#         nc
#     )
# end

summary_clusts = collect(zip(
    getindex.(sols_clusts_moore, 2),
    HR.critical_path.(getindex.(sols_clusts_moore, 1), Ref(problem))
))

best_score_clusts = minimum(getindex.(summary_clusts, 2))
best_no_clusters = summary_clusts[(argmin(getindex.(summary_clusts, 2)))][1]

# PLOT
cluster_numbers = getindex.(summary_clusts, 1)
titles_clusts = ["$c proposed clusters - Moore Reef" for c in cluster_numbers]
plot_clusts_moore = [
    Plot.solution(
        problem,
        sol;
        highlight_critical_path_flag=true,
        title=ttl
    )
    for (sol, ttl) in zip(getindex.(sols_clusts_moore, 1), titles_clusts)
]
display.(plot_clusts_moore)
for (n, p) in zip(getindex.(summary_clusts, 1), plot_clusts_moore)
    save("outputs/sensitivity/clusters/plot_clusts_moore_$(n).png", p)
end

##########################################################
#########################################################

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
    -5.0, # -10.0, # -2.5, #
    -2.0, # -5.0, # -1.0, #
    0.2, #5.0,
    0.075, #2.0,
    3,
    2;
    # debug_mode=true
);

sols_clusts_batt = Vector{Tuple{HR.MSTSolution,Int}}()
for nc in vcat(3:10, 12:2:20)
    @info "Solving with $(nc) clusters"
    push!(
        sols_clusts_batt,
        (
            HR.solve(
                problem_alt;
                k=nc,
                waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=4),
                seed=1234,
                do_improve=true
            ),
            nc
        )
    )
end

summary_clusts_batt = collect(zip(
    getindex.(sols_clusts_batt, 2),
    HR.critical_path.(getindex.(sols_clusts_batt, 1), Ref(problem_alt))
))

best_score_clusts_batt = minimum(getindex.(summary_clusts_batt, 2))
best_no_clusters_batt = summary_clusts_batt[(argmin(getindex.(summary_clusts_batt, 2)))][1]

# PLOT
plot_clusts_batt_tongue = Plot.solution.(
    Ref(problem_alt),
    getindex.(sols_clusts_batt, 1);
    highlight_critical_path_flag=true,
    title="Varying Number of Clusters - Batt & Tongue"
)

for (n, p) in zip(getindex.(summary_clusts_batt, 1), plot_clusts_batt_tongue)
    save("outputs/sensitivity/clusters/plot_clusts_batt_tongue_$(n).png", p)
end
##########################################################
