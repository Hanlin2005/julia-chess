using Test
using Chess

if !isdefined(@__MODULE__, :store!)
    include(joinpath(@__DIR__, "..", "src", "minimax.jl"))
end
if !isdefined(@__MODULE__, :choose_move)
    include(joinpath(@__DIR__, "..", "src", "searches.jl"))
end

@testset "transposition table" begin
    table = TranspositionTable(8)
    @test probe(table, UInt64(1), 1, -Inf, Inf, 0).hit == false

    store!(table, UInt64(1), 3, 5.0, EXACT, MOVE_NULL)
    exact = probe(table, UInt64(1), 3, -Inf, Inf, 0)
    @test exact.cutoff
    @test exact.score == 5

    shallow = probe(table, UInt64(1), 4, -Inf, Inf, 0)
    @test shallow.hit
    @test !shallow.cutoff

    other_key = probe(table, UInt64(1 + 8), 1, -Inf, Inf, 0)
    @test !other_key.hit

    store!(table, UInt64(2), 2, 4.0, LOWER, MOVE_NULL)
    high = probe(table, UInt64(2), 2, -Inf, 3.0, 0)
    @test high.cutoff
    @test high.score == 4
    raised = probe(table, UInt64(2), 2, -Inf, 10.0, 0)
    @test !raised.cutoff
    @test raised.alpha == 4

    store!(table, UInt64(3), 2, 2.0, UPPER, MOVE_NULL)
    low = probe(table, UInt64(3), 2, 3.0, 10.0, 0)
    @test low.cutoff
    @test low.score == 2
    lowered = probe(table, UInt64(3), 2, -10.0, 10.0, 0)
    @test !lowered.cutoff
    @test lowered.beta == 2

    mate_score = pack_score(99999 - 3, 3)
    store!(table, UInt64(4), 4, mate_score, EXACT, MOVE_NULL)
    mate = probe(table, UInt64(4), 4, -Inf, Inf, 5)
    @test mate.cutoff
    @test mate.score == 99999 - 5

    board = startboard()
    hash_move = collect(moves(board))[end]
    @test ordered_moves(board, hash_move)[1] == hash_move

    kept = TranspositionTable(8)
    store!(kept, UInt64(1), 5, 4.0, EXACT, MOVE_NULL)
    store!(kept, UInt64(1 + 8), 1, 7.0, EXACT, MOVE_NULL)
    @test probe(kept, UInt64(1), 5, -Inf, Inf, 0).score == 4
    new_generation!(kept)
    store!(kept, UInt64(1 + 8), 1, 7.0, EXACT, MOVE_NULL)
    @test !probe(kept, UInt64(1), 1, -Inf, Inf, 0).hit

    search_board = startboard()
    maximizing = sidetomove(search_board) == WHITE
    without = minimax(search_board, 3, maximizing)
    with_table = TranspositionTable(1 << 12)
    with = minimax(search_board, 3, maximizing, -Inf, Inf, 0, nothing, with_table)
    @test without == with

    played_table = TranspositionTable(1 << 12)
    played = move(search_board, 2, nothing, played_table)
    stored = probe(played_table, search_board.key, 2, -Inf, Inf, 0)
    @test stored.cutoff
    @test stored.best_move == played

    draw_board = fromfen("2R5/1k3pQp/8/6P1/8/8/7P/4K3 w - - 0 51")
    draw_board.r50 = UInt8(12)
    history = UInt64[draw_board.key, 0x2, draw_board.key, 0x4]
    draw_table = TranspositionTable(16)
    @test minimax(draw_board, 1, true, -Inf, Inf, 0, history, draw_table) == 0
    @test !probe(draw_table, draw_board.key, 1, -Inf, Inf, 0).hit

    @test choose_move(MinimaxSearch(1), search_board, 0.0) in moves(search_board)

    order_board = fromfen("3rk3/8/8/3n4/3pP3/8/8/3QK3 w - - 0 1")
    @test tostring(ordered_moves(order_board)[1]) == "e4d5"
    before = fen(order_board)
    move(order_board, 2)
    @test fen(order_board) == before
    minimax(order_board, 2, true)
    @test fen(order_board) == before

    persistent = MinimaxSearch(1)
    held = persistent.table
    choose_move(persistent, startboard(), 0.0)
    @test persistent.table === held
    @test probe(held, startboard().key, 1, -Inf, Inf, 0).cutoff
    new_generation!(held)
    @test probe(held, startboard().key, 1, -Inf, Inf, 0).hit
    clear!(held)
    @test !probe(held, startboard().key, 1, -Inf, Inf, 0).hit
end
