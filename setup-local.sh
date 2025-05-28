#!/bin/bash

# MariaDB Local Installation Script
# This script installs MariaDB locally on Linux and macOS using native package managers

set -e

MARIADB_VERSION=""
MARIADB_PORT=""
MARIADB_ROOT_PASSWORD=""
MARIADB_USER=""
MARIADB_PASSWORD=""
MARIADB_DATABASE=""
MARIADB_CONFIG_FILE=""

###############################################################################
echo "::group::🔍 Detecting Package Manager"

# Detect package manager
if command -v brew &> /dev/null; then
    PKG_MANAGER="brew"
    echo "✅ Using Homebrew package manager (macOS)"
elif command -v apt-get &> /dev/null; then
    PKG_MANAGER="apt"
    echo "✅ Using APT package manager (Ubuntu/Debian)"
elif command -v yum &> /dev/null; then
    PKG_MANAGER="yum"
    echo "✅ Using YUM package manager (RHEL/CentOS)"
elif command -v dnf &> /dev/null; then
    PKG_MANAGER="dnf"
    echo "✅ Using DNF package manager (Fedora)"
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    echo "✅ Using Pacman package manager (Arch Linux)"
elif command -v zypper &> /dev/null; then
    PKG_MANAGER="zypper"
    echo "✅ Using Zypper package manager (openSUSE)"
else
    echo "❌ No supported package manager found"
    echo "Supported: brew (macOS), apt (Ubuntu/Debian), yum (RHEL/CentOS), dnf (Fedora), pacman (Arch), zypper (openSUSE)"
    exit 1
fi

echo "::endgroup::"

###############################################################################
echo "::group::🔧 Processing Configuration"

# Set MariaDB version
if [[ -n "${SETUP_TAG}" && "${SETUP_TAG}" != "latest" ]]; then
    MARIADB_VERSION="${SETUP_TAG}"
    echo "✅ MariaDB version set to ${MARIADB_VERSION}"
else
    echo "✅ Using latest MariaDB version"
fi

# Set port
MARIADB_PORT="${SETUP_PORT:-3306}"
echo "✅ MariaDB port set to ${MARIADB_PORT}"

# Set root password
if [[ -n "${SETUP_ROOT_PASSWORD}" ]]; then
    MARIADB_ROOT_PASSWORD="${SETUP_ROOT_PASSWORD}"
    echo "✅ Root password is explicitly set"
else
    if [[ -n "${SETUP_ALLOW_EMPTY_ROOT_PASSWORD}" && ( "${SETUP_ALLOW_EMPTY_ROOT_PASSWORD}" == "1" || "${SETUP_ALLOW_EMPTY_ROOT_PASSWORD}" == "yes" ) ]]; then
        MARIADB_ROOT_PASSWORD=""
        echo "⚠️ Root password will be empty"
    else
        MARIADB_ROOT_PASSWORD=$(openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)
        echo "⚠️ Root password will be randomly generated: ${MARIADB_ROOT_PASSWORD}"
    fi
fi

# Set user and password
if [[ -n "${SETUP_USER}" ]]; then
    MARIADB_USER="${SETUP_USER}"
    echo "✅ MariaDB user set to ${MARIADB_USER}"
fi

if [[ -n "${SETUP_PASSWORD}" ]]; then
    MARIADB_PASSWORD="${SETUP_PASSWORD}"
    echo "✅ MariaDB user password is explicitly set"
fi

# Set database
if [[ -n "${SETUP_DATABASE}" ]]; then
    MARIADB_DATABASE="${SETUP_DATABASE}"
    echo "✅ Initial database set to ${MARIADB_DATABASE}"
fi

# Check for unsupported SETUP_ADDITIONAL_CONF
if [[ -n "${SETUP_ADDITIONAL_CONF}" ]]; then
    echo "⚠️ SETUP_ADDITIONAL_CONF is not supported in local installation and will be ignored"
fi

echo "::endgroup::"

###############################################################################
echo "::group::📦 Installing MariaDB"

