#!/bin/bash
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

echo 'Following software will be installed on your system:'
echo '   - WordFence CLI'

# Function to install Docker
install_docker() {
    echo "= Checking for Docker..."
    if ! command -v docker &> /dev/null; then
        echo "= Docker not found. Starting Docker installation."
        apt-get update > /dev/null 2>&1

        release=$(cat /etc/debian_version | tr "." "\n" | head -n1)
        if [ "$release" -gt 10 ]; then
            # Debian > 10
            apt-get install -y ca-certificates curl > /dev/null 2>&1
            echo "= Installing docker repo"
            install -m 0755 -d /etc/apt/keyrings && \
            curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
            chmod a+r /etc/apt/keyrings/docker.asc && \
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            echo "= Installing docker"
            apt-get update > /dev/null 2>&1
            apt-get install -y docker-ce docker-ce-cli containerd.io
            apt-get install -y docker-buildx-plugin docker-compose-plugin
        else
            # Debian < 11
            apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common
            curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
            add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
            apt-get update > /dev/null 2>&1
            apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
        if ! command -v docker &> /dev/null; then
            echo "- Error installing docker !!!";
            exit 1;
        fi
        # echo "= Creating docker group"
        # newgrp docker
        echo "= Installing docker-compose"
        curl -s https://api.github.com/repos/docker/compose/releases/latest | grep browser_download_url | grep docker-compose-linux-x86_64 | cut -d '"' -f 4 | wget -qi - && \
        chmod +x docker-compose-linux-x86_64 && \
        mv docker-compose-linux-x86_64 /usr/local/bin/docker-compose
        # docker-compose version
        systemctl restart docker
        echo "= Docker installation completed."
    else
        echo "= Docker is already installed."
    fi
}

# Function to check and install Git if needed
install_git() {
    echo "= Checking for Git..."
    if ! command -v git &> /dev/null; then
        echo "= Git not found. Starting Git installation."
        apt-get update > /dev/null 2>&1
        apt-get install -y git
        echo "= Git installation completed."
    else
        echo "= Git is already installed."
    fi
}

# Install and configure WordFence CLI
install_wordfence_cli() {
    echo "= Starting WordFence CLI installation..."
    if [ -d "/root/wordfence-cli" ]; then
        cd /root/wordfence-cli
        git pull
    else
        cd ~ && git clone https://github.com/wordfence/wordfence-cli.git
        cd ~/wordfence-cli
    fi
    docker build -t wordfence-cli:latest .
    echo "= WordFence CLI installation completed."

    if [ ! -d "/root/wfcli-conf" ]; then
        echo "= Starting WordFence CLI configuration..."
        docker run -it -v /var/www:/var/www wordfence-cli:latest configure
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

# Final setup steps
final_setup() {
    wget https://raw.githubusercontent.com/isscbta/myvesta-wordfence-cli/main/bin/v-wf-malware-scan -O /root/vesta/bin/v-wf-malware-scan
    wget https://raw.githubusercontent.com/isscbta/myvesta-wordfence-cli/main/bin/v-wf-vulnerability-scan -O /root/vesta/bin/v-wf-vulnerability-scan
    wget https://raw.githubusercontent.com/isscbta/myvesta-wordfence-cli/main/bin/v-wf-remediate -O /root/vesta/bin/v-wf-remediate
    wget https://raw.githubusercontent.com/isscbta/myvesta-wordfence-cli/refs/heads/main/bin/v-wf-db-scan -O /root/vesta/bin/v-wf-db-scan
    chmod a+x /root/vesta/bin/v-wf-malware-scan
    chmod a+x /root/vesta/bin/v-wf-vulnerability-scan
    chmod a+x /root/vesta/bin/v-wf-remediate
    chmod a+x /root/vesta/bin/v-wf-db-scan
    cp /root/vesta/bin/v-wf-malware-scan /usr/local/vesta/bin/v-wf-malware-scan
    cp /root/vesta/bin/v-wf-vulnerability-scan /usr/local/vesta/bin/v-wf-vulnerability-scan
    cp /root/vesta/bin/v-wf-remediate /usr/local/vesta/bin/v-wf-remediate
    cp /root/vesta/bin/v-wf-db-scan /usr/local/vesta/bin/v-wf-db-scan
    echo "==============================="
    echo "WordFence CLI is ready to use."
    echo "==============================="
    echo ""
    echo "Use:"
    echo "v-wf-malware-scan DOMAIN"
    echo "... for malware scanning."
    echo ""
    echo "Use:"
    echo "v-wf-vulnerability-scan DOMAIN"
    echo "... for vulnerability scanning."
    echo ""
    echo "Use:"
    echo "v-wf-remediate DOMAIN"
    echo "... for automatically repairing known files belonging to a WordPress installation"
    echo "Use:"
    echo "v-wf-db-scan DOMAIN"
    echo "... for scanning WordPress database"
    echo ""
    echo ""
    echo "Append --progress, --banner, etc., at the end of the command to include additional parameters. A full list of parameters can be found on the WordFence CLI documentation page."
    echo ""
    echo "==============================="
}

# Main installation process
install_docker
install_git
install_wordfence_cli
final_setup
