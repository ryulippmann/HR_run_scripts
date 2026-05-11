
using Revise, Infiltrator, BenchmarkTools
using HierarchicalRouting,
    HierarchicalRouting.DataFrames,
    HierarchicalRouting.GeometryBasics,
    HierarchicalRouting.AG,
    HierarchicalRouting.Plot.GeoMakie,
    HierarchicalRouting.Random

using HierarchicalRouting: Cluster, MothershipSolution, TenderSolution, Plot

## Case study @ Moore
    target_path = "data/targets/scenarios/output_slopes_3-10m.geojson"
    # target_path_new = "data/targets/scenarios/reefguide_output_100x20.geojson"
    subset_path = "data/site/Moore_2024-02-14b_v060_rc1.gpkg"
    bathy_path = "data/env_constraints/bathy/Cairns-Cooktown_bathy.tif"
    wave_disturbance_path = "data/env_disturbances/waves/zonal_Hs_CC_x_reefguide_polys.geojson"#"data/env_disturbances/waves/output_slope_zs_Hs_Tp.geojson"

    problem = load_problem(
        target_path,
        subset_path,
        bathy_path,
        wave_disturbance_path,
        (146.175, -16.84),                                              # depot,
        -10.0,                                                          # draft_ms,
        -5.0,                                                           # draft_t,
        5.0,                                                            # weight_ms,
        2.0,                                                            # weight_t,
        3,                                                              # n_tenders,
        2;                                                              # t_cap,
        debug_mode=true,
    );

    vessel_weightings = (problem.mothership.weighting, problem.tenders.weighting);
    Random.seed!(1); # For reproducibility
    moore_case_study = HierarchicalRouting.solve(problem; k=7);

    fig = Figure(size=(750, 880))   ## 1 fig plot
        ax = Axis(fig[1, 1], xlabel="Longitude", ylabel="Latitude");
        HierarchicalRouting.Plot.exclusions!(
            ax,
            problem.tenders.exclusion,
            labels=true
        );
        HierarchicalRouting.Plot.clusters!(
            ax,
            clusters=moore_case_study.cluster_sets[end],
            labels=true,
            centers=true,
            nodes=true,
            cluster_radius=0#.0025
        );
        HierarchicalRouting.Plot.linestrings!(
            ax,
            moore_case_study.mothership_routes[end].route;
            labels=true,
            color=:black
        );
        HierarchicalRouting.Plot.tenders!(ax, moore_case_study.tenders[end]);
        HierarchicalRouting.Plot.annotate_cost!(
            ax,
            HierarchicalRouting.critical_path(moore_case_study),
            fontsize=14
        );

    save("outputs/figs/20250703/moore.png", fig);

#########################
## Case study @ batt & tongue
    target_path_batt_tongue = "data/targets/scenarios/reefguide_output_100x20.geojson"
    subset_path_batt_tongue = "data/site/batt_tongue.gpkg"
    bathy_path = "data/env_constraints/bathy/Cairns-Cooktown_bathy.tif"
    wave_disturbance_path = "data/env_disturbances/waves/zonal_Hs_CC_x_reefguide_polys.geojson"

    # problem_batt_tongue = load_problem(
    #     target_path_batt_tongue,
    #     subset_path_batt_tongue,
    #     bathy_path,
    #     wave_disturbance_path,
    #     (145.674, -16.356),                                              # depot,
    #     -10.0,                                                          # draft_ms,
    #     -5.0,                                                           # draft_t,
    #     5.0,                                                            # weight_ms,
    #     2.0,                                                            # weight_t,
    #     3,                                                              # n_tenders,
    #     2;                                                              # t_cap,
    #     target_subset = "batt_tongue",
    #     # polygon_min_area = 5E-7,
    #     # polygon_simplify_tol = 1E-4,
    # );
    problem_batt_tongue = load_problem(
        target_path_batt_tongue,
        subset_path_batt_tongue,
        bathy_path,
        wave_disturbance_path,
        (145.65, -16.36),                                              # depot,
        -10.0,                                                          # draft_ms,
        -5.0,                                                           # draft_t,
        5.0,                                                            # weight_ms,
        2.0,                                                            # weight_t,
        3,                                                              # n_tenders,
        2;                                                              # t_cap,
        debug_mode=true,
        # target_subset = "batt_tongue"
    );
    vessel_weightings = (problem_batt_tongue.mothership.weighting, problem_batt_tongue.tenders.weighting);
    Random.seed!(1); # For reproducibility
    case_study_b = HierarchicalRouting.solve(problem_batt_tongue, k=8);

    fig = Figure(size=(750, 880))   ## 1 fig plot
        ax = Axis(fig[1, 1], xlabel="Longitude", ylabel="Latitude");
        HierarchicalRouting.Plot.exclusions!(
            ax,
            problem_batt_tongue.mothership.exclusion,
            labels=true
        );
        HierarchicalRouting.Plot.exclusions!(
            ax,
            problem_batt_tongue.tenders.exclusion,
            labels=false
        );
        # scatter!(ax, problem_batt_tongue.depot; color=:black, markersize=10);
        HierarchicalRouting.Plot.clusters!(
            ax,
            clusters=clusters, #case_study_b.cluster_sets[end],
            labels=true,
            centers=true,
            nodes=true,
            cluster_radius=0.0
        );
        HierarchicalRouting.Plot.linestrings!(
            ax,
            case_study_b.mothership_routes[end].route;
            labels=true,
            color=:black
        );
        HierarchicalRouting.Plot.tenders!(ax, case_study_b.tenders[end]);
        # Annotate critical path cost on plot
        HierarchicalRouting.Plot.annotate_cost!(
            ax,
            HierarchicalRouting.critical_path(case_study_b),
            fontsize=14
        );

    # save("outputs/figs/batt_tongue_case_study_Q_1234.png", fig);
    # save("outputs/figs/batt_tongue_case_study_Q_1234_mothership.png", fig);