install_mariadb() {
    case $PKG_MANAGER in
        "brew")
            echo "Installing MariaDB using Homebrew..."
            if [[ -n "${MARIADB_VERSION}" ]]; then
                brew install mariadb@"${MARIADB_VERSION}"
            else
                brew install mariadb
            fi

            ;;
        "apt")
            echo "Installing MariaDB using APT..."
            sudo apt-get update
            if [[ -n "${MARIADB_VERSION}" ]]; then
                sudo apt-get install -y mariadb-server="${MARIADB_VERSION}*" mariadb-client="${MARIADB_VERSION}*"
            else
                sudo apt-get install -y mariadb-server mariadb-client
            fi
            ;;
        "yum")
            echo "Installing MariaDB using YUM..."
            if [[ -n "${MARIADB_VERSION}" ]]; then
                sudo yum install -y mariadb-server-"${MARIADB_VERSION}" mariadb-"${MARIADB_VERSION}"
            else
                sudo yum install -y mariadb-server mariadb
            fi
            ;;
        "dnf")
            echo "Installing MariaDB using DNF..."
            if [[ -n "${MARIADB_VERSION}" ]]; then
                sudo dnf install -y mariadb-server-"${MARIADB_VERSION}" mariadb-"${MARIADB_VERSION}"
            else
                sudo dnf install -y mariadb-server mariadb
            fi
            ;;
        "pacman")
            echo "Installing MariaDB using Pacman..."
            sudo pacman -Sy --noconfirm mariadb
            ;;
        "zypper")
            echo "Installing MariaDB using Zypper..."
            if [[ -n "${MARIADB_VERSION}" ]]; then
                sudo zypper install -y mariadb-"${MARIADB_VERSION}" mariadb-client-"${MARIADB_VERSION}"
            else
                sudo zypper install -y mariadb mariadb-client
            fi
            ;;
        *)
            echo "❌ Unsupported package manager: $PKG_MANAGER"
            exit 1
            ;;
    esac
}

# Check if MariaDB is already installed
if command -v mysql &> /dev/null || command -v mariadb &> /dev/null; then
    echo "⚠️ MariaDB/MySQL appears to be already installed"
    if command -v mariadb &> /dev/null; then
        EXISTING_VERSION=$(mariadb --version 2>/dev/null || echo "unknown")
        echo "Existing version: ${EXISTING_VERSION}"
    fi
else
    install_mariadb
    echo "✅ MariaDB installation completed"
fi

echo "::endgroup::"

###############################################################################
echo "::group::🚀 Starting MariaDB Service"

start_mariadb() {
    case $PKG_MANAGER in
        "brew")
            if [[ -n "${MARIADB_VERSION}" ]]; then
                brew services start mariadb@"${MARIADB_VERSION}"
            else
                brew services start mariadb
            fi
            echo "✅ MariaDB service started"
            ;;
        *)
            # Linux distributions
            if command -v systemctl &> /dev/null; then
                sudo systemctl start mariadb || sudo systemctl start mysql
                sudo systemctl enable mariadb || sudo systemctl enable mysql
                echo "✅ MariaDB service started and enabled"
            elif command -v service &> /dev/null; then
                sudo service mariadb start || sudo service mysql start
                echo "✅ MariaDB service started"
            else
                echo "⚠️ Could not start MariaDB service automatically"
            fi
            ;;
    esac
}

start_mariadb

# Wait for MariaDB to be ready
echo "⏳ Waiting for MariaDB to be ready..."

