
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
    -5.0,
    -2.0,
    0.2, # 0.25, # 0.2,
    0.1, # 0.1, # 0.075,
    3,
    2;
    debug_mode=true
);

HR.Plot.Makie.inline!(true)
# HR.Plot.Makie.inline!(false)

problem_moore = HR.Plot.problem(
    problem;
    labels=false,
    title="Moore Reef"
)
# save("outputs/Moore/problem_moore.png", problem_moore)
# vessel weighting = inverse of speed -> weight = 2: speed = 0.5m/s, weight = 5: speed = 0.2m/s
waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=6)

@time solution_case_moore_undisturbed = HR.solve(
    problem;
    waypoint_optim_method,
    seed=1234,
    wpt_optim_plot_flag=true,
    soln_progress_plot_flag=true,
);

@time solution_case_moore_random_initial = HR.solve(
    problem;
    waypoint_optim_method,
    seed=1234,
    wpt_optim_plot_flag=true,
    soln_progress_plot_flag=true,
    cluster_iterations=0,
    cluster_restarts=0,
);

fig_moore_undisturbed = HR.Plot.solution(
    problem,
    solution_case_moore_undisturbed;
    highlight_critical_path_flag=true,
    title="Moore Reef",
)
save("outputs/Moore/case_moore_undisturbed.png", fig_moore_undisturbed)

###############################

disturbance_clusters = Set([2, 4]) # Set([3, 6])
solution_moore_disturbed = HR.solve(
    problem;
    waypoint_optim_method,
    seed=1234,
    disturbance_clusters,
)

case_moore_disturbances = HR.Plot.solution_disturbances(
    problem,
    solution_moore_disturbed,
    disturbance_clusters;
    highlight_critical_path_flag=true
)
case_moore_disturbed = HR.Plot.solution(
    problem,
    solution_moore_disturbed;
    highlight_critical_path_flag=true,
    title="Moore Reef - Disturbed"
)
save("outputs/Moore/case_moore_disturbances.png", case_moore_disturbances)
save("outputs/Moore/case_moore_disturbed.png", case_moore_disturbed)

#######################
# PERFECT INFO SOLUTION
disturbed_nodes = vcat(getfield.(solution_moore_disturbed.cluster_sets[end], :nodes)...)
target_points = DataFrame(ID=1:length(disturbed_nodes), geometry=disturbed_nodes);

lost_nodes = setdiff(problem.targets.points.geometry, target_points.geometry)
lost_points = DataFrame(ID=1:length(lost_nodes), geometry=lost_nodes);

problem_lost_nodes = HR.Problem(
    problem.depot,
    HR.Targets(
        lost_points,
        problem.targets.path,
        problem.targets.disturbance_gdf
    ),
    problem.mothership,
    problem.tenders
)

fig_lost_nodes = HR.Plot.problem(problem_lost_nodes; title="Lost nodes from disturbances")
save("outputs/Moore/problem_moore_lost_nodes.png", fig_lost_nodes)

problem_perfect_info = HR.Problem(
    problem.depot,
    HR.Targets(
        target_points,
        problem.targets.path,
        problem.targets.disturbance_gdf
    ),
    problem.mothership,
    problem.tenders
)

solution_perfect_info = HR.solve(
    problem_perfect_info;
    waypoint_optim_method,
    seed=1234,
)
fig_problem_perfect_info = HR.Plot.problem(
    problem_perfect_info;
    title="Problem with perfect information"
)
save("outputs/Moore/problem_moore_perfect_info.png", fig_problem_perfect_info)

k_perfect_info = length(solution_perfect_info.cluster_sets[end])
case_moore_disturbed_perfect_info = HR.Plot.solution(
    problem_perfect_info,
    solution_perfect_info,
    highlight_critical_path_flag=true,
    title="Perfect Info (k=$k_perfect_info)"
)
save("outputs/Moore/case_moore_perfect_info.png", case_moore_disturbed_perfect_info)

case_moore_disturbed_reactive_vs_perfect_info = HR.Plot.solution(
    problem_perfect_info,
    solution_moore_disturbed,
    solution_perfect_info;
    highlight_critical_path_flag=true,
    title=("Disturbed reactive solution", "Solution with perfect information")
)
save("outputs/Moore/case_moore_reactive_vs_perfect.png", case_moore_disturbed_reactive_vs_perfect_info)

solution_perfect_info_cross_swaps = HR.solve(
    problem_perfect_info;
    waypoint_optim_method,
    seed=1234,
)
case_moore_disturbed_perfect_info_cross_swaps = HR.Plot.solution(
    problem_perfect_info,
    solution_perfect_info_cross_swaps;
    highlight_critical_path_flag=true,
    title="Perfect Info, cross-cluster swaps"
)

k_reactive = length(solution_moore_disturbed.cluster_sets[end])
solution_perfect_info_k_match = HR.solve(
    problem_perfect_info;
    k=k_reactive,
    waypoint_optim_method,
    seed=1234,
)
case_moore_perfect_info_k_match = HR.Plot.solution(
    problem_perfect_info,
    solution_perfect_info_k_match;
    highlight_critical_path_flag=true,
    title="Solution with perfect information (k=$k_reactive)"
)
save("outputs/Moore/case_moore_perfect_info_k=$k_reactive.png", case_moore_perfect_info_k_match)
case_moore_disturbed_reactive_vs_perfect_info_k_match = HR.Plot.solution(
    problem_perfect_info,
    solution_moore_disturbed,
    solution_perfect_info_k_match;
    highlight_critical_path_flag=true,
    title=("Disturbed reactive solution", "Solution with perfect information (k=$k_reactive)")
)
save("outputs/Moore/case_moore_reactive_vs_perfect_k=$k_reactive.png", case_moore_disturbed_reactive_vs_perfect_info_k_match)
