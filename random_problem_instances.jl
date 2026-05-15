
import HierarchicalRouting as HR
using HierarchicalRouting,
    HierarchicalRouting.Plot.Makie,
    HierarchicalRouting.CairoMakie

CairoMakie.activate!(type="png")

# # runscript_local.jl  (display, GLMakie for interactivity)
# using GLMakie; GLMakie.activate!()

const SUBSET_PATH = "data/site/Moore_2024-02-14b_v060_rc1.gpkg";
const BATHY_PATH = "data/env_constraints/bathy/Cairns-Cooktown_bathy.tif";
const WAVE_DISTURBANCE_PATH = "data/env_disturbances/waves/output_slope_zs_Hs_Tp.geojson";
const DEPOT = (146.175, -16.84)
const DRAFT_MS = -5.0
const DRAFT_T = -2.0
const WEIGHT_MS = 0.2
const WEIGHT_T = 0.1
const N_TENDERS = 3
const T_CAP = 2

const N_INSTANCES = 100
const N_ALREADY_DONE = 0
const SOLVE_SEED = 1234

const N_TARGET_PTS = 29
const BUFFER_DIST = 1E-3
const PRINT_PLOTS = false
const INFO_LOG = false

const OUTPUT_DIR = "outputs/Random_Instances/Problem_instances"
mkpath(OUTPUT_DIR)

const LOG_FILE = joinpath(OUTPUT_DIR, "objective_log.csv")
const LOG_LOCK = ReentrantLock()

# Write header
isfile(LOG_FILE) || open(LOG_FILE, "w") do f
    println(f, "problem_instance,objective_value,solve_seed,runtime(sec)")
end

waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=6)

##############################
total_time_start = time()
@info "Running $N_INSTANCES random instances on $(Threads.nthreads()) threads..."
Threads.@threads for ITER in ((1:N_INSTANCES) .+ N_ALREADY_DONE)
    t_start = time()
    @info "Generating instance $ITER"

    run_dir = joinpath("$OUTPUT_DIR", "$ITER")
    problem = HR.generate_randomised_problem(
        SUBSET_PATH,
        BATHY_PATH,
        WAVE_DISTURBANCE_PATH,
        DEPOT,
        DRAFT_MS,
        DRAFT_T,
        WEIGHT_MS,
        WEIGHT_T,
        N_TENDERS,
        T_CAP;
        no_target_pts=N_TARGET_PTS,
        points_buffer_dist=BUFFER_DIST,
        debug_mode=false,        # suppress per-thread debug noise
        seed=ITER
    )

    fig_problem = HR.Plot.problem(
        problem;
        labels=false,
        title="Seed $ITER"
    )

    mkpath(joinpath("$OUTPUT_DIR", "$ITER"))
    save(joinpath("$OUTPUT_DIR", "$ITER", "0_problem.png"), fig_problem)

    @info "Solving instance $ITER"
    solution = HR.solve(
        problem;
        waypoint_optim_method,
        seed=SOLVE_SEED,
        wpt_optim_plot_flag=PRINT_PLOTS,
        soln_progress_plot_flag=PRINT_PLOTS,
        output_dir=run_dir,
        sa_improve_plot_flag=PRINT_PLOTS,
        info_log=INFO_LOG
    )
    obj_val = HR.critical_path(solution, problem)
    t_elapsed = time() - t_start
    lock(LOG_LOCK) do
        open(LOG_FILE, "a") do f
            println(f, "$ITER,$(obj_val),$SOLVE_SEED,$t_elapsed")
        end
    end

    fig_solution = HR.Plot.solution(
        problem,
        solution;
        highlight_critical_path_flag=true,
        title="Random Problem Instance $ITER"
    )
    save(joinpath(run_dir, "4_solution.png"), fig_solution)

    t_elapsed = time() - t_start
    @info "Instance $ITER completed in $(floor(Int, t_elapsed ÷ 60))m $(round(Int, t_elapsed % 60))s (incl plot time)"
end

t_total_elapsed = time() - total_time_start
t_total_elapsed_sec = round(Int, t_total_elapsed % 60)
t_total_elapsed_min = floor(Int, (t_total_elapsed ÷ 60) % 60)
t_total_elapsed_hrs = floor(Int, t_total_elapsed ÷ 3600)
@info "$N_INSTANCES instances completed in $(t_total_elapsed_hrs)h, $(t_total_elapsed_min)m $(t_total_elapsed_sec)s"
@info "Outputs saved to $OUTPUT_DIR/"

##############################

