PR_MERGED_FOR_BRANCH() {
  # args: repo_slug branch worktree_path
  local slug="$1" branch="$2" wtpath="$3"
  local default_branch
  default_branch="$(git -C "$wtpath" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's#^refs/remotes/origin/##')"
  [ -z "$default_branch" ] && default_branch=main
  # remote branch exists?
  local remote_exists=0
  git -C "$wtpath" ls-remote --exit-code origin "refs/heads/$branch" >/dev/null 2>&1 && remote_exists=1
  # HEAD reachable from origin default
  local head_reachable=0
  git -C "$wtpath" fetch origin --quiet 2>/dev/null || true
  if git -C "$wtpath" merge-base --is-ancestor HEAD "origin/$default_branch" 2>/dev/null; then head_reachable=1; fi
  # gh PR state
  local pr_json
  if command -v gh-axi >/dev/null 2>&1; then
    pr_json="$(gh-axi pr list --repo "$slug" --head "$branch" --state all --json state,mergedAt 2>/dev/null || true)"
  elif command -v gh >/dev/null 2>&1; then
    pr_json="$(gh pr list --repo "$slug" --head "$branch" --state all --json state,mergedAt 2>/dev/null || true)"
  else
    pr_json=""
  fi
  if printf '%s' "$pr_json" | grep -qi '"mergedAt":[[:space:]]*"[^"]*"'; then return 0; fi
  if printf '%s' "$pr_json" | grep -qi '"state":[[:space:]]*"MERGED"'; then return 0; fi
  # fallback HEAD reachable from default
  [ "$head_reachable" -eq 1 ] && return 0
  return 1
}

