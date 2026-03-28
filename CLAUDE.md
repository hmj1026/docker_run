# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**POSDEV Docker** is a unified local development environment for multiple PHP projects (Yii 1.1 framework and Laravel applications) running in Docker containers. It supports 6 PHP versions (5.6, 7.4, 8.0, 8.1, 8.2, 8.3) with corresponding Composer and PHPUnit installations, enabling developers to test across different PHP versions without reinstalling tools.

### Key Projects Hosted
- **zdpos_dev**: Main POS application (Yii 1.1 framework)
- **zdpos_oklao**: OKL merchant variant
- **conductor_dev**: Community management system
- **mypos_kds**: Kitchen Display System (Laravel 5.6)
- **mypos_dev3**: MyPOS variant
- **notifier**: Notification service
- **yii_framework**: Shared Yii 1.1 framework

### Architecture
Three Docker containers:
- **Nginx** (1.24-alpine): Web server
- **PHP-FPM**: Versioned PHP with Composer + PHPUnit
- **MySQL**: Database server (versions 5.7, 8.0, 8.4)

All projects use a **distributed management model**:
- Independent directories (`pos_dev/`, `yii_framework/`, etc.) mounted into containers
- Host path changes sync immediately to containers
- Database host must be `mysql` (not localhost) in container configs

---

## Essential Commands

### Environment Setup & Startup
```bash
# Copy and configure environment
cp .env.example .env
# Edit .env to set PROJECT_PATH, YII_FRAMEWORK_PATH, WEB_ROOT_PATH, etc.

# Start all services
docker compose up -d

# Build and start (if images changed)
docker compose build --no-cache && docker compose up -d

# Stop services
docker compose down --remove-orphans

# Full rebuild (removes containers/networks)
docker compose down --remove-orphans && docker compose build --no-cache && docker compose up -d
```

### Make Commands (preferred - use instead of docker compose directly)
```bash
make help              # Show all available commands
make up                # Start all containers
make down              # Stop all containers
make build             # Full rebuild
make restart           # Restart containers
make shell             # Enter PHP container shell
make db-shell          # Enter MySQL shell
make logs              # Tail all logs
make logs-php          # Tail PHP logs only
make php-version       # Show PHP version
make mysql-version     # Show MySQL version
```

### PHP Version Switching (change PHP_VERSION in .env first)
```bash
# Interactive mode
bash scripts/switch-version.sh

# Test all versions
bash scripts/test-versions.sh

# Manually
PHP_VERSION=74 docker compose build php --no-cache && docker compose up -d
```

### Testing (within PHP container or via docker exec)
```bash
# Enter PHP container
docker compose exec php bash

# Run PHPUnit tests
docker exec -i -w //var/www/www.posdev/zdpos_dev pos_php phpunit -c protected/tests/phpunit.xml

# Run specific test suite (unit/integration/functional)
docker exec -i -w //var/www/www.posdev/zdpos_dev pos_php phpunit -c protected/tests/phpunit.xml --testsuite unit

# Generate coverage report
docker exec -i -w //var/www/www.posdev/zdpos_dev pos_php \
  phpunit -c protected/tests/phpunit.xml \
  --coverage-html protected/tests/coverage/html
```

### Debugging & Logs
```bash
# View container status
docker compose ps

# Check Nginx config
docker compose exec nginx nginx -t

# Follow Nginx logs
docker compose logs -f nginx

# Follow PHP logs
docker compose logs -f php

# Follow MySQL logs
docker compose logs -f mysql

# Database connection test
docker compose exec mysql mysql -uroot -e "SHOW DATABASES;"
```

---

## Critical Configuration Notes

### Database Host Configuration
**IMPORTANT**: All project config files must use `mysql` as database host (not `localhost`), as containers communicate via the internal Docker network:

```php
// ✅ CORRECT - for all projects
'db' => [
    'connectionString' => 'mysql:host=mysql;dbname=zdpos_dev',
    'username' => 'root',
    'password' => '',
]

// ❌ WRONG - will fail in Docker
'connectionString' => 'mysql:host=localhost;dbname=zdpos_dev',
```

