using Test

if isempty(ARGS)
    search_depth = 3
elseif length(ARGS) == 1
    search_depth = tryparse(Int, ARGS[1])
    if search_depth === nothing || search_depth < 1
        error("depth must be an integer of at least 1")
    end
else
    error("Usage: julia --project=. test/runtests.jl [depth]")
end

const SEARCH_DEPTH = search_depth

@testset "JuliaChess" begin
    include("nnue.jl")
    include("optimal_moves.jl")
    include("repetition.jl")
end
