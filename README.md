*This project has been created as part of the 42 curriculum by tmoga.*

# Inception

## Description

### Project Overview & Goals
**Inception** is a System Administration and DevOps project from the 42 school curriculum. The objective is to design, build, and orchestrate a secure, multi-container web infrastructure deployed on a personal virtual machine using **Docker** and **Docker Compose**.

The entire stack is built from scratch without using any pre-built application images from public registries such as Docker Hub. Each container is built from a dedicated custom `Dockerfile` based on the penultimate stable version of Debian (`debian:bookworm-slim`).

The infrastructure consists of three isolated services communicating over a private Docker network:
1. **NGINX**: The sole entry point of the infrastructure, listening strictly on port `443` over TLSv1.2 / TLSv1.3. It acts as a reverse proxy and web server, routing dynamic PHP requests to WordPress.
2. **WordPress + PHP-FPM**: The content management system running PHP 8.2 FastCGI Process Manager (PHP-FPM) without an embedded NGINX web server, serving pages and interacting with MariaDB.
3. **MariaDB**: The relational database management system storing the WordPress database tables, completely isolated from direct outside access.

### Sources & Repository Structure
The project sources are structured as follows:
- `Makefile`: Located at the root, orchestrates building images, starting containers, and cleaning resources.
- `secrets/`: Local directory containing confidential files (`credentials.txt`, `db_password.txt`, `db_root_password.txt`), ignored by Git. Templates are provided via `*.example` files.
- `srcs/`: Contains all infrastructure configuration:
  - `docker-compose.yml`: Declares services, custom networks, named volumes, and Docker secrets.
  - `.env`: Stores non-sensitive configuration parameters (such as `DOMAIN_NAME`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_ADMIN_USER`).
  - `requirements/mariadb/`: Dockerfile, configuration, and initialization scripts for MariaDB.
  - `requirements/nginx/`: Dockerfile, TLS configuration, and entrypoint for NGINX.
  - `requirements/wordpress/`: Dockerfile, PHP-FPM pool configuration, and automated WP-CLI bootstrap script.

### Setup

Copy the provided templates and fill in your own values (non-sensitive config in `.env`, sensitive credentials in `secrets/`):

```console
cp srcs/.env.example srcs/.env
cp secrets/credentials.txt.example secrets/credentials.txt
cp secrets/db_password.txt.example secrets/db_password.txt
cp secrets/db_root_password.txt.example secrets/db_root_password.txt
```

---

### Key Architectural Comparisons & Design Choices

#### 1. Virtual Machines vs Docker
| Feature | Virtual Machine (VM) | Docker Containers |
| :--- | :--- | :--- |
| **Virtualization Level** | Hardware-level virtualization (Hypervisor). | Operating system-level virtualization (shared Linux kernel). |
| **Guest OS** | Each VM runs a complete guest operating system with dedicated kernel, drivers, and overhead. | Containers share the host kernel and only bundle the application binaries and runtime libraries. |
| **Resource Usage** | Heavy; fixed CPU and RAM allocation upfront. | Extremely lightweight; dynamically consumes only active memory and CPU. |
| **Startup Time** | Minutes (boots a full operating system). | Seconds to sub-seconds (starts a single process tree). |
| **Isolation** | Strong hardware boundary; fault in guest cannot crash the host. | Process-level isolation via Linux `namespaces` and `cgroups`. |
| **Choice in Inception** | A virtual machine is used as the **host environment** (sandbox), inside which Docker containers run to isolate services cleanly without VM hypervisor overhead. |

#### 2. Secrets vs Environment Variables
| Feature | Environment Variables (`.env` / `environment`) | Docker Secrets (`secrets:`) |
| :--- | :--- | :--- |
| **Storage & Visibility** | Stored in process memory; visible via `docker inspect`, `env`, `/proc/<pid>/environ`, and process listing. | Mounted as in-memory files under `/run/secrets/<secret_name>` (tmpfs). Never written to disk inside the container. |
| **Leak Risk** | High; logged in error dumps, subshells, child processes, and easily captured in version control. | Minimal; accessible only to authorized processes with filesystem read access to the specific secret mount. |
| **Best Used For** | Non-confidential application configuration (e.g., domain names, database names, usernames, ports). | Sensitive credentials, API tokens, passwords, private certificates, and encryption keys. |
| **Choice in Inception** | Non-sensitive parameters (`DOMAIN_NAME`, `MYSQL_DATABASE`, `MYSQL_USER`) live in `srcs/.env`. All passwords and admin credentials are securely passed via Docker Secrets. |

#### 3. Docker Network vs Host Network
| Feature | Docker Bridge Network (`bridge`) | Host Network (`network_mode: host`) |
| :--- | :--- | :--- |
| **Isolation** | Creates a private virtual software bridge with independent IP subnet and port routing. | Bypasses container network isolation; container shares the host network namespace directly. |
| **Service Discovery** | Built-in internal DNS resolution allows containers to address each other by service name (e.g., `mariadb`, `wordpress`). | No internal DNS resolution; services bind directly to host ports, causing potential port conflicts. |
| **Security** | Unexposed ports (e.g., MariaDB `3306`, PHP-FPM `9000`) are strictly unreachable from the outside world. | All container ports are exposed on the host network interfaces without filtering. |
| **Choice in Inception** | A custom Docker network (`inception`) is used. Port `443` on NGINX is the only published port to the host. MariaDB and WordPress communicate privately over the bridge network. |

#### 4. Docker Volumes vs Bind Mounts
| Feature | Docker Named Volumes | Bind Mounts |
| :--- | :--- | :--- |
| **Management** | Fully managed by Docker (`docker volume ls`, `docker volume rm`); decoupled from host directory structures. | Directly maps an arbitrary file or folder on the host machine to a container path. |
| **Portability** | High; platform-independent and managed through Docker Compose specifications. | Tied to the host directory layout and file permissions. |
| **Safety & Persistence** | Protected against accidental modifications; data lifecycle is independent of container lifecycles. | Direct risk of host-side accidental deletion, privilege discrepancies, and file locking issues. |
| **Choice in Inception** | The project defines Docker **named volumes** (`db_data`, `wp_data`) backed by local storage driver options (`type: none`, `o: bind`, `device: /home/tmoga/data/...`) as required by the 42 subject. This combines the management and abstraction of named volumes with persistent storage on the host filesystem. |

---

## Instructions

### 1. Prerequisites
- **Operating System**: Linux (Debian 12 Bookworm or Ubuntu recommended) or a Linux Virtual Machine.
- **Docker Engine**: Docker CE 24.0+ and Docker Compose v2.20+.
- **Make**: GNU Make utility.
- **Administrative Privileges**: `sudo` access to create data directories in `/home/tmoga/data/` and edit `/etc/hosts`.

### 2. Domain Name Configuration
Map the project domain name (`tmoga.42.fr`) to your local loopback address:
```bash
sudo echo "127.0.0.1 tmoga.42.fr" | sudo tee -a /etc/hosts
```

### 3. Setup Secrets & Environment Files
Before starting the infrastructure, ensure that your configuration and secret files exist:

1. **Environment File**:
   Copy the example environment file if it does not already exist:
   ```bash
   cp srcs/.env.example srcs/.env
   ```
   Verify that `DOMAIN_NAME=tmoga.42.fr`.

2. **Secret Files**:
   Create the secret files from their examples in the `secrets/` directory:
   ```bash
   cp secrets/credentials.txt.example secrets/credentials.txt
   cp secrets/db_password.txt.example secrets/db_password.txt
   cp secrets/db_root_password.txt.example secrets/db_root_password.txt
   ```
   *Replace any placeholder passwords inside these files with your chosen secure passwords.*

### 4. Compilation & Execution
All lifecycle operations are managed through the root `Makefile`:

- **Build images and launch containers** in detached mode:
  ```bash
  make
  # or
  make up
  ```
  *This automatically creates `/home/tmoga/data/db_data` and `/home/tmoga/data/wp_data`, builds custom Docker images, and starts the stack.*

- **Stop running containers** without destroying them:
  ```bash
  make stop
  ```

- **Stop and remove containers and networks**:
  ```bash
  make down
  ```

- **Remove containers, networks, and custom images**:
  ```bash
  make clean
  ```

- **Full clean (deep reset)**:
  Stops containers, deletes custom images, and removes persistent volume directories on the host (`/home/tmoga/data/*`):
  ```bash
  make fclean
  ```

- **Rebuild and restart from scratch**:
  ```bash
  make re
  ```

---

## Resources

### References & Documentation
- [Official Docker Documentation](https://docs.docker.com/) — Multi-container orchestration, named volumes, bridge networking, Docker secrets.
- [Docker Compose Specification](https://docs.docker.com/compose/compose-file/) — Compose file v3/v2 reference.
- [NGINX Documentation](https://nginx.org/en/docs/) — Reverse proxy configuration, FastCGI integration, and TLS setup.
- [PHP-FPM Documentation](https://www.php.net/manual/en/install.fpm.php) — FastCGI Process Manager configuration (`www.conf`).
- [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/) — Command-line interface for automated WordPress installation and user provisioning.
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/) — Non-interactive database initialization, user privileges, and security settings.

### AI Usage Declaration
In compliance with the 42 AI Guidelines (Chapter IV & Chapter VI):
- **Assisted Tasks**:
  - Formatting and reviewing the documentation files (`README.md`, `USER_DOC.md`, `DEV_DOC.md`) according to the subject specifications.
  - Reviewing `.gitignore` rules and cache untracking strategies.
- **Human Verification & Validation**:
  - Every script, Dockerfile directive, and configuration parameter was manually inspected, reviewed line-by-line, and tested in the execution environment to ensure adherence to 42 requirements.