### .env Path Format
Use your platform's native path format:
```bash
# Linux / WSL2:
PROJECT_PATH=/home/<username>/projects/pos_dev

# macOS:
PROJECT_PATH=/Users/<username>/projects/pos_dev

# Windows (Docker Desktop):
PROJECT_PATH=C:/Users/<username>/projects/pos_dev
```

### Port Conflicts
Ensure ports 80, 443, 3306 are available. Stop other services before starting Docker:
```bash
lsof -i :80
lsof -i :443
lsof -i :3306
```

### Directory Structure Expected
```
<projects>/                # Platform-dependent base path (see .env Path Format above)
├── pos_dev/               # Main POS application
├── yii_framework/         # Shared Yii 1.1
├── www.posdev/            # Web root (merchants: dev/, xxoo/, etc.)
├── mypos_kds/             # Laravel KDS
├── conductor_dev/         # Community system
└── notifier/              # Notification service
```

---

## File Structure Key Directories

| Directory | Purpose |
|-----------|---------|
| `/php/php{56,74,80,81,82,83}/` | PHP Dockerfile & php.ini for each version |
| `/nginx/conf.d/` | Nginx virtual host configs |
| `/nginx/ssl/` | SSL certificates (self-signed) |
| `/mysql/conf.d/` | MySQL configuration |
| `/mysql/init/` | Database init scripts (git-ignored) |
| `/docs/` | Comprehensive setup and troubleshooting docs |
| `/scripts/` | Version switching, cert generation, testing scripts |
| `/logs/` | All container logs (nginx, php, mysql, app) |
| `/data/mysql/` | MySQL persistent data |

---

## PHP Version Composer & PHPUnit Compatibility

Each PHP version has pre-installed Composer and PHPUnit:

| PHP Version | Composer Version | PHPUnit Version | Installation Method |
|------------|------------------|-----------------|---------------------|
| 5.6        | 1.10.27          | 5.7.27          | PHAR (Composer deprecated) |
| 7.4        | 2.2.24           | 9.6.30          | Composer            |
| 8.0        | 2.8.x            | 9.6.x           | Composer            |
| 8.1        | 2.8.12           | 10.5.59         | Composer            |
| 8.2        | 2.8.x            | 10.5.x          | Composer            |
| 8.3        | 2.8.x            | 11.x            | Composer            |

Verify after version switch:
```bash
docker compose run --rm php composer --version
docker compose run --rm php phpunit --version
```

---

## Storage Directory Management

The application logs to `/var/www/zdnStorage/logs` and creates directories dynamically (e.g., 2026-03, 2026-04, etc.).

### Permission Management (Automatic)

`scripts/php-entrypoint.sh` provides two layers of permission management:

1. **Startup fix**: On container start, sets `chmod -R 0777` and `chown www-data:www-data` on existing zdnStorage directories, plus `umask 0000` for the PHP-FPM process.
2. **Background watcher**: A background process runs every 60 seconds, scanning `/var/www/zdnStorage` and correcting any directories to `0777` and files to `0666`. This catches directories created at runtime with wrong permissions (e.g., PHP `mkdir()` calls with restrictive mode parameters).

If you're experiencing directory creation errors:
```
fopen(/var/www/zdnStorage/logs/2026-04/.../file.xml): failed to open stream
```

Simply restart containers -- permissions will be auto-corrected within 60 seconds:
```bash
docker compose down && docker compose up -d
```

### StorageHelper (Optional Application-level Solution)

For application-level directory management, see [`docs/STORAGE_HELPER_INTEGRATION.md`](docs/STORAGE_HELPER_INTEGRATION.md).

---

## Common Issues & Solutions

### "Connection is not private" SSL warning
Self-signed certificates are used. Either:
1. Trust the certificate (`nginx/ssl/laragon.crt`)
2. Access via HTTP instead (Nginx redirects to HTTPS by default)
3. Regenerate: `bash scripts/generate-cert.sh www.posdev.test`

