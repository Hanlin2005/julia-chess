# Puzzles benchmark for the minimax engine.
#
# The final rating is the highest rating at which every selected puzzle of
# that rating or lower was solved. After the results print, the script asks
# whether to save the run and whether to attach a note. A saved run appends
# a row to data/benchmark_history.csv and redraws data/benchmark_history.png.
#
# Usage:
#     julia --project=. scripts/puzzles_benchmark.jl [depth]

using Chess
using Dates
using Printf

include(joinpath(@__DIR__, "..", "src", "minimax.jl"))
include(joinpath(@__DIR__, "..", "data", "benchmark_puzzles.jl"))

if isempty(ARGS)
    search_depth = 3
elseif length(ARGS) == 1
    search_depth = tryparse(Int, ARGS[1])
    if search_depth === nothing || search_depth < 1
        error("depth must be an integer of at least 1")
    end
else
    error("Usage: julia --project=. scripts/puzzles_benchmark.jl [depth]")
end

const SEARCH_DEPTH = search_depth
const HISTORY_PATH = joinpath(@__DIR__, "..", "data", "benchmark_history.csv")
const GRAPH_PATH = joinpath(@__DIR__, "..", "data", "benchmark_history.png")
const HISTORY_HEADER = "ran_at,engine,depth,seconds,puzzles,solved,failed,solved_percent,final_rating,highest_solved,lowest_missed,bands,note"

function benchmark_summary(results)
    solved_ratings = Int[rating for (rating, ok) in results if ok]
    missed_ratings = Int[rating for (rating, ok) in results if !ok]
    final = nothing
    if isempty(missed_ratings)
        if !isempty(solved_ratings)
            final = maximum(solved_ratings)
        end
    else
        cutoff = minimum(missed_ratings)
        below = [rating for rating in solved_ratings if rating < cutoff]
        if !isempty(below)
            final = maximum(below)
        end
    end
    highest = isempty(solved_ratings) ? nothing : maximum(solved_ratings)
    lowest = isempty(missed_ratings) ? nothing : minimum(missed_ratings)
    return (; final, highest, lowest)
end

function rating_bands(results)
    bands = sort(unique(rating ÷ 100 * 100 for (rating, _) in results))
    rows = NamedTuple[]
    for band in bands
        group = [ok for (rating, ok) in results if rating ÷ 100 * 100 == band]
        solved = count(group)
        total = length(group)
        push!(rows, (; band, solved, total, failed = total - solved))
    end
    return rows
end

function band_field(bands)
    parts = String[]
    for row in bands
        solved_percent = row.total == 0 ? 0.0 : 100 * row.solved / row.total
        failed_percent = row.total == 0 ? 0.0 : 100 * row.failed / row.total
        push!(
            parts,
            string(
                row.band, ":", row.solved, "/", row.total, ":",
                @sprintf("%.1f", solved_percent), ":",
                @sprintf("%.1f", failed_percent),
            ),
        )
    end
    return join(parts, ";")
end

function csv_field(text)
    return "\"" * replace(text, "\"" => "\"\"") * "\""
end

function history_line(ran_at, engine, depth, seconds, results, summary, bands, note)
    puzzles = length(results)
    solved = count(ok for (_, ok) in results)
    failed = puzzles - solved
    solved_percent = puzzles == 0 ? 0.0 : 100 * solved / puzzles
    optional(value) = value === nothing ? "" : string(value)
    return string(
        ran_at, ",",
        engine, ",",
        depth, ",",
        @sprintf("%.3f", seconds), ",",
        puzzles, ",",
        solved, ",",
        failed, ",",
        @sprintf("%.1f", solved_percent), ",",
        optional(summary.final), ",",
        optional(summary.highest), ",",
        optional(summary.lowest), ",",
        "\"", band_field(bands), "\",",
        csv_field(note),
    )
end

function append_history_line(path, line)
    new_file = !isfile(path) || filesize(path) == 0
    open(path, "a") do io
        if new_file
            println(io, HISTORY_HEADER)
        end
        println(io, line)
    end
end

function parse_csv_line(line)
    fields = String[]
    current = IOBuffer()
    quoted = false
    characters = collect(line)
    index = 1
    while index <= length(characters)
        character = characters[index]
        if character == '"'
            if quoted && index < length(characters) && characters[index + 1] == '"'
                print(current, '"')
                index += 2
                continue
            end
            quoted = !quoted
        elseif character == ',' && !quoted
            push!(fields, String(take!(current)))
        else
            print(current, character)
        end
        index += 1
    end
    push!(fields, String(take!(current)))
    return fields
end

function parse_optional_int(field)
    field == "" && return nothing
    return parse(Int, field)
end

function parse_bands(field)
    rows = NamedTuple[]
    field == "" && return rows
    for piece in split(field, ";")
        band, score, solved_percent, failed_percent = split(piece, ":")
        solved, total = split(score, "/")
        push!(rows, (;
            band = parse(Int, band),
            solved = parse(Int, solved),
            total = parse(Int, total),
            solved_percent = parse(Float64, solved_percent),
            failed_percent = parse(Float64, failed_percent),
        ))
    end
    return rows
end

