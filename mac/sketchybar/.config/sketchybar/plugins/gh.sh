#!/bin/bash
# GitHub island: gh.reviews (PRs waiting for your review) + gh.prs (your open
# PRs, icon coloured by the worst CI state). One GraphQL call via `gh`, cached
# in ~/.cache/sketchybar/gh.json; refresh interval set by providers.sh.
# Popup: review queue, your PRs with CI/review state (click = open, ⌥ = checks),
# unread notifications, refresh.
source "$HOME/.config/sketchybar/plugins/lib.sh"
handle_hover && exit 0
CACHE="$STATE_DIR/gh.json"
QUERY='query {
  viewer { login }
  reviews: search(query: "is:pr is:open review-requested:@me archived:false", type: ISSUE, first: 6) {
    issueCount
    nodes { ... on PullRequest { number title url updatedAt isDraft repository { nameWithOwner } author { login } } }
  }
  mine: search(query: "is:pr is:open author:@me archived:false sort:updated-desc", type: ISSUE, first: 6) {
    issueCount
    nodes { ... on PullRequest { number title url updatedAt isDraft reviewDecision
      repository { nameWithOwner }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } } }
  }
}'

fetch() {
  mkdir -p "$STATE_DIR"
  local data notif
  data="$(gh api graphql -f query="$QUERY" 2>/dev/null)" || { echo offline > "$STATE_DIR/gh_status"; return 1; }
  notif="$(gh api 'notifications?per_page=100' --jq length 2>/dev/null || echo 0)"
  jq --argjson n "${notif:-0}" --arg ts "$(date +%s)" '.data + {notifications: $n, ts: ($ts | tonumber)}' <<< "$data" > "$CACHE.$$" || return 1
  [ -f "$CACHE" ] && announce "$CACHE" "$CACHE.$$"
  mv "$CACHE.$$" "$CACHE" && echo ok > "$STATE_DIR/gh_status"
}

# announce <old> <new>: new review requests and CI state changes on your PRs
# become a notification card (first event shown, "+N" for the rest).
announce() {
  local events
  events="$(jq -r --slurpfile old "$1" '
    def short: split("/") | last;
    def who: sub("-aderant$"; "") | sub("\\[bot\\]$"; "");
    def ci: .commits.nodes[0].commit.statusCheckRollup.state // "NONE";
    ($old[0].reviews.nodes | map(.url)) as $seen
    | ($old[0].mine.nodes | map({key: .url, value: ci}) | from_entries) as $was
    | (.reviews.nodes[] | select(.url as $u | $seen | index($u) | not)
        | ["Review requested · \(.repository.nameWithOwner | short) #\(.number)",
           "@\(.author.login | who) — \(.title)", .url]),
      (.mine.nodes[] | ci as $now | $was[.url] as $before
        | select($before != null and $before != $now and ($now == "FAILURE" or $now == "ERROR"
                 or ($now == "SUCCESS" and $before != "SUCCESS")))
        | [(if $now == "SUCCESS" then "CI passed" else "CI failed" end) + " · \(.repository.nameWithOwner | short) #\(.number)",
           .title, .url])
    | join("\u001f")' "$2" 2>/dev/null)"
  [ -n "$events" ] || return 0
  local n title body url
  n=$(printf '%s\n' "$events" | wc -l | tr -d ' ')
  IFS=$'\x1f' read -r title body url <<< "$(printf '%s\n' "$events" | head -1)"
  [ "$n" -gt 1 ] && title="$title (+$((n - 1)))"
  "$HOME/.config/sketchybar/plugins/toast.sh" post "GitHub" "$title" "$body" "open $url" "GitHub Desktop"
}

