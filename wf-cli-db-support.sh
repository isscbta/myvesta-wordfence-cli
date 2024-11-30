install_custom_wordfence_cli() {
    echo "= Building custom WordFence CLI image with database support..."

    # Create the directory for the custom image
    mkdir -p /root/custom-wordfence-cli
    cd /root/custom-wordfence-cli

    # Create the Dockerfile
    cat <<EOF > Dockerfile
# Use the existing Wordfence CLI image as the base
FROM wordfence-cli:latest

# Install necessary packages
RUN apt-get update && \\
    apt-get install -y --no-install-recommends \\
        mariadb-client \\
        libmariadb3 \\
        libmariadb-dev \\
        build-essential \\
        python3-dev \\
        python3-pip \\
        pkg-config && \\
    rm -rf /var/lib/apt/lists/*

# Install Python MySQL client libraries
RUN pip3 install mysqlclient PyMySQL

# (Optional) Install ping for testing purposes
RUN apt-get update && \\
    apt-get install -y iputils-ping && \\
    rm -rf /var/lib/apt/lists/*
EOF

    # Build the custom Docker image
    docker build -t custom-wordfence-cli .

    echo "= Custom WordFence CLI image with database support built successfully."
}

final_setup () {
    wget https://raw.githubusercontent.com/isscbta/myvesta-wordfence-cli/main/bin/v-wf-db-scan -O /root/vesta/bin/v-wf-db-scan
    chmod a+x /root/vesta/bin/v-wf-db-scan
    cp /root/vesta/bin/v-wf-db-scan /usr/local/vesta/bin/v-wf-db-scan
}

install_custom_wordfence_cli
final_setup
