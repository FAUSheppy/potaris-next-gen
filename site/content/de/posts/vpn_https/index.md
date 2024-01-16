---
title: Making VPN stealthy
date: 2018-07-02
description: VPN over HTTPS via nginx stream-multiplexing
---

Blocking VPNs is a common practice nowadays, be it on ISP/Government level or just the local coffee shop. Also, if you can hide the information that you are using a VPN, shouldn’t you just do it for the sake of it?

## Threat models
### Blind blocking of ports (or IPs)
The most common way of blocking VPN connections — or really any connections of well known services — is by blocking it’s default port(s). In extension, some public WLAN-hotspots may even block all ports except 80 (HTTP) and 443 (HTTPS). Not quite as common, but still sometimes observable in public hotspots is the blocking of specific IPs — which may include servers of big VPN providers. However since we will set up our own small VPN server, it is safe to assume that we aren’t in any such blacklist (yet). This brings me to the next point.

### Targeted blocking of your server due to information leakage
Now obviously we are starting to leave the realm of coffee-shop-next-door-blocking. But assuming someone cares enough, may it just be a bored admin, a second threat model is an active attacker that attempts to find out, if a given server provides a VPN, based on information the server or client leaks. Such leaked information would for example be the [Server Name Identification](https://en.wikipedia.org/wiki/Server_Name_Indication) (SNI), which could leak from an unencrypted DNS-request or the server’s certificate or the TLS handshake itself), plus the fact that a VPN-service answers on such a leaked sub-domains.

### Deep package inspection
Lastly, even if DPI is a far less common blocking mechanism (and also kinda illegal in my country), it is an inbuilt feature in some commercially available firewalls, and I know of at least one public hotspot in my area which seems to recognize and block VPN connections over ports 80 and 443 (presumably based on DPI). Way more important perhaps: if you are on vacation in for example Turkey, then assuming that the government analyzes your traffic, flag you for using a VPN, block it and/or blacklist your server, might not be so unreasonable. After all people in Turkey have [gone to jail](https://www.mdr.de/nachrichten/politik/inland/deutsche-in-haft-in-der-tuerkei-100.html) for equally ridiculous reasons.

## Other things to consider
### Impossibility of SNI Confidentiality
An important thing to note is that we *cannot protect the request SNI* as it is in the ***plain text part of the TLS handshake***. This has implication on how our server must differentiate between a normal HTTPS request and VPN connection attempt, so that even an active attacker can’t identify our server as a VPN provider. We will discuss this problem in a later section.

### Abnormalities in browsing behavior
Since we will route our traffic through the VPN, it will look like we are only visiting one site. If we were paranoid, we would also have to look into a tool to simulate other browsing behavior, but I think this will be a topic for another time.

### Legal and moral implications
Circumventing VPN blocks might be against the law or at the very least the terms of service of a public hotspot, while it is basically impossible that any of your VPN activity will come back to haunt the hotspot provider, since the rest of the internet will only see the IP of your server, fear of circumvention might impede the creation of more public WLAN spots.

### False sense of anonymity
It is always important to remember that a VPN is not Tor. Even if you aren’t hosting the VPN endpoint yourself, and even if you trust your VPN provider to not log your data (or at the very least not give it away), a VPN does not protect you identity reliably. You are still susceptible to browser fingerprinting and information leaks from your software. If you need real anonymity, you have to use the Tor Browser and read carefully through it’s recommendations about browsing practices. The tor browser also has very advanced obfuscation plugins itself.

## Formulating design goals for our stealth VPN
must use port 443 or 80 for VPN connection to circumvent port blocking
the VPN traffic must look like HTTPS traffic when analyzed
server, client and connection should not leak any information that would make it look like non-standard traffic

## Outlining the internal workings
We will use stunnel on our client to connect to the nginx on our server. Nginx will have to multiplex the connection and either provide normal web-content or stream the connection to our VPN server. As said earlier: We cannot protect the request SNI. Therefore if we want to be completely safe, we cannot multiplex based on the SNI (aka the requested subdomain), as an active attacker would easily be able to tell apart a VPN server from an HTTP server, if he attempts to connect to a give SNI. Nevertheless we will do that first in the configuration section below and then build upon it, since this is probably the point where we enter full-scale paranoia territory.

You will need `nginx > 1.15.0` on your server, `stunnel` on your client, and, obviously, `openvpn` on both. The following sections assume you have already set up a working nginx that listens for SSL connections on port 443 and have a working certificate for your domain and at least one subdomain *(I will use my own server 'atlantishq.de' and the subdomain 'vpn.atlantishq.de' as example here)*. Also I will not go in detail on how to set up a VPN server in general and only focus on the non standard part of the openvpn configuration.

So before we start your nginx-configuration should look something like this:

    http { 
      ssl_certificate /path/to/cert;
      ssl_certificate_key/path/to/key;
      server{
        server_name atlantishq.de;
        listen [::]:443 ipv6only=off;
      }
    }

## nginx configuration
Essentially we now want to introduce the subdomain vpn.atlantishq.de which we connect to on port 443. First we need a `stream` section outside of the `http` section (by the way: this means we have to write the ssl-certificate paths again, if they were defined in the `http` section) Until stated otherwise, everything that follows takes place in the `stream` section.

    stream { 
        ssl_certificate /path/to/cert;
        ssl_certificate_key /path/to/key;
    }

We need a mapping for subdomains, this can be achieved by using the `map` construct, which maps SNIs or the keyword `default` to certain upstreams:

    map $ssl_preread_server_name $name {
         default https;
         vpn.atlantishq.de vpn;
    }

Since we reference those upstreams, we also have to create them. They represent our outgoing multiplexed connections, which we will later forward to the respective backends. Since they are system-internal, we can and should use unix-sockets here. Nginx will automatically generate them for us.

*IMPORTANT EDIT 2020: If you are using the latest nginx version as of October 2020, the ssl directive must be behind the listen directive, in the server block, NOT behind the server directive, in the upstream block, thanks to my readers for pointing this out.*

    upstream https { 
        server unix:/path/to/location/nginx/can/write/to_https ssl;
    }
    upstream vpn {
        server unix:/path/to/location/nginx/can/write/to_vpn ssl;
    }

Now we need the two virtual servers (without ‘ssl’ directive, since we terminated TLS in the upstream-directive) and proxy the connection to the correct backend:

    server {
        listen unix:/path/to/location/nginx/can/write/to_https
        # openvpn doesn't support unix-sockets
        proxy_pass 127.0.0.1:VPNPORT
    }
    server{
        listen unix:/path/to/location/nginx/can/write/to_https
        # could also use a unix-socket here
        proxy_pass 127.0.0.1:INTERNAL-HTTPPORT
    }

Still within the `stream` block, we need a server that listens for incoming connections:

    server { 
        listen [::]:443 ipv6only=off;
        proxy_protocol on;
        proxy_pass $name;
    }

As you may notice this listen directive now conflicts with the listen directive in the `http` block, described in the 'Requirements' section. Indeed we now have to change the listen directive in the http block. For normal HTTPS connections the TLS-Layer is (like for the VPN traffic) already removed in the proxying servers, listening on the unix-sockets. Therefore we change the listen directive to:

    http {
        ...
        server{
            ...
            listen 127.0.0.1:INTERNAL-HTTPPORT
            ...
        }
    }

You have to do this for all servers previously listening on port 443. As a sidenote, if you want to enable logging in a stream block, you should define a custom log-format:

    log_format sni_multiplexer '$remote_addr [$time_local] ' 
                             'with SNI name "$ssl_preread_server_name"'
                             'proxying to "$name" '
                             '$protocol $status'
                             '$bytes_sent $bytes_received'
                             '$session_time';
    access_log /var/log/nginx/tls.log sni_multiplexer;

For me on Debian 9 (but this bug exists on multiple distributions), subsequent starts would fail, because nginx didn’t clear the unix-socket files on exit. You can fix this behaviour by editing the systemd-unit file with `systemctl edit nginx` and change `--retry QUIT/5` in `ExecStop` to `--retry TERM/5` by writing the flowing:

    [Service]
    # unset exec stop
    ExecStop=
    # set to new value
    ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry TERM/5 \
                                      --pidfile /run/nginx.pid

## stunnel configuration
Stunnel configuration (on the client) is relatively easy and self explaining:

    [randomname]
    client = yes
    accept = 127.0.0.1:LOCAL_PORT
    connect = vpn.atlantishq.de:443
    sni = vpn.atlantishq.de
    verifyChain = yes
    CAPath = /etc/ssl/certs/
    checkHost = vpn.atlantishq.de

So we connect to **vpn.atlantishq.de:443** (with the same SNI), verify the certificate-chain, check the host certificate and expose this connection on the localhost interface on port `LOCAL_PORT`. The CAPath must point to the directory your trusted certificates are stored in, for Debian that is the above path.

# openvpn configuration
The only thing to note about OpenVPN is that you have to use TCP. Other than that you can use your normal VPN configuration, no matter if shared secret or CA with certs. There are numerous tutorials about setting up a basic VPN server, for example [this one](https://openvpn.net/index.php/open-source/documentation/miscellaneous/78-static-key-mini-howto.html). The relevant lines for our configuration are:

**serverside**

    # only listen on localhost
    local 127.0.0.1
    # and set the port
    port VPN_PORT_YOU_USED_IN_NGINX
    # use tls
    tls-server
    # the above necessitates
    mode server

**clientside**

    # use tcp
    proto tcp
    remote 127.0.0.1 STUNNEL_LOCAL_PORT

Now, as I said above, an active attacker could notice that we are always connecting to a specific subdomain, from which, with a normal web browser, he would get a seemingly empty response. As the attacker can see that the packages, which I am receiving (encrypted of course), aren’t empty, he will likely figure out the nature of the service listening on my subdomain eventually.

A possible solution to this is to not multiplex the connection by SNI, but by TLS client certificate. For that you will have to create a PKI (public key infrastructure). You can find explanations and a comprehensive [tutorial](https://wiki.archlinux.org/index.php/Easy-RSA) over at ArchWiki. It is of course possible to stack both approaches, but I will now reuse the previous map-/socket names and ports which will break your nginx config unless you change them or use just one of the approaches. Also consider creating something like a `stream-submodules-available` and `stream-submodules-enabled` directory structure while using `include stream-submodules-enabled/*` in your main configuration to keep track of everything. We won't have to change anything for OpenVPN, it will still connect to stunnel and nginx locally respectively and won't even notice something changed.

## nginx configuration
Upstream stays the same, if you use the log format from above for debugging, you should probably change the SNI-line to something like:

    'with cert status "$ssl_client_verify"'
    'proxying to "$correct_NEW_map_name" ' # <-- carefull

In the map-structure, we now have to map `$ssl_client_verify` instead of `$ssl_preread`. The former has the format `"SUCCESS"` and `FAILED:REASON`. Since we don't really care why the certificate verification failed (if it failed), we can just match on `SUCCESS` in our map, and otherwise default to *http*.

    map $ssl_client_verify $mapname{
        "SUCCESS" vpn;
        default http;
    }

We need to change the stream-section virtual server to now resolve/remove the TLS layer so we can access the client certificate, which unlike SNI is protected by TLS. This means we don’t need `ssl_preread` anymore and we need to add `ssl_verify_client optional` to allow for client authentication and population of the variable by the same name.

    server {
        listen [::]:443 ipv6only=off ssl;
        ssl_verify_client optional;
        proxy_protocol on;
        proxy_pass $mapname;
    }

Just remove the *“vpn.”*-prefix/subdomain and add the client certificate (accepts various encodings including p12 and PEM):

    [randomname]
    client = yes
    accept = 127.0.0.1:LOCAL_PORT
    connect = atlantishq.de:443
    sni = atlantishq.de
    verifyChain = yes
    CAPath = /etc/ssl/certs/ checkHost = atlantishq.de cert = /etc/stunnel/clientcert{.p12|.pem|...}
    Workaround for HTTP2

Using the certificate multiplexing solution, you cannot enable the HTTP2 protocol in nginx, because nginx only allows for the `http2` directive to be a) in a subblock of the `http` and b) the `http2` directive must be in the same v-server as the `ssl` directive. This is not an inherent problem but a bug/missing feature in *nginx* *(EDIT 2022: Fixed in nginx > 21.0.0)*. If you want to use *HTTP2* you have to multiplex the connection based on protocol (or SNI) first, and then multiplex the connections that weren't *HTTP2* (which would include the VPN connection) second. Here is a small code excerpt to give you an Idea on how to do that:

    stream {
        ...
        map $ssl_preread_alpn_protocols $protocol_stream {
            default 127.0.0.1:CERT_MAP_SERVER_PORT;
            ~\bh2\b 127.0.0.1:HTTP_VSERVER_PORT;
        }
        map $ssl_verify_client $protocol_stream {
            "SUCCESS" 127.0.0.1:VPN_PORT;
            default 127.0.0.1:HTTP_VSERVER_PORT_NOSSL;
        }
        # multiplex protocol
        server {
            listen 443;
            ssl_preread on;
            ...
            proxy_protocol on;
            proxy_pass $protocol_stream;
         }
         # listen internall and multiplex certificate
         server {
             # remove TLS listen 127.0.0.1:CERT_MAP_SERVER_PORT ssl;
             ...
             ssl_verify_client optional;
             proxy_protocol on; proxy_pass $name;
         } 
    }
    http {
        ...
        server {
            listen 127.0.0.1:HTTP_VSERVER_PORT proxy_protocol ssl http2;
            listen 127.0.0.1:HTTP_VSERVER_PORT_NOSSL;
            ...
        }
    }


<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Mail, Postfix, automx, IMAP, SMTP_</sup>
