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

# Install and configure WordFence CLI
install_wordfence_cli() {
    echo "= Starting WordFence CLI installation..."

    # Pull the custom Wordfence CLI image with Vectorscan installed
    echo "= Pulling WordFence CLI Docker image from Docker Hub..."
    docker pull mycityhosting/wordfence-cli:with-vectorscan-amd64 || {
        echo "- Failed to pull custom Wordfence CLI image."
        exit 1
    }

    # Tag the pulled image locally as 'wordfence-cli:latest'
    docker tag mycityhosting/wordfence-cli:with-vectorscan-amd64 wordfence-cli:latest

    echo "= WordFence CLI installation completed."

    # Only configure if configuration directory doesn't exist
    if [ ! -d "/root/wfcli-conf" ]; then
        echo "= Starting WordFence CLI configuration..."

        # Run 'configure' in an interactive container
        docker run -it -v /var/www:/var/www wordfence-cli:latest configure

        # Find the container that ran the 'configure' command
        CONFCONTAINER=$(docker ps -a | grep 'wordfence configure' | head -n 1 | awk '{print $NF}')

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

# Sanity check
echo "= Sanity check..."
docker run --rm "${IMAGE_LOCAL}" version

echo
echo "==============================="
echo "WordFence CLI update completed."
echo "==============================="
echo
