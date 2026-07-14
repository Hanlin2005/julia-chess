"""
Script for simulating games between chess engines.

Usage:
    julia simulate_games.jl <num_rounds> <agent1> <agent2> [agents...]

Agent format:
    minimax:<depth>       e.g. minimax:3
    mcts:<simulations>    e.g. mcts:5000

Example:
    julia simulate_games.jl 2 minimax:3 mcts:5000
"""

include("environment.jl")

# --- Parse CLI args ---
function print_usage()
    println("Usage: julia simulate_games.jl <num_rounds> <agent1> <agent2> [agents...]")
    println("")
    println("Agent formats:")
    println("  minimax:<depth>        e.g. minimax:3")
    println("  mcts:<simulations>     e.g. mcts:5000")
    println("")
    println("Example:")
    println("  julia simulate_games.jl 2 minimax:3 mcts:5000 minimax:4")
    exit(1)
end

#Make sure arguments are right
if length(ARGS) < 3
    print_usage()
end

num_rounds = parse(Int, ARGS[1])

function parse_agent(spec::String)::Engine
    parts = split(spec, ":")
    agent_type = lowercase(parts[1])

    if agent_type == "minimax"
        depth = length(parts) >= 2 ? parse(Int, parts[2]) : 3
        return create_minimax(depth)
    elseif agent_type == "mcts"
        sims = length(parts) >= 2 ? parse(Int, parts[2]) : 1000
        return create_mcts(sims)
    else
        println("Unknown agent type: $agent_type")
        print_usage()
        error("unreachable")
    end
end

players = [parse_agent(arg) for arg in ARGS[2:end]]

println("=== Chess Engine Simulation ===")
println("Rounds: $num_rounds")
println("Players:")
for (i, p) in enumerate(players)
    println("  [$i] $(p.name) (ELO: $(p.eloscore))")
end
println()

# --- Run a single game with board printing ---
function run_game_verbose(white::Engine, black::Engine; max_moves::Int=100)
    board = startboard()
    movenum = 0
    println("  White: $(white.name)  vs  Black: $(black.name)")
    println(board)
    println()

    white_turn = true
    while !isterminal(board) && movenum < max_moves
        if white_turn
            mv = white.func(board)
        else
            mv = black.func(board)
        end

        san = movetosan(board, mv)
        domove!(board, mv)

        if white_turn
            movenum += 1
            print("  $movenum. $san ")
        else
            println(san)
        end

        println(board)
        println()

        white_turn = !white_turn
    end

    if !white_turn
        println()
    end

    if ischeckmate(board) && sidetomove(board) == BLACK
        result = 1
        println("  Result: White wins (checkmate)")
    elseif ischeckmate(board) && sidetomove(board) == WHITE
        result = -1
        println("  Result: Black wins (checkmate)")
    else
        result = 0
        println("  Result: Draw")
    end

    return result
end

# --- Simulate ---

global game_count = 0
for round in 1:num_rounds
    println("--- Round $round / $num_rounds ---")
    for i in 1:length(players)
        for j in (i+1):length(players)
            global game_count += 1
            println("\n[Game $game_count]")
            result = run_game_verbose(players[i], players[j])
            elo_update(players[i], players[j], result, 10)

            global game_count += 1
            println("\n[Game $game_count]")
            result = run_game_verbose(players[j], players[i])
            elo_update(players[j], players[i], result, 10)
        end
    end
end

# --- Print final ELO ---

println("\n=== Final ELO Ratings ===")
sorted = sort(collect(enumerate(players)), by=x -> x[2].eloscore, rev=true)
for (i, p) in sorted
    println("  [$i] $(p.name): $(round(p.eloscore, digits=1))")
end