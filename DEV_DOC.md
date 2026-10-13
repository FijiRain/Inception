# Developer Documentation (DEV_DOC.md)

This technical guide is intended for developers maintaining, extending, or auditing the **Inception** infrastructure.

---

## 1. Setting Up the Environment from Scratch

### 1.1. System Prerequisites
- **Operating System**: A clean installation of Debian 12 (Bookworm) or Ubuntu 22.04+ running inside a Virtual Machine.
- **Packages**:
  - `make`
  - `curl`, `ca-certificates`, `openssl`
  - `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose-plugin` (Docker Compose v2)
  - Current user added to the `docker` group (`sudo usermod -aG docker $USER`).

### 1.2. Host Configuration & DNS
Add the custom domain to `/etc/hosts` on the host system:
```bash
echo "127.0.0.1 tmoga.42.fr" | sudo tee -a /etc/hosts
```

### 1.3. Volume Directories Preparation
The named volumes map to specific local directories on the host:
```bash
sudo mkdir -p /home/tmoga/data/db_data
sudo mkdir -p /home/tmoga/data/wp_data
sudo chown -R $USER:$USER /home/tmoga/data
```
*(Note: The root `Makefile` automatically ensures these directories exist upon calling `make up`).*

### 1.4. Environment Variables (`srcs/.env`)
Create `srcs/.env` by copying `srcs/.env.example`:
```bash
cp srcs/.env.example srcs/.env
```

| Variable | Description | Example |
| :--- | :--- | :--- |
| `DOMAIN_NAME` | Primary domain name for NGINX server block and WordPress URL. | `tmoga.42.fr` |
| `MYSQL_DATABASE` | Name of the database to be created for WordPress. | `wordpress` |
| `MYSQL_USER` | Dedicated MySQL user account used by WordPress. | `tmoga_user` |
| `MYSQL_ADMIN_USER` | Secondary MySQL administrator user. | `tmoga` |

### 1.5. Docker Secrets Setup (`secrets/`)
Create the secret files from their template counterparts:
```bash
cp secrets/credentials.txt.example secrets/credentials.txt
cp secrets/db_password.txt.example secrets/db_password.txt
cp secrets/db_root_password.txt.example secrets/db_root_password.txt
```

File contents:
- **`secrets/credentials.txt`**:
  ```ini
  WP_ADMIN_USER=tmoga_wp
  WP_ADMIN_PASSWORD=StrongAdminPasswordHere1!
  WP_USER=user_wp
  WP_USER_PASSWORD=StrongUserPasswordHere2!
  ```
  *(Important: `WP_ADMIN_USER` cannot contain `admin` or `Admin`).*
- **`secrets/db_password.txt`**: Single-line string containing the MySQL user password.
- **`secrets/db_root_password.txt`**: Single-line string containing the MySQL root password.

---

## 2. Architecture & Service Design

```mermaid
graph TD
    User["Client Browser"] -->|Port 443 (HTTPS TLS 1.2/1.3)| NGINX["NGINX Container"]
    subgraph "Docker Private Network (inception)"
        NGINX -->|FastCGI Port 9000| WP["WordPress + PHP-FPM Container"]
        WP -->|MySQL Port 3306| DB["MariaDB Container"]
    end
    subgraph "Persistent Storage (/home/tmoga/data)"
        WP -.->|Named Volume: wp_data| WP_DIR["/home/tmoga/data/wp_data"]
        DB -.->|Named Volume: db_data| DB_DIR["/home/tmoga/data/db_data"]
    end
```

### Container Implementation Details

1. **`mariadb` (`srcs/requirements/mariadb/`)**:
   - Base image: `debian:bookworm-slim`.
   - Listens on internal port `3306`.
   - `tools/install.sh`: Installs `mariadb-server` and cleans `/var/lib/mysql`.
   - `tools/init.sh`: Reads secrets from `/run/secrets/`, provisions the `wordpress` database, creates users with appropriate privileges, sets the root password, and executes `mysqld` as PID 1 (`exec mysqld --user=mysql`).

2. **`wordpress` (`srcs/requirements/wordpress/`)**:
   - Base image: `debian:bookworm-slim`.
   - Installs PHP-FPM 8.2 and extensions, plus WP-CLI.
   - Listens on `0.0.0.0:9000` via `/etc/php/8.2/fpm/pool.d/www.conf`.
   - `tools/init.sh`: Waits for MariaDB socket availability (`mysqladmin ping`), generates `wp-config.php`, executes `wp core install`, creates the second WordPress user (`wp user create`), marks completion with `.wp_good_init`, and runs PHP-FPM in foreground (`exec php-fpm8.2 -F`).

