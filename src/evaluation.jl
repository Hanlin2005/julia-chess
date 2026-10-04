# Centipawn material plus a piece-square table. The table is written from White's
# side; Black reads it with the rank flipped. `material_score` scans the board.
# `update_score` adjusts that total for one move.

using Chess

const MATERIAL = [100, 320, 330, 500, 900, 0]

# Rank 8 through rank 1, file a through file h.
function square_table(ranks)
    table = zeros(Int, 64)
    for (from_eighth, row) in enumerate(ranks)
        white_rank = 9 - from_eighth
        for (file, value) in enumerate(row)
            table[(file - 1) * 8 + (9 - white_rank)] = value
        end
    end
    return table
end

const PIECE_SQUARE_TABLES = [
    square_table([
        [0, 0, 0, 0, 0, 0, 0, 0],
        [50, 50, 50, 50, 50, 50, 50, 50],
        [10, 10, 20, 30, 30, 20, 10, 10],
        [5, 5, 10, 25, 25, 10, 5, 5],
        [0, 0, 0, 20, 20, 0, 0, 0],
        [5, -5, -10, 0, 0, -10, -5, 5],
        [5, 10, 10, -20, -20, 10, 10, 5],
        [0, 0, 0, 0, 0, 0, 0, 0],
    ]),
    square_table([
        [-50, -40, -30, -30, -30, -30, -40, -50],
        [-40, -20, 0, 0, 0, 0, -20, -40],
        [-30, 0, 10, 15, 15, 10, 0, -30],
        [-30, 5, 15, 20, 20, 15, 5, -30],
        [-30, 0, 15, 20, 20, 15, 0, -30],
        [-30, 5, 10, 15, 15, 10, 5, -30],
        [-40, -20, 0, 5, 5, 0, -20, -40],
        [-50, -40, -30, -30, -30, -30, -40, -50],
    ]),
    square_table([
        [-20, -10, -10, -10, -10, -10, -10, -20],
        [-10, 0, 0, 0, 0, 0, 0, -10],
        [-10, 0, 5, 10, 10, 5, 0, -10],
        [-10, 5, 5, 10, 10, 5, 5, -10],
        [-10, 0, 10, 10, 10, 10, 0, -10],
        [-10, 10, 10, 10, 10, 10, 10, -10],
        [-10, 5, 0, 0, 0, 0, 5, -10],
        [-20, -10, -10, -10, -10, -10, -10, -20],
    ]),
    square_table([
        [0, 0, 0, 0, 0, 0, 0, 0],
        [5, 10, 10, 10, 10, 10, 10, 5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [-5, 0, 0, 0, 0, 0, 0, -5],
        [0, 0, 0, 5, 5, 0, 0, 0],
    ]),
    square_table([
        [-20, -10, -10, -5, -5, -10, -10, -20],
        [-10, 0, 0, 0, 0, 0, 0, -10],
        [-10, 0, 5, 5, 5, 5, 0, -10],
        [-5, 0, 5, 5, 5, 5, 0, -5],
        [0, 0, 5, 5, 5, 5, 0, -5],
        [-10, 5, 5, 5, 5, 5, 0, -10],
        [-10, 0, 5, 0, 0, 0, 0, -10],
        [-20, -10, -10, -5, -5, -10, -10, -20],
    ]),
    square_table([
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-30, -40, -40, -50, -50, -40, -40, -30],
        [-20, -30, -30, -40, -40, -30, -30, -20],
        [-10, -20, -20, -20, -20, -20, -20, -10],
        [20, 20, 0, 0, 0, 0, 20, 20],
        [20, 30, 10, 0, 0, 10, 30, 20],
    ]),
]

function piece_value(piece::Piece, square::Square)
    kind = ptype(piece).val
    index = pcolor(piece) == WHITE ? square.val : ((square.val - 1) ⊻ 7) + 1
    value = MATERIAL[kind] + PIECE_SQUARE_TABLES[kind][index]
    return pcolor(piece) == WHITE ? value : -value
end

function material_score(position::Board)
    score = 0
    for square in occupiedsquares(position)
        score += piece_value(pieceon(position, square), square)
    end
    return score
end

function evaluate(position)
    if ischeckmate(position) && sidetomove(position) == BLACK
        return CHECKMATE_SCORE
    elseif ischeckmate(position) && sidetomove(position) == WHITE
        return -CHECKMATE_SCORE
    elseif isterminal(position)
        return 0
    end

    return material_score(position)
end

# `score` is the material score of `position` before `move` is played.
function update_score(position::Board, move::Move, score::Int)
    from_square = from(move)
    to_square = to(move)
    mover = pieceon(position, from_square)
    mover_color = pcolor(mover)
    score -= piece_value(mover, from_square)

    if moveiscastle(position, move)
        queenside = file(to_square) < file(from_square)
        king_to = Square(queenside ? FILE_C : FILE_G, rank(from_square))
        rook_file = queenside ? Chess.queensidecastlefile(position) : Chess.kingsidecastlefile(position)
        rook_from = Square(rook_file, rank(from_square))
        rook_to = Square(queenside ? FILE_D : FILE_F, rank(from_square))
        score -= piece_value(pieceon(position, rook_from), rook_from)
        score += piece_value(Piece(mover_color, KING), king_to)
        score += piece_value(Piece(mover_color, ROOK), rook_to)
        return score
    end

    if moveisep(position, move)
        captured_square = Square(file(to_square), rank(from_square))
        score -= piece_value(pieceon(position, captured_square), captured_square)
    elseif moveiscapture(position, move)
        score -= piece_value(pieceon(position, to_square), to_square)
    end

    placed = ispromotion(move) ? Piece(mover_color, promotion(move)) : mover
    return score + piece_value(placed, to_square)
end
