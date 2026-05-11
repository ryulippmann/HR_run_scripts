
tender_fleet_config = collect(zip([6, 3, 2, 1], reverse([6, 3, 2, 1])))
n_configs = length(tender_fleet_config)

# Vary tender fleet size & capacity (Moore Reef)
problem_t_fleet = load_problem.(
    Ref(target_path),
    Ref(subset_path),
    Ref(bathy_path),
    Ref(wave_disturbance_path),
    Ref((146.175, -16.84)),
    Ref(-5.0),
    Ref(-2.0),
    Ref(0.2),
    Ref(0.075),
    getindex.(tender_fleet_config, 1), # number of tenders
    getindex.(tender_fleet_config, 2) # Tender cap;
);

waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=6)

soln_varied_t_fleet = Vector{Tuple{HR.MSTSolution,Int,Int}}(undef, n_configs)

using Base.Threads
Threads.@threads for i in eachindex(problem_t_fleet)
    problem = problem_t_fleet[i]
    n_tenders, tender_capacity = tender_fleet_config[i]
    @info "Solving config $(i): $(n_tenders) n_tenders, $(tender_capacity) tender_capacity"
    sol = HR.solve(
        problem;
        waypoint_optim_method,
        seed=1234,
        wpt_optim_plot_flag=false,
        cross_cluster_flag=false,
        soln_progress_plot_flag=false
        #! set min_iters::Int=20 in solve_problem.jl to improve comp time
    )
    soln_varied_t_fleet[i] = (sol, n_tenders, tender_capacity)
end

obj_vals_t_fleet = HierarchicalRouting.critical_path.(
    getindex.(soln_varied_t_fleet, 1), problem_t_fleet
)

plot_vary_t_moore = [
    Plot.solution(
        prob_t,
        soln_t;
        highlight_critical_path_flag=true,
        title="$n Tender Fleet, Capacity $c - Moore Reef"
    )
    for (prob_t, (soln_t, n, c)) in zip(problem_t_fleet, soln_varied_t_fleet)
]
plot_vary_t_moore .|> display
for ((n, c), p) in zip(tender_fleet_config, plot_vary_t_moore)
    save("outputs/sensitivity/tenders/plot_tenders_moore_$(n)x$(c).png", p)
end

#########################################################
# Vary tender fleet size & capacity (Batt & Tongue)

problem_t_fleet_batt = load_problem.(
    Ref(target_path_alt),
    Ref(subset_path_alt),
    Ref(bathy_path),
    Ref(wave_disturbance_path_alt),
    Ref((145.6, -16.35)),
    Ref(-5.0),
    Ref(-2.0),
    Ref(0.2),
    Ref(0.075),
    reverse([1, 2, 3, 6]), # number of tenders
    [1, 2, 3, 6] # Vary tender cap;
);

soln_varied_t_fleet_batt = HierarchicalRouting.solve.(
    problem_t_fleet_batt;
    waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=4),
    seed=1234,
);

obj_vals_t_fleet_batt = HierarchicalRouting.critical_path.(
    soln_varied_t_fleet_batt, problem_t_fleet_batt
)

plot_vary_t_batt = Plot.solution.(
    problem_t_fleet_batt,
    soln_varied_t_fleet_batt;
    highlight_critical_path_flag=true,
    title="Varying Tender Fleet - Batt & Tongue"
)
plot_vary_t_batt .|> display

t_no_cap_batt_tongue = zip(
    getfield.(getfield.(problem_t_fleet_batt, :tenders), :number),
    getfield.(getfield.(problem_t_fleet_batt, :tenders), :capacity)
)

for (n, p) in zip(t_no_cap_batt_tongue, plot_vary_t_batt)
    save("outputs/sensitivity/tenders/plot_tenders_batt_tongue_$(n[1])x$(n[2]).png", p)
end

#########################################################
#########################################################
# # Vary tender cap ONLY
# problem_t_cap_only = load_problem.(
#     Ref(target_path),
#     Ref(subset_path),
#     Ref(bathy_path),
#     Ref(wave_disturbance_path),
#     Ref((146.175, -16.84)),
#     Ref(-5.0), # Ref(-2.5),
#     Ref(-2.0), # Ref(-1.0),
#     Ref(0.2),
#     Ref(0.075),
#     Ref(3), # number of tenders
#     [1, 2, 3, 4, 6, 8, 10] # Vary tender cap;
# );

# soln_varied_t_cap_only = HierarchicalRouting.solve.(
#     problem_t_cap_only;
#     waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=5),
#     seed=1234,
# );

# obj_vals_t_cap_only = HierarchicalRouting.critical_path.(
#     soln_varied_t_cap_only, problem_t_cap_only
# )

# HR.Plot.solution.(
#     problem_t_cap_only,
#     soln_varied_t_cap_only;
#     highlight_critical_path_flag=true,
#     title="Varying Tender Capacity ONLY - Moore Reef"
# ) .|> display

# #########################################################
# # Vary tender NUMBER
# problem_t_num = load_problem.(
#     Ref(target_path),
#     Ref(subset_path),
#     Ref(bathy_path),
#     Ref(wave_disturbance_path),
#     Ref((146.175, -16.84)),
#     Ref(-2.5),
#     Ref(-1.0),
#     Ref(0.2),
#     Ref(0.075),
#     [1, 2, 3, 4, 6, 8, 10], # Vary number of tenders
#     Ref(2) # Fixed tender cap;
# );

# soln_varied_t_num = HierarchicalRouting.solve.(
#     problem_t_num;
#     waypoint_optim_method=HR.Optim.ParticleSwarm(n_particles=5),
#     seed=1234,
# );

# obj_vals_t_num = HierarchicalRouting.critical_path.(
#     soln_varied_t_num, problem_t_num
# )

# HR.Plot.solution.(
#     problem_t_num,
#     soln_varied_t_num;
#     highlight_critical_path_flag=true,
#     title="Varying Tender Number - Moore Reef"
# ) .|> display

#########################################################
