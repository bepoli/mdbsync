#!/bin/bash
# MDBSync (https://github.com/bepoli/mdbsync)
# Copyright (C) 2026 Benedetto Polimeni
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

base=https://api.mdblist.com
api_key="${MDBLIST_API_KEY:?MDBLIST_API_KEY is not set}"
api="?apikey=$api_key"

state_file="./.last_sync"
last_sync=$(cat "$state_file" 2>/dev/null || echo "")

extlists=$(curl -s "$base/external/lists/user$api")

letterboxd_list=$(echo "$extlists" | jq '.[] |
  select(.name == "Letterboxd Watchlist")')
letterboxd_id=$(echo "$letterboxd_list" | jq -r '.id')
letterboxd_updated=$(echo "$letterboxd_list" | jq -r '.updated')

items=$(curl -s "$base/external/lists/$letterboxd_id/items$api")
watchlist=$(curl -s "$base/watchlist/items$api")

echo "## In watchlist but not in Letterboxd"
jq -rn \
  --argjson items "$items" \
  --argjson watchlist "$watchlist" \
  '($items.movies | map(.ids.mdblist)) as $letterboxd_ids |
   $watchlist.movies
   | map(select(.ids.mdblist | IN($letterboxd_ids[]) | not))
   | map("- [\(.title)](https://letterboxd.com/imdb/\(.imdb_id))")
   | .[]'

if [[ -n "$last_sync" && ! "$letterboxd_updated" > "$last_sync" ]]; then
  echo "Up to date (last sync: $last_sync). Skipping."
  exit 0
fi

echo "Syncing (list updated: $letterboxd_updated, last sync: ${last_sync:-never})"

curl -s -X POST "$base/watchlist/items/add$api" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d "$items" > /dev/null

watchlist_after=$(curl -s "$base/watchlist/items$api")

echo "## Newly added to watchlist"
jq -rn \
  --argjson before "$watchlist" \
  --argjson after "$watchlist_after" \
  '($before.movies | map(.ids.mdblist)) as $before_ids |
   $after.movies
   | map(select(.ids.mdblist | IN($before_ids[]) | not))
   | map("- \(.title)")
   | .[]'

date -u +"%Y-%m-%dT%H:%M:%S.000Z" > "$state_file"
