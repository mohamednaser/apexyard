#!/bin/bash
# Blocks direct pushes and commits to main/master branch.
# All changes must go through pull requests.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Block: git push origin main, git push origin master
if echo "$COMMAND" | grep -qE '\bgit\s+push\s+\S+\s+(main|master)(\s|$)'; then
  echo "BLOCKED: Cannot push directly to main/master. All changes must go through a PR." >&2
  exit 2
fi

# Block: git commit on main/master branch
if echo "$COMMAND" | grep -qE '\bgit\s+commit\b'; then
  # Resolve working tree: nested repos often use `cd <repo> && git commit` or
  # `git -C <repo> commit`. Without this, `git branch` uses the wrong cwd (e.g.
  # ops-repo main while committing inside workspace/<project>).
  GIT_WT=""
  if [[ "$COMMAND" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+)[[:space:]]+commit ]]; then
    GIT_WT="${BASH_REMATCH[1]}"
  elif [[ "$COMMAND" =~ cd[[:space:]]+([^&]+)\&\&[[:space:]]*git[[:space:]]+commit ]]; then
    GIT_WT="${BASH_REMATCH[1]}"
    # trim surrounding quotes / whitespace from `cd '...' &&`
    GIT_WT="${GIT_WT#"${GIT_WT%%[![:space:]]*}"}"
    GIT_WT="${GIT_WT%"${GIT_WT##*[![:space:]]}"}"
    GIT_WT="${GIT_WT#\'}"
    GIT_WT="${GIT_WT%\'}"
    GIT_WT="${GIT_WT#\"}"
    GIT_WT="${GIT_WT%\"}"
  fi

  if [ -n "$GIT_WT" ] && [ -e "$GIT_WT/.git" ]; then
    CURRENT_BRANCH=$(git -C "$GIT_WT" branch --show-current 2>/dev/null)
  else
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
  fi

  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    echo "BLOCKED: Cannot commit directly on $CURRENT_BRANCH. Create a feature branch first." >&2
    exit 2
  fi
fi

exit 0
