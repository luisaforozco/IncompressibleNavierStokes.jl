"""
    reate_boundary_conditions!(setup)

Create discrete boundary condtions.
"""
function create_boundary_conditions!(setup)
    # Get BC type
    bc = setup.bc.bc_type()
    for (key, value) ∈ zip(keys(bc), bc)
        setfield!(setup.bc, key, value)
    end
    setup.bc.u.left ∈ ["dir", "per", "pres"] || error("wrong BC for u-left")
    setup.bc.u.right ∈ ["dir", "per", "pres"] || error("wrong BC for u-right")
    setup.bc.u.low ∈ ["dir", "per", "sym"] || error("wrong BC for u-low")
    setup.bc.u.up ∈ ["dir", "per", "sym"] || error("wrong BC for u-up")
    setup.bc.v.left ∈ ["dir", "per", "sym"] || error("wrong BC for v-left")
    setup.bc.v.right ∈ ["dir", "per", "sym"] || error("wrong BC for v-right")
    setup.bc.v.low ∈ ["dir", "per", "pres"] || error("wrong BC for v-low")
    setup.bc.v.up ∈ ["dir", "per", "pres"] || error("wrong BC for v-up")

    ## set BC functions

    # values set below can be either Dirichlet or Neumann value,
    # depending on BC set above. in case of Neumann (symmetry, pressure)
    # one uses normally zero gradient

    # values should either be scalars or vectors
    # ALL VALUES (u, v, p, k, e) are defined at x, y locations,
    # i.e. the corners of pressure volumes, so they cover the entire domain
    # including corners

    ## pressure
    # pressure BC is only used when at the corresponding boundary
    # "pres" is specified
    p_inf = 0
    pLe = p_inf
    pRi = p_inf
    pLo = p_inf
    pUp = p_inf

    setup.bc.pLe = pLe
    setup.bc.pRi = pRi
    setup.bc.pLo = pLo
    setup.bc.pUp = pUp

    ## k-eps values
    if setup.case.visc == "keps"
        kLo = 0
        kUp = 0
        kLe = 0
        kRi = 0

        eLo = 0
        eUp = 0
        eLe = 0
        eRi = 0

        setup.bc.kLe = kLe
        setup.bc.kRi = kRi
        setup.bc.kLo = kLo
        setup.bc.kUp = kUp

        setup.bc.eLe = eLe
        setup.bc.eRi = eRi
        setup.bc.eLo = eLo
        setup.bc.eUp = eUp
    end

    setup
end
