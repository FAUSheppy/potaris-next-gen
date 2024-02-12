---
title: QR-Codes as Key-Backups
date: 2023-03-01
description: QR-Codes as Key-Backups
---

# QR-Codes as Key-Backups

<div style="background-color: #30df56 !important;
            color: black;
            font-weight: bold;
            padding: 20px;
            margin: 10px;
            text-align: center;
            font-family: monospace;">
  Easy Difficulty
</div>

# QR-Codes as Key-Backups


If you have the technical know-how and want to hard-copy backup important passwords and keys, I suggest keeping it as an encrypted file, base64-encoded as a printed QR-code. You can then leave it in a safety deposit box or third party for safekeeping. The ultimate air gap, error resistant to damage up to 30% of the total information thanks to QR-Code encoding.

## The Process
### Requirements
We need a base64-encoder, a QR-encoder, a QR-decoder, an image/PDF conversion tool and GPG. On Debian, this equates to

    apt install coreutils imagemagick zbar-tools gpg qrencode

These packages pretty standard and should be widely available under the same or similar names on other distributions.

### GPG encrypt the file
You can encrypt a file like this:

    gpg --symmetric --cipher-algo AES256 logins_1.csv

If you want to script the process and do it for multiple file, consider doing it like this instead:

    pass=$(python -c "print(input(), end='')")
    gpg --yes --batch --passphrase $pass --symmetric --cipher-algo AES256 logins_1.csv

Since you are potentially giving out these prints to "untrusted" third-parties, remember to use a really strong passphrase here WHICH YOU CAN REMEMBER, for example **five random medium length  words**.

### Check the size
The tool we are using is not going to tell us, if we are above the maximum size for our QR-Codes. QR-Codes with "H" (high) error-resistance (30%) can store up to 2047 bits of information. If you are encoding a binary file and have to convert it to base64, remember to add some buffer - though we are going to notice later if we are missing data:

    max_size=2000
    test $(stat -c %s logins_1.csv.gpg) -gt $max_size && echo "logins_1.csv.gpg too big" && exit 1

### Create the QR-Code
Now we can finally create the QR-code. The base64 encoding, even for binary files, isn't strictly necessary, most modern QR-readers are able to decode binary codes

    cat logins_1.csv.gpg | base64 | qrencode -l H -s 20 -o logins_1.gpg.png

### Convert the Image to PDF
Convert the image to a PDF file for printing:

    convert logins_1.gpg.png logins_1.gpg.pdf

### Verify QR-Code / Restore
I recommend to, at least once check the following process with a full print-scan cycle, however for now, we are just going to test our QR-code right back from the created PDF:

    convert logins_1.gpg.pdf test_logins_1.gpg.png
    zbarimg -q test_logins_1.gpg.png | sed 's/QR-Code://' | base64 -d > test_logins_1.csv.gpg
    f=logins_1.csv.gpg
    diff $f "test_${f}" && echo $f ok || echo $f diff failed

If the files don't match, something went wrong, you should especially recheck the maximum size - otherwise, you are ready to distribute your backup.

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Linux, Backup, Security_ </sup>