# Function to check if MariaDB is ready
check_mariadb_ready() {
    local password="$1"
    local port="${2:-3306}"

    echo $PATH

    which mysql
    mysql --version

    which mariadb
    mariadb --version

    ls -la $(brew --prefix)/bin | grep -i maria

    # Check where Homebrew installed MariaDB
    brew list mariadb | head -20

    # Check Homebrew's bin directory
    ls -la $(brew --prefix)/bin | grep maria

    # Manually add to current session
    export PATH="$(brew --prefix)/bin:$PATH"

    mariadb --version

    if [[ -n "$password" ]]; then
      mysqlCmd=(mariadb -uroot --password="$password" --port= "$port")
    else
      mysqlCmd=(mariadb -uroot --port="$port")
    fi
    for i in {15..0}; do
      if echo 'SELECT 1' | "${mysqlCmd[@]}" &> /dev/null; then
          break
      fi
      echo 'data server still not active'
      sleep 5
    done
    if [ "$i" = 0 ]; then
      if echo 'SELECT 1' | "${mysqlCmd[@]}" ; then
          return 1;
      fi
      return 0;
    else
      return 1
    fi
}

if check_mariadb_ready "" "3306"; then
    echo "✅ MariaDB is ready!"
else
    echo "❌ MariaDB failed to start within 30 seconds"
    exit 1
fi

echo "::endgroup::"

###############################################################################
echo "::group::🔐 Configuring MariaDB"

# Configure MariaDB
configure_mariadb() {
    # Set root password if specified
    if [[ -n "${MARIADB_ROOT_PASSWORD}" ]]; then
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';" 2>/dev/null || \
        mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MARIADB_ROOT_PASSWORD}');" 2>/dev/null || \
        mysqladmin -u root password "${MARIADB_ROOT_PASSWORD}" 2>/dev/null
        echo "✅ Root password configured"
    fi

    # Create database if specified
    if [[ -n "${MARIADB_DATABASE}" ]]; then
        if [[ -n "${MARIADB_ROOT_PASSWORD}" ]]; then
            mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;"
        else
            mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;"
        fi
        echo "✅ Database '${MARIADB_DATABASE}' created"
    fi

    # Create user if specified
    if [[ -n "${MARIADB_USER}" && -n "${MARIADB_PASSWORD}" ]]; then
        if [[ -n "${MARIADB_ROOT_PASSWORD}" ]]; then
            mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';"
            if [[ -n "${MARIADB_DATABASE}" ]]; then
                mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';"
            else
                mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON *.* TO '${MARIADB_USER}'@'%';"
            fi
            mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
        else
            mysql -u root -e "CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';"
            if [[ -n "${MARIADB_DATABASE}" ]]; then
                mysql -u root -e "GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';"
            else
                mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '${MARIADB_USER}'@'%';"
            fi
            mysql -u root -e "FLUSH PRIVILEGES;"
        fi
        echo "✅ User '${MARIADB_USER}' created and granted privileges"
    fi

    # Configure port if different from default
    if [[ "${MARIADB_PORT}" != "3306" ]]; then
        # Find MariaDB configuration file
        for config_file in /etc/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/my.cnf /etc/my.cnf /usr/local/etc/my.cnf; do
            if [[ -f "$config_file" ]]; then
                MARIADB_CONFIG_FILE="$config_file"
                break
            fi
        done

        if [[ -n "${MARIADB_CONFIG_FILE}" ]]; then
            # Backup original config
            sudo cp "${MARIADB_CONFIG_FILE}" "${MARIADB_CONFIG_FILE}.backup"
            
            # Update port in config file
            if grep -q "^port" "${MARIADB_CONFIG_FILE}"; then
                sudo sed -i "s/^port.*/port = ${MARIADB_PORT}/" "${MARIADB_CONFIG_FILE}"
            else
                sudo sed -i "/^\[mysqld\]/a port = ${MARIADB_PORT}" "${MARIADB_CONFIG_FILE}"
            fi
            
            echo "✅ Port configured to ${MARIADB_PORT} in ${MARIADB_CONFIG_FILE}"
            
            # Restart MariaDB to apply port change
            case $PKG_MANAGER in
                "brew")
                    if [[ -n "${MARIADB_VERSION}" ]]; then
                        brew services restart mariadb@"${MARIADB_VERSION}"
                    else
                        brew services restart mariadb
                    fi
                    ;;
                *)
                    sudo systemctl restart mariadb || sudo systemctl restart mysql
                    ;;
            esac
            echo "✅ MariaDB restarted with new port configuration"
            
            # Wait for MariaDB to be ready after restart
            echo "⏳ Waiting for MariaDB to be ready after restart..."
            if check_mariadb_ready "${MARIADB_ROOT_PASSWORD}" "${MARIADB_PORT}"; then
                echo "✅ MariaDB is ready!"
            else
                echo "❌ MariaDB failed to start within 30 seconds"
                exit 1
            fi
        else
            echo "⚠️ Could not find MariaDB configuration file to set custom port"
        fi
    fi
}

