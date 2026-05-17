# runscript_sensitivity_weightings.jl
# Sensitivity analysis: critical path vs. vessel weightings across N random problem instances.
# Outer loop (instances) is threaded; inner sweep over weight configs is sequential per thread.
# Launch: julia --threads auto runscript_sensitivity_weightings.jl

include("config.jl")

# ── Weighting sweep ───────────────────────────────────────────────────────────
const n_configs = length(WEIGHT_CONFIGS)

# ── Output ────────────────────────────────────────────────────────────────────
const OUT_ROOT = "outputs/sensitivity/weightings"
mkpath(OUT_ROOT)

# Pre-allocate: one Vector per instance, written by its own thread
# Columns: (instance, w_ms, w_t, obj_val)
instance_results = Vector{Vector{Tuple{Int,Float64,Float64,Float64}}}(undef, N_INSTANCES)

@info "Weighting sensitivity: $N_INSTANCES instances x $n_configs weight configs on $(Threads.nthreads()) threads"
@info "Mothership weights: $WEIGHTS_MS"
@info "Tender weights:     $WEIGHTS_T"

# ── csv_file set up ───────────────────────────────────────────────────────────
const csv_lock = ReentrantLock()
master_path = joinpath(OUT_ROOT, "sensitivity_weightings.csv")
open(master_path, "w") do io
    write(io, "instance,w_ms,w_t,obj_val,solve_time_s\n")
end

# ── Parallel outer loop ───────────────────────────────────────────────────────
@info "\nStart: $(Dates.now())"
progress = Progress(N_INSTANCES * n_configs; desc="Instances: ", showspeed=true)
ProgressMeter.update!(progress, 0)  # display at 0 before any thread completes

t_start = time()
io = open(master_path, "a")
try
    Threads.@threads for instance in 1:N_INSTANCES
        for (j, (w_ms, w_t)) in enumerate(WEIGHT_CONFIGS)
            problem = HR.generate_randomised_problem(
                SUBSET_PATH,
                BATHY_PATH,
                WAVE_DISTURBANCE_PATH,
                DEPOT,
                DRAFT_MS,
                DRAFT_T,
                w_ms,
                w_t,
                N_TENDERS,
                T_CAP;
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

            solve_time = time() - t_solve
            obj_val = HR.critical_path(soln, problem)

            lock(csv_lock) do
                write(io, "$instance,$w_ms,$w_t,$obj_val,$solve_time\n")
            end
        end
        next!(progress)  # thread-safe; replaces @info timing line if desired
    end
finally
    close(io)
end

# # ── Aggregate to master CSV ───────────────────────────────────────────────────
# master_path = joinpath(OUT_ROOT, "sensitivity_weightings.csv")
# open(master_path, "w") do io
#     write(io, "instance,w_ms,w_t,obj_val\n")
#     for rows in instance_results
#         for (inst, w_ms, w_t, obj_val) in rows
#             write(io, "$inst,$w_ms,$w_t,$obj_val\n")
#         end
#     end
# end

t = time() - t_start
@info "Done. Master CSV → $master_path"
@info "$N_INSTANCES instances x $n_configs weight configs on $(Threads.nthreads()) threads"
@info "Comp time\t$(floor(Int, t ÷ 3600))h $(floor(Int, (t % 3600) ÷ 60))m $(round(Int, t % 60))s"
