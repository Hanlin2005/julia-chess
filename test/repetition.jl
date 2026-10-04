using Test
using Chess

if !isdefined(@__MODULE__, :repeated)
    include(joinpath(@__DIR__, "..", "src", "minimax.jl"))
end
if !isdefined(@__MODULE__, :rollout)
    include(joinpath(@__DIR__, "..", "src", "engine.jl"))
end

@testset "repetition" begin
    key = UInt64(0xabc)
    in_search = UInt64[0x1, 0x2, key, 0x3]
    @test repeated(in_search, key, 10, 4)
    @test !repeated(in_search, key, 10, 2)

    third = UInt64[key, 0x2, key, 0x4]
    @test repeated(third, key, 12, 0)
    @test !repeated(third, key, 2, 0)

    board = fromfen("2R5/1k3pQp/8/6P1/8/8/7P/4K3 w - - 0 51")
    board.r50 = UInt8(12)
    history = UInt64[board.key, 0x2, board.key, 0x4]
    @test minimax(board, 1, true, -Inf, Inf, 0, history) == 0
    @test length(history) == 4
    @test minimax(board, 1, true, -Inf, Inf, 0, UInt64[]) != 0

    # Queen and rook ahead. The black king steps b7-b6-b7 whenever that is legal.
    board = fromfen("2R5/1k3pQp/8/6P1/8/8/7P/4K3 w - - 9 51")
    board.r50 = UInt8(9)
    history = UInt64[]
    seen = Dict{UInt64,Int}()
    for _ in 1:8
        seen[board.key] = get(seen, board.key, 0) + 1
        @test seen[board.key] < 3
        isterminal(board) && break
        if sidetomove(board) == WHITE
            played = move(board, 7, history)
        else
            king = only(sq for sq in squares(kings(board)) if pcolor(pieceon(board, sq)) == BLACK)
            target = tostring(king) == "b6" ? "b7" : "b6"
            played = movefromstring(tostring(king) * target)
            played in moves(board) || break
        end
        push!(history, board.key)
        board = domove(board, played)
    end

    board = fromfen("2R5/1k3pQp/8/6P1/8/8/7P/4K3 w - - 0 51")
    board.r50 = UInt8(12)
    node = create_node(board)
    rollout(node, UInt64[board.key, 0x2, board.key, 0x4], 0)
    @test node.visits == 1
    @test node.value == 0
end
