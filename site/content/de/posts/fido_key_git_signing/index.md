---
title: Git-Commit Signatures with fido2-keys
date: 2025-30-10
description: SSH-key based git-signing, ecdsa-sk & fido2
---

<div style="background-color: #30df56 !important;
            color: black;
            font-weight: bold;
            padding: 20px;
            margin: 10px;
            text-align: center;
            font-family: monospace;">
  Easy Difficulty
</div>

Git somewhat recently - by git standards - introduced signing commits with SSH keys. This seems like a rather miscellaneous feature at first sight. However it carries with it the possibility to sign commits with normal fido2-hardware keys via ecdsa keys. Meaning, you can use generic hardware keys, which do not support PGP for signing purposes.

## Key creation
The key creation is straight forward, you want the key to reside on the hardware key, and if your key supports it (which it should) you also want to require user verification, i.e. by fingerprint or pin, the final argument adds a comment to identify the key later.

    cd ~/.ssh/
    ssh-keygen -t ecdsa-sk -O resident -O verify-required -C "a comment"

This creates a key on your key, a normal public key file and a stub private key on your machine, which you will reference when signing. The private key stub is required to use the key and cannot be recovered if lost from the hardware key. This part of the key by itself cannot be used to sign anything, but you should still keep it private, as it could potentially be used for fraudulent signing requests to your hardware key.

    # ls -l ~/.ssh/
    id_ecdsa_sk_git.pub # the public key
    id_ecdsa_sk_git     # the private key stub

## Git config

To enable ssh-key signing you need to set the GPG format and user signing key.

    git config --global gpg.format ssh
    git config --global user.signingkey ~/.ssh/id_ecdsa_sk_git.pub

Maybe you also want to enable signing by default:

    git config --global commit.gpgsign true

Your whole `.gitconfig` should then look something like the following sections:

    [user]
        email = "..."
        name = "..."
        signingkey = ~/.ssh/id_ecdsa_sk_git.pub
    [gpg]
        format = ssh
    [commit]
	    gpgsign = true

If you don't want to enable signing by default, you can use  the `-S` parameter when committing. The commit will fail if your device is not connected and will hang until you touch/verify it if it is.

## Verifying

If you're using any of the major git server types (GitHub, GitLab, GitTea, etc..), then you can add your public key in your profile to have your commits display as verified. If you want to verify ssh-key commits locally, you need to create a file containing the trusted email to public-key pairs (mail-address with its trusted key, one per line) and reference it with the `gpg.ssh.allowedSignersFile` option, for example like this:


    echo -n "yourmail@domain.tld" >> ~/.git_trusted_keys
    cat ~/.ssh/id_ecdsa_sk_git.pub >> ~/.git_trusted_keys
    git config --global gpg.ssh.allowedSignersFile ~/.git_trusted_keys 
    git verify-commit HEAD  # or commit id

If you use multiple emails, add the keys multiple times with the respective mails you want to trust it for. Careful with the global config here though, trusting your own key in every repository might be fine, but maybe you don't want to trust any key you add in every repository.

## Working with signed commits
Signing commits is worthless if nobody checks the signature and frankly very few people do. If you want to use it, to improve security in your organization, it needs to be checked. Your options here are.. not great.

### Client Side Verification
The state of client side verification is quite terrible. There is no dedicated function in git for it, nor is there even a _good_ hook for it. I wrote this script, which you can run before `git pull` (function or alias it):

    #!/usr/bin/python3
    
    import subprocess
    import sys
    import argparse
    
    def run(cmd):
        return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    def get_commits(remote=None, branch=None):
    
        if remote and branch:
    
            run(["git", "fetch", remote, branch])
    
            REV_PARSE_HEAD = ["git", "rev-parse", "HEAD"]
            local = run(REV_PARSE_HEAD).stdout.strip()
    
            REV_PARSE_REMOTE = ["git", "rev-parse", f"{remote}/{branch}"]
            remote = run(REV_PARSE_REMOTE).stdout.strip()
    
            if local == remote_head:
                return []
    
            REV_LIST = ["git", "rev-list", f"{local}..{remote_head}"]
            commits = run(REV_LIST).stdout.splitlines()
    
            return commits
    
        return commits
    
    def verify_commit(commit):
    
        result = run(["git", "verify-commit", commit])
        if result.returncode != 0:
            return False
    
        for key in TRUSTED_KEYS:
            if key in result.stdout:
                return True
    
        return False
    
    def main():
    
        parser = argparse.ArgumentParser()
        parser.add_argument("REMOTE", type=str)
        parser.add_argument("BRANCH", type=str)
    
        args = parser.parse_args()
        commits = get_commits(args.remote, args.branch)
    
        if not commits:
            sys.exit(0)
    
        untrusted = []
        for c in commits:
            if not verify_commit(c):
                untrusted.append(c)
    
        if untrusted:
            print("Untrusted commits found:")
            for c in untrusted:
                print(c)
            sys.exit(1)
    
        print("All commits trusted.")
        sys.exit(0)
    
    if __name__ == "__main__":
        main()

you can run it like this (fro within the repository):

    python check_signatures.py origin $(git rev-parse --abbrev-ref HEAD)

### Server side verification
You can do more or less the same thing as a client hook, as a pre-receive server hook. If you pay for GitHub/GitLab enterprise that is or if you are using GitTea. That's not bad, but it also means if the server gets compromised and your clients don't also check, you're breached - not really a great trust model when talking about personal signatures. So this is more of a solution for preventing mistakes from your users. It's better than nothing of course, it's also something useful to do before running any CI/CD.

Surprisingly 20 years after git's release, there is no industry standard for doing some sort of commit signature alerting automation. Various GitHub actions, scripts and kubernetes plugins exist, but nothing quite like I would imagine a solution to look like. Maybe this could be a gap in the market, I might develop something in the future.

But then again. Git commit signing, for whatever reason, isn't really something most orgs do. Laziness really is the death of security.

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Linux, git, Fido-2, Security_</sup>
