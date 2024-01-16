---
title: SSL with NGINX & certbot
date: 2019-02-18
description: SSL with NGINX & certbot
---

Nginx is a reverse proxy and web-server which can handle SSL connections for your applications and web content. It is actually very easy to get SSL up an running for free with [Let’s Encrypt](https://letsencrypt.org/) as your certification authority. Even if you can’t or don’t want to use Nginx as your main web-server, your can simply terminate all SSL connections there and then [connect locally via HTTP](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) to your hosted applications.

## Certbot
Certbot does most of the work for you, it’s basically a client for certificate authority servers. In our example we will use ACME, which means Certbot will place a magic file in our web-space which the CA-server can then query and therefore confirm that a certain DNS belongs to this server.

Installing should, usually, work via the package manager:

    apt install certbot

If everything else fails, you can install Certbot via the python package manager:

    python3 -m pip install cerbot

## Preparing Nginx
Make sure Nginx is available via HTTP. Be careful if you have an HTTPS redirect, while most CAs will connect fine over HTTP (since they must assume you don’t have a certificate yet), some will **not** connect over a broken HTTPS connection, i.e. with an expired or self-signed certificate. If it is not yet installed, install Nginx with:

    apt install nginx

You need the location `/.well-known/acme-challenge/`, this location must be writable for Nginx.

    # inside ALL servers in sites-enabled/ or nginx.conf # 
    # sites-enabled/ sometimes called vhosts.d/ or vservers.d/ #
        location /.well-known/acme-challenge/ {
        alias /var/www/.well-known/acme-challenge/;
    }

    # set up directories/permissions #
    mkdir -p /var/www/.well-known/acme-challenge/
    chown -R :www-data /var/www/.well-known/
    chmod -R g+x /var/www/.well-known/
    chmod g+rw /var/www/.well-known/acme-challenge/
    
    # reload nginx #
    systemctl reload nginx

## Run Certbot
Run certbot and follow the instructions:

    certbot certonly --webroot -w /var/www -d domain.toplevel -d domain2.toplevel --rsa-key-size 2048

..and you are done! Certbot will suggest you a command line which you can add to your crontab for regular certificate renewal. Let’s Encrypt certificates are valid for 3 months, executing the renewal jobs every months will be safe. Don’t forget to also add a `systemctl reload nginx` to the crontab or the certificates won't be reloaded.

## Add SSL-configuration in Nginx
The following lines must be added to the http-block or into all server-blocks you want to use SSL. The location will be different if you don’t use Let’s Encrypt (which is the default though):

    ssl_certificate /etc/letsencrypt/live/domain.toplevel/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/domain.toplevel/privkey.pem;

Also, you must add an SSL-listen directive to the relevant server blocks:

    listen 443 ssl; # ipv4
    listen [::]:443 ssl; # ipv6

## Common pitfalls
### HTTPS redirect
If you employ a _HTTP->HTTPS_ redirect on your page, make sure to place the acme-location block **before** the redirect or your renewal might fail, if your certificate ever becomes invalid for whatever reason.

    server{
        listen 80 default;
        location /.well-known/acme-challenge/ {
            alias /var/www/.well-known/acme-challenge/;
        }
        location /{
            return 302 https://$host$request_uri;
        }
    }

### Basic-Auth/Deny-Directives
If you have *basic auth* or a deny-directive on one of your (sub-)domains you must disable those in the acme-location block:

    auth_basic off;
    allow all;

### Adding new Subdomains
If you ever want to add more subdomains, add an `--expand` to the Certbot command, otherwise Certbot will create/symlink the new certificate with another name (something like `domain.toplevel.002`). Changing the initial domain will also cause Certbot to symlink certificates under a different name.

    certbot certonly --webroot \
                     -w /var/www \
                     -d domain.toplevel \
                     -d domain2.toplevel \
                     --rsa-key-size 2048 \
                     --expand # <-- note this

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Linux, nginx, TLS, cerbot, Let's Encrypt_</sup>
