# Python , UV, FastAPI installation and Fastapi Service creation Steps in Amazon linux Ec2

We'll create three scripts:

1. `install_python_uv.sh` — installs `uv` and the selected Python version.
2. `setup_fastapi.sh` — creates the FastAPI project and installs dependencies.
3. `create_fastapi_service.sh` — creates and enables the `systemd` service.

We'll also create a fourth optional script, `deploy_fastapi.sh`, to install updated dependencies and restart the service whenever you change your code.

# 1. Directory structure

Create a folder for your deployment scripts:

```
fastapi-deployment/
├── install_python_uv.sh
├── setup_fastapi.sh
├── create_fastapi_service.sh
└── deploy_fastapi.sh
└── setup_nginx.sh

```

These scripts assume your application directory is `/home/ec2-user/fastapi-app`, your service is named `fastapi`, and your application uses `main.py` with `app = FastAPI()`
 
 
 
 # Install Python and uv : install_python_uv.sh
 This script:

- Installs the required system packages.
- Installs `uv` for the current user.
- Installs Python 3.15 through `uv`.
- Lets you select a different version when needed.

If you want Python 3.14 instead, run:

```shell
PYTHON_VERSION=3.14 bash install_python_uv.sh
```

Run this script as `ec2-user`, not as root, so `uv` and its managed Python versions are installed for the intended application user.

# Create the FastAPI application : setup_fastapi.sh
Important: This script preserves an existing `main.py`, so it won't overwrite your customized application code. It also uses `uv add` to record the FastAPI dependency in your project.

If you changed the project directory, you can specify it like this:

```
APP_DIR="$HOME/my-api" bash setup_fastapi.sh
```
# Create and enable the systemd service: create_fastapi_service.sh

This script automatically:

1. Validates your application directory and Uvicorn installation.
2. Creates `/etc/systemd/system/fastapi.service`.
3. Reloads systemd's configuration.
4. Enables FastAPI at boot.
5. Restarts the application and checks whether it started.

The script uses `sudo` for systemd operations, while the application itself runs as `ec2-user`

# Deploy code and dependency updates: deploy_fastapi.sh
- Whenever you update your application or install new Python packages, use this script to synchronize dependencies and restart FastAPI.
- Note: `uv sync` installs the dependencies declared in your project and lockfile. If you add a new dependency, use `uv add package-name` first, then run the deployment script.

# Make all scripts executable

From your `fastapi-deployment` directory, run:

```shell
chmod +x install_python_uv.sh
chmod +x setup_fastapi.sh
chmod +x create_fastapi_service.sh
chmod +x deploy_fastapi.sh
```


# Run the complete setup
Run these commands in order, as `ec2-user`:

```
./install_python_uv.sh
```

```
./setup_fastapi.sh
```

```
./create_fastapi_service.sh
```

Afterward, verify the service:

```
sudo systemctl status fastapi
```

Test the API:

```
curl http://127.0.0.1:8000/health
```

Expected result:

```
{"status":"healthy"}
```


# How to use these scripts later

First-time installation

Install Python and uv, create the app, and configure systemd.

```
./install_python_uv.sh
./setup_fastapi.sh
./create_fastapi_service.sh
```

After changing code or dependencies

```
./deploy_fastapi.sh
```

Troubleshooting

```
sudo journalctl -u fastapi -f
```

# A few production considerations

- Keep your EC2 Security Group restricted; don't expose port 8000 to everyone unless you explicitly intend to.
- Keep `pyproject.toml` and `uv.lock` in version control so deployments use reproducible dependencies.
- These scripts assume your application is already present on the EC2 instance. For automated deployments from Git, add a Git checkout or pull step before `uv sync`.
- Run the initial setup scripts as `ec2-user`. Don't run the entire installation script with `sudo`, because `uv` should be installed for the application user.

My recommendation: Once these scripts work, keep them in a Git repository. You can reuse them whenever you launch a new Amazon Linux 2023 EC2 instance, rather than repeating each installation step manually.


# NGNIX Setup ; setup_nginx.sh

It assumes your existing project is /home/ec2-user/fastapi-app and your service is named fastapi.




## 4. Run the script

Make it executable:

```
chmod +x setup_nginx.sh
```

Run it as `ec2-user` (do not run the entire script using `sudo`):

```
./setup_nginx.sh
```

When prompted, enter your actual domain, such as:

```
api.example.com
```

The script will install Nginx, change Uvicorn to listen on `127.0.0.1:8000`, create the Nginx configuration, and restart both services.

## 5. Configure DNS

At your domain provider, create an A record:

| DNS setting | Value                        |
| ----------- | ---------------------------- |
| Type        | A                            |
| Name / Host | `api`                        |
| Value       | Your EC2 public IPv4 address |
| TTL         | Provider default             |

For example, if your domain is `example.com`, the resulting hostname is `api.example.com`.

Consider associating an Elastic IP with your EC2 instance so the IP address remains stable across instance stops and starts.

## 6. Update the EC2 Security Group

Open AWS Console → EC2 → Instances → your instance → Security → Security Groups → Inbound rules.

Configure:

| Port | Source       | Purpose                |
| ---- | ------------ | ---------------------- |
| 22   | Your IP only | SSH administration     |
| 80   | `0.0.0.0/0`  | Public HTTP API access |

After confirming Nginx works, remove the inbound port `8000` rule. Nginx and FastAPI communicate over localhost, so no public rule for port 8000 is needed.

## 7. Verify the deployment

Run these commands on EC2:

```
sudo systemctl status nginx
sudo systemctl status fastapi
```

Confirm FastAPI is listening only on localhost:

```
sudo ss -ltnp | grep ':8000'
```

The expected address is:

```
127.0.0.1:8000
```

Test the reverse proxy locally:

```
curl -H "Host: api.example.com" http://127.0.0.1/health
curl -H "Host: publicip" http://127.0.0.1/health
```

Replace `api.example.com` with your actual domain. Expected response:

```
{"status":"healthy"}
```

Finally, test from your browser:

`http://api.example.com/docs`

If DNS has propagated and the Security Group is configured correctly, the FastAPI interactive documentation should appear.

## 8. Troubleshooting commands

| Problem                   | Command                                            |
| ------------------------- | -------------------------------------------------- |
| Check Nginx configuration | `sudo nginx -t`                                    |
| View Nginx errors         | `sudo tail -n 50 /var/log/nginx/fastapi_error.log` |
| View access logs          | `sudo tail -f /var/log/nginx/fastapi_access.log`   |
| Restart Nginx             | `sudo systemctl restart nginx`                     |
| Restart FastAPI           | `sudo systemctl restart fastapi`                   |
| Check DNS resolution      | `getent hosts api.example.com`                     |

One final recommendation: this script sets up HTTP only. Once the domain works, the next step should be enabling HTTPS with a TLS certificate, for example through Let's Encrypt and Certbot, so API traffic is encrypted.







