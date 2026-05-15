# runscript_sensitivity.jl
# Sensitivity analysis: critical path vs. cluster count across N random problem instances.
# Outer loop (seeds 1:N_INSTANCES) is threaded; inner cluster sweep is sequential per thread.
# Launch: julia --threads auto runscript_sensitivity.jl

include("config.jl")

# ── Output ────────────────────────────────────────────────────────────────────
const OUT_ROOT = "outputs/sensitivity/clusters"
mkpath(OUT_ROOT)

const n_sweeps = length(CLUSTER_SWEEP)

@info "Sensitivity analysis: $N_INSTANCES instances x $n_sweeps cluster counts on $(Threads.nthreads()) threads"
@info "Cluster sweep: $CLUSTER_SWEEP"

# ── csv_file set up ───────────────────────────────────────────────────────────
const csv_lock = ReentrantLock()
master_path = joinpath(OUT_ROOT, "sensitivity_clusters.csv")
open(master_path, "w") do io
    write(io, "instance,n_clusters,obj_val,solve_time_s\n")
end

# ── Parallel outer loop ───────────────────────────────────────────────────────
progress = Progress(N_INSTANCES * n_sweeps; desc="Instances: ", showspeed=true)
ProgressMeter.update!(progress, 0)  # display at 0 before any thread completes

t_start = time()
Threads.@threads for instance in 1:N_INSTANCES

    if SAVE_PLOTS
        instance_dir = joinpath(OUT_ROOT, "instance_$(instance)")
        mkpath(instance_dir)
    end

    # --- Generate random instance ---
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
        debug_mode=false,
        seed=instance,
    )

    for (j, nc) in enumerate(CLUSTER_SWEEP)
        t_solve = time()

        soln = HR.solve(
            problem;
            k=nc,
            waypoint_optim_method,
            seed=SOLVE_SEED,
            sa_improve_plot_flag=PLOT_FLAG,
            wpt_optim_plot_flag=PLOT_FLAG,
            soln_progress_plot_flag=PLOT_FLAG,
            info_log=INFO_FLAG,
        )

        obj_val = HR.critical_path(soln, problem)
        solve_time = time() - t_solve

        lock(csv_lock) do
            open(master_path, "a") do io
                write(io, "$instance,$nc,$obj_val,$solve_time\n")
            end
        end
        next!(progress)  # thread-safe; replaces @info timing line if desired
    end
end

# # ── Aggregate to master CSV ───────────────────────────────────────────────────
# master_path = joinpath(OUT_ROOT, "sensitivity_clusters.csv")
# open(master_path, "w") do io
#     write(io, "instance,n_clusters,obj_val,solve_time_s\n")
#     for rows in instance_results
#         for (s, nc, obj_val, t) in rows
#             write(io, "$s,$nc,$obj_val,$t\n")
#         end
#     end
# end

t = time() - t_start
@info "Done. Master CSV → $master_path"
@info "$N_INSTANCES instances x $n_sweeps cluster counts on $(Threads.nthreads()) threads"
@info "Comp time\t$(floor(Int, t ÷ 3600))h $(floor(Int, (t % 3600) ÷ 60))m $(round(Int, t % 60))s"
