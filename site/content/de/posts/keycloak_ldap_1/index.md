---
title: Advanced LDAP integration with Keycloak
date: 2023-01-05
description: Connect LDAP to Keycloak from scratch
---

<div style="background-color: #992d2d !important;
            color: black;
            font-weight: bold;
            padding: 20px;
            margin: 10px;
            text-align: center;
            font-family: monospace;">
  Advanced Difficulty
</div> 

LDAP is an open source database, mostly user for tree-like user management. It has rich integrations into many applications and libraries and is supported as a user federation backend for Keycloak. This is an advanced topic, you require a basic understanding of LDAP, Ansible, Python, Linux and Keycloak, as well as a working Keycloak setup. Please read **[SSO with Keycloak, oauth2proxy and Ansible](https://yannikschmidt.com/posts/keycloak_ansible/)** first if this does not apply to you.

## Setting up Variables

In our Ansible setup we will have to define the following variables. Please note that secrets should go into an Ansible Vault:

    # keycloak API-access
    keycloak_admin_password: the_keycloak_admin_pw
    keycloak_address: external_https_address
    
    # LDAP settings #
    ldap_password:
    ldap_dc:
    ldap_org:
    ldap_suffix:
    ldap_bind_dn:
    ldap_user_dn:
    ldap_group_dn:
    ldap_connection_url:
    
On a simplified level, LDAP works on the basis of *"domains-components"* (dc), *organizations* (o) *"organizational units"* (ou), and *"common names"* (cn). A full path of such elements is called a "domain" (dn), and the partial, latter part of the path a "suffix".

So if you are working on the domain `example.com`, the two domain components are `example` and `com`. In general, you always require at least two *organizational units*, `groups` and `people`. Within these *OUs*, the actual *groups* (with their respective members) and *users* are defined. All of these components are defined as a comma separated list of `key=value` pairs. A full path is then often called a *"domain"* (dn), though this is a misnomer in the sense of the LDAP RFCs.

    # LDAP settings example.com #
    ldap_suffix: dc=example,dc=com
    ldap_group_dn: ou=groups,dc=example,dc=com
    ldap_user_dn: ou=groups,dc=example,dc=com
    # a user-path would be:
    # cn=username,ou=people,dc=example,dc=com

`ldap_group_dn` and `ldap_user_dn` will later be used to tell Keycloak from where to import users and groups. We could also define multiple OUs for better separation or different Keycloak-realms.

Now you have to set ``ldap_connection_url``, be careful not to use *localhost*, because Keycloak is running in a container and your LDAP (hopefully) is not running in the same container as Keycloak. 

    ldap_connection_url: ldap://XXX.XXX.XXX.XXX

We need to define a user and password, which Keycloak will use to access the LDAP server. We will use `cn=Manager` on the default suffix, though in production setups you should a user with the minimally necessary permissions:

    ldap_password: something_secure
    ldap_bind_dn: "cn=Manager,dc=example,dc=com"

Finally we define our root component and organization. By convention, the root-component is usually the first non-TLD part of the FQDN:

    ldap_dc: example
    ldap_org: example com

Assuming your aren't doing this during your Ansible run, save a hashed version of the `ldap_password` for later use in the config:

    export ldap_password=your_password
    echo -n $ldap_password | openssl dgst -sha1 -binary | openssl enc -base64 | awk '{print "{SHA}"$0}'
    
    # save the resulting string in your ansible config
    ldap_password_hashed: ....

## Setting up LDAP

For our fresh LDAP deployment (with files in `/etc/ldap/`), we will require the following files/templates:

* ldap.conf
* slapd.conf
* slapd-custom.service

`ldap.conf` only needs to set the two variables. The `bind_dn` (aka the admin user) and the `connection_url`:

    # this goes into templates/ldap.conf
    BASE {{ ldap_bind_dn }}
    URI {{ ldap_connection_url }}
    
`slapd.conf` defines basic settings, target directories and notably schemata, which define required and optional attributes for users and groups:

    modulepath /usr/lib/ldap/
    moduleload back_bdb.la

    pidfile         /var/lib/ldap/slapd.pid
    argsfile        /var/lib/ldap/slapd.args

    include /etc/ldap/schema/core.schema
    include /etc/ldap/schema/cosine.schema
    include /etc/ldap/schema/inetorgperson.schema
    include /etc/ldap/schema/nis.schema

    database    bdb
    suffix      "{{ ldap_suffix }}"
    rootdn      "{{ ldap_bind_dn }}"
    rootpw      {{ ldap_password_hashed }}
    
    # this goes into templates/slapd.conf
    #TLSCACertificateFile  /etc/ssl/certs/ca-certificates.crt
    #TLSCertificateFile set_if_your_want_TLS
    #TLSCertificateKeyFile set_if_you_want_TLS
    TLSVerifyClient try


    logfile /var/log/slapd.log
    #loglevel -1 # <-- log everything
    loglevel none

    directory /var/lib/ldap/
    cachesize 2000
    
If you are running this with systemd, you can create a service for your configuration like this:

    # this goes into templates/slapd-custom.service
    [Unit]
    Description=Slapd Custom Service

    [Service]

    Type=forking
    ExecStart=/usr/sbin/slapd -f /etc/ldap/slapd.conf -h "ldap:///"

    User=openldap
    Group=openldap

    CapabilityBoundingSet=CAP_NET_BIND_SERVICE
    AmbientCapabilities=CAP_NET_BIND_SERVICE

    Restart=on-failure

    PrivateTmp=yes
    ProtectSystem=full
    ProtectHome=yes
    ProtectKernelModules=yes
    ProtectKernelTunables=yes
    ProtectControlGroups=yes
    NoNewPrivileges=yes
    MountFlags=private
    SystemCallArchitectures=native
    PrivateDevices=yes

    [Install]
    WantedBy=multi-user.target

## Deploying LDAP configuration with Ansible

With these preparations for the LDAP deployment done, we can start writing the Ansible tasks.

Before deploying our tasks in `tasks/main.yaml` we will deploy `handlers/main.yaml`, to use the `notify`-keyword to restart our LDAP-server in case something changes:

    # this goes in handlers/main.yaml
    - name: daemon reload
      systemd:
        daemon-reload: yes
    
    - name: restart slapd
      systemd:
        name: slapd-custom
        state: restarted

Deploy and configure the base LDAP service:

    - name: Install LDAP packages
      apt:
        pkg:
          - slapd
          - ldap-utils
          - python3-ldap # explained later

    - name: Create directory /var/lib/slapd/
      file:
        path: /var/lib/ldap/
        owner: root
        group: openldap
        mode: 0770
        state: directory

    - name: Deploy slapd-LDAP Conf
      template:
        src: slapd.conf
        dest: /etc/ldap/slapd.conf
        owner: openldap
      notify:
        - restart slapd

    - name: Disable & mask broken Debian slapd unit
      systemd:
        name: slapd
        state: stopped
        enabled: false
        masked: yes

    - name: Copy slapd systemd unit
      template:
        src: slapd-custom.service
        dest: /etc/systemd/system/slapd-custom.service
        mode: 0644
      notify:
        - daemon reload
        - restart slapd

    - name: Enable and start slapd custom service
      systemd:
        name: slapd-custom.service
        state: started
        enabled: yes

    - name: LDAP master conf
      template:
        src: ldap.conf
        dest: /etc/ldap/ldap.conf
        owner: openldap
      notify:
        - restart slapd

    - meta: flush_handlers

Flush handlers will cause all *handlers* to be run (if *"notify"* was triggered by a change) after that, we have to wait for LDAP to be available again.

    - name: Wait for LDAP to become ready
      wait_for:
        port: 389 # <-- ldap default port
        timeout: 30
        delay: 5

Now we can create our LDAP root organization and admin-user *("Manager")*. Note that we are using *localhost* here, since the `ldap_entry`-module runs on the remote machine directly, unlike Keycloak, which runs in it's own container:

    - name: Create LDAP root (1)
      ldap_entry:
        dn: "{{ ldap_suffix }}"
        objectClass:
          - dcObject
          - organization
        attributes: |
            { "o" : "{{ ldap_org }}", "dc" : "{{ ldap_dc }}" }
        state: present
        server_uri: "ldap://localhost"
        bind_dn: "{{ ldap_bind_dn }}"
        bind_pw: "{{ ldap_password }}"

    - name: Create LDAP root (2)
      ldap_entry:
        dn: "cn=Manager,dc=atlantishq,dc=de"
        objectClass:
          - organizationalRole
        attributes: |
            { "cn" : "Manager" }
        state: present
        server_uri: "ldap://localhost"
        bind_dn: "{{ ldap_bind_dn }}"
        bind_pw: "{{ ldap_password }}"

And finally create some default groups:

    - name: Create LDAP Group people
      ldap_entry:
        dn: "ou=People,{{ ldap_suffix }}"
        objectClass:
          - organizationalUnit
        state: present
        server_uri: "ldap://localhost"
        bind_dn: "{{ ldap_bind_dn }}"
        bind_pw: "{{ ldap_password }}"

    - name: Create LDAP groups root
      ldap_entry:
        dn: "ou=groups,{{ ldap_suffix }}"
        objectClass:
          - organizationalUnit
        state: present
        server_uri: "ldap://localhost"
        bind_dn: "{{ ldap_bind_dn }}"
        bind_pw: "{{ ldap_password }}"

    - name: Create LDAP groups
      ldap_entry:
        dn: "cn={{ item }},ou=groups,{{ ldap_suffix }}"
        objectClass:
          - groupOfNames
        attributes: { "member" : "" }
        state: present
        server_uri: "ldap://localhost"
        bind_dn: "{{ ldap_bind_dn }}"
        bind_pw: "{{ ldap_password }}"
      with_items:
        - group1
        - group2
        
We could use the same strategy to pre-create users in `ou=People,..`, but Keycloak can also do this for us later.

## Keycloak Issue#25883

Speaking of Keycloak, there is an ongoing [Issue](https://github.com/keycloak/keycloak/issues/25883) with LDAP-federation, causing imports to fail, if groups contain empty members (which happens if you create a group and remove all members via the Keycloak web-interface).

To fix this, there isn't really a good solution, other than deploying a script to handle the situation and execute it via a cronjob. If you already have a "new user"-hook, you could also add it there.

    # this goes into templates/fix_ldap.py
    #!/usr/bin/python3

    from ldap3 import Server, Connection, MODIFY_ADD, MODIFY_DELETE

    ldap_server = 'ldap://localhost'
    ldap_user = '{{ ldap_bind_dn }}'
    ldap_password = '{{ ldap_password }}'
    base_dn = '{{ ldap_user_dn }}'
    groups_base_dn = '{{ ldap_group_dn }}'
    new_objectclass = 'verification'

    # Connect to the LDAP server
    server = Server(ldap_server)
    conn = Connection(server, user=ldap_user, password=ldap_password)

    if not conn.bind():
        print(f"Failed to bind to LDAP server: {conn.last_error}")
        exit(1)

    # handle groups #
    conn.search(groups_base_dn, '(objectClass=*)')
    for entry in conn.entries:

        dn = entry.entry_dn

        # add verification class if it is missing #
        conn.modify(dn, {'member': [(MODIFY_DELETE, [""])]})

    # handle people #
    conn.search(base_dn, '(objectClass=person)')
    for entry in conn.entries:

        dn = entry.entry_dn

        # add verification class if it is missing #
        conn.modify(dn, {'objectClass': [(MODIFY_ADD, ["verification"])]})

        # set verification value if it is not set #
        modifications = {
            'emailVerified': [(MODIFY_ADD, ["false"])]
        }
        conn.modify(dn, modifications)

    # Unbind from the LDAP server
    conn.unbind()

Now deploy the fixer script and register a cronjob for it:

    - name: deploy LDAP fixer scripts
      template:
        src: fix_ldap.py
        dest: /opt/fix_ldap.py
        mode: 0700

    - name: Create cronjob LDAP fixer
      cron:
        hour: "*"
        minute: "*"
        name: LDAP keycloak fixer
        job: "/opt/fix_ldap.py"


# LDAP Federation Object

Now that we have a LDAP service running on our server, we need to create the actual federation in Keycloak. For this we need to use the [Ansible-keycloak_user_federation submodule](https://docs.ansible.com/ansible/latest/collections/community/general/keycloak_user_federation_module.html):

    - name: Create LDAP user federation
      community.general.keycloak_user_federation:
        auth_keycloak_url: https://{{ keycloak_address }}
        auth_realm: master
        auth_username: admin
        auth_password: "{{ keycloak_admin_password }}"
        realm: master
        name: ldap-ansible
        state: present
        provider_id: ldap
        provider_type: org.keycloak.storage.UserStorageProvider
        id: 11111111-0000-0000-0000-000000000001
        config:
          priority: 0
          enabled: true
          cachePolicy: DEFAULT
          batchSizeForSync: 1000
          editMode: WRITABLE
          importEnabled: true
          syncRegistrations: true
          fullSyncPeriod: 600
          vendor: other
          usernameLDAPAttribute: uid
          rdnLDAPAttribute: uid
          uuidLDAPAttribute: uid
          userObjectClasses: person, inetOrgPerson, organizationalPerson, verification
          connectionUrl: "{{ ldap_connection_url }}"
          usersDn: "{{ ldap_user_dn }}"
          authType: simple
          bindDn: "{{ ldap_bind_dn }}"
          bindCredential: "{{ ldap_password }}"
          searchScope: "1"
          validatePasswordPolicy: false
          trustEmail: false
          useTruststoreSpi: ldapsOnly
          connectionPooling: true
          pagination: true
          allowKerberosAuthentication: false
          debug: false
          useKerberosForPasswordAuthentication: false
        mappers:
          # will do this in next stop
          
Most of these values should be self explanatory, though if you have any problems understanding them, head to the Keycloak web-interface of your deployment. All of the given values have respective configuration fields with short explanations.
      
## LDAP Federation Mappers

The above entry is still not enough however. We need to tell the Keycloak instance how to map values from it's internal user model to the LDAP attributes. If you create a user federation, some of the mappers (like `username` and `email`) will already be created by default, however it is good practice to include them in a IaC-setup as well:

      # this goes indented into the "mapper" keyword
      - name: "username"
        providerId: "user-attribute-ldap-mapper"
        providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"
        config:
          always.read.value.from.ldap: false
          is.mandatory.in.ldap: true
          read.only: false
          user.model.attribute: username
          ldap.attribute: uid
      - name: "email"
        providerId: "user-attribute-ldap-mapper"
        providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"
        config:
          always.read.value.from.ldap: false
          is.mandatory.in.ldap: true
          read.only: false
          user.model.attribute: email
          ldap.attribute: mail
      - name: "first name"
        providerId: "user-attribute-ldap-mapper"
        providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"
        config:
          always.read.value.from.ldap: true
          is.mandatory.in.ldap: true
          read.only: false
          user.model.attribute: firstName
          ldap.attribute: cn
      - name: "last name"
        providerId: "user-attribute-ldap-mapper"
        providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"
        config:
          always.read.value.from.ldap: true
          is.mandatory.in.ldap: true
          read.only: false
          user.model.attribute: lastName
          ldap.attribute: sn
      - name: "modify date"
        providerId: "user-attribute-ldap-mapper"
        providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"
        config:
          always.read.value.from.ldap: true
          is.mandatory.in.ldap: false
          read.only: true
          user.model.attribute: modifyTimestamp
          ldap.attribute: modifyTimestamp
      - name: "creation date"
        providerId: "user-attribute-ldap-mapper"
        providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"
        config:
          always.read.value.from.ldap: true
          is.mandatory.in.ldap: false
          read.only: true
          user.model.attribute: createTimestamp
          ldap.attribute: createTimestamp

Then we require a group mapper to map the users LDAP groups via the `memberOf` attributes:

      - name: "group-mapper"
        providerId: "group-ldap-mapper"
        providerType: "org.keycloak.storage.ldap.mappers.LDAPStorageMapper"
        config:
          membership.attribute.type: "DN"
          group.name.ldap.attribute: "cn"
          preserve.group.inheritance: true
          membership.user.ldap.attribute: "uid"
          groups.dn: "ou=groups,{{ ldap_suffix }}"
          mode: "LDAP_ONLY"
          user.roles.retrieve.strategy: "LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"
          ignore.missing.groups: false
          membership.ldap.attribute: "member"
          group.object.classes: "groupOfNames"
          memberof.ldap.attribute: "memberOf"
          groups.path: "/"
          drop.non.existing.groups.during.sync : true

After running your playbook (including all of the federation mappers), you should now head to the web-interface at `{{ keycloak_address }}` and test your connection.

![Test LDAP Federation Connection](/keycloak_ldap_2023.png)

If you set your connection mode to`WRITE`, you will be able to use the admin interface to modify, create and delete users and groups, as well as add and remove group-memberships for users.

<br>
<sup style="font-style: italic;">by Yannik Schmidt</sup><br>

<sup>**Tags:** _IAM, LDAP, Keycloak, Ansible_</sup>