3. **`nginx` (`srcs/requirements/nginx/`)**:
   - Base image: `debian:bookworm-slim`.
   - Generates a self-signed TLS certificate for `${DOMAIN_NAME}` via OpenSSL during build.
   - Configures `/etc/nginx/sites-available/default` with `ssl_protocols TLSv1.2 TLSv1.3;`.
   - Forwards PHP scripts to `wordpress:9000` through `fastcgi_pass`.
   - Runs as PID 1 via `CMD ["nginx", "-g", "daemon off;"]`.

---

## 3. Building and Launching the Infrastructure

### Standard Lifecycle Commands (`Makefile`)
The repository includes a top-level `Makefile` wrapping Docker Compose:

```bash
# Build images and start containers in background
make up
# or
make

# Pause / stop containers
make stop

# Tear down containers and networks
make down

# Remove containers, networks, and custom images
make clean

# Complete purge (removes images, containers, networks, and persistent data on disk)
make fclean

# Full rebuild from clean slate
make re
```

### Direct Docker Compose Commands
If running commands directly:
```bash
# Build images with no cache
docker compose -f srcs/docker-compose.yml build --no-cache

# Run with interactive logs
docker compose -f srcs/docker-compose.yml up --build

# Validate configuration syntax
docker compose -f srcs/docker-compose.yml config
```

---

## 4. Useful Management & Debugging Commands

### 4.1. Managing Containers
```bash
# View running containers and status
docker compose -f srcs/docker-compose.yml ps

# Follow logs of a specific service
docker compose -f srcs/docker-compose.yml logs -f mariadb
docker compose -f srcs/docker-compose.yml logs -f wordpress
docker compose -f srcs/docker-compose.yml logs -f nginx

# Open an interactive shell inside a container
docker compose -f srcs/docker-compose.yml exec mariadb sh
docker compose -f srcs/docker-compose.yml exec wordpress sh
docker compose -f srcs/docker-compose.yml exec nginx sh

# Restart an individual container
docker compose -f srcs/docker-compose.yml restart wordpress
```

### 4.2. Managing Volumes & Storage
```bash
# List Docker volumes
docker volume ls

# Inspect volume driver options and host mount points
docker volume inspect srcs_db_data
docker volume inspect srcs_wp_data

# Inspect file contents directly on the host
ls -la /home/tmoga/data/db_data
ls -la /home/tmoga/data/wp_data
```

### 4.3. Managing Networks
```bash
# Inspect the private bridge network
docker network inspect srcs_inception
```

### 4.4. Testing WordPress via WP-CLI inside Container
```bash
# List existing WordPress users
docker compose -f srcs/docker-compose.yml exec wordpress \
  wp user list --path=/var/www/wordpress --allow-root

# Check database tables
docker compose -f srcs/docker-compose.yml exec wordpress \
  wp db tables --path=/var/www/wordpress --allow-root
```

---

## 5. Data Storage and Persistence

### Storage Strategy
The 42 Inception subject strictly requires Docker **named volumes** (not raw bind mounts) whose underlying data resides in `/home/<login>/data` on the host machine.

This is achieved using Docker's local volume driver with bind mount options declared in `srcs/docker-compose.yml`:
```yaml
volumes:
  db_data:
    driver_opts:
      type: none
      o: bind
      device: /home/tmoga/data/db_data
  wp_data:
    driver_opts:
      type: none
      o: bind
      device: /home/tmoga/data/wp_data
```

### What Persists in Each Volume?
1. **`db_data` (`/home/tmoga/data/db_data`)**:
   - Houses the MySQL/MariaDB database catalog (`/var/lib/mysql`).
   - Stores the database schema, posts, user tables (`wp_users`, `wp_usermeta`), comments, and site configurations.
2. **`wp_data` (`/home/tmoga/data/wp_data`)**:
   - Houses the WordPress filesystem root (`/var/www/wordpress`).
   - Stores `wp-config.php`, plugin assets, uploaded media files (`wp-content/uploads/`), themes, and the initialization flag (`.wp_good_init`).

### Data Lifecycle Behavior
- **Reboots / Container Stops (`make stop` / `make down`)**:
  - The containers and network may be recreated, but the files in `/home/tmoga/data/` remain untouched.
  - Upon restart (`make up`), WordPress checks for `/var/www/wordpress/.wp_good_init` and skips re-installation, ensuring continuous data integrity.
- **Full Purge (`make fclean`)**:
  - Executes `sudo rm -rf /home/tmoga/data/*`.
  - The next `make up` will perform a fresh initialization, re-creating the database schema and default WordPress admin and user accounts.
