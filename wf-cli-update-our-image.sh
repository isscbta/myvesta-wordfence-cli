#!/bin/bash
set -e

# Clear screen and print welcome message
clear
echo
echo "                __     __        _        "
echo "  _ __ ___  _   \ \   / /__  ___| |_ __ _ "
echo " | '_ \` _ \| | | \ \ / / _ \/ __| __/ _\` |"
echo " | | | | | | |_| |\ V /  __/\__ \ || (_| |"
echo " |_| |_| |_|\__, | \_/ \___||___/\__\__,_|"
echo "            |___/                         "
echo
echo '          myVesta Control Panel           '
echo -e "\n\n"

echo 'Following software will be updated on your system:'
echo '   - WordFence CLI'
echo

IMAGE_LOCAL="wordfence-cli:latest"
REPO_REMOTE="mycityhosting/wordfence-cli"
TAG_FILTER_REGEX='^[0-9]+\.[0-9]+\.[0-9]+(-r[0-9]+)?$'

wait_to_press_enter=1
function press_enter {
    if [ $wait_to_press_enter -eq 1 ]; then
        read -p "$1"
    else
        echo "$1"
    fi
}

ask_yes_no() {
  local prompt="$1"
  local answer
  read -r -p "$prompt [y/N]: " answer
  case "$answer" in
    y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

# 1) Delete only WordFence containers (running + stopped)
echo "= Removing WordFence CLI containers..."
docker ps -a --format '{{.ID}} {{.Image}}' \
  | awk '$2 ~ /^(wordfence-cli|mycityhosting\/wordfence-cli|isscbta\/wordfence-cli)(:|$)/ {print $1}' \
  | xargs -r docker rm -f

# 2) Delete only wordfence CLI images
echo "= Removing WordFence CLI images..."
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
  | awk '$1 ~ /^(wordfence-cli|mycityhosting\/wordfence-cli|isscbta\/wordfence-cli)(:|$)/ {print $2}' \
  | sort -u \
  | xargs -r docker rmi -f

# 3) Delete local folders
echo "= Removing local WordFence folders..."
rm -rf ~/wordfence-cli
rm -rf ~/wfcli-conf
rm -rf ~/myvesta-wordfence-cli

press_enter "=== Press Enter to download and install Wordfence CLI (you can select a version) ==="

fetch_remote_tags() {
  # Docker Hub v2 tags endpoint
  # Note: Docker Hub may paginate, but for a small number of tags this is fine.
  local url="https://hub.docker.com/v2/repositories/${REPO_REMOTE}/tags?page_size=100"

  if command -v jq >/dev/null 2>&1; then
    curl -fsSL "$url" | jq -r '.results[].name'
  else
    # Fallback without jq: extract "name":"..."
    curl -fsSL "$url" \
      | grep -oE '"name"\s*:\s*"[^"]+"' \
      | sed -E 's/.*"name"\s*:\s*"([^"]+)".*/\1/'
  fi
}

choose_remote_tag_interactive() {
  local tags filtered

  tags="$(fetch_remote_tags || true)"
  if [ -z "$tags" ]; then
    echo "- Unable to fetch tags from Docker Hub." >&2
    exit 1
  fi

  # Only versioned tags, newest first
  filtered="$(echo "$tags" | grep -E "${TAG_FILTER_REGEX}" | sort -Vr || true)"

  if [ -z "$filtered" ]; then
    echo "- No versioned tags found on Docker Hub that match: ${TAG_FILTER_REGEX}" >&2
    exit 1
  fi

  echo >&2
  echo "=== Select Wordfence CLI image tag to install (newest is first) ===" >&2

  local options=()
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    options+=("$t")
  done <<< "$filtered"

  PS3="Choose an option (1-${#options[@]}): "
  select opt in "${options[@]}"; do
    if [ -z "$opt" ]; then
      echo "- Invalid selection, try again." >&2
      continue
    fi
    echo "$opt"
    return 0
  done
}

update_vesta_commands() {
  echo "= Updating myVesta Wordfence CLI command scripts..."

  local base="https://raw.githubusercontent.com/isscbta/myvesta-wordfence-cli/refs/heads/main/bin"
  local dest="/usr/local/vesta/bin"

  # List of command scripts to update
  local files=(
    "v-wf-malware-scan"
    "v-wf-malware-hyperscan"
    "v-wf-vulnerability-scan"
    "v-wf-remediate"
    "v-wf-db-scan"
    "v-wf-scan-path"
    "v-wf-malware-hyperscan-with-remediate"
  )

  for f in "${files[@]}"; do
    echo "  - Updating ${dest}/${f}"
    wget -q -O "${dest}/${f}.tmp" "${base}/${f}" || {
      echo "- Failed to download ${base}/${f}"
      rm -f "${dest}/${f}.tmp"
      exit 1
    }
    mv -f "${dest}/${f}.tmp" "${dest}/${f}"
    chmod a+x "${dest}/${f}"
  done

  echo "= Command scripts updated."
}

# Install and configure WordFence CLI
install_wordfence_cli() {
    echo "= Starting WordFence CLI installation..."

    # Choose a tag (latest or a pinned version)
    REMOTE_TAG="$(choose_remote_tag_interactive | tr -d '\r' | xargs)"
    IMAGE_REMOTE="${REPO_REMOTE}:${REMOTE_TAG}"

    echo "= Pulling Wordfence CLI Docker image: ${IMAGE_REMOTE} ..."
    docker pull "${IMAGE_REMOTE}" || {
        echo "- Failed to pull Wordfence CLI image: ${IMAGE_REMOTE}"
        exit 1
    }

    # Tag the pulled image locally as 'wordfence-cli:latest'
    docker tag "${IMAGE_REMOTE}" "${IMAGE_LOCAL}"

    echo "= WordFence CLI installation completed."

    # Only configure if configuration directory doesn't exist
    if [ ! -d "/root/wfcli-conf" ]; then
        echo "= Starting WordFence CLI configuration..."

    # Run 'configure' in an interactive container
    docker run -it -v /var/www:/var/www wordfence-cli:latest configure

    # Get the last created container (more reliable than grepping)
    CONFCONTAINER="$(docker ps -aq --latest)"

        docker start "$CONFCONTAINER"
        CONFCONTENT=$(docker exec -it "$CONFCONTAINER" cat ~/.config/wordfence/wordfence-cli.ini)
        docker stop "$CONFCONTAINER"

        mkdir -p ~/wfcli-conf
        echo "$CONFCONTENT" > ~/wfcli-conf/wordfence-cli.ini

        if [ -s ~/wfcli-conf/wordfence-cli.ini ]; then
            echo "= WordFence CLI configuration completed successfully."
            cat ~/wfcli-conf/wordfence-cli.ini
        else
            echo "- WordFence CLI configuration failed. The configuration file is empty or missing."
        fi
    fi
}

# Main update process
install_wordfence_cli

if ask_yes_no "Update myVesta Wordfence CLI command scripts (v-wf-*) as well?"; then
  update_vesta_commands
else
  echo "= Skipping command scripts update."
fi

# Sanity check
echo "= Sanity check..."
docker run --rm "${IMAGE_LOCAL}" --version 2>/dev/null \
  || docker run --rm "${IMAGE_LOCAL}" version 2>/dev/null \
  || docker run --rm "${IMAGE_LOCAL}" --help | head -n 20

echo
echo "==============================="
echo "WordFence CLI update completed."
echo "==============================="
echo
