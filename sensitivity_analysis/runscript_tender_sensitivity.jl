# runscript_sensitivity_tenders.jl
# Sensitivity analysis: critical path vs. tender fleet config across N random problem instances.
# Outer loop (instances) is threaded; inner sweep over fleet configs is sequential per thread.
# Launch: julia --threads auto runscript_sensitivity_tenders.jl

include("config.jl")

const n_configs = length(TENDER_CONFIGS)

# ── Output ────────────────────────────────────────────────────────────────────
const OUT_ROOT = "outputs/sensitivity/tenders"
mkpath(OUT_ROOT)

@info "Tender sensitivity: $N_INSTANCES instances x $n_configs fleet configs on $(Threads.nthreads()) threads"
@info "Fleet configs (n_tenders, capacity): $TENDER_CONFIGS"

# ── csv_file set up ───────────────────────────────────────────────────────────
const csv_lock = ReentrantLock()
master_path = joinpath(OUT_ROOT, "sensitivity_tenders.csv")
open(master_path, "w") do io
    write(io, "instance,n_tenders,tender_capacity,obj_val,solve_time_s\n")
end

# ── Parallel outer loop ───────────────────────────────────────────────────────
progress = Progress(N_INSTANCES; desc="Instances: ", showspeed=true)
ProgressMeter.update!(progress, 0)  # display at 0 before any thread completes

t_start = time()
Threads.@threads for instance in 1:N_INSTANCES
    for (j, (n_tenders, t_cap)) in enumerate(TENDER_CONFIGS)
        problem = HR.generate_randomised_problem(
            SUBSET_PATH,
            BATHY_PATH,
            WAVE_DISTURBANCE_PATH,
            DEPOT,
            DRAFT_MS,
            DRAFT_T,
            WEIGHT_MS,
            WEIGHT_T,
            n_tenders,
            t_cap;
            no_target_pts=N_TARGET_PTS,
            points_buffer_dist=BUFFER_DIST,
            debug_mode=false,
            seed=instance,
        )

        t_solve = time()
        soln = HR.solve(
            problem;
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
                write(io, "$instance,$n_tenders,$t_cap,$obj_val,$solve_time\n")
            end
        end
    end

    # @info "Instance $instance done | $(floor(Int, t ÷ 60))m $(round(Int, t % 60))s"
    next!(progress)  # thread-safe; replaces @info timing line if desired
end

# # ── Aggregate to master CSV ───────────────────────────────────────────────────
# master_path = joinpath(OUT_ROOT, "sensitivity_tenders.csv")
# open(master_path, "w") do io
#     write(io, "instance,n_tenders,tender_capacity,obj_val\n")
#     for rows in instance_results
#         for (inst, n, c, obj_val) in rows
#             write(io, "$inst,$n,$c,$obj_val\n")
#         end
#     end
# end

t = time() - t_start
@info "Done. Master CSV → $master_path"
@info "$N_INSTANCES instances x $n_configs fleet configs on $(Threads.nthreads()) threads"
@info "Comp time\t$(floor(Int, t ÷ 3600))h $(floor(Int, (t % 3600) ÷ 60))m $(round(Int, t % 60))s"
