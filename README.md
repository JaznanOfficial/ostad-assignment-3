# Assignment 3 — AWS EC2 Deployment (Completed)

I deployed the `next-japan` project to an AWS EC2 instance and configured PM2 and Nginx as a reverse proxy with a self-signed SSL certificate. Below are the exact commands I ran and the Nginx configuration I used.

---

## Instance & key

- Instance Public DNS: `ec2-3-113-11-74.ap-northeast-1.compute.amazonaws.com`
- Private key file used: `ostad.pem`

## Commands I executed (from my point of view)

```bash
# on my local machine: lock down private key
chmod 400 "ostad.pem"

# SSH to the instance (replace user if needed)
ssh -i ostad.pem ubuntu@ec2-3-113-11-74.ap-northeast-1.compute.amazonaws.com

# update packages
sudo apt update

# install git, npm and required tools
sudo apt install -y git npm curl gnupg2 ca-certificates lsb-release ubuntu-keyring

# clone repository and build
git clone https://github.com/mdarifahammedreza/next-japan.git
cd next-japan
npm install
npm run build

# test run
npm start

# install pm2 and run app as service
sudo npm install -g pm2
pm2 start npm --name "assignment-3" -- start
pm2 save
pm2 startup

# install nginx
sudo apt update
sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# create nginx-cert dir and generate self-signed cert (I used .crt to match Nginx config)
mkdir -p /home/ubuntu/nginx-cert
cd /home/ubuntu/nginx-cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx.key -out nginx.crt
```

I generated `/home/ubuntu/nginx-cert/nginx.crt` and `/home/ubuntu/nginx-cert/nginx.key` and placed them on the instance.

---

## Nginx configuration I applied

I added the following configuration (the exact block I used):

```nginx
#how many worker should run
worker_processes 1;

events {
    worker_connections 1024;
}


http {
    include /etc/nginx/mime.types;


    #upstream block to define the application
    upstream nodejs_cluster {
        server 127.0.0.1:3000;
    }

    server {
        listen 443 ssl;
        server_name localhost;

        # SSL certificate paths
        ssl_certificate /home/ubuntu/nginx-cert/nginx.crt;
        ssl_certificate_key /home/ubuntu/nginx-cert/nginx.key;
   

        #server location

        location / {
            proxy_pass http://nodejs_cluster;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }

    server {
        listen 80;
        server_name localhost;
        
        #redirect
        location /{
            return 301 https://$host$request_uri;
        }
    }
}
```

I placed this file at `/etc/nginx/sites-available/assignment-3` (or appended appropriately to `/etc/nginx/nginx.conf`) and reloaded Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## Ports & Security Group

- I ensured the EC2 security group allows inbound TCP on ports `22` (SSH), `80` (HTTP) and `443` (HTTPS). The Node app listens on `3000` locally and is proxied by Nginx.

## Verification steps I ran

- `pm2 status` and `pm2 logs assignment-3` to confirm the app was running
- `sudo systemctl status nginx` and `curl -I https://localhost --insecure` to confirm Nginx + SSL

## Result

I completed the assignment: the `next-japan` app is running under PM2 and served through Nginx with the SSL configuration above.

If you want, I can now:

- Add the `/etc/nginx/sites-available/assignment-3` file in the repo and a small script to enable it, or
- Replace the self-signed certificate with Let's Encrypt (`certbot`) steps.

---

## Access & Behavior Notes

- The site is available at: `https://3.113.11.74/` (no `:3000` shown in the browser). Nginx listens on `443` and proxies requests internally to the Node process on `localhost:3000`, so users never see port `3000`.
- Any request to `http://3.113.11.74/` is redirected to `https://3.113.11.74/` by the Nginx configuration (HTTP -> HTTPS redirect).
- The EC2 security group exposes `80` and `443` to the public; `3000` is only bound to `127.0.0.1` and not publicly accessible.