render() {
  [ -f "$CACHE" ] || return
  IFS=$'\x1f' read -r reviews mine worst <<< "$(jq -r '
    [.reviews.issueCount, .mine.issueCount,
     ([.mine.nodes[].commits.nodes[0].commit.statusCheckRollup.state // "NONE"]
      | if index("FAILURE") or index("ERROR") then "FAILURE"
        elif index("PENDING") or index("EXPECTED") then "PENDING" else "SUCCESS" end)]
    | map(tostring) | join("\u001f")' "$CACHE")"
  rc=$WHITE; [ "${reviews:-0}" -gt 0 ] && rc=$YELLOW
  case "$worst" in FAILURE) pc=$RED ;; PENDING) pc=$YELLOW ;; *) pc=$GREEN ;; esac
  [ "${mine:-0}" -eq 0 ] && pc=$GREY
  sketchybar $(anim) --set gh.reviews label="${reviews:-0}" icon.color="$rc" \
                     --set gh.prs label="${mine:-0}" icon.color="$pc"
}

popup() {
  local refresh="+sketchybar --set gh.prs.row.1 label='Refreshing…'; NAME=gh.reviews SENDER=refresh $0"
  {
    jq -r --arg now "$(date +%s)" '
      # compact rows: "repo #123 · @author · 2h — title…" (title gets what is left of ~72 chars)
      def short: split("/") | last;
      def who: sub("-aderant$"; "") | sub("\\[bot\\]$"; "");
      def ago: ((($now | tonumber) - (fromdateiso8601)) | if . < 3600 then "\(. / 60 | floor)m"
               elif . < 86400 then "\(. / 3600 | floor)h" else "\(. / 86400 | floor)d" end);
      def fit($head; $title): $head as $h            # the head is never cut
        | (72 - ($h | length) - 3) as $room
        | if $room < 10 then $h
          else "\($h) — \($title | if length > $room then .[0:$room - 1] + "…" else . end)" end;
      def row($i; $l; $c; $s): [$i, $l, $c, $s] | join("\t");
      row("󰊤"; "\(.viewer.login) · \(.notifications) unread"; "open https://github.com/notifications"; "h"),
      row(""; "REVIEW REQUESTED · \(.reviews.issueCount)"; ""; "s"),
      (.reviews.nodes[] | row(if .isDraft then "󰏫" else "󰳐" end;
         fit("\(.repository.nameWithOwner | short) #\(.number) · @\(.author.login | who) · \(.updatedAt | ago)"; .title);
         "open \(.url)"; if .isDraft then "m" else "r" end)),
      (if .reviews.issueCount > (.reviews.nodes | length) then
         row("󰅂"; "\(.reviews.issueCount - (.reviews.nodes | length)) more in your review queue";
             "open https://github.com/pulls/review-requested"; "a") else empty end),
      row(""; "YOUR PULL REQUESTS · \(.mine.issueCount)"; ""; "s"),
      (.mine.nodes[] | (.commits.nodes[0].commit.statusCheckRollup.state // "NONE") as $ci
       | ({"APPROVED": "approved", "CHANGES_REQUESTED": "changes", "REVIEW_REQUIRED": "needs review"}[.reviewDecision // ""]
          // (if .isDraft then "draft" else "open" end)) as $rev
       | row(if $ci == "SUCCESS" then "󰄬" elif $ci == "FAILURE" or $ci == "ERROR" then "󰅖"
             elif $ci == "NONE" then "󰄱" else "󰔟" end;
           fit("\(.repository.nameWithOwner | short) #\(.number) · \($rev)"; .title);
           "[ \"$MODIFIER\" = alt ] && open \(.url)/checks || open \(.url)";
           if $ci == "SUCCESS" then "g" elif $ci == "FAILURE" or $ci == "ERROR" then "x"
           elif $ci == "NONE" then "r" else "y" end))
    ' "$CACHE" 2>/dev/null
    printf '󰑓\tRefresh · updated %s ago\t%s\ta\n' "$(human_age "$(jq -r .ts "$CACHE" 2>/dev/null || date +%s)")" "$refresh"
  } | fill_popup gh.prs 18 "${1:-toggle}"
}

case "$SENDER" in
  mouse.clicked) [ -f "$CACHE" ] && popup || { fetch && render && popup; } ;;
  refresh) fetch; render; popup keep ;;
  *) [ "$NAME" = gh.prs ] && { fetch; render; } ;;   # gh.prs owns the polling
esac
