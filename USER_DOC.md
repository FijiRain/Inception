# User Documentation (USER_DOC.md)

This document provides a guide for end users and administrators to operate and interact with the **Inception** infrastructure.

---

## 1. Services Provided by the Stack

The Inception infrastructure delivers a self-contained, containerized WordPress web platform composed of three primary services:

1. **NGINX (Web Server & Reverse Proxy)**
   - **Role**: Secure gateway and only entrypoint to the entire infrastructure.
   - **Protocol & Port**: Serves traffic strictly over HTTPS on port `443` using TLSv1.2 and TLSv1.3 encryption.
   - **Function**: Directly serves static assets and proxies dynamic `.php` requests securely to the WordPress PHP-FPM service over a private Docker network.

2. **WordPress with PHP-FPM (Application Server)**
   - **Role**: Dynamic web content engine.
   - **Runtime**: PHP 8.2 FastCGI Process Manager (PHP-FPM) listening internally on port `9000`.
   - **Function**: Executes the WordPress core, handles page rendering, user authentication, and business logic without exposing any public web ports.

3. **MariaDB (Database Engine)**
   - **Role**: Relational database storage.
   - **Port**: Listens internally on port `3306` inside the private network.
   - **Function**: Persistently manages all WordPress posts, comments, registered user data, and system configurations. It is never exposed to the outside world.

---

## 2. Starting and Stopping the Project

All operational commands can be executed using `make` from the repository root:

### Starting the Services
To build (if necessary) and launch all containers in the background:
```bash
make up
# or simply:
make
```
*Docker will create the necessary storage directories on the host, configure the internal network, mount secrets, and start the containers.*

### Pausing / Stopping the Services
To stop running containers without removing their state or network definitions:
```bash
make stop
```

### Shutting Down the Stack
To stop and tear down containers and internal networks (while keeping all persistent database and website files safe):
```bash
make down
```

### Restarting the Stack
To cleanly restart all services:
```bash
make down
make up
```

---

## 3. Accessing the Website and Administration Panel

### Host Setup (First Time Only)
Ensure your host machine resolves `tmoga.42.fr` to your local machine:
```bash
# Add this entry to /etc/hosts if not already present
127.0.0.1   tmoga.42.fr
```

### Accessing the Public Website
Open your browser and navigate to:
```text
https://tmoga.42.fr
```

> **Note on Browser SSL Warnings**:
> Because Inception uses a self-signed SSL/TLS certificate generated at build time, modern browsers will display a warning (e.g., *"Your connection is not private"* or *"Potential Security Risk Ahead"*).
> Click **Advanced** and then **Proceed to tmoga.42.fr (unsafe)** / **Accept the Risk and Continue** to access the site.

### Accessing the WordPress Administration Panel
To log in as an administrator:
1. Navigate to:
   ```text
   https://tmoga.42.fr/wp-login.php
   # or
   https://tmoga.42.fr/wp-admin
   ```
2. Enter the administrator credentials (see Section 4 below).

---

## 4. Locating and Managing Credentials

All sensitive credentials and passwords are stored in the local `secrets/` directory on the host machine. These files are excluded from version control to prevent credential leaks.

### Credentials Location & Files
The secret files are stored at:
- `secrets/credentials.txt`: Contains WordPress user accounts.
  ```env
  WP_ADMIN_USER=tmoga_wp
  WP_ADMIN_PASSWORD=<your_admin_password>
  WP_USER=user_wp
  WP_USER_PASSWORD=<your_user_password>
  ```
- `secrets/db_password.txt`: The password for the standard MariaDB user (`tmoga_user`).
- `secrets/db_root_password.txt`: The password for the MariaDB root administrator.

### User Roles & Constraints
- **Administrator User (`WP_ADMIN_USER`)**:
  - Full rights to configure themes, plugins, site settings, and users.
  - Per project requirements, the administrator's username **cannot** contain `admin`, `Admin`, or `administrator`.
- **Standard User (`WP_USER`)**:
  - Assigned the `author` role.
  - Intended for authoring and publishing content without administrative privileges.

### Changing Passwords
- **Via the WordPress Dashboard**:
  Log into `https://tmoga.42.fr/wp-admin`, navigate to **Users > Profile**, and set a new password.
- **Via WP-CLI (from terminal)**:
  ```bash
  docker compose -f srcs/docker-compose.yml exec wordpress \
    wp user update tmoga_wp --user_pass="NewPassword123!" --allow-root
  ```

---

## 5. Checking Service Health & Status

You can verify that all components are operating properly using standard Docker commands:

### 1. Verify Container Status
Run:
```bash
docker compose -f srcs/docker-compose.yml ps
```
**Expected Output**:
All three containers (`nginx`, `wordpress`, `mariadb`) should have a `STATUS` of `Up`.

### 2. Inspect Service Logs
To monitor logs in real-time or troubleshoot errors:
```bash
# View logs from all services:
docker compose -f srcs/docker-compose.yml logs -f

# View logs for a specific service:
docker compose -f srcs/docker-compose.yml logs -f nginx
docker compose -f srcs/docker-compose.yml logs -f wordpress
docker compose -f srcs/docker-compose.yml logs -f mariadb
```

### 3. Verify HTTPS & TLS Configuration
Test that NGINX accepts TLSv1.2 or TLSv1.3 and rejects insecure protocols (TLSv1.0 / TLSv1.1):
```bash
# Verify TLSv1.2 connection:
openssl s_client -connect tmoga.42.fr:443 -tls1_2

# Verify TLSv1.3 connection:
openssl s_client -connect tmoga.42.fr:443 -tls1_3

# Verify HTTP response code:
curl -k -I https://tmoga.42.fr
# Expected: HTTP/2 200 (or HTTP/1.1 200 OK)
```

### 4. Verify Database Connectivity
Check that MariaDB responds to ping commands:
```bash
docker compose -f srcs/docker-compose.yml exec mariadb \
  mysqladmin ping -u tmoga_user -p$(cat secrets/db_password.txt)
# Expected: mysqld is alive
```
