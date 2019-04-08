using SimpleDiffEq, StaticArrays, OrdinaryDiffEq, Test

function loop(u, p, t)
    @inbounds begin
        σ = p[1]; ρ = p[2]; β = p[3]
        du1 = σ*(u[2]-u[1])
        du2 = u[1]*(ρ-u[3]) - u[2]
        du3 = u[1]*u[2] - β*u[3]
        return SVector{3}(du1, du2, du3)
    end
end
function liip(du, u, p, t)
    σ = p[1]; ρ = p[2]; β = p[3]
    du[1] = σ*(u[2]-u[1])
    du[2] = u[1]*(ρ-u[3]) - u[2]
    du[3] = u[1]*u[2] - β*u[3]
    return nothing
end

u0 = 10ones(3)
dt = 1e-2

odeoop = ODEProblem{false}(loop, SVector{3}(u0), (0.0, 100.0),  [10, 28, 8/3])
odeiip = ODEProblem{true}(liip, u0, (0.0, 100.0),  [10, 28, 8/3])

oop = init(odeoop,SimpleATsit5(),dt=dt)
step!(oop); step!(oop)

iip = init(odeiip,SimpleATsit5(),dt=dt)
step!(iip); step!(iip)

deoop = DiffEqBase.init(odeoop, Tsit5(); dt = dt)
step!(deoop); step!(deoop)
@test oop.u ≈ deoop.u atol=1e-9
@test oop.t ≈ deoop.t atol=1e-9

deiip = DiffEqBase.init(odeiip, Tsit5(); dt = dt)
step!(deiip); step!(deiip)
@test iip.u ≈ deiip.u atol=1e-9
@test iip.t ≈ deiip.t atol=1e-9

sol = solve(odeoop,SimpleATsit5(),dt=dt)

# Test keywords:
oop = init(odeoop,SimpleATsit5(),dt=dt, reltol = 1e-9, abstol = 1e-9)
step!(oop); step!(oop)
deoop = DiffEqBase.init(odeoop, Tsit5(); dt = dt, reltol=1e-9, abstol=1e-9)
step!(deoop); step!(deoop)

@test oop.u ≈ deoop.u atol=1e-9
@test oop.t ≈ deoop.t atol=1e-9

# Test reinit!
reinit!(oop, odeoop.u0; dt = dt)
reinit!(iip, odeiip.u0; dt = dt)
step!(oop); step!(oop)
step!(iip); step!(iip)

@test oop.u ≈ deoop.u atol=1e-9
@test oop.t ≈ deoop.t atol=1e-9
@test iip.u ≈ deiip.u atol=1e-9
@test iip.t ≈ deiip.t atol=1e-9

# Interpolation tests
uprev = copy(oop.u)
step!(oop)
@test uprev ≈ oop(oop.tprev) atol = 1e-12
@test oop(oop.t) ≈ oop.u atol = 1e-12

uprev = copy(iip.u)
step!(iip)
@test uprev ≈ iip(iip.tprev) atol = 1e-12
@test iip(iip.t) ≈ iip.u atol = 1e-12

# Interpolation tests comparing Tsit5 and SimpleATsit5
function f(du,u,p,t)
    du[1] = 2.0*u[1] + 3.0*u[2]
    du[2] = 4.0*u[1] + 5.0*u[2]
end
tmp = [1.0;1.0]
tspan = (0.0,1.0)
prob = ODEProblem(f,tmp,tspan)
integ1 = init(prob, SimpleATsit5(), abstol = 1e-6, reltol = 1e-6, save_everystep = false, dt = 0.1)
integ2 = init(prob, Tsit5(), abstol = 1e-6, reltol = 1e-6, save_everystep = false, dt = 0.1)
step!(integ2)
step!(integ1)
for i in 1:9
    x = i/10
    y = 1 - x
    @test integ1(x * integ2.t + y * integ2.tprev) ≈ integ2(x * integ2.t + y * integ2.tprev) atol=1e-12
end
step!(integ2)
step!(integ1)
for i in 1:9
    x = i/10
    y = 1 - x
    @test integ1(x * integ2.t + y * integ2.tprev) ≈ integ2(x * integ2.t + y * integ2.tprev) atol=1e-12
end
###################################################################################
# Internal norm test:
function moop(u, p, t)
    x = loop(u[:, 1], p, t)
    y = loop(u[:, 2], p, t)
    return hcat(x,y)
end
function miip(du, u, p, t)
    @views begin
        liip(du[:, 1], u[:, 1], p, t)
        liip(du[:, 2], u[:, 2], p, t)
    end
    return nothing
end

ran = rand(SVector{3})
odemoop = ODEProblem{false}(moop, SMatrix{3,2}(hcat(u0, ran)), (0.0, 100.0),  [10, 28, 8/3])
odemiip = ODEProblem{true}(miip, hcat(u0, ran), (0.0, 100.0),  [10, 28, 8/3])

using LinearAlgebra

oop = init(odemoop,SimpleATsit5(),dt=dt, internalnorm = u -> norm(u[:, 1]))
step!(oop); step!(oop)

iip = init(odemiip,SimpleATsit5(),dt=dt, internalnorm = u -> norm(u[:, 1]))
step!(iip); step!(iip)

@test oop.u ≈ iip.u atol=1e-9
@test oop.t ≈ iip.t atol=1e-9

###################################################################################
# VectorVector test:
function vvoop(du, u, p, t) # takes Vector{SVector}
    @inbounds for j in 1:2
        du[j] = loop(u[j], p, t)
    end
    return nothing
end
function vviip(du, u, p, t) # takes Vector{Vector}
    @inbounds for j in 1:2
        liip(du[j], u[j], p, t)
    end
    return nothing
end

ran = rand(3)
odevoop = ODEProblem{true}(vvoop, [SVector{3}(u0),  SVector{3}(ran)], (0.0, 100.0),  [10, 28, 8/3])
odeviip = ODEProblem{true}(vviip, [u0, ran], (0.0, 100.0),  [10, 28, 8/3])

viip = init(odeviip,SimpleATsit5(),dt=dt; internalnorm = u -> SimpleDiffEq.defaultnorm(u[1]))
step!(viip); step!(viip)

iip = init(odeiip,SimpleATsit5(),dt=dt)
step!(iip); step!(iip)

@test iip.u ≈ viip.u[1] atol=1e-9

voop = init(odevoop,SimpleATsit5(),dt=dt,internalnorm = u -> SimpleDiffEq.defaultnorm(u[1]))
step!(voop); step!(voop)

oop = init(odeoop,SimpleATsit5(),dt=dt)
step!(oop); step!(oop)

@test oop.u ≈ voop.u[1] atol=1e-9

# Final test that the states of both methods should be the same:
@test voop.u[2] ≈ viip.u[2] atol=1e-9



# viip = init(odeviip,SimpleATsit5(),dt=dt; internalnorm = u -> SimpleDiffEq.defaultnorm(u[1]))
# step!(viip); step!(viip)
# x = Float64[]; y = Float64[]
# for i in 1:1000
#     step!(viip)
#     push!(x, viip.u[1][1])
#     push!(y, viip.u[1][2])
# end
# using PyPlot
# plot(x,y)
