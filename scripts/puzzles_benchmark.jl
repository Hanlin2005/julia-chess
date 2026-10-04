# Puzzles benchmark for the minimax engine.
#
# The final rating is the highest rating at which every selected puzzle of
# that rating or lower was solved. Each run appends a row to
# data/benchmark_history.csv and rebuilds data/benchmark_history.html.
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
const GRAPH_PATH = joinpath(@__DIR__, "..", "data", "benchmark_history.html")
const HISTORY_HEADER = "ran_at,engine,depth,seconds,puzzles,solved,failed,solved_percent,final_rating,highest_solved,lowest_missed,bands"

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

function history_line(ran_at, engine, depth, seconds, results, summary, bands)
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
        "\"", band_field(bands), "\"",
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
    for character in line
        if character == '"'
            quoted = !quoted
        elseif character == ',' && !quoted
            push!(fields, String(take!(current)))
        else
            print(current, character)
        end
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
        ))
    end
    return runs
end

json_string(text) = "\"" * replace(text, "\\" => "\\\\", "\"" => "\\\"") * "\""
json_int(value) = value === nothing ? "null" : string(value)

function runs_json(runs)
    rows = String[]
    for run in runs
        bands = join([
            "{\"band\":$(row.band),\"solved\":$(row.solved),\"total\":$(row.total),\"solved_percent\":$(row.solved_percent),\"failed_percent\":$(row.failed_percent)}"
            for row in run.bands
        ], ",")
        push!(rows, "{" *
            "\"ran_at\":$(json_string(run.ran_at))," *
            "\"engine\":$(json_string(run.engine))," *
            "\"depth\":$(run.depth)," *
            "\"seconds\":$(run.seconds)," *
            "\"puzzles\":$(run.puzzles)," *
            "\"solved\":$(run.solved)," *
            "\"failed\":$(run.failed)," *
            "\"solved_percent\":$(run.solved_percent)," *
            "\"final_rating\":$(json_int(run.final_rating))," *
            "\"highest_solved\":$(json_int(run.highest_solved))," *
            "\"lowest_missed\":$(json_int(run.lowest_missed))," *
            "\"bands\":[$bands]}"
        )
    end
    return "[" * join(rows, ",") * "]"
end

function write_benchmark_graph(path, runs)
    open(path, "w") do io
        println(io, """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>Benchmark history</title>
        <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.6"></script>
        <style>
        body { background: #ffffff; color: #111111; font-family: ui-sans-serif, system-ui, sans-serif; margin: 24px; max-width: 860px; }
        canvas { margin: 24px 0; }
        table { border-collapse: collapse; }
        th, td { border-bottom: 1px solid #ddd; padding: 6px 10px; text-align: right; }
        th:first-child, td:first-child, th:nth-child(2), td:nth-child(2) { text-align: left; }
        </style>
        </head>
        <body>
        <h1>Benchmark history</h1>
        <p id="count"></p>
        <h2>Final rating</h2><canvas id="rating"></canvas>
        <h2>Solved percent</h2><canvas id="percent"></canvas>
        <h2>Seconds</h2><canvas id="seconds"></canvas>
        <h2>Latest run by rating band</h2><canvas id="bands"></canvas>
        <table id="history"></table>
        <script>
        const runs = $(runs_json(runs));
        const labels = runs.map(run => run.ran_at);
        document.getElementById("count").textContent = runs.length + " runs";
        function line(id, data) {
            new Chart(document.getElementById(id), {
                type: "line",
                data: { labels, datasets: [{ data, borderColor: "#3b6ea5", tension: 0.2 }] },
                options: { plugins: { legend: { display: false } } }
            });
        }
        line("rating", runs.map(run => run.final_rating));
        line("percent", runs.map(run => run.solved_percent));
        line("seconds", runs.map(run => run.seconds));
        const latest = runs[runs.length - 1];
        if (latest) {
            new Chart(document.getElementById("bands"), {
                type: "bar",
                data: {
                    labels: latest.bands.map(row => row.band + "-" + (row.band + 99)),
                    datasets: [{ data: latest.bands.map(row => row.solved_percent), backgroundColor: "#3b6ea5" }]
                },
                options: { indexAxis: "y", plugins: { legend: { display: false } } }
            });
        }
        const table = document.getElementById("history");
        table.innerHTML = "<tr><th>Ran at</th><th>Engine</th><th>Depth</th><th>Seconds</th><th>Solved</th><th>Failed</th><th>Solved %</th><th>Final rating</th><th>Highest solved</th><th>Lowest missed</th></tr>";
        for (const run of runs) {
            const cells = [run.ran_at, run.engine, run.depth, run.seconds, run.solved + "/" + run.puzzles, run.failed, run.solved_percent, run.final_rating ?? "", run.highest_solved ?? "", run.lowest_missed ?? ""];
            table.insertAdjacentHTML("beforeend", "<tr>" + cells.map(cell => "<td>" + cell + "</td>").join("") + "</tr>");
        }
        </script>
        </body>
        </html>
        """)
    end
end

function save_benchmark_history(results, depth::Int, seconds::Float64, ran_at::AbstractString, engine::AbstractString = "minimax")
    summary = benchmark_summary(results)
    bands = rating_bands(results)
    line = history_line(ran_at, engine, depth, seconds, results, summary, bands)
    append_history_line(HISTORY_PATH, line)
    write_benchmark_graph(GRAPH_PATH, read_history(HISTORY_PATH))
    return (; summary, bands)
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

    save_benchmark_history(results, SEARCH_DEPTH, elapsed, ran_at)
    println("History: $(abspath(HISTORY_PATH))")
    println("Graph: $(abspath(GRAPH_PATH))")
end

main()
