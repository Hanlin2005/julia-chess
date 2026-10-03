using Test
using Chess

include(joinpath(@__DIR__, "..", "src", "minimax.jl"))
include(joinpath(@__DIR__, "..", "data", "test_puzzles.jl"))

@testset "optimal moves" begin
    for (id, rating, fen, expected, mate_in_one) in TEST_PUZZLES
        board = fromfen(fen)
        played = move(board, SEARCH_DEPTH)
        @testset "$id $rating" begin
            if mate_in_one
                @test ischeckmate(domove(board, played))
            else
                @test tostring(played) == expected
            end
        end
    end
end