function read_history(path)
    isfile(path) || return NamedTuple[]
    runs = NamedTuple[]
    for line in eachline(path)
        line == "" && continue
        startswith(line, "ran_at,") && continue
        fields = parse_csv_line(line)
        push!(runs, (;
            ran_at = fields[1],
            engine = fields[2],
            depth = parse(Int, fields[3]),
            seconds = parse(Float64, fields[4]),
            puzzles = parse(Int, fields[5]),
            solved = parse(Int, fields[6]),
            failed = parse(Int, fields[7]),
            solved_percent = parse(Float64, fields[8]),
            final_rating = parse_optional_int(fields[9]),
            highest_solved = parse_optional_int(fields[10]),
            lowest_missed = parse_optional_int(fields[11]),
            bands = parse_bands(fields[12]),
            note = length(fields) >= 13 ? fields[13] : "",
        ))
    end
    return runs
end

function write_benchmark_graph(path, runs)
    @eval using Plots
    Base.invokelatest(draw_benchmark_graph, path, runs)
end

function draw_benchmark_graph(path, runs)
    runs_index = 1:length(runs)
    labels = [run.ran_at for run in runs]
    ticks = (marker = :circle, legend = false, xticks = (runs_index, labels), xrotation = 30, bottom_margin = 12Plots.mm, xtickfontsize = 8)
    ratings = [run.final_rating === nothing ? NaN : Float64(run.final_rating) for run in runs]
    rating_plot = plot(runs_index, ratings; ylabel = "Final rating", ticks...)
    percent_plot = plot(runs_index, [run.solved_percent for run in runs]; ylabel = "Solved %", ticks...)
    time_plot = plot(runs_index, [run.seconds for run in runs]; ylabel = "Seconds", ticks...)
    latest = runs[end]
    band_labels = ["$(row.band)-$(row.band + 99)" for row in latest.bands]
    band_plot = bar(band_labels, [row.solved_percent for row in latest.bands]; legend = false, ylabel = "Solved %", title = "Latest run", xrotation = 60, bottom_margin = 14Plots.mm, xtickfontsize = 7)
    figure = plot(rating_plot, percent_plot, time_plot, band_plot, layout = (4, 1), size = (900, 1400), plot_title = "Benchmark history")
    savefig(figure, path)
end


function ensure_note_column(path)
    isfile(path) || return
    lines = readlines(path)
    isempty(lines) && return
    startswith(lines[1], HISTORY_HEADER) && return
    open(path, "w") do io
        println(io, HISTORY_HEADER)
        for line in lines[2:end]
            line == "" && continue
            println(io, line * ",\"\"")
        end
    end
end

function save_benchmark_history(results, depth::Int, seconds::Float64, ran_at::AbstractString, note::AbstractString, engine::AbstractString = "minimax")
    ensure_note_column(HISTORY_PATH)
    summary = benchmark_summary(results)
    bands = rating_bands(results)
    line = history_line(ran_at, engine, depth, seconds, results, summary, bands, note)
    append_history_line(HISTORY_PATH, line)
    write_benchmark_graph(GRAPH_PATH, read_history(HISTORY_PATH))
end

function ask_yes_no(prompt)
    while true
        print(prompt, " [y/n] ")
        flush(stdout)
        answer = lowercase(strip(readline()))
        if answer == "y" || answer == "yes"
            return true
        elseif answer == "n" || answer == "no"
            return false
        elseif answer == "" && (stdin isa Base.TTY ? !isreadable(stdin) : eof(stdin))
            # eof(stdin) on a TTY reads one byte ahead and steals the next line.
            println()
            return false
        end
        println("Please type y or n.")
    end
end

function main()
    println("Puzzles benchmark")
    ran_at = Dates.format(Dates.now(), dateformat"yyyy-mm-dd HH:MM:SS")
    results = Tuple{Int, Bool}[]
    started = time()

    for (id, rating, fen, expected, mate_in_one) in BENCHMARK_PUZZLES
        board = fromfen(fen)
        played = move(board, SEARCH_DEPTH)
        if mate_in_one
            ok = ischeckmate(domove(board, played))
        else
            ok = tostring(played) == expected
        end
        println("$id  $rating  $(ok ? "solved" : "missed")  $(tostring(played))")
        push!(results, (rating, ok))
    end
    elapsed = time() - started

    println()
    @printf("%-12s  %8s  %10s  %8s\n", "Rating band", "Solved", "Succeeded", "Failed")
    bands = rating_bands(results)
    for row in bands
        @printf(
            "%4d-%-7d  %3d/%-4d  %9.1f%%  %7.1f%%\n",
            row.band,
            row.band + 99,
            row.solved,
            row.total,
            row.total == 0 ? 0.0 : 100 * row.solved / row.total,
            row.total == 0 ? 0.0 : 100 * row.failed / row.total,
        )
    end

    summary = benchmark_summary(results)
    println()
    println("Final rating: $(summary.final === nothing ? "none" : summary.final)")
    println("Highest solved: $(summary.highest === nothing ? "none" : summary.highest)")
    println("Lowest missed: $(summary.lowest === nothing ? "none" : summary.lowest)")
    solved = count(ok for (_, ok) in results)
    @printf("Solved: %d/%d (%.1f%%)\n", solved, length(results), length(results) == 0 ? 0.0 : 100 * solved / length(results))
    println("Engine: minimax  Depth: $SEARCH_DEPTH")
    println("Ran: $ran_at")
    @printf("Elapsed: %.3f seconds\n", elapsed)

    if !ask_yes_no("Save this run?")
        println("Not saved.")
        return
    end
    note = ""
    if ask_yes_no("Add a note?")
        print("Note: ")
        flush(stdout)
        note = strip(readline())
    end
    save_benchmark_history(results, SEARCH_DEPTH, elapsed, ran_at, note)
    println("History: $(abspath(HISTORY_PATH))")
    println("Graph: $(abspath(GRAPH_PATH))")
end

main()
