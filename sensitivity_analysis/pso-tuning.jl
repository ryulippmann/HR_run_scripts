
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

# problem = load_problem(
#     target_path,
#     subset_path,
#     bathy_path,
#     wave_disturbance_path,
#     (146.175, -16.84),                                      # depot
#     -10.0,                                                  # draft_ms
#     -5.0,                                                   # draft_t
#     1.0,                                                    # weight_ms
#     1.0,                                                    # weight_t
#     3,                                                      # n_tenders
#     2;                                                      # t_cap
# );
problem = load_problem(
    target_path,
    subset_path,
    bathy_path,
    wave_disturbance_path,
    (146.175, -16.84),                                      # depot
    -2.5, #-10.0,                                           # draft_ms
    -1.0, #5.0,                                             # draft_t
    0.2, #5.0,                                              # weight_ms
    0.075, #2.0,                                            # weight_t
    3,                                                      # n_tenders
    2;                                                      # t_cap
    debug_mode=true
);
vessel_weights = (problem.mothership.weighting, problem.tenders.weighting)

waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=6)

sols_refined = Vector{Tuple{HR.MSTSolution,Int}}()
for np in 3:10 # min particles defaults to 3
    waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=np)
    @info "Trying PSO with $(np) particles"
    push!(
        sols_refined,
        (
            HR.solve(problem; waypoint_optim_method, seed=1234, do_improve=true),
            waypoint_optim_method.n_particles
        )
    )
end

summary = collect(zip(
    getindex.(sols_refined, 2),
    HR.critical_path.(getindex.(sols_refined, 1), Ref(problem))
))

best_score = minimum(getindex.(summary, 2))
best_no_particles = summary[(argmin(getindex.(summary, 2)))][1]

# waypoint_optim_method = HR.Optim.SAMIN(nt=1, ns=1, rt=1)
sols = Vector{Tuple{HR.MSTSolution,Int}}()
for np in 0:5:50
    waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=np)
    @info "Trying PSO with $(np) particles"
    push!(
        sols,
        (
            HR.solve(problem; k=8, waypoint_optim_method, seed=1234),
            waypoint_optim_method.n_particles
        )
    )
end

sol_pso_5 = HR.solve(
    problem;
    k=8,
    waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=5),
    seed=1234
);

########################################################
########################################################

sols_refined_alt = Vector{Tuple{HR.MSTSolution,Int}}()
for np in 3:10 # min particles defaults to 3
    waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=np)
    @info "Trying PSO with $(np) particles"
    push!(
        sols_refined_alt,
        (
            HR.solve(problem_alt; waypoint_optim_method, seed=1234, do_improve=true),
            waypoint_optim_method.n_particles
        )
    )
end

summary_alt = collect(zip(
    getindex.(sols_refined_alt, 2),
    HR.critical_path.(getindex.(sols_refined_alt, 1), Ref(problem_alt))
))

best_score_alt = minimum(getindex.(summary_alt, 2))
best_no_particles_alt = summary_alt[(argmin(getindex.(summary_alt, 2)))][1]


#####
# Long run as benchmark

HR.Plot.Makie.inline!(true)
sol_long_run = HR.solve(
    problem;
    waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=12),
    seed=1234,
    do_improve=true,
    time_limit=1800.0
);
HR.Plot.solution(
    problem,
    sol_long_run;
    highlight_critical_path_flag=true,
    title="Moore Reef Long Run PSO (12 particles, 30 min)"
)

dbl_bbox = HR.solve(
    problem;
    waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=12),
    seed=1234,
    do_improve=true,
    time_limit=1500.0
);
HR.Plot.solution(
    problem,
    dbl_bbox;
    highlight_critical_path_flag=true,
    title="Moore Reef Double BBox PSO (12 particles, 25 min)"
)

sol_long_run_dbl_bbox = HR.solve(
    problem;
    waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=30),
    seed=1234,
    do_improve=true,
    time_limit=3600.0
);
HR.Plot.solution(
    problem,
    sol_long_run_dbl_bbox;
    highlight_critical_path_flag=true,
    title="Moore Reef Long Run Double BBox PSO (30 particles, 60 min)"
)

#########################################################

problem_alt = load_problem(
    target_path_alt,
    subset_path_alt,
    bathy_path,
    wave_disturbance_path_alt,
    (145.6, -16.35),
    -2.5, #-10.0, #
    -1.0, #-5.0, #
    0.2, #5.0,
    0.075, #2.0,
    3,
    2;
    # debug_mode=true
);
HR.Plot.problem(
    problem_alt;
    labels=false,
    title="Batt & Tongue Reefs"
)

sol_long_run_batt_bbox_01 = HR.solve(
    problem_alt;
    waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=30),
    seed=1234,
    do_improve=true,
    time_limit=3600.0
);
# 13 - 14
HR.Plot.solution(
    problem_alt,
    sol_long_run_batt_bbox_01;
    highlight_critical_path_flag=true,
    title="Batt & Tongue Long Run PSO (30 particles, 60 min) bbox +/-0.1"
)