configure_mariadb

echo "::endgroup::"

###############################################################################
echo "::group::🎯 Running Additional Configuration"

# Run configuration scripts if provided
if [[ -n "${SETUP_CONF_SCRIPT_FOLDER}" && -d "${SETUP_CONF_SCRIPT_FOLDER}" ]]; then
    echo "✅ Processing configuration scripts from ${SETUP_CONF_SCRIPT_FOLDER}"
    for conf_file in "${SETUP_CONF_SCRIPT_FOLDER}"/*.cnf; do
        if [[ -f "$conf_file" ]]; then
            echo "Processing configuration file: $conf_file"
            # Copy configuration files to MariaDB conf.d directory
            if [[ -d "/etc/mysql/conf.d" ]]; then
                sudo cp "$conf_file" "/etc/mysql/conf.d/"
            elif [[ -d "/etc/mysql/mariadb.conf.d" ]]; then
                sudo cp "$conf_file" "/etc/mysql/mariadb.conf.d/"
            fi
        fi
    done
fi

# Run initialization scripts if provided
if [[ -n "${SETUP_INIT_SCRIPT_FOLDER}" && -d "${SETUP_INIT_SCRIPT_FOLDER}" ]]; then
    echo "✅ Processing initialization scripts from ${SETUP_INIT_SCRIPT_FOLDER}"
    for init_file in "${SETUP_INIT_SCRIPT_FOLDER}"/*.sql; do
        if [[ -f "$init_file" ]]; then
            echo "Executing initialization script: $init_file"
            if [[ -n "${MARIADB_ROOT_PASSWORD}" ]]; then
                mysql -u root -p"${MARIADB_ROOT_PASSWORD}" < "$init_file"
            else
                mysql -u root < "$init_file"
            fi
        fi
    done
fi

echo "::endgroup::"

###############################################################################
echo "::group::✅ MariaDB Local Installation Complete"

echo "🎉 MariaDB has been successfully installed and configured locally!"
echo ""
echo "📋 Configuration Summary:"
echo "  • Port: ${MARIADB_PORT}"
echo "  • Root Password: ${MARIADB_ROOT_PASSWORD:-"(empty)"}"
if [[ -n "${MARIADB_USER}" ]]; then
    echo "  • User: ${MARIADB_USER}"
    echo "  • User Password: ${MARIADB_PASSWORD:-"(not set)"}"
fi
if [[ -n "${MARIADB_DATABASE}" ]]; then
    echo "  • Database: ${MARIADB_DATABASE}"
fi
echo ""
echo "🔗 Connection Examples:"
if [[ -n "${MARIADB_ROOT_PASSWORD}" ]]; then
    echo "  mysql -u root -p'${MARIADB_ROOT_PASSWORD}' -P ${MARIADB_PORT}"
else
    echo "  mysql -u root -P ${MARIADB_PORT}"
fi
if [[ -n "${MARIADB_USER}" && -n "${MARIADB_PASSWORD}" ]]; then
    echo "  mysql -u ${MARIADB_USER} -p'${MARIADB_PASSWORD}' -P ${MARIADB_PORT}"
    if [[ -n "${MARIADB_DATABASE}" ]]; then
        echo "  mysql -u ${MARIADB_USER} -p'${MARIADB_PASSWORD}' -P ${MARIADB_PORT} ${MARIADB_DATABASE}"
    fi
fi

echo "::endgroup::"

exit 0 