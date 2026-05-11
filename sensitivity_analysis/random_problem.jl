
problem_instances = Vector{HR.Problem}(undef, 10);
@time for i in 1:length(problem_instances) # Time ~= 0.4-0.5 sec per instance
    problem_instances[i] = HR.generate_randomised_problem(
        subset_path,
        bathy_path,
        wave_disturbance_path,
        (146.175, -16.84),
        -5.0,
        -2.0,
        0.2,
        0.1,
        3,
        2;
        no_target_pts=29,
        points_buffer_dist=1E-3,
        debug_mode=true)
end

# Plot instances
@time for i in 1:length(problem_instances) # Time ~= 20-25 sec
    HR.Plot.problem(
        problem_instances[i];
        labels=false,
        title="Random Problem Instance $i"
    ) |> display
    # save("outputs/RandomProblems/problem_$i.png", fig)
end

waypoint_optim_method = HR.Optim.ParticleSwarm(n_particles=6)

solution_instances = Vector{HR.MSTSolution}(undef, length(problem_instances));
solution_figs = Vector{HR.Plot.Figure}(undef, length(problem_instances));
for i in 1:length(problem_instances)
    @time solution_instances[i] = HR.solve(
        problem_instances[i];
        waypoint_optim_method,
        seed=1234,
        wpt_optim_plot_flag=true,
        soln_progress_plot_flag=true,
    )
    solution_figs[i] = HR.Plot.solution(
        problem_instances[i],
        solution_instances[i];
        highlight_critical_path_flag=true,
        title="Solution to Random Problem Instance $i",
    )
    display(solution_figs[i])
    # save("outputs/RandomProblems/solution_$i.png", fig)
end

##############################
#### Test for same random seed
problem_instances_a_test = Vector{HR.Problem}(undef, 100);
@time for i in 1:length(problem_instances_a_test)
    problem_instances_a_test[i] = HR.generate_randomised_problem(
        subset_path,
        bathy_path,
        wave_disturbance_path,
        (146.175, -16.84),
        -5.0,
        -2.0,
        0.2,
        0.1,
        3,
        2;
        no_target_pts=29,
        points_buffer_dist=1E-3,
        debug_mode=true,
        seed=i
    )
end

problem_instances_b_test = Vector{HR.Problem}(undef, 100);
@time for i in 1:length(problem_instances_b_test)
    problem_instances_b_test[i] = HR.generate_randomised_problem(
        subset_path,
        bathy_path,
        wave_disturbance_path,
        (146.175, -16.84),
        -5.0,
        -2.0,
        0.2,
        0.1,
        3,
        2;
        no_target_pts=29,
        points_buffer_dist=1E-3,
        debug_mode=true,
        seed=i
    )
end

all(
    getfield.(getfield.(problem_instances_a_test, :targets), :points) .==
    getfield.(getfield.(problem_instances_b_test, :targets), :points)
)
