struct MinimaxSearch
    depth::Int
end

struct MonteCarloSearch
    simulations::Int
end

struct Engine{S}
    search::S
end

# Seconds this move may take, from a UCI `go` line. Milliseconds in, seconds out.
function move_time(go_line::AbstractString, board::Board)
    tokens = split(go_line)
    values = Dict{String,Int}()
    index = 2
    while index <= length(tokens)
        key = tokens[index]
        if index < length(tokens)
            parsed = tryparse(Int, tokens[index + 1])
            if parsed !== nothing
                values[key] = parsed
                index += 2
                continue
            end
        end
        index += 1
    end

    if haskey(values, "movetime")
        return values["movetime"] / 1000
    end

    white_to_move = sidetomove(board) == WHITE
    remaining = get(values, white_to_move ? "wtime" : "btime", 0)
    increment = get(values, white_to_move ? "winc" : "binc", 0)
    if get(values, "movestogo", 0) > 0
        budget = remaining / values["movestogo"]
    else
        budget = remaining / 30 + increment / 2
    end
    if remaining > 0
        budget = min(budget, remaining / 10)
    end
    return max(budget, 0) / 1000
end

# `search.depth` always finishes. Later depths start only while the budget remains.
function choose_move(
    search::MinimaxSearch,
    board::Board,
    seconds::Float64,
    history::Union{Nothing,Vector{UInt64}} = nothing,
)
    table = TranspositionTable()
    started = time()
    best = move(board, search.depth, history, table)
    last_duration = time() - started
    depth = search.depth + 1

    while true
        remaining = seconds - (time() - started)
        if remaining <= 0 || last_duration > remaining
            break
        end
        began = time()
        best = move(board, depth, history, table)
        last_duration = time() - began
        depth += 1
    end

    return best
end

# The simulation count always finishes. A positive budget keeps searching the same tree until that time.
function choose_move(
    search::MonteCarloSearch,
    board::Board,
    seconds::Float64,
    history::Union{Nothing,Vector{UInt64}} = nothing,
)
    if seconds > 0
        return mcts(board, search.simulations; stop_time = time() + seconds, history = history)
    end
    return mcts(board, search.simulations; history = history)
end

function choose_move(
    engine::Engine,
    board::Board,
    seconds::Float64,
    history::Union{Nothing,Vector{UInt64}} = nothing,
)
    choose_move(engine.search, board, seconds, history)
end

function engine_from_args(args)
    kind = "minimax"
    depth = 3
    simulations = 10_000

    for arg in args
        if startswith(arg, "--search=")
            kind = split(arg, "=", limit = 2)[2]
        elseif startswith(arg, "--depth=")
            depth = parse(Int, split(arg, "=", limit = 2)[2])
        elseif startswith(arg, "--sims=")
            simulations = parse(Int, split(arg, "=", limit = 2)[2])
        end
    end

    if kind == "minimax"
        return Engine(MinimaxSearch(depth))
    elseif kind == "mcts"
        return Engine(MonteCarloSearch(simulations))
    else
        error("search must be minimax or mcts")
    end
end
