---
title: SSO with Keycloak, oauth2proxy and Ansible
date: 2023-12-22
description: Keycloak with Ansible and oauth2proxy
---

# SSO with Keycloak and Ansible

<div style="background-color: #992d2d !important;
            color: black;
            font-weight: bold;
            padding: 20px;
            margin: 10px;
            text-align: center;
            font-family: monospace;">
  Advanced Difficulty
</div> 

Ansible is a Infrastructure-as-Code definition language, Keycloak is a OpenID-Connect provider, authentication broker and can handle user federation.

In this article, I will describe how to create a scalable Keycloak Single Sign-On (SSO) setup, entirely modeled in Ansible. To follow along, you will need a basic understanding of Docker(-compose), Ansible, proxying, Linux and OpenID-Connect itself.

## Ansible Basics

I assume you already have some basic understanding of Ansible, but in general you need the following directories:

    # file templates Keycloak
    mkdir ./roles/keycloak/templates
    
    # Ansible tasks keycloak
    mkdir ./roles/keycloak/tasks
    
    # file templates deployments
    mkdir ./roles/deployments/templates
    
    # Ansible tasks deployments
    mkdir ./roles/deployments/tasks
    
    # variables
    mkdir ./group_vars/
    
If you want an Ansible vault for your secrets instead of using `group_vars/all.yaml`, refer to the [Ansible vault documentation](https://docs.ansible.com/ansible/latest/vault_guide/index.html).
    

## Deploying Keycloak

OIDC requires *https*, meaning you require a TLS setup in front of your Keycloak. The easiest way to do this is with [nginx and Let's Encrypt](https://yannikschmidt.com/posts/ssl_nginx/). The outward facing *https*-address of Keycloak will be referenced as `{{ keycloak_address }}` from now on.

Let's start with the Keycloak compose file. If you are going with Ansible this should go into `roles/keycloak/templates` and be called `keycloak.yaml`.

    ---
    version: '3.3'
    services:
      keycloak:
        container_name: keycloak-container
        command: start --hostname-strict=false --log-level=WARNING
        image: quay.io/keycloak/keycloak:23.0.3 # <- version as of dez 2023
        environment:
          - KEYCLOAK_ADMIN=admin
          - KEYCLOAK_ADMIN_PASSWORD={{ keycloak_admin_password }}
          - PROXY_ADDRESS_FORWARDING=true
          - KC_PROXY=edge
          - KC_LOG_LEVEL=ALL
          - KC_DB_URL_HOST=postgres
          - KC_DB_USERNAME=keycloak
          - KC_DB_PASSWORD={{ keycloak_postgres_password }}
          - KC_HEALTH_ENABLED=true
          - KC_METRICS_ENABLED=true
          - KEYCLOAK_LOGLEVEL=WARN
        restart: unless-stopped
        ports:
        - 5050:8080
        depends_on:
        - postgres
      postgres:
        container_name: postgres-container
        image: postgres:15.1
        environment:
          - POSTGRES_DB=keycloak
          - POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password
          - POSTGRES_USER=keycloak
        restart: unless-stopped
        secrets:
        - postgres_password
        volumes:
        - /data/keycloak-postgres/:/var/lib/postgresql/data

    secrets:
      postgres_password:
        file: postgres_password

    ...

There is a lot going on here, first we have to define the variables/secrets referenced in the compose file, those being `keycloak_admin_password` and `keycloak_postgres_password`, which we will also need for the secrets-file. Secondly we have the volume, which mounts a filesystem-path of the host into the postgres container. Now this isn't strictly necessary if all of your configurations are modeled in Ansible, but it also means, you don't have to run your playbook, every time your recreate the container.

For demonstration purposes we will define these secrets in `group_vars/all.yaml`, but generally secrets should be defined in a vault and only for individual hosts:

    # group_vars/all.yaml
    keycloak_admin_password=adminpassword
    keycloak_postgres_password=pgpassword

Finally we need to define Ansible tasks to:

* install the necessary packages on the system
* create the volume-data directory in `/data/`
* create the target directory for the docker-compose deployment
* template and copy the compose file to remote
* deploy the compose file
* wait for keycloak to boot before starting configuration

As an Ansible-tasks file it should look like this:

    # roles/keycloak/tasks/main.yaml
    - name: Install docker-compose
      package:
          name:
              - docker-compose # should include the systems container-manager
          state: present
              
    - name: Create data-dir
      file:
        name: /data/
        state: directory

    - name: Create keycloak psql volume-mount
      file:
        name: /data/keycloak-postgres/
        state: directory

    - name: Create compose directory keycloak
      file:
        name: "/opt/keycloak/"
        state: directory

    - name: Copy compose templates keycloak
      template:
        src: "keycloak.yaml"
        dest: "/opt/keycloak/"

    - name: Copy compose environment files keycloak
      copy:
        content: "{{ keycloak_postgres_password }}"
        dest: "/opt/keycloak/postgres_password"
      with_items:
        - postgres_password

    - name: Deploy compose templates
      community.docker.docker_compose:
        project_src: "/opt/keycloak/"
        pull: true
        files:
          - "keycloak.yaml"
    
    - name: Check/Wait for Keycloak to be up
      uri:
        url: https://keycloak.atlantishq.de/health
        method: GET
        return_content: yes
        status_code: 200
        body_format: json
      register: result
      until: result.status == 200 and result.json.status == "UP"
      retries: 10
      delay: 20
      check_mode: false

## Create a OIDC-Client

Now lets secure an application, which does not support OIDC by itself with [oauth2proxy](https://github.com/oauth2-proxy/oauth2-proxy). [Traeffic](https://doc.traefik.io/traefik-enterprise/middlewares/oidc/) also supports this functionality if you are already using it.

To create a working setup we need to:


* create an OIDC-client in Keycloak
* configure & deploy an oauth2proxy container in front of our application 

We will be using the Ansible module **[keycloak-client](https://docs.ansible.com/ansible/latest/collections/community/general/keycloak_client_module.html)** as a **[local_action](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_delegation.html)**.

Let's define the necessary variables for our client first and build the Ansible tasks in a way, so multiple clients can be deployed easily later.

Please note, that the the secrets need to be exactly the given lengths, you should create those with the command given (provided by the package of the same name), something you *can* do in Ansible itself, but I would configure them statically as variables.

    # this goes into group_vars/all.yaml
    keycloak_clients:
        client_name:
            party_secret: "$(pwgen -s 16 -n 1)"
            client_id: name_of_your_client
            client_secret: "$(pwgen -s 32 -n 1)"
            redirect_uris:
                - "https://target_subdomain.example.com/*"
            description: "A description only displayed in Keycloak"
            keycloak_id: "00000000-0000-0000-0000-000000000001"
            groups:
            # groups: "group1,group2"
            master_address: "https://target_subdomain.example.com"
            skips:
                - "/logo/light.svg"


* *groups* optionally defines a list of groups a user must be part of, to be allowed to continue
* *redirect_uris* defines a list of allowed redirection URLs, meaning the URLs you will be redirected to, after logging in. This is important, because pages can request arbitrary redirect URLs when redirecting to the login.
* *master_address* defines a default for redirection, if none is given as part of the login request
* *skips* optionally defines a list of paths, which will be forwarded without authentication, you may use those for health-endpoints, icons or other unprivileged pages

Now we use the Ansible-list `keycloak_clients` in a task to create and update those clients on our deployment like this:

    # this goes into roles/keycloak/task/main.yaml, after the waiting task
    - name: Create Keycloak Clients
      local_action:
        module: keycloak_client
        auth_client_id: admin-cli
        auth_keycloak_url: https://keycloak.atlantishq.de/
        auth_realm: master
        auth_username: admin
        auth_password: "{{ keycloak_admin_password }}"
        state: present
        realm: master
        client_id: '{{ keycloak_clients[item]["client_id"] }}'
        id: '{{ keycloak_clients[item]["keycloak_id"] }}'
        name: '{{ keycloak_clients[item]["client_id"] }}'
        description: '{{ keycloak_clients[item]["description"] }}'
        enabled: True
        client_authenticator_type: client-secret
        public_client: false
        secret: '{{ keycloak_clients[item]["client_secret"] }}'
        authorization_services_enabled: true
        service_accounts_enabled: true
        redirect_uris: '{{ keycloak_clients[item]["redirect_uris"] }}'
        web_origins: '{{ keycloak_clients[item]["redirect_uris"] }}'
        frontchannel_logout: False
        protocol: openid-connect
        
        # >> explanation below << #
        protocol_mappers:
          - config:
                accesss.token.claim: true
                claim.name: "groups"
                id.token.claim: true
                userinfo.token.claim: true
                full.path: false
            id: "{{ keycloak_clients[item]['keycloak_id'] | regex_replace('^(?P<X>.{2})(.)', '\\g<X>' ~ '1') }}"
            consentRequired: false
            protocol: "openid-connect"
            protocolMapper: "oidc-group-membership-mapper"
            name: "client-group-mapper"
          - config:
                included.client.audience: '{{ keycloak_clients[item]["client_id"] }}'
                id.token.claim: false
                access.token.claim: true
            id: "{{ keycloak_clients[item]['keycloak_id'] | regex_replace('^(?P<X>.{2})(.)', '\\g<X>' ~ '2') }}"
            consentRequired: false
            protocol: "openid-connect"
            protocolMapper: "oidc-audience-mapper"
            name: "aud-mapper-client"
      with_items: "{{ keycloak_clients.keys() | list }}"

The task iterates over the keycloak_clients list we defined in the previous step in `group_vars/all.yaml`. The first part should be pretty self-explanatory. But what about the second part?

Those are so called [OIDC-scope claims](https://auth0.com/docs/get-started/apis/scopes/openid-connect-scopes), in short, they define information on the OIDC-server, which should be passed on to the client. In our case we are passing two special information:

* the groups the user is part of
* the intended "audience" aka the name of the client we are authenticating with (something required internally by oauth2proxy)

The `regex_replace` might seem strange, but it only replaces a single number in the ID with a *1* and *2* respectively, to create unique associated IDs for every client. Meaning:

    # keycloak client base ID
    00000000-0000-0000-0000-000000000001
    # becomes
    00100000-0000-0000-0000-000000000001
    # and
    00200000-0000-0000-0000-000000000001

..you can later use similar strategies for managing IDs of more complicated mappers or claims.

## Create a oauth2proxy-Deployment

With these preparations done, we can now finally deploy an oauth2proxy-container with an application behind it. To do this, first create a compose template again (note the `UPSTREAM` address and port, which has to be the port and address, the target application is running on):

    version: "3.7"
    services:
      oauth2-proxy-{{ item }}:
        image: bitnami/oauth2-proxy:7.3.0
        depends_on:
          - redis
        restart: always
        command:
    {% if keycloak_clients[item].get("skips") %}
    {% for route in keycloak_clients[item].skips %}
          - --skip-auth-route
          - {{ route }}
    {% endfor %}
    {% endif %}
          - --http-address
          - 0.0.0.0:{{ services[item].port }}
        ports:
          - {{ services[item].port }}:{{ services[item].port }}
        environment:
          OAUTH2_PROXY_SCOPE: openid email profile
          OAUTH2_PROXY_UPSTREAMS: http://{{ ansible_default_ipv4.address }}:5000
          OAUTH2_PROXY_EMAIL_DOMAINS: '*'
          OAUTH2_PROXY_PROVIDER: keycloak-oidc
          OAUTH2_PROXY_PROVIDER_DISPLAY_NAME: "Display Name"
          OAUTH2_PROXY_REDIRECT_URL: "{{ keycloak_clients[item].master_address }}/oauth2/callback"
          OAUTH2_PROXY_OIDC_ISSUER_URL: "https://{{ keycloak_address }}/realms/master"
          OAUTH2_PROXY_CLIENT_ID: "{{ keycloak_clients[item].client_id }}"
          OAUTH2_PROXY_CLIENT_SECRET: "{{ keycloak_clients[item].client_secret }}"

          {% if keycloak_clients[item].groups %}
    OAUTH2_PROXY_ALLOWED_GROUPS: {{ keycloak_clients[item].groups }}
          {% endif %}

          OAUTH2_PROXY_OIDC_EMAIL_CLAIM: sub
          OAUTH2_PROXY_SET_XAUTHREQUEST: "true"

          OAUTH2_PROXY_SESSION_STORE_TYPE: redis
          OAUTH2_PROXY_REDIS_CONNECTION_URL: redis://redis

          OAUTH2_PROXY_COOKIE_REFRESH: 15m
          OAUTH2_PROXY_COOKIE_NAME: SESSION
          OAUTH2_PROXY_COOKIE_SECRET: "{{ keycloak_clients[item].party_secret }}"

          OAUTH2_PROXY_REVERSE_PROXY: "true"
          OAUTH2_PROXY_SKIP_PROVIDER_BUTTON: "true"

          OAUTH2_PROXY_WHITELIST_DOMAIN: "{{ keycloak_address }}"

      # as part of the compose file we also need a session storage
      redis:
        image: redis:7.2.4-alpine
        restart: always
        volumes:
          - cache:/data

    # no mounts, since session storage is transitory
    volumes:
      cache:
        driver: local

..and the deploy it with Ansible tasks:

    # this goes into roles/deployments/tasks/main.yaml
    - name: Create opt-dir
      file:
        name: /opt/
        state: directory

    - name: OAuth2Proxy directories
      file:
        path: "/opt/oauth2proxy/{{ item }}/"
        state: directory
        recurse: yes
      with_items:
        - client_name

    - name: Deploy OAuth2Proxy compose files
      template:
        src: oauth-standalone-docker-compose.yaml
        dest: "/opt/oauth2proxy/{{ item }}/docker-compose.yaml"
      with_items:
        - client_name

    - name: Deploy OAuth2Proxy
      community.docker.docker_compose:
        project_src: /opt/oauth2proxy/{{ item }}/
        pull: true
      with_items:
        - client_name

Now if you want to test it, you can try it with your application or by running a simple web-server on the correct port like this:

    docker run -p 5000:80 nginx

## Top-Level Ansible Playbook 

If you want to deploy the whole thing on your server, we need to define some more Ansible overhead. All of the following files go into the root directory of your Ansible project (meaning the same directory the `group_vars` and `roles`-directories reside in).

### Host.ini
A file describing a list of*hosts*, for example:

    # host.ini
    [keycloak]
    192.168.122.1
    [deployments]
    192.168.122.1

### playbook.yaml
A playbook file describing, which *roles* to run on which *host*:

    - hosts: keycloak
      roles:
          - keycloak

    - hosts: deployments
      roles:
          - deployments

With these files ready we can finally run the whole thing with:

    ansible-playbook -i hosts.ini playbook.yaml --diff

## Further Reading
* [Really good OpenID-Connect E-Book by Bruno Krebs](https://auth0.com/resources/ebooks/the-openid-connect-handbook)
* [Keycloak Documentation](https://www.keycloak.org/documentation)
* [oauth2proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/overview/)

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Ansible, IAM/SSO, Keycloak, oauth2proxy_</sup>
