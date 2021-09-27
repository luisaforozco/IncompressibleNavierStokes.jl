function operator_postprocessing!(setup)
    # construct postprocessing operators such as vorticity

    # boundary conditions
    bc =  setup.bc

    @unpack Nx, Ny = setup.grid
    @unpack hx, hy, gx, gy = setup.grid
    @unpack gxi, gyi, gxd, gyd = setup.grid

    order4 = setup.discretization.order4

    if order4
        α = setup.discretization.α
        β = setup.discretization.β
        gxi3 = setup.grid.gxi3
        gyi3 = setup.grid.gyi3
        Omvort3 = setup.grid.Omvort3
    end

    ## vorticity

    # operators act on internal points only
    #
    # du/dy, like Su_uy
    diag1 = 1 ./ gy[2:end-1]
    W1D = spdiagm(Ny - 1, Ny, 0 => -diag1, 1 => diag1)
    # extend to 2D
    Wu_uy = kron(W1D, sparse(I, Nx - 1, Nx - 1))

    # dv/dx, like Sv_vx
    diag1 = 1 ./ gx[2:end-1]
    W1D = spdiagm(Nx - 1, Nx, 0 => -diag1, 1 => diag1)
    # extend to 2D
    Wv_vx = kron(sparse(I, Ny - 1, Ny - 1), W1D)


    ## for periodic BC, covering entire mesh
    if bc.u.left == "per" && bc.v.low == "per"

        # du/dy, like Su_uy
        diag1 = 1 ./ gyd
        W1D = spdiagm(Ny + 1, Ny, -Ny => diag1, -1 => -diag1, 0 => diag1, Ny - 1 => -diag1)
        # extend to 2D
        diag2 = ones(Nx)
        Wu_uy = kron(W1D, spdiagm(Nx + 1, Nx, -Nx => diag2, 0 => diag2))

        # dv/dx, like Sv_vx
        diag1 = 1 ./ gxd
        W1D = spdiagm(Nx + 1, Nx, -Nx => diag1, -1 => -diag1, 0 => diag1, Nx - 1 => -diag1)
        # extend to 2D
        diag2 = ones(Ny)
        Wv_vx = kron(spdiagm(Ny + 1, Ny, -Ny => diag2, 0 => diag2), W1D)

    end

    setup.discretization.Wv_vx = Wv_vx
    setup.discretization.Wu_uy = Wu_uy

    setup
end