### "CDbConnection failed to open the DB connection"
1. Check database host is `mysql` (not localhost) in project configs
2. Verify MySQL container is running: `docker compose ps`
3. Check MySQL logs: `docker compose logs mysql`
4. Ensure database and user exist

### 404 or 502 errors
1. Verify `.env` paths are correct and directories exist
2. Check Nginx config: `docker compose exec nginx nginx -t`
3. Check file mounts: `docker compose exec php ls -la /var/www/www.posdev/`
4. Review Nginx logs: `docker compose logs nginx`
5. **Merchant directories 404** (dev3, 186, bdfy, etc.): These require explicit volume mounts in `docker-compose.yml` for both nginx and php services. If a new merchant is added, its mount must be added to both services.

### Containers fail to start
1. Check ports are available (80, 443, 3306)
2. Check Docker CE is running: `systemctl status docker`
3. Review build logs: `docker compose build --no-cache php`

### Host file entry needed
Add to `/etc/hosts`:
```
127.0.0.1 www.posdev.test
```

---

## Networking & URLs

**Web access** (https by default):
- `https://www.posdev.test/dev/` - zdpos_dev
- `https://mypos.posdev.test/` - MyPOS KDS (requires matching hosts entry)

**Container-to-container**: Use service names as hostnames
- PHP ↔ MySQL: use `mysql:3306`
- Nginx ↔ PHP: use `php:9000`

**Host-to-container**: Use localhost:PORT
- MySQL: `localhost:3306` (from host machine)
- HTTP: `localhost:80` (from host machine)

---

## Documentation Files

Detailed docs are in `/docs/`:
- **README.md**: Quick start, prerequisites, configuration checklist
- **PHP_COMPOSER_PHPUNIT_SETUP.md**: Composer & PHPUnit unified setup details
- **VERSION_REFERENCE.md**: Version compatibility matrix
- **TEST_GUIDE.md**: PHP version testing procedures and troubleshooting
- **FILE_STRUCTURE.md**: Directory structure explanation

---

## Important Constraints

### Git-Ignored Paths (not version-controlled)
- `.env` (environment config)
- `logs/` (all container logs)
- `data/mysql/` (database files)
- `nginx/ssl/*.crt` & `nginx/ssl/*.key` (SSL certificates)
- `mysql/init/*` except `.gitkeep` (database init scripts)

### Volume Mounting Order
In docker-compose.yml, parent directories mount before child directories. This allows child project directories to override parent mounts. Order matters for correct path resolution.

All directories that need to be accessible inside the container (merchant entry-points like dev3, 186, bdfy, etc.) must have **explicit individual mounts** in both nginx and php services. When adding a new merchant directory to `www.posdev`, you must also add its mount to `docker-compose.yml`.

### PHP 5.6 Compatibility
- No type hints, return types, or null coalescing operators (`??`)
- Use PHPDoc for type documentation
- Use Yii 1.1 framework conventions strictly

### Container Names
Derived from `.env` COMPOSE_PROJECT_NAME (default: `posdev`):
- `posdev_nginx`
- `posdev_php`
- `posdev_mysql`
- Network: `posdev_network`

---

## Development Workflow

1. **Modify code** in host directory (e.g., `<projects>/pos_dev/`)
2. **Changes sync immediately** to container (no rebuild needed)
3. **Access via browser** or container shell to test
4. **Check logs** if issues: `docker compose logs [service]`
5. **Database changes** might require SQL execution in MySQL container
6. **Version changes** require `.env` modification + `docker compose up -d --build`

---

## Next Steps for Contributors

- Read **README.md** for setup procedures
- Read **docs/TEST_GUIDE.md** if testing multiple PHP versions
- Read **docs/PHP_COMPOSER_PHPUNIT_SETUP.md** for Composer/PHPUnit details
- Use `bash scripts/switch-version.sh` to test versions
- Run full test suite before committing: `phpunit -c protected/tests/phpunit.xml`
