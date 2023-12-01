#!/bin/bash

# Nginx configuration directory and default test domain
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
HOSTS_FILE="/etc/hosts"
DEFAULT_TEST_DOMAIN=".test"

# Function to check if a domain entry already exists in /etc/hosts
domain_exists() {
    local test_domain="$1"
    grep -q "$test_domain" "$HOSTS_FILE"
}

# Function to create Nginx configuration file
create_nginx_conf() {
    local project_name="$1"
    local conf_file="${project_name,,}.conf"
    local test_domain="${project_name,,}$DEFAULT_TEST_DOMAIN"

    # Create Nginx conf file
    cat > "$NGINX_CONF_DIR/$conf_file" <<EOF
server {
    listen 80;
    server_name $test_domain www.$test_domain;

    root /var/www/$project_name;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;  # Adjust for your PHP version
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    error_log  /var/log/nginx/$project_name_error.log;
    access_log /var/log/nginx/$project_name_access.log;
}
EOF

    # Create symbolic link in sites-enabled
    sudo ln -s "$NGINX_CONF_DIR/$conf_file" "$NGINX_ENABLED_DIR/"

    # Check if domain entry already exists in /etc/hosts
    if ! domain_exists "$test_domain"; then
        # Add entry to /etc/hosts
        echo "127.0.0.1 $test_domain www.$test_domain" | sudo tee -a $HOSTS_FILE > /dev/null
    else
        echo "Domain entry already exists in /etc/hosts for $test_domain"
    fi

    # Reload Nginx to apply changes
    sudo service nginx reload

    echo "Nginx configuration created for $project_name at http://$test_domain"
}

# Check projects in /var/www/ folder
for project_path in /var/www/*; do
    if [[ -d "$project_path" && ! -e "$NGINX_CONF_DIR/$(basename "$project_path" | tr '[:upper:]' '[:lower:]').conf" ]]; then
        create_nginx_conf "$(basename "$project_path")"
    fi
done
