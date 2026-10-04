using Test
using Chess
using Random

if !isdefined(@__MODULE__, :update_score)
    include(joinpath(@__DIR__, "..", "src", "minimax.jl"))
end

function same_score(board, move)
    update_score(board, move, material_score(board)) == material_score(domove(board, move))
end

@testset "piece square score" begin
    @test material_score(startboard()) == 0

    board = startboard()
    score = material_score(board)
    for uci in ("e2e4", "e7e5", "g1f3", "b8c6")
        move = movefromstring(uci)
        score = update_score(board, move, score)
        board = domove(board, move)
        @test score == material_score(board)
    end

    capture = fromfen("4k3/8/8/3p4/4P3/8/8/4K3 w - - 0 1")
    @test same_score(capture, movefromstring("e4d5"))

    promotion = fromfen("8/P7/8/8/8/8/8/k1K5 w - - 0 1")
    @test same_score(promotion, movefromstring("a7a8q"))

    castle = fromfen("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")
    @test same_score(castle, movefromstring("e1g1"))
    @test same_score(castle, movefromstring("e1c1"))

    en_passant = fromfen("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3")
    ep = movefromstring("e5d6")
    @test moveisep(en_passant, ep)
    @test same_score(en_passant, ep)

    board = startboard()
    score = material_score(board)
    Random.seed!(1)
    for _ in 1:40
        legal = collect(moves(board))
        isempty(legal) && break
        move = legal[rand(1:length(legal))]
        score = update_score(board, move, score)
        board = domove(board, move)
        @test score == material_score(board)
    end

    board = startboard()
    best = maximum(material_score(domove(board, move)) for move in moves(board))
    @test minimax(board, 1, true) == best
end
