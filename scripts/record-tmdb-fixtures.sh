#!/bin/sh
# Records live TMDB responses into RyuujiTests/Fixtures/ for the decoding tests.
# Reads TMDB_TOKEN from Config/Secrets.xcconfig.
set -eu

cd "$(dirname "$0")/.."
TOKEN=$(sed -n 's/^TMDB_TOKEN *= *//p' Config/Secrets.xcconfig | tr -d '[:space:]')
if [ -z "$TOKEN" ]; then
    echo "TMDB_TOKEN is empty in Config/Secrets.xcconfig" >&2
    exit 1
fi

OUT=RyuujiTests/Fixtures
API=https://api.themoviedb.org/3

fetch() {
    curl -sf -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" "$API/$1" | python3 -m json.tool > "$OUT/$2"
    echo "recorded $2"
}

fetch "search/multi?query=frieren&include_adult=false&language=en-US&page=1" search-frieren.json
fetch "movie/372058?language=en-US" movie-372058.json
fetch "tv/120089?language=en-US" tv-120089.json

# Season batch for the same show, using whatever seasons TMDB lists.
SEASONS=$(python3 -c "import json;print(','.join('season/%d' % s['season_number'] for s in json.load(open('$OUT/tv-120089.json'))['seasons']))")
fetch "tv/120089?language=en-US&append_to_response=$SEASONS" tv-120089-seasons.json

# Per-episode cast/crew lists are large and unused; drop them to keep the fixture small.
python3 - "$OUT/tv-120089-seasons.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
for key, season in data.items():
    if key.startswith("season/"):
        for episode in season.get("episodes", []):
            episode.pop("crew", None)
            episode.pop("guest_stars", None)
json.dump(data, open(path, "w"), indent=4, ensure_ascii=False)
PY