#########################
## Disturbance case study
    # Q=1234
    disturbance_clusters = Set([2, 4]);
    moore_disturbed_case_study = HierarchicalRouting.solve_problem(
        problem; k,
        disturbance_clusters
    );

    fig = Figure(size=(1650, 600));  ## 3 fig plot
        ax1, ax2, ax3 =
            Axis(fig[1, 1], xlabel="Longitude", ylabel="Latitude"),
            Axis(fig[1, 2], xlabel="Longitude"),
            Axis(fig[1, 3], xlabel="Longitude");

        HierarchicalRouting.Plot.exclusions!.(
            [ax1, ax2, ax3],
            [problem.tenders.exclusion], # problem.mothership.exclusion,
            labels=false
        );
        HierarchicalRouting.Plot.clusters!(
            ax1,
            clusters=moore_disturbed_case_study.cluster_sets[1],
            labels=true,
            centers=false,
            nodes=true,
            cluster_radius=0.0
        );
        HierarchicalRouting.Plot.clusters!(
            ax2,
            clusters=moore_disturbed_case_study.cluster_sets[2],
            labels=true,
            centers=false,
            nodes=true,
            cluster_radius=0.0
        );
        HierarchicalRouting.Plot.clusters!(
            ax3,
            clusters=moore_disturbed_case_study.cluster_sets[3],
            labels=true,
            centers=false,
            nodes=true,
            cluster_radius=0.0
        );
        ##
        HierarchicalRouting.Plot.linestrings!.(
            [ax1, ax2, ax3],
            [moore_disturbed_case_study.mothership_routes[1].route,
                moore_disturbed_case_study.mothership_routes[2].route,
                moore_disturbed_case_study.mothership_routes[3].route],
            labels=true,
            color=:black
        );
        ##
        ordered_disturbances = sort(unique(disturbance_clusters));
        HierarchicalRouting.Plot.tenders!.(
            [ax1, ax2, ax3],
            [moore_disturbed_case_study.tenders[1][1:ordered_disturbances[1]-1],
                moore_disturbed_case_study.tenders[2][1:ordered_disturbances[2]-1],
                moore_disturbed_case_study.tenders[3]],
            length.(moore_disturbed_case_study.tenders[1:3])
        );
        HierarchicalRouting.Plot.annotate_cost!(
            ax3,
            HierarchicalRouting.critical_path(moore_disturbed_case_study)
        );

    save("outputs/figs/moore_disturbed_case_study_Q_1234.png", fig);
    # HierarchicalRouting.export_clusters(
    #     moore_disturbed_case_study.mothership_routes[end].cluster_sequence,
    #     false,
    #     "outputs/cases/moore_disturbed_case_study_clusters.gpkg"
    # );

#########################
## Disturbed locations with perfect info
# Q=1234
disturbed_nodes = vcat(getfield.(moore_disturbed_case_study.cluster_sets[end], :nodes)...)
disturbed_nodes_df = HierarchicalRouting.DataFrames.DataFrame(
    ID=1:length(disturbed_nodes),
    geometry=disturbed_nodes
);
disturbed_problem = HierarchicalRouting.Problem(
    problem.depot,
    HierarchicalRouting.Targets(
        disturbed_nodes_df, "",
        problem.targets.disturbance_gdf,
    ),
    problem.mothership,
    problem.tenders
);
moore_disturbed_perf_info = HierarchicalRouting.solve_problem(disturbed_problem; k);

