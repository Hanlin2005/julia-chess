#!/usr/bin/env julia
#This file communicates via the UCI protocol
using Chess
using Random
script_dir = @__DIR__
include(joinpath(script_dir, "engine.jl"))
include(joinpath(script_dir, "minimax.jl"))
include(joinpath(script_dir, "searches.jl"))

const active_engine = engine_from_args(ARGS)

#todo: implement functionality for debugging, respond to debug, setoption, register, return options, 

#function to load position, make need to revise the length arguments thing
function board_from_position(input)
    arguments = split(input, " ")
    history = UInt64[]

    if(arguments[2] == "fen")
        fen = join(arguments[3:8], " ")
        board = fromfen(fen)
        halfmove = length(arguments) >= 7 ? tryparse(Int, arguments[7]) : nothing
        if halfmove !== nothing
            board.r50 = UInt8(clamp(halfmove, 0, 255))
        end
        moves = length(arguments) >= 10 ? arguments[10:end] : String[]
    else
        board = startboard()
        moves = length(arguments) >= 4 ? arguments[4:end] : String[]
    end

    for move in moves
        push!(history, board.key)
        board = domove(board, movefromstring(String(move)))
    end

    return board, history
end


#Code for asynchronous Search

#Launch asynchronous Search
function launch_search(bd::Board, go_line::AbstractString, history::Vector{UInt64})
    last_board[] = bd
    last_history[] = history
    thinking[]   = true
    search_task[] = @async begin
        seconds = move_time(go_line, bd)
        mv = tostring(choose_move(active_engine, bd, seconds, history))
        println("bestmove $mv")
        flush(stdout)
        thinking[] = false
    end
end

#Pick legal move if stopped
function random_move_string(bd::Board)
    m  = rand(moves(bd))
    return tostring(m)
end

const search_task  = Ref{Union{Task, Nothing}}(nothing)
const thinking     = Ref(false)
const last_board   = Ref(startboard())
const last_history = Ref{Vector{UInt64}}(UInt64[])

#This is the UCI loop for interfacing with Lichess
while true
    try
        line = readline(stdin)
        input = strip(line)

        if input == "uci"
            println("id name JuliaChess")
            println("id author Shrimpio")
            println("uciok")
            flush(stdout)

        elseif input == "isready"
            println("readyok")
            flush(stdout)

        elseif input == "ucinewgame"
            last_history[] = UInt64[]

        elseif length(input) >= 8 && input[1:8] == "position"
            last_board[], last_history[] = board_from_position(input)

        elseif length(input) >= 2 && input[1:2] == "go"

            thinking[] && (println("info string aborting old search"); thinking[] = false)
            launch_search(last_board[], input, last_history[])
        
        elseif input == "stop"
            if thinking[]
                println("bestmove $(random_move_string(last_board[]))")
                flush(stdout)
                thinking[] = false
            end

        elseif input == "quit"
            thinking[] && search_task[] !== nothing && Base.throwto(search_task[] , InterruptException())
            break
        end

    catch e
        @error "Error reading stdin"
        println(stderr, "UCI engine error: ", e)
        Base.show_backtrace(stderr, catch_backtrace())
        break
    end

end