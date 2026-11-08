---
title: Git-Commit Signatures with fido2-keys
date: 2025-10-27
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

Git somewhat recently - by git standards - introduced signing commits with SSH keys. This seems like a rather miscellaneous feature at first sight. However, it carries with it the possibility to sign commits with normal fido2-hardware keys via ECDSA keys. This means you can use generic hardware keys, which do not support PGP for signing purposes.

## Key creation
The key creation is straightforward. You want the key to reside on the hardware key, and if your key supports it (which it should), you also want to require user verification, i.e. by fingerprint or PIN. The final argument adds a comment to identify the key later.

    cd ~/.ssh/
    ssh-keygen -t ecdsa-sk -O resident -O verify-required -C "a comment" -f "id_ecdsa_sk_git"

This creates a key on your key, a normal public key file and a stub private key on your machine, which you will reference when signing. The private key stub is required to use the key and can only be recovered from the hardware key if it is a resident key. This part of the key by itself cannot be used to sign anything, but you should still keep it private, as it could potentially be used for fraudulent signing requests to your hardware key.

    # ls -l ~/.ssh/
    id_ecdsa_sk_git.pub # the public key
    id_ecdsa_sk_git     # the private key stub

## Git config

To enable ssh-key signing, you need to set the GPG format and user signing key.

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

If you're using any of the major git server types (GitHub, GitLab, Gittea, etc.), then you can add your public key in your profile to have your commits display as verified. If you want to verify ssh-key commits locally, you need to create a file containing the trusted email to public-key pairs (mail-address with its trusted key, one per line) and reference it with the `gpg.ssh.allowedSignersFile` option, for example like this:


    echo "yourmail@domain.tld $(cat ~/.ssh/id_ecdsa_sk_git.pub)" >> ~/.git_trusted_keys
    git config --global gpg.ssh.allowedSignersFile ~/.git_trusted_keys 
    git verify-commit HEAD  # or commit id

If you use multiple emails, add the keys multiple times with the respective mails you want to trust it for. Careful with the global config here though, trusting your own key in every repository might be fine, but maybe you don't want to trust any key you add in every repository.

## Working with signed commits
Signing commits is worthless if nobody checks the signature and frankly very few people do. If you want to use it to improve security in your organization, it needs to be checked. Your options here are.. not great.

### Client Side Verification
The state of client-side verification is quite terrible. There is no dedicated function in git for it, nor is there even a _good_ hook for it. I wrote this script, which you can run before `git pull` (function or alias it):


    #!/usr/bin/env python3
    import subprocess
    import sys

    def git(*args):
        return subprocess.run(
            ["git", *args], check=True, capture_output=True, text=True
        ).stdout.strip()

    def main(remote, branch):
        git("fetch", remote, branch)
        commits = git("rev-list", "HEAD..FETCH_HEAD").splitlines()

        untrusted = []
        for commit in commits:
            try:
                git("verify-commit", commit)
            except subprocess.CalledProcessError:
                untrusted.append(commit)

        if untrusted:
            print("Untrusted commits:", *untrusted, sep="\n")
            return 1

        print(f"All {len(commits)} incoming commits verified.")
        return 0

    if __name__ == "__main__":
        try:
            sys.exit(main(*sys.argv[1:]))
        except (subprocess.CalledProcessError, TypeError) as e:
            sys.exit(f"Verification failed: {e}")


Run it like this (from within the repository):

    python check_signatures.py origin $(git rev-parse --abbrev-ref HEAD)

### Server side verification
You can do more or less the same thing as a client hook, as a pre-receive server hook (if you pay for GitHub/GitLab enterprise) or use Gitea. GitHub's free tier supports rejecting unverified commits, but not checking against a specific whitelist. GitLab is even more complicated, offering a similar option on some plans, but not on the free tier of gitlab.com, while supporting custom server hooks on the self-hosted Community Edition. It's a mess.

All in all, none of this is bad, but for any of these solutions, if the server gets compromised and your clients don't also check, you're breached - not really a great trust model when talking about personal signatures. So this is more of a solution for preventing mistakes from your users. It's better than nothing of course - it's also something useful to do before running any CI/CD.

Surprisingly, 20 years after git's release, there is no industry standard for doing some sort of commit signature alerting automation. Various GitHub actions, scripts and Kubernetes plugins exist, but nothing quite like I would imagine a solution to look like. Maybe this could be a gap in the market. I might develop something in the future.

But then again. Git commit signing, for whatever reason, isn't really something most orgs do. Laziness really is the death of security.

### Updates
- *2025-11-15:* Frustratingly I ran into another lack of verification options only weeks after writing this article, when I noticed the otherwise great [fleet-gitops solution](https://github.com/rancher/fleet) does in fact not support it either. I did open a [feature request](https://github.com/rancher/fleet/issues/4333) for it, let's see if something comes from that.
- *2026-05-05:* Multiple people have asked if the key stub remaining on the disk contains any secrets or if it could be considered public. The main threat from a stub-key leak is that it enables *malicious signing requests* to the hardware key. So no, the key should not be considered public and the corresponding hardware key should probably be regenerated/rotated if it is leaked, but it's still useless without the hardware key.

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Linux, git, Fido-2, Security_</sup>