fig = Figure(size=(1000, 600))
ax1, ax2 = Axis(fig[1, 1]), Axis(fig[1, 2]);

HierarchicalRouting.Plot.exclusions!.(
    [ax1, ax2],
    [problem.tenders.exclusion], # problem.mothership.exclusion,
    labels=false
);
##
HierarchicalRouting.Plot.clusters!(
    ax1,
    clusters=moore_disturbed_case_study.cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.clusters!(
    ax2,
    clusters=moore_disturbed_perf_info.cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);

HierarchicalRouting.Plot.linestrings!.(
    [ax1, ax2],
    [moore_disturbed_case_study.mothership_routes[end].route,
        moore_disturbed_perf_info.mothership_routes[end].route],
    labels=true,
    color=:black
);
HierarchicalRouting.Plot.tenders!.(
    [ax1, ax2],
    [moore_disturbed_case_study.tenders[end], moore_disturbed_perf_info.tenders[end]]
);
HierarchicalRouting.Plot.annotate_cost!.(
    [ax1, ax2],
    [HierarchicalRouting.critical_path(moore_disturbed_case_study),
        HierarchicalRouting.critical_path(moore_disturbed_perf_info)]
);
#Weighted cost
vessel_weightings = (problem.mothership.weighting, problem.tenders.weighting)
HierarchicalRouting.critical_path(moore_disturbed_case_study, vessel_weightings)
HierarchicalRouting.critical_path(moore_disturbed_perf_info, vessel_weightings)
#! The result with perfect info is worse than the itertively disturbed solution.
save("outputs/figs/moore_disturbed_perf_info_Q_1234.png", fig);

## Sensitivity analysis
# Vary number of clusters
k = [5, 7, 8, 10];
soln_varied_clusts = [
    HierarchicalRouting.solve_problem(problem; k=j) for j in k]

#Plot solutions with varied clusters
fig = Figure(size=(1000, 600))
ax1, ax2, ax3, ax4 = Axis(fig[1, 1]), Axis(fig[1, 2]), Axis(fig[1, 3]), Axis(fig[1, 4]);
HierarchicalRouting.Plot.exclusions!.(
    [ax1, ax2, ax3, ax4],
    [problem.tenders.exclusion], # problem.mothership.exclusion,
    labels=false
);
HierarchicalRouting.Plot.clusters!(
    ax1,
    clusters=soln_varied_clusts[1].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.clusters!(
    ax2,
    clusters=soln_varied_clusts[2].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.clusters!(
    ax3,
    clusters=soln_varied_clusts[3].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.clusters!(
    ax4,
    clusters=soln_varied_clusts[4].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.linestrings!.(
    [ax1, ax2, ax3, ax4],
    [soln_varied_clusts[1].mothership_routes[end].route,
        soln_varied_clusts[2].mothership_routes[end].route,
        soln_varied_clusts[3].mothership_routes[end].route,
        soln_varied_clusts[4].mothership_routes[end].route],
    labels=true,
    color=:black
);
HierarchicalRouting.Plot.tenders!.(
    [ax1, ax2, ax3, ax4],
    [soln_varied_clusts[1].tenders[end],
        soln_varied_clusts[2].tenders[end],
        soln_varied_clusts[3].tenders[end],
        soln_varied_clusts[4].tenders[end]]
);
HierarchicalRouting.Plot.annotate_cost!.(
    [ax1, ax2, ax3, ax4],
    [HierarchicalRouting.critical_path(soln_varied_clusts[1]),
        HierarchicalRouting.critical_path(soln_varied_clusts[2]),
        HierarchicalRouting.critical_path(soln_varied_clusts[3]),
        HierarchicalRouting.critical_path(soln_varied_clusts[4])]
);
save("outputs/figs/sensitivity/varied_clusters.png", fig);

# Vary tender cap
problem_t_caps = load_problem.(
    Ref(target_path),
    Ref(subset_path),
    Ref(bathy_path),
    Ref(wave_disturbance_path),
    Ref((146.175, -16.84)),
    Ref(-10.0),
    Ref(-5.0),
    Ref(5.0),
    Ref(2.0),
    Ref(3),
    [1, 3, 5, 7] # Vary tender cap;
);
k = 7
soln_varied_t_caps = HierarchicalRouting.solve_problem.(
    problem_t_caps;
    k
);

# Plot solutions with varied tender caps
fig = Figure(size=(1000, 600))
ax1, ax2, ax3 = Axis(fig[1, 1]), Axis(fig[1, 2]), Axis(fig[1, 3]);
HierarchicalRouting.Plot.exclusions!.(
    [ax1, ax2, ax3],
    [problem.tenders.exclusion], # problem.mothership.exclusion,
    labels=false
);
HierarchicalRouting.Plot.clusters!(
    ax1,
    clusters=soln_varied_t_caps[1].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.clusters!(
    ax2,
    clusters=soln_varied_t_caps[2].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.clusters!(
    ax3,
    clusters=soln_varied_t_caps[3].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.linestrings!.(
    [ax1, ax2, ax3],
    [soln_varied_t_caps[1].mothership_routes[end].route,
        soln_varied_t_caps[2].mothership_routes[end].route,
        soln_varied_t_caps[3].mothership_routes[end].route],
    labels=true,
    color=:black
);
HierarchicalRouting.Plot.tenders!.(
    [ax1, ax2, ax3],
    [soln_varied_t_caps[1].tenders[end],
        soln_varied_t_caps[2].tenders[end],
        soln_varied_t_caps[3].tenders[end]]
);
HierarchicalRouting.Plot.annotate_cost!.(
    [ax1, ax2, ax3],
    [HierarchicalRouting.critical_path(soln_varied_t_caps[1]),
        HierarchicalRouting.critical_path(soln_varied_t_caps[2]),
        HierarchicalRouting.critical_path(soln_varied_t_caps[3])]
);
save("outputs/figs/sensitivity/varied_tender_caps.png", fig);

# Vary number of tenders
problem_n_tenders = load_problem.(
    Ref(target_path),
    Ref(subset_path),
    Ref(bathy_path),
    Ref(wave_disturbance_path),
    Ref((146.175, -16.84)),
    Ref(-10.0),
    Ref(-5.0),
    Ref(5.0),
    Ref(2.0),
    [2, 3, 4, 5], # Vary number of tenders
    Ref(2);
);

soln_varied_n_tenders = HierarchicalRouting.solve_problem.(
    problem_n_tenders;
    k
);

# Plot solutions with varied number of tenders
fig = Figure(size=(1000, 600))
ax1, ax2, ax3, ax4 = Axis(fig[1, 1]), Axis(fig[1, 2]), Axis(fig[1, 3]), Axis(fig[1, 4]);
HierarchicalRouting.Plot.exclusions!.(
    [ax1, ax2, ax3, ax4],
    [problem.tenders.exclusion], # problem.mothership.exclusion,
    labels=false
);
HierarchicalRouting.Plot.clusters!(
    ax1,
    clusters=soln_varied_n_tenders[1].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.clusters!(
    ax2,
    clusters=soln_varied_n_tenders[2].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.clusters!(
    ax3,
    clusters=soln_varied_n_tenders[3].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.clusters!(
    ax4,
    clusters=soln_varied_n_tenders[4].cluster_sets[end],
    labels=true,
    centers=false,
    nodes=true,
    cluster_radius=0.0
);
HierarchicalRouting.Plot.linestrings!.(
    [ax1, ax2, ax3, ax4],
    [soln_varied_n_tenders[1].mothership_routes[end].route,
        soln_varied_n_tenders[2].mothership_routes[end].route,
        soln_varied_n_tenders[3].mothership_routes[end].route,
        soln_varied_n_tenders[4].mothership_routes[end].route],
    labels=true,
    color=:black
);
HierarchicalRouting.Plot.tenders!.(
    [ax1, ax2, ax3, ax4],
    [soln_varied_n_tenders[1].tenders[end],
        soln_varied_n_tenders[2].tenders[end],
        soln_varied_n_tenders[3].tenders[end],
        soln_varied_n_tenders[4].tenders[end]]
);
HierarchicalRouting.Plot.annotate_cost!.(
    [ax1, ax2, ax3, ax4],
    [HierarchicalRouting.critical_path(soln_varied_n_tenders[1]),
        HierarchicalRouting.critical_path(soln_varied_n_tenders[2]),
        HierarchicalRouting.critical_path(soln_varied_n_tenders[3]),
        HierarchicalRouting.critical_path(soln_varied_n_tenders[4])]
);
save("outputs/figs/sensitivity/varied_n_tenders.png", fig);
