
using Revise, Infiltrator, BenchmarkTools
import HierarchicalRouting as HR
using HierarchicalRouting,
    HierarchicalRouting.DataFrames,
    HierarchicalRouting.GeometryBasics,
    HierarchicalRouting.AG,
    HierarchicalRouting.Plot.Makie
using HierarchicalRouting: Cluster, MothershipSolution, TenderSolution, Plot
HR.Plot.Makie.inline!(true)

target_path_alt = "data/targets/scenarios/b_t_subset.geojson"; #reefguide_output_100x20.geojson";
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
    debug_mode=true
);

HR.Plot.problem(
    problem_alt;
    labels=false,
    title="Batt & Tongue Reefs",
    size=(700, 490)
)

vessel_weightings_alt = (problem_alt.mothership.weighting, problem_alt.tenders.weighting)
waypoint_optim_method_alt = HR.Optim.ParticleSwarm(n_particles=6)

@time solution_case_alt = HR.solve(
    problem_alt;
    waypoint_optim_method=waypoint_optim_method_alt,
    # time_limit=600,
    seed=1234,
    wpt_optim_plot_flag=true,
    soln_progress_plot_flag=true,
    cross_cluster_flag=true
)

fig_batt_tongue_undisturbed = HR.Plot.solution(
    problem_alt,
    solution_case_alt;
    highlight_critical_path_flag=true,
    title="Batt & Tongue",
    size=(700, 490)
)
save("outputs/B&T/case_batt_tongue_undisturbed.png", fig_batt_tongue_undisturbed)

###############################
# for k in 5:8
#     @time solution_case_alt_k = HR.solve(
#         problem_alt;
#         k,
#         waypoint_optim_method=waypoint_optim_method_alt,
#         seed=1234,
#         wpt_optim_plot_flag=true,
#         cross_cluster_flag=true
#     )

#     fig_k = HR.Plot.solution(
#         problem_alt,
#         solution_case_alt_k;
#         highlight_critical_path_flag=true,
#         title="Batt & Tongue (k=$k)",
#         size=(700, 490)
#     )
#     save("outputs/B&T/case_batt_tongue_k_$k.png", fig_k)
# end
###############################

disturbance_clusters = Set([2, 4])
@time solution_alt_disturbed = HR.solve(
    problem_alt;
    waypoint_optim_method=waypoint_optim_method_alt, #! PSO needs more iterations for B&T
    # time_limit=600.0, #! Give PSO more iterations by increasing time limit (3x)
    seed=1234,
    disturbance_clusters,
    wpt_optim_plot_flag=true,
    soln_progress_plot_flag=true,
    cross_cluster_flag=false #! cross-clust swap problematic with disturbances
)

# for k in 5:8
#     solution_alt_disturbed_k = HR.solve(
#         problem_alt;
#         k,
#         waypoint_optim_method=waypoint_optim_method_alt, #! PSO needs more iterations for B&T
#         time_limit=600.0, #! Give PSO more iterations by increasing time limit (3x)
#         seed=1234,
#         disturbance_clusters,
#         cross_cluster_flag=false #! cross-clust swap problematic with disturbances
#     )

#     fig_k_disturbances = HR.Plot.solution_disturbances(
#         problem_alt,
#         solution_alt_disturbed_k,
#         disturbance_clusters;
#         highlight_critical_path_flag=true,
#         size=(1650, 350)
#     )
#     fig_k_disturbed = HR.Plot.solution(
#         problem_alt,
#         solution_alt_disturbed_k;
#         highlight_critical_path_flag=true,
#         title="Batt & Tongue - Disturbed (k=$k)",
#         size=(700, 490)
#     )
#     save("outputs/B&T/case_batt_tongue_disturbances_k_$k.png", fig_k_disturbances)
#     save("outputs/B&T/case_batt_tongue_disturbed_k_$k.png", fig_k_disturbed)
# end

case_batt_tongue_disturbances = HR.Plot.solution_disturbances(
    problem_alt,
    solution_alt_disturbed,
    disturbance_clusters;
    highlight_critical_path_flag=true,
    size=(1650, 400)
)
case_batt_tongue_disturbed = HR.Plot.solution(
    problem_alt,
    solution_alt_disturbed;
    highlight_critical_path_flag=true,
    title="Batt & Tongue - Disturbed",
    size=(700, 490)
)
save("outputs/B&T/case_batt_tongue_disturbances.png", case_batt_tongue_disturbances)
save("outputs/B&T/case_batt_tongue_disturbed.png", case_batt_tongue_disturbed)
#######################
# PERFECT INFO SOLUTION
disturbed_nodes = vcat(getfield.(solution_alt_disturbed.cluster_sets[end], :nodes)...)
target_points = DataFrame(ID=1:length(disturbed_nodes), geometry=disturbed_nodes);

lost_nodes = setdiff(problem_alt.targets.points.geometry, target_points.geometry)
lost_points = DataFrame(ID=1:length(lost_nodes), geometry=lost_nodes);

problem_lost_nodes = HR.Problem(
    problem_alt.depot,
    HR.Targets(
        lost_points,
        problem_alt.targets.path,
        problem_alt.targets.disturbance_gdf
    ),
    problem_alt.mothership,
    problem_alt.tenders
)

fig_lost_nodes = HR.Plot.problem(
    problem_lost_nodes;
    title="Lost nodes due to disturbances",
    size=(700, 490),
)

problem_perfect_info = HR.Problem(
    problem_alt.depot,
    HR.Targets(
        target_points,
        problem_alt.targets.path,
        problem_alt.targets.disturbance_gdf
    ),
    problem_alt.mothership,
    problem_alt.tenders
)
HR.Plot.problem(
    problem_perfect_info;
    title="Perfect info of disturbances",
    size=(700, 490)
)
solution_perfect_info = HR.solve(
    problem_perfect_info;
    time_limit=600,
    waypoint_optim_method=waypoint_optim_method_alt,
    seed=1234,
    cross_cluster_flag=true,
    wpt_optim_plot_flag=true
)

k_reactive = length(solution_alt_disturbed.cluster_sets[end])
k_perfect_info = length(solution_perfect_info.cluster_sets[end])

case_batt_tongue_perfect_info = HR.Plot.solution(
    problem_perfect_info,
    solution_perfect_info;
    highlight_critical_path_flag=true,
    title="Perfect Info (k=$k_perfect_info)",
    size=(700, 435)
)
save("outputs/B&T/case_batt_tongue_perfect_info.png", case_batt_tongue_perfect_info)

case_batt_tongue_reactive_vs_perfect_info = HR.Plot.solution(
    problem_perfect_info,
    solution_alt_disturbed,
    solution_perfect_info;
    highlight_critical_path_flag=true,
    title=("Disturbed reactive solution", "Solution with perfect information")
)
save("outputs/B&T/case_batt_tongue_reactive_vs_perfect_info.png", case_batt_tongue_reactive_vs_perfect_info)

# solution_perfect_info_unconstrained_k = HR.solve(
#     problem_perfect_info;
#     # k=7,
#     waypoint_optim_method=waypoint_optim_method_alt,
#     seed=1234,
# )

# HR.Plot.solution(
#     problem_perfect_info,
#     solution_perfect_info_unconstrained_k;
#     highlight_critical_path_flag=true,
#     title=("Perfect info, unconstrained k")
# )