# @info "Generating test random problem instance..."
# @time test_problem = HR.generate_randomised_problem(
#     SUBSET_PATH,
#     BATHY_PATH,
#     WAVE_DISTURBANCE_PATH,
#     DEPOT,
#     DRAFT_MS,
#     DRAFT_T,
#     WEIGHT_MS,
#     WEIGHT_T,
#     N_TENDERS,
#     T_CAP;
#     no_target_pts=N_TARGET_PTS,
#     points_buffer_dist=BUFFER_DIST,
#     debug_mode=false,
#     seed=0
# )
# @info "Plotting test random problem instance..."
# @time begin
#     fig_test_problem = HR.Plot.problem(
#         test_problem;
#         labels=false,
#         title="TEST Random Problem Instance",
#     )
#     save("$OUTPUT_DIR/test_problem.png", fig_test_problem)
# end

# @info "Solving test random problem instance..."
# @time begin
#     test_solution = HR.solve(
#         test_problem;
#         waypoint_optim_method,
#         seed=SOLVE_SEED,
#         wpt_optim_plot_flag=WPT_PLOT_FLAG,
#         soln_progress_plot_flag=true,
#         output_dir=joinpath("$OUTPUT_DIR", "0")
#     )
# end

# @info "Plotting solution for test random problem instance..."
# @time begin
#     test_solution_fig = HR.Plot.solution(
#         test_problem,
#         test_solution;
#         highlight_critical_path_flag=true,
#         title="Solution to TEST Random Problem Instance",
#     )
#     save("$OUTPUT_DIR/test_solution.png", test_solution_fig)
# end

##############################
# p_test = Vector{HR.Problem}(undef, N_INSTANCES);
# s_test = Vector{HR.MSTSolution}(undef, N_INSTANCES);
# @info "Running $N_INSTANCES random instances on $(Threads.nthreads()) threads..."
# total_time_start = time()

# for i in text_instances
#     p_test[i] = HR.generate_randomised_problem(
#         SUBSET_PATH,
#         BATHY_PATH,
#         WAVE_DISTURBANCE_PATH,
#         DEPOT,
#         DRAFT_MS,
#         DRAFT_T,
#         WEIGHT_MS,
#         WEIGHT_T,
#         N_TENDERS,
#         T_CAP;
#         no_target_pts=N_TARGET_PTS,
#         points_buffer_dist=BUFFER_DIST,
#         debug_mode=false,        # suppress per-thread debug noise
#         seed=i
#     )

#     s_test[i] = HR.solve(
#         problem;
#         waypoint_optim_method,
#         seed=SOLVE_SEED,
#         wpt_optim_plot_flag=WPT_PLOT_FLAG,
#         soln_progress_plot_flag=true,
#         # output_dir=run_dir
#     )
# end

##############################
# problem_instances = Vector{HR.Problem}(undef, 20);
# solution_instances = Vector{HR.MSTSolution}(undef, length(problem_instances));

# @info "Generating random problem instances..."
# @time for i in 1:length(problem_instances)
#     problem_instances[i] = HR.generate_randomised_problem(
#         SUBSET_PATH,
#         BATHY_PATH,
#         WAVE_DISTURBANCE_PATH,
#         DEPOT,
#         DRAFT_MS,
#         DRAFT_T,
#         WEIGHT_MS,
#         WEIGHT_T,
#         N_TENDERS,
#         T_CAP;
#         no_target_pts=29,
#         points_buffer_dist=1E-3,
#         debug_mode=true,
#         seed=i + 30
#     )
# end

## Started at 11:00 - finish at 17:00?
# @info "Solving all $length(problem_instances) instances..."
# solution_instances = HR.solve.(
#     problem_instances;
#     waypoint_optim_method,
#     seed=1234,
#     wpt_optim_plot_flag=WPT_PLOT_FLAG,
#     soln_progress_plot_flag=true,
# )

# @info "Plotting problem figures for all instances..."
# @time figs_probs = HR.Plot.problem.(
#     problem_instances;
#     labels=false,
#     title="Random Problem Instance \$i"
# )
# @info "Plotting solution figures for all instances..."
# @time figs_solutions = HR.Plot.solution.(
#     problem_instances,
#     solution_instances;
#     highlight_critical_path_flag=true,
#     title="Solution to Random Problem Instance \$i"
# )
# @info "Saving figures for all instances..."
# save.(
#     string.("$OUTPUT_DIR/problem_", collect(1:length(problem_instances)) .+ 30, ".png"),
#     figs_probs
# )
# save.(
#     string.("$OUTPUT_DIR/solution_", collect(1:length(problem_instances)) .+ 30, ".png"),
#     figs_solutions
# )
