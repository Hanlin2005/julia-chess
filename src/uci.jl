#!/usr/bin/env julia
#This file communicates via the UCI protocol
using Chess
using Random
script_dir = @__DIR__
include(joinpath(script_dir, "engine.jl"))

#todo: implement functionality for debugging, respond to debug, setoption, register, return options, 

#function to load position, make need to revise the length arguments thing
function board_from_position(input)
    arguments = split(input, " ")

    if(arguments[2] == "fen")
        fen = join(arguments[3:8], " ")
        board = fromfen(fen)

        if length(arguments) >= 10
            for move in arguments[10:end]
                m = movefromstring(String(move))
                board = domove(board, m)
            end
        end
    else
        board = startboard()
        if length(arguments) >= 4
            for move in arguments[4:end]
                m = movefromstring(String(move))
                board = domove(board, m)
            end
        end
    end

    return board
end


#Code for asynchronous Search

#Launch asynchronous Search
function launch_search(bd::Board)
    last_board[] = bd
    thinking[]   = true
    search_task[] = @async begin
        mv = tostring(mcts(bd, 10000))
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
            #tells us new game is happening

        elseif length(input) >= 8 && input[1:8] == "position"
            last_board[] = board_from_position(input)

        elseif length(input) >= 2 && input[1:2] == "go"

            thinking[] && (println("info string aborting old search"); thinking[] = false)
            launch_search(last_board[])
        
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