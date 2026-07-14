#This is code for a minimax engine
using Chess

const CHECKMATE_SCORE = 99999

function minimax(position::Board, depth::Int, maximizingPlayer::Bool, alpha = -Inf, beta = Inf)
    if depth == 0 || isterminal(position)
        return evaluate(position)
    end

    if maximizingPlayer
        max_evaluation = -Inf
        for child in moves(position)
            evaluation = minimax(domove(position, child), depth-1, false, alpha, beta)
            max_evaluation = max(max_evaluation, evaluation)
            alpha = max(alpha, max_evaluation)
            alpha >= beta && break
        end
        return max_evaluation
    else
        min_evaluation = Inf
        for child in moves(position)
            evaluation = minimax(domove(position, child), depth-1, true, alpha, beta)
            min_evaluation = min(min_evaluation, evaluation)
            beta = min(beta, min_evaluation)
            alpha >= beta && break
        end
        return min_evaluation
    end
end

function evaluate(position)
    if ischeckmate(position) && sidetomove(position) == BLACK
        return CHECKMATE_SCORE
    elseif ischeckmate(position) && sidetomove(position) == WHITE
        return -CHECKMATE_SCORE
    elseif isterminal(position)
        return 0
    end

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
    if sidetomove(position) == WHITE
        best_eval = -Inf
        best_move = first(moves(position))
        alpha = -Inf
        beta = Inf

        for move in moves(position)
            new_position = domove(position, move)
            evaluation = minimax(new_position, depth, false, alpha, beta)
            if evaluation > best_eval
                best_eval = evaluation
                best_move = lastmove(new_position)
            end
            alpha = max(alpha, best_eval)
        end

        return best_move
    else
        best_eval = Inf
        best_move = first(moves(position))
        alpha = -Inf
        beta = Inf

        for move in moves(position)
            new_position = domove(position, move)
            evaluation = minimax(new_position, depth, true, alpha, beta)
            if evaluation < best_eval
                best_eval = evaluation
                best_move = lastmove(new_position)
            end
            beta = min(beta, best_eval)
        end
        
        return best_move

    end

end
