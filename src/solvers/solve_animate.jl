"""
    solve_animate(
        problem::UnsteadyProblem, method;
        pressure_solver = DirectPressureSolver(problem.setup),
        Δt = nothing,
        cfl = 1,
        n_adapt_Δt = 1,
        processors = Processor[],
        method_startup = nothing,
        nstartup = 1,
        animator = RealTimePlotter(),
    )

Solve unsteady problem using `method`.

The time step is chosen every `n_adapt_Δt` iteration with CFL-number `cfl` if `Δt` is
`nothing`.

For methods that are not self-starting, `nstartup` startup iterations are performed with
`method_startup`.

Each `processor` is called after every `processor.nupdate` time step.
"""
function solve_animate(
    problem::UnsteadyProblem,
    method;
    pressure_solver = DirectPressureSolver(problem.setup),
    Δt = nothing,
    cfl = 1,
    n_adapt_Δt = 1,
    method_startup = nothing,
    nstartup = 1,
    animator = RealTimePlotter(),
    filename = "output/vorticity.gif",
    nframe = 200,
    nsubframe = 4,
    framerate = 20,
)
    (; setup, V₀, p₀, tlims) = problem
    
    t_start, t_end = tlims
    isadaptive = isnothing(Δt)

    # For methods that need a velocity field at n-1 the first time step
    # (e.g. AB-CN, oneleg beta) use ERK or IRK
    if needs_startup_method(method)
        println("Starting up with method $(method_startup)")
        method_use = method_startup
    else
        method_use = method
    end

    cache = ode_method_cache(method_use, setup)
    momentum_cache = MomentumCache(setup)
    stepper = TimeStepper(;
        method = method_use,
        setup,
        pressure_solver,
        V = copy(V₀),
        p = copy(p₀),
        t = copy(t_start),
        Vₙ = copy(V₀),
        pₙ = copy(p₀),
        tₙ = copy(t_start),
    )
    isadaptive && (Δt = get_timestep(stepper, cfl))

    # Initialize BC arrays
    set_bc_vectors!(setup, stepper.t)

    initialize!(animator, stepper)
    process!(animator, stepper)

    fig = current_figure()

    record(fig, filename, 1:nframe; framerate) do frame
        for subframe = 1:nsubframe
            if stepper.n == nstartup && needs_startup_method(method)
                println("n = $(stepper.n): switching to primary ODE method ($method)")
                cache = ode_method_cache(method, setup)
                stepper = change_time_stepper(stepper, method)
            end

            # Change timestep based on operators
            if isadaptive && rem(stepper.n, n_adapt_Δt) == 0 
                Δt = get_timestep(stepper, cfl)
            end

            # Perform a single time step with the time integration method
            stepper = step!(stepper, Δt; cache, momentum_cache)
        end

        process!(animator, stepper)
    end

    (; V, p) = stepper
    V, p
end