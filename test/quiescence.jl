using Test
using Chess

if !isdefined(@__MODULE__, :quiescence)
    include(joinpath(@__DIR__, "..", "src", "minimax.jl"))
end

@testset "quiescence" begin
    # The queen can take the pawn, and the rook on d8 recaptures the queen.
    hanging = fromfen("3rk3/8/8/8/3p4/8/8/3QK3 w - - 0 1")
    @test tostring(move(hanging, 1)) != "d1d4"

    after = fromfen("3rk3/8/8/8/3Q4/8/8/4K3 b - - 0 1")
    static = material_score(after)
    resolved = quiescence(after, false, -Inf, Inf, 0, UInt64[], nothing, static)
    @test static > 0
    @test resolved < 0

    free = fromfen("4k3/8/8/8/3p4/8/8/3QK3 w - - 0 1")
    @test tostring(move(free, 1)) == "d1d4"

    promotion = fromfen("8/P7/8/8/8/8/8/k1K5 w - - 0 1")
    before = material_score(promotion)
    promoted = quiescence(promotion, true, -Inf, Inf, 0, UInt64[], nothing, before)
    @test promoted > before + 500
end
