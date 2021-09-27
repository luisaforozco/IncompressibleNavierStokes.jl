function operator_convection_diffusion!(setup)
    # construct convection and diffusion operators

    # boundary conditions
    bc = setup.bc

    # number of interior points and boundary points
    @unpack Nx, Ny = setup.grid
    @unpack Nu, Nux_in, Nux_b, Nux_t, Nuy_in, Nuy_b, Nuy_t = setup.grid
    @unpack Nv, Nvx_in, Nvx_b, Nvx_t, Nvy_in, Nvy_b, Nvy_t = setup.grid
    @unpack hx, hy, hxi, hyi, hxd, hyd = setup.grid
    @unpack gxi, gyi, gxd, gyd = setup.grid
    @unpack Buvy, Bvux = setup.grid

    order4 = setup.discretization.order4

    if order4
        α = setup.discretization.α
        @unpack hxi3, hyi3, gxi3, gyi3, hxd13, hxd3, hyd13, hyd3 = setup.grid
        @unpack gxd13, gxd3, gyd13, gyd3 = setup.grid
        @unpack Omux, Omuy, Omvx, Omvy = setup.grid
        @unpack Omux1, Omux3, Omuy1, Omuy3, Omvx1, Omvx3, Omvy1, Omvy3 = setup.grid
    end

    visc = setup.case.visc
    Re = setup.fluid.Re

    ## Convection (differencing) operator Cu

    # calculates difference from pressure points to velocity points
    diag1 = ones(Nux_t - 2)
    D1D = spdiagm(Nux_t - 2, Nux_t - 1, 0 => -diag1, 1 => diag1)
    Cux = kron(sparse(I, Nuy_in, Nuy_in), D1D)
    if !order4
        Dux = kron(spdiagm(Ny, Ny, hyi), D1D)
    end

    # calculates difference from corner points to velocity points
    diag1 = ones(Nuy_t - 2)
    D1D = spdiagm(Nuy_t - 2, Nuy_t - 1, 0 => -diag1, 1 => diag1)
    Cuy = kron(D1D, sparse(I, Nux_in, Nux_in))
    if !order4
        Duy = kron(D1D, spdiagm(Nux_in, Nux_in, gxi))
    end

    # Cu = [Cux Cuy];
    # Du = [Dux Duy];

    ## Convection (differencing) operator Cv

    # calculates difference from pressure points to velocity points
    diag1 = ones(Nvx_t - 2)
    D1D = spdiagm(Nvx_t - 2, Nvx_t - 1, 0 => -diag1, 1 => diag1)
    Cvx = kron(sparse(I, Nvy_in, Nvy_in), D1D)
    if !order4
        Dvx = kron(spdiagm(Nvy_in, Nvy_in, gyi), D1D)
    end

    # calculates difference from corner points to velocity points
    diag1 = ones(Nvy_t - 2)
    D1D = spdiagm(Nvy_t - 2, Nvy_t - 1, 0 => -diag1, 1 => diag1)
    Cvy = kron(D1D, sparse(I, Nvx_in, Nvx_in))
    if !order4
        Dvy = kron(D1D, spdiagm(Nx, Nx, hxi))
    end

    # Cv = [Cvx Cvy];
    # Dv = [Dvx Dvy];

    if !order4
        ## Diffusion operator (stress tensor), u-component
        # similar to averaging, but with mesh sizes

        ## Su_ux: evaluate ux
        diag1 = 1 ./ hxd
        S1D = spdiagm(Nux_t - 1, Nux_t, 0 => -diag1, 1 => diag1)

        # boundary conditions
        Su_ux_bc = bc_general(Nux_t, Nux_in, Nux_b, bc.u.left, bc.u.right, hx[1], hx[end])

        # extend to 2D
        Su_ux = kron(sparse(I, Ny, Ny), S1D * Su_ux_bc.B1D)
        Su_ux_bc = (; Su_ux_bc..., Bbc = kron(sparse(I, Ny, Ny), S1D * Su_ux_bc.Btemp))

        ## Su_uy: evaluate uy
        diag1 = 1 ./ gyd
        S1D = spdiagm(Nuy_t - 1, Nuy_t, 0 => -diag1, 1 => diag1)

        # boundary conditions
        # Su_uy_bc = bc_general_stag(Nuy_t, Nuy_in, Nuy_b, bc.u.low, bc.u.up, hy[1], hy[end]);
        Su_uy_bc = bc_diff_stag(Nuy_t, Nuy_in, Nuy_b, bc.u.low, bc.u.up, hy[1], hy[end])

        # extend to 2D
        Su_uy = kron(S1D * Su_uy_bc.B1D, sparse(I, Nux_in, Nux_in))
        Su_uy_bc =
            (; Su_uy_bc..., Bbc = kron(S1D * Su_uy_bc.Btemp, sparse(I, Nux_in, Nux_in)))

        ## Sv_uy: evaluate vx at uy;
        # same as Iv_uy except for mesh sizes and -diag diag

        diag1 = 1 ./ gxd
        S1D = spdiagm(Nvx_t - 1, Nvx_t, 0 => -diag1, 1 => diag1)
        # the restriction is essentially 1D so it can be directly applied to I1D
        S1D = Bvux * S1D
        S2D = kron(sparse(I, Nuy_t - 1, Nuy_t - 1), S1D)


        # boundary conditions low/up
        Nb = Nuy_in + 1 - Nvy_in
        Sv_uy_bc_lu = bc_general(Nuy_in + 1, Nvy_in, Nb, bc.v.low, bc.v.up, hy[1], hy[end])
        Sv_uy_bc_lu =
            (; Sv_uy_bc_lu..., B2D = kron(Sv_uy_bc_lu.B1D, sparse(I, Nvx_in, Nvx_in)))
        Sv_uy_bc_lu =
            (; Sv_uy_bc_lu..., Bbc = kron(Sv_uy_bc_lu.Btemp, sparse(I, Nvx_in, Nvx_in)))

        # boundary conditions left/right
        Sv_uy_bc_lr =
            bc_general_stag(Nvx_t, Nvx_in, Nvx_b, bc.v.left, bc.v.right, hx[1], hx[end])
        # take I2D into left/right operators for convenience
        Sv_uy_bc_lr = (;
            Sv_uy_bc_lr...,
            B2D = S2D * kron(sparse(I, Nuy_t - 1, Nuy_t - 1), Sv_uy_bc_lr.B1D),
        )
        Sv_uy_bc_lr = (;
            Sv_uy_bc_lr...,
            Bbc = S2D * kron(sparse(I, Nuy_t - 1, Nuy_t - 1), Sv_uy_bc_lr.Btemp),
        )

        # resulting operator:
        Sv_uy = Sv_uy_bc_lr.B2D * Sv_uy_bc_lu.B2D

        ## Diffusion operator (stress tensor), v-component
        # similar to averaging!

        ## Su_vx: evaluate uy at vx
        # same as Iu_vx except for mesh sizes and -diag diag

        diag1 = 1 ./ gyd
        S1D = spdiagm(Nuy_t - 1, Nuy_t, 0 => -diag1, 1 => diag1)
        S1D = Buvy * S1D
        S2D = kron(S1D, sparse(I, Nvx_t - 1, Nvx_t - 1))

        # boundary conditions low/up
        Su_vx_bc_lu =
            bc_general_stag(Nuy_t, Nuy_in, Nuy_b, bc.u.low, bc.u.up, hy[1], hy[end])
        Su_vx_bc_lu = (;
            Su_vx_bc_lu...,
            B2D = S2D * kron(Su_vx_bc_lu.B1D, sparse(I, Nvx_t - 1, Nvx_t - 1)),
        )
        Su_vx_bc_lu = (;
            Su_vx_bc_lu...,
            Bbc = S2D * kron(Su_vx_bc_lu.Btemp, sparse(I, Nvx_t - 1, Nvx_t - 1)),
        )

        # boundary conditions left/right
        Nb = Nvx_in + 1 - Nux_in
        Su_vx_bc_lr =
            bc_general(Nvx_in + 1, Nux_in, Nb, bc.u.left, bc.u.right, hx[1], hx[end])

        Su_vx_bc_lr =
            (; Su_vx_bc_lr..., B2D = kron(sparse(I, Nuy_in, Nuy_in), Su_vx_bc_lr.B1D))
        Su_vx_bc_lr =
            (; Su_vx_bc_lr..., Bbc = kron(sparse(I, Nuy_in, Nuy_in), Su_vx_bc_lr.Btemp))

        # resulting operator:
        Su_vx = Su_vx_bc_lu.B2D * Su_vx_bc_lr.B2D

        ## Sv_vx: evaluate vx
        diag1 = 1 ./ gxd
        S1D = spdiagm(Nvx_t - 1, Nvx_t, 0 => -diag1, 1 => diag1)

        # boundary conditions
        # Sv_vx_bc = bc_general_stag(Nvx_t, Nvx_in, Nvx_b, #                                            bc.v.left, bc.v.right, hx[1], hx[end]);
        Sv_vx_bc = bc_diff_stag(Nvx_t, Nvx_in, Nvx_b, bc.v.left, bc.v.right, hx[1], hx[end])

        # extend to 2D
        Sv_vx = kron(sparse(I, Nvy_in, Nvy_in), S1D * Sv_vx_bc.B1D)
        Sv_vx_bc =
            (; Sv_vx_bc..., Bbc = kron(sparse(I, Nvy_in, Nvy_in), S1D * Sv_vx_bc.Btemp))

        ## Sv_vy: evaluate vy
        diag1 = 1 ./ hyd
        S1D = spdiagm(Nvy_t - 1, Nvy_t, 0 => -diag1, 1 => diag1)

        # boundary conditions
        Sv_vy_bc = bc_general(Nvy_t, Nvy_in, Nvy_b, bc.v.low, bc.v.up, hy[1], hy[end])

        # extend to 2D
        Sv_vy = kron(S1D * Sv_vy_bc.B1D, sparse(I, Nx, Nx))
        Sv_vy_bc = (; Sv_vy_bc..., Bbc = kron(S1D * Sv_vy_bc.Btemp, sparse(I, Nx, Nx)))
    end

    ## fourth order operators
    if order4
        ## Convection (differencing) operator Cu

        # calculates difference from pressure points to velocity points
        diag1 = ones(Nux_t)
        D1D = spdiagm(Nux_t - 2, Nux_t + 1, 1 => -diag1, 2 => diag1)
        Dux = kron(spdiagm(Ny, Ny, hyi), D1D)
        # the "second order" Cux is unchanged
        # the "second order" Dux changes, because we also use the "second
        # order" flux at "fourth order" ghost points (Dux should have the same
        # size as Dux3)

        # calculates difference from pressure points to velocity points
        diag1 = ones(Nux_t)
        D1D3 = spdiagm(Nux_t - 2, Nux_t + 1, 0 => -diag1, 3 => diag1)
        Cux3 = kron(sparse(I, Ny, Ny), D1D3)
        Dux3 = kron(spdiagm(Ny, Ny, hyi3), D1D3)

        # calculates difference from corner points to velocity points
        diag1 = ones(Nuy_t)
        D1D = spdiagm(Nuy_t - 2, Nuy_t + 1, 1 => -diag1, 2 => diag1)
        Duy = kron(D1D, spdiagm(Nux_in, Nux_in, gxi, 0))

        # calculates difference from corner points to velocity points
        diag1 = ones(Nuy_t)
        D1D3 = spdiagm(Nuy_t - 2, Nuy_t + 1, 0 => -diag1, 3 => diag1)
        # uncomment for new BC (functions/new)
        if bc.u.low == "dir"
            D1D3[1, 1] = 1
            D1D3[1, 2] = -2
        end
        if bc.u.up == "dir"
            D1D3[end, end-1] = 2
            D1D3[end, end] = -1
        end
        Cuy3 = kron(D1D3, sparse(I, Nux_in, Nux_in))
        Duy3 = kron(D1D3, spdiagm(Nux_in, Nux_in, gxi3))

        ## Convection (differencing) operator Cv

        # calculates difference from pressure points to velocity points
        diag1 = ones(Nvx_t)
        D1D = spdiagm(Nvx_t - 2, Nvx_t + 1, 1 => -diag1, 2 => diag1)
        Dvx = kron(spdiagm(Nvy_in, Nvy_in, gyi), D1D)

        # calculates difference from pressure points to velocity points
        diag1 = ones(Nvx_t)
        D1D3 = spdiagm(Nvx_t - 2, Nvx_t + 1, 0 => -diag1, 3 => diag1)
        # uncomment for new BC (functions/new)
        if bc.v.left == "dir"
            D1D3[1, 1] = 1
            D1D3[1, 2] = -2
        end
        if bc.v.right == "dir"
            D1D3[end, end-1] = 2
            D1D3[end, end] = -1
        end
        Cvx3 = kron(sparse(I, Nvy_in, Nvy_in), D1D3)
        Dvx3 = kron(spdiagm(Nvy_in, Nvy_in, gyi3), D1D3)

        # calculates difference from corner points to velocity points
        diag1 = ones(Nvy_t, 1)
        D1D = spdiagm(Nvy_t - 2, Nvy_t + 1, 1 => -diag1, 2 => diag1)
        Dvy = kron(D1D, spdiagm(Nx, Nx, hxi))

        # calculates difference from corner points to velocity points
        diag1 = ones(Nvy_t, 1)
        D1D3 = spdiagm(Nvy_t - 2, Nvy_t + 1, 0 => -diag1, 3 => diag1)
        Cvy3 = kron(D1D3, sparse(I, Nvx_in, Nvx_in))
        Dvy3 = kron(D1D3, spdiagm(Nx, Nx, hxi3))

        ## Su_ux: evaluate ux
        diag1 = 1 ./ hxd13
        S1D = spdiagm(Nux_in + 3, Nux_t + 4, 1 => -diag1, 2 => diag1)

        # boundary conditions
        Su_ux_bc = bc_diff3(
            Nux_t + 4,
            Nux_in,
            Nux_t + 4 - Nux_in,
            bc.u.left,
            bc.u.right,
            hx[1],
            hx[end],
        )

        # extend to 2D
        Su_ux = spdiagm(Omux1) * kron(sparse(I, Ny, Ny), S1D * Su_ux_bc.B1D)
        Su_ux_bc = (;
            Su_ux_bc...,
            Bbc = spdiagm(Omux1) * kron(sparse(I, Ny, Ny), S1D * Su_ux_bc.Btemp),
        )

        diag1 = 1 ./ hxd3
        S1D3 = spdiagm(Nux_in + 3, Nux_t + 4, 0 => -diag1, 3 => diag1)

        # boundary conditions
        Su_ux_bc3 = bc_diff3(
            Nux_t + 4,
            Nux_in,
            Nux_t + 4 - Nux_in,
            bc.u.left,
            bc.u.right,
            hx[1],
            hx[end],
        )
        # extend to 2D
        Su_ux3 = spdiagm(Omux3) * kron(sparse(I, Nuy_in, Nuy_in), S1D3 * Su_ux_bc3.B1D)
        Su_ux_bc3.Bbc =
            spdiagm(Omux3) * kron(sparse(I, Nuy_in, Nuy_in), S1D3 * Su_ux_bc3.Btemp)

        ## Su_uy: evaluate uy
        diag1 = 1 ./ gyd13
        S1D = spdiagm(Nuy_in + 3, Nuy_t + 4, 1 => -diag1, 2 => diag1)
        # boundary conditions
        Su_uy_bc = bc_diff_stag3(
            Nuy_t + 4,
            Nuy_in,
            Nuy_t + 4 - Nuy_in,
            bc.u.low,
            bc.u.up,
            hy[1],
            hy[end],
        )
        # extend to 2D
        Su_uy = spdiagm(Omuy1) * kron(S1D * Su_uy_bc.B1D, sparse(I, Nux_in, Nux_in))
        Su_uy_bc.Bbc =
            spdiagm(Omuy1) * kron(S1D * Su_uy_bc.Btemp, sparse(I, Nux_in, Nux_in))

        diag1 = 1 ./ gyd3
        S1D3 = spdiagm(Nuy_in + 3, Nuy_t + 4, 0 => -diag1, 3 => diag1)
        # boundary conditions
        Su_uy_bc3 = bc_diff_stag3(
            Nuy_t + 4,
            Nuy_in,
            Nuy_t + 4 - Nuy_in,
            bc.u.low,
            bc.u.up,
            hy[1],
            hy[end],
        )
        # extend to 2D
        Su_uy3 = spdiagm(Omuy3) * kron(S1D3 * Su_uy_bc3.B1D, sparse(I, Nux_in, Nux_in))
        Su_uy_bc3.Bbc =
            spdiagm(Omuy3) * kron(S1D3 * Su_uy_bc3.Btemp, sparse(I, Nux_in, Nux_in))

        ## Sv_vx: evaluate vx
        diag1 = 1 ./ gxd13
        S1D = spdiagm(Nvx_in + 3, Nvx_t + 4, 1 => -diag1, 2 => diag1)

        # boundary conditions
        Sv_vx_bc = bc_diff_stag3(
            Nvx_t + 4,
            Nvx_in,
            Nvx_t + 4 - Nvx_in,
            bc.v.left,
            bc.v.right,
            hx[1],
            hx[end],
        )

        # extend to 2D
        Sv_vx = spdiagm(Omvx1) * kron(sparse(I, Nvy_in, Nvy_in), S1D * Sv_vx_bc.B1D)
        Sv_vx_bc.Bbc =
            spdiagm(Omvx1) * kron(sparse(I, Nvy_in, Nvy_in), S1D * Sv_vx_bc.Btemp)

        diag1 = 1 ./ gxd3
        S1D3 = spdiagm(Nvx_in + 3, Nvx_t + 4, 0 => -diag1, 3 => diag1)

        # boundary conditions
        Sv_vx_bc3 = bc_diff_stag3(
            Nvx_t + 4,
            Nvx_in,
            Nvx_t + 4 - Nvx_in,
            bc.v.left,
            bc.v.right,
            hx[1],
            hx[end],
        )
        # extend to 2D
        Sv_vx3 = spdiagm(Omvx3) * kron(sparse(I, Nvy_in, Nvy_in), S1D3 * Sv_vx_bc3.B1D)
        Sv_vx_bc3.Bbc =
            spdiagm(Omvx3) * kron(sparse(I, Nvy_in, Nvy_in), S1D3 * Sv_vx_bc3.Btemp)

        ## Sv_vy: evaluate vy
        diag1 = 1 ./ hyd13
        S1D = spdiagm(Nvy_in + 3, Nvy_t + 4, 1 => -diag1, 2 => diag1)

        # boundary conditions
        Sv_vy_bc = bc_diff3(
            Nvy_t + 4,
            Nvy_in,
            Nvy_t + 4 - Nvy_in,
            bc.v.low,
            bc.v.up,
            hy[1],
            hy[end],
        )

        # extend to 2D
        Sv_vy = spdiagm(Omvy1) * kron(S1D * Sv_vy_bc.B1D, sparse(I, Nvx_in, Nvx_in))
        Sv_vy_bc.Bbc =
            spdiagm(Omvy1) * kron(S1D * Sv_vy_bc.Btemp, sparse(I, Nvx_in, Nvx_in))

        diag1 = 1 ./ hyd3
        S1D3 = spdiagm(Nvy_in + 3, Nvy_t + 4, 0 => -diag1, 3 => diag1)

        # boundary conditions
        # Su_uy_bc = bc_general_stag(Nuy_t, Nuy_in, Nuy_b, #                                            bc.u.low, bc.u.up, hy[1], hy[end]);
        Sv_vy_bc3 = bc_diff3(
            Nvy_t + 4,
            Nvy_in,
            Nvy_t + 4 - Nvy_in,
            bc.v.low,
            bc.v.up,
            hy[1],
            hy[end],
        )
        # extend to 2D
        Sv_vy3 = spdiagm(Omvy3) * kron(S1D3 * Sv_vy_bc3.B1D, sparse(I, Nvx_in, Nvx_in))
        Sv_vy_bc3.Bbc =
            spdiagm(Omvy3) * kron(S1D3 * Sv_vy_bc3.Btemp, sparse(I, Nvx_in, Nvx_in))
    end

    ## assemble operators
    if visc == "laminar"
        if !order4
            Diffu = Dux * 1 / Re * Su_ux + Duy * 1 / Re * Su_uy
            Diffv = Dvx * 1 / Re * Sv_vx + Dvy * 1 / Re * Sv_vy
        elseif order4
            Diffux_div = (α * Dux - Dux3) * spdiagm(1 ./ Omux)
            Diffuy_div = (α * Duy - Duy3) * spdiagm(1 ./ Omuy)
            Diffvx_div = (α * Dvx - Dvx3) * spdiagm(1 ./ Omvx)
            Diffvy_div = (α * Dvy - Dvy3) * spdiagm(1 ./ Omvy)
            Diffu =
                1 / Re * Diffux_div * (α * Su_ux - Su_ux3) +
                1 / Re * Diffuy_div * (α * Su_uy - Su_uy3)
            Diffv =
                1 / Re * Diffvx_div * (α * Sv_vx - Sv_vx3) +
                1 / Re * Diffvy_div * (α * Sv_vy - Sv_vy3)
        end
    elseif visc ∈ ["keps", "LES", "qr", "ML"]
        # only implemented for 2nd order
        # the terms below are an example of how the laminar case is
        # evaluated with the full stress tensor
        # these are not used in practical computations, as in the turbulent
        # case one needs to add nu_T, making the effective operator
        # solution-dependent, so that it cannot be computed beforehand
        # see diffusion.m for actual use
        # # diffusion u-momentum
        # Diffu_u = Dux*( (1/Re) * 2*Su_ux) + Duy*( (1/Re) * Su_uy);
        # Diffu_v = Duy*( (1/Re) * Sv_uy);
        # # diffusion v-momentum
        # Diffv_u = Dvx*( (1/Re) * Su_vx);
        # Diffv_v = Dvx*( (1/Re) * Sv_vx) + Dvy*( (1/Re) * 2*Sv_vy);
    else
        error("wrong visc parameter")
    end

    setup.discretization.Cux = Cux
    setup.discretization.Cuy = Cuy
    setup.discretization.Cvx = Cvx
    setup.discretization.Cvy = Cvy
    setup.discretization.Su_ux = Su_ux
    setup.discretization.Su_uy = Su_uy
    setup.discretization.Sv_vx = Sv_vx
    setup.discretization.Sv_vy = Sv_vy
    setup.discretization.Su_ux_bc = Su_ux_bc
    setup.discretization.Su_uy_bc = Su_uy_bc
    setup.discretization.Sv_vx_bc = Sv_vx_bc
    setup.discretization.Sv_vy_bc = Sv_vy_bc
    setup.discretization.Dux = Dux
    setup.discretization.Duy = Duy
    setup.discretization.Dvx = Dvx
    setup.discretization.Dvy = Dvy

    if visc == "laminar"
        setup.discretization.Diffu = Diffu
        setup.discretization.Diffv = Diffv
    elseif visc ∈ ["keps", "LES", "qr", "ML"]
        setup.discretization.Sv_uy = Sv_uy
        setup.discretization.Su_vx = Su_vx
        # setup.discretization.Diffu_u = Diffu_u;
        # setup.discretization.Diffu_v = Diffu_v;
        # setup.discretization.Diffv_u = Diffv_u;
        # setup.discretization.Diffv_v = Diffv_v;
    end

    if order4
        setup.discretization.Cux3 = Cux3
        setup.discretization.Cuy3 = Cuy3
        setup.discretization.Cvx3 = Cvx3
        setup.discretization.Cvy3 = Cvy3
        setup.discretization.Su_ux_bc3 = Su_ux_bc3
        setup.discretization.Su_uy_bc3 = Su_uy_bc3
        setup.discretization.Sv_vx_bc3 = Sv_vx_bc3
        setup.discretization.Sv_vy_bc3 = Sv_vy_bc3
        setup.discretization.Diffux_div = Diffux_div
        setup.discretization.Diffuy_div = Diffuy_div
        setup.discretization.Diffvx_div = Diffvx_div
        setup.discretization.Diffvy_div = Diffvy_div
    else
        setup.discretization.Su_vx_bc_lr = Su_vx_bc_lr
        setup.discretization.Su_vx_bc_lu = Su_vx_bc_lu
        setup.discretization.Sv_uy_bc_lr = Sv_uy_bc_lr
        setup.discretization.Sv_uy_bc_lu = Sv_uy_bc_lu
    end

    ## additional for implicit time stepping diffusion
    if setup.time.method == 2 && visc == "laminar"
        θ = setup.time.θ
        dt = setup.time.dt
        Omu_inv = setup.grid.Omu_inv
        Omv_inv = setup.grid.Omv_inv
        # implicit time-stepping for diffusion
        # solving (I-dt*Diffu)*uh* =
        Diffu_impl = sparse(I, Nu, Nu) - θ * dt * spdiagm(Omu_inv) * Diffu
        Diffv_impl = sparse(I, Nv, Nv) - θ * dt * spdiagm(Omv_inv) * Diffv

        # LU decomposition
        setup.discretization.lu_diffu = lu(Diffu_impl)
        setup.discretization.lu_diffv = lu(Diffv_impl)
    end

    setup
end
