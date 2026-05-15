
import HierarchicalRouting as HR
using HierarchicalRouting,
    HierarchicalRouting.Plot.Makie,
    HierarchicalRouting.CairoMakie

CairoMakie.activate!(type="png");

const TARGET_PATH = "data/targets/scenarios/output_slopes_3-10m.geojson";
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

const PRINT_PLOTS = false
const INFO_LOG = false

const NUM_SIMS = 100

const OUTPUT_DIR = "outputs/Random_Instances/Solution_instances"
mkpath(OUTPUT_DIR)

const LOG_FILE = joinpath(OUTPUT_DIR, "objective_log.csv")
const LOG_LOCK = ReentrantLock()

# Write header
isfile(LOG_FILE) || open(LOG_FILE, "w") do f
    println(f, "problem_instance,objective_value,solve_seed,runtime(sec)")
end


problem_moore = load_problem(
    TARGET_PATH,
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
    debug_mode=true
);

fig_problem = HR.Plot.problem(
    problem_moore;
    labels=false,
    title="Moore Reef"
)
save(joinpath(OUTPUT_DIR, "problem_moore.png"), fig_problem)

waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=6)

# ── Parallel solve ───────────────────────────────────────────────────────────
total_time_start = time()
@info "Running $NUM_SIMS simulations of case study on $(Threads.nthreads()) threads..."
Threads.@threads for i in 1:NUM_SIMS
    t_start = time()

    run_dir = joinpath("$OUTPUT_DIR", "$i")
    mkpath(run_dir)

    @info "Solving simulation $i"
    solution = HR.solve(
        problem_moore;
        waypoint_optim_method,
        seed=i,
        wpt_optim_plot_flag=PRINT_PLOTS,
        soln_progress_plot_flag=PRINT_PLOTS,
        output_dir=run_dir,
        sa_improve_plot_flag=PRINT_PLOTS,
        info_log=INFO_LOG
    )

    obj_val = HR.critical_path(solution, problem_moore)
    t_elapsed = time() - t_start

    lock(LOG_LOCK) do
        open(LOG_FILE, "a") do f
            println(f, "Case Study - Moore,$(obj_val),$i,$t_elapsed")
        end
    end
    @info "Finished simulation $i in $(floor(Int, t_elapsed ÷ 60))m $(round(Int, t_elapsed % 60))s"

    fig = HR.Plot.solution(
        problem_moore,
        solution;
        highlight_critical_path_flag=true,
        title="Moore Reef - Seed $i"
    )
    save(joinpath(run_dir, "4_solution.png"), fig)
end


t_total_elapsed = time() - total_time_start
t_total_elapsed_sec = round(Int, t_total_elapsed % 60)
t_total_elapsed_min = floor(Int, (t_total_elapsed ÷ 60) % 60)
t_total_elapsed_hrs = floor(Int, t_total_elapsed ÷ 3600)
@info "$NUM_SIMS instances completed in $(t_total_elapsed_hrs)h, $(t_total_elapsed_min)m $(t_total_elapsed_sec)s"
@info "Outputs saved to $OUTPUT_DIR/"

# solutions_moore = Vector{Any}(undef, NUM_ITERS)   # pre-allocate; indexed writes are thread-safe
# Threads.@threads for i in 1:NUM_ITERS
#     solutions_moore[i] = HR.solve(
#         problem_moore;
#         waypoint_optim_method,
#         seed=i,
#         wpt_optim_plot_flag=false,      # disabled: Makie not thread-safe -- CairoMakie IS!
#         soln_progress_plot_flag=false,  # disabled: Makie not thread-safe
#     )

#     fig = HR.Plot.solution(
#         problem_moore,
#         solutions_moore[i];
#         highlight_critical_path_flag=true,
#         title="Moore Reef - Seed $i"
#     )
#     save("$OUTPUT_DIR/case_moore_$(i).png", fig)
# end

###############################################################################
###############################################################################
# solutions_moore = [
#     HR.solve(
#         problem_moore;
#         waypoint_optim_method,
#         seed=i,
#         wpt_optim_plot_flag=true,
#         soln_progress_plot_flag=true,
#     )
#     for i in 1:NUM_ITERS
# ]
#
# figs_moore = [
#     HR.Plot.solution(
#         problem_moore,
#         solutions_moore[i];
#         highlight_critical_path_flag=true,
#         title="Moore Reef - Seed $i"
#     )
#     for i in 1:NUM_ITERS
# ]
# fig_file_paths = ["$OUTPUT_DIR/case_moore_$(i).png" for i in eachindex(figs_moore)]
# save.(fig_file_paths, figs_moore)
# fig_file_paths = ["$OUTPUT_DIR/case_moore_$(i).png" for i in eachindex(figs_moore)]
# save.(fig_file_paths, figs_moore)
