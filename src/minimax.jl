#This is code for a minimax engine
using Chess

function minimax(position::Board, depth::Int, maximizingPlayer::Bool)
    if depth == 0 || isterminal(position)
        return evaluate(position)
    end

    if maximizingPlayer
        max_evaluation = -Inf
        for child in moves(position)
            evaluation = minimax(domove(position, child), depth-1, false)
            max_evaluation = max(max_evaluation, evaluation)
        end
        return max_evaluation
    else
        min_evaluation = Inf
        for child in moves(position)
            evaluation = minimax(domove(position, child), depth-1, true)
            min_evaluation = min(min_evaluation, evaluation)
        end
        return min_evaluation
    end
end

function evaluate(position)

    white_score = 0
    black_score = 0

    for sq in occupiedsquares(position)
        piece = pieceon(position, sq)
        piecetype = ptype(piece)
        value = get_piece_value(piecetype)

        if pcolor(piece) == WHITE
            white_score += value
        else
            black_score += value
        end
    end

    if ischeckmate(position) && sidetomove(position) == "BLACK"
        white_score += 99999
    elseif ischeckmate(position) && sidetomove(position) == "WHITE"
        black_score += 99999
    end

    return white_score - black_score
end

function get_piece_value(pt::PieceType)
    if pt == PAWN
        return 1
    elseif pt == KNIGHT
        return 3
    elseif pt == BISHOP
        return 3
    elseif pt == ROOK
        return 5
    elseif pt == QUEEN
        return 9
    end
    return 0
end

function move(position::Board, depth::Int)

    #if white
    if sidetomove(position) == "WHITE"
        best_eval = -Inf
        best_move = first(moves(position))

        for move in moves(position)
            new_position = domove(position, move)
            evaluation = minimax(new_position, depth, true)
            if evaluation > best_eval
                best_eval = evaluation
                best_move = lastmove(new_position)
            end
        end

        return best_move
    else
        best_eval = Inf
        best_move = first(moves(position))
        for move in moves(position)
            new_position = domove(position, move)
            evaluation = minimax(new_position, depth, false)
            if evaluation < best_eval
                best_eval = evaluation
                best_move = lastmove(new_position)
            end
        end
        
        return best_move

    end

end
