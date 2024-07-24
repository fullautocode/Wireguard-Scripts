#!/bin/bash

# Function to check if WireGuard is running
function check_wireguard {
    if ! systemctl is-active --quiet wg-quick@wg0; then
        echo -e "\e[31mError: WireGuard is not running. Please start WireGuard to proceed.\e[0m"
        exit 1
    fi
}

function check_curl {
    if ! command -v curl &> /dev/null; then
        echo -e "\e[31mError: curl is not installed. Please install curl to proceed.\e[0m"
        exit 1
    fi
}

# Function to generate WireGuard keys
function generate_keys {
    PRIVATE_KEY=$(wg genkey)
    PUBLIC_KEY=$(echo $PRIVATE_KEY | wg pubkey)
}

# Function to get user input without default value
function get_input {
    local prompt=$1
    local input=""
    while [ -z "$input" ]; do
        read -p "$prompt: " input
        if [ -z "$input" ]; then
            echo -e "\e[31mError: This field is required. Please try again.\e[0m"
        fi
    done
    echo "$input"
}

# Funtion to get user input with default value 
function get_input_with_default {
    local prompt=$1
    local default=$2
    read -p "$prompt [$default]: " input
    echo "${input:-$default}"
}

# Get server public key from file 
if [[ -f /etc/wireguard/publickey ]]; then 
    server_public_key=$(cat /etc/wireguard/publickey)
else 
    echo -e "\e[31mError: /etc/wireguard/publickey not found. Closing...\e[0m"
    exit 1
fi

# Function to create the WireGuard client configuration file
function create_config {
    local ip_address=$1
    local listen_port=$2
    local server_public_key=$3
    local server_endpoint=$4
    local template_name=$5

    config_dir="/etc/wireguard/client-templates/${template_name}"
    config_file="${config_dir}/${template_name}.conf"

    mkdir -p "$config_dir"
    echo "$PRIVATE_KEY" > "${config_dir}/privatekey"
    echo "$PUBLIC_KEY" > "${config_dir}/publickey"

    cat <<EOF > $config_file
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $ip_address
DNS = 1.1.1.1

[Peer]
PublicKey = $server_public_key
Endpoint = $server_endpoint:$listen_port
AllowedIPs = 0.0.0.0/0
EOF

    echo -e "\e[32mConfiguration file created at $config_file\e[0m"
}

# Check if WireGuard is running
check_wireguard

# Check if curl is installed
check_curl

# Generate WireGuard keys
generate_keys

# Get user inputs
template_name=$(get_input "Enter the template name")
ip_address=$(get_input "Enter the IP address of the host on the VPN (example: 10.0.0.2/32)")
listen_port=$(get_input_with_default "Enter the listen port (default: 51820)" "51820")

# Get the server's public IPv4 address
server_endpoint=$(curl -s4 ifconfig.me)
if [[ -z "$server_endpoint" ]]; then
    echo -e "\e[31mError: Unable to retrieve the server's public IP address. Closing...\e[0m"
    exit 1
fi

# Create configuration file
create_config "$ip_address" "$listen_port" "$server_public_key" "$server_endpoint" "$template_name"

# Display the WireGuard add peer command
echo -e "\e[32mTo add the client to the WireGuard server, run the following command on the server:\e[0m"
echo "wg set wg0 peer $PUBLIC_KEY allowed-ips $ip_address"
