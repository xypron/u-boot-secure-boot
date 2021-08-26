#!/bin/sh
## SPDX-License-Identifier: GPL-2.0-or-later

set -e

MYGUID='6b0b4667-d057-4729-9544-53b75fbf326b'
MSGUID='77fa9abd-0359-4d32-bd60-28f4e78f784b'

if test ! -f PK.key -a ! -f PK.crt; then

echo Creating PK, KEK, db

# Create the platform key (PK): 
openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=Test_PK/ \
        -keyout PK.key -out PK.crt -nodes -days 3650

cert-to-efi-sig-list -g $MYGUID PK.crt PK.esl;
sign-efi-sig-list -c PK.crt -k PK.key PK PK.esl PK.auth

# Create the key exchange key (KEK):
openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=Test_KEK/ \
        -keyout KEK.key -out KEK.crt -nodes -days 3650
cert-to-efi-sig-list -g $MYGUID KEK.crt KEK.esl

if test ! -f MicCorKEKCA2011_2011-06-24.crt; then
curl -e 'https://docs.microsoft.com/' \
-A 'Mozilla/5.0 (X11; Linux arm64; rv:91.0) Gecko/20100101 Firefox/91.0' \
https://www.microsoft.com/pkiops/certs/MicCorKEKCA2011_2011-06-24.crt > \
MicCorKEKCA2011_2011-06-24.crt
fi

if sha1sum MicCorKEKCA2011_2011-06-24.crt | \
grep 31590bfd89c9d74ed087dfac66334b3931254b30; then
cert-to-efi-sig-list -g $MSGUID MicCorKEKCA2011_2011-06-24.crt MS.esl
cat MS.esl >> KEK.esl
else
echo Microsoft KEK checksum does not match
echo Certificate not included
rm MicCorKEKCA2011_2011-06-24.crt
fi

sign-efi-sig-list -c PK.crt -k PK.key KEK KEK.esl KEK.auth

# Create the secure boot signature store (db):
openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=Test_db/ \
        -keyout db.key -out db.crt -nodes -days 3650
cert-to-efi-sig-list -g $MYGUID db.crt db.esl
sign-efi-sig-list -c KEK.crt -k KEK.key db db.esl db.auth

# The secure boot blacklist signature store (dbx) can be downloaded from
# https://uefi.org/revocationlistfile

else
	echo PK already exists
fi

echo Updating ubootefi.var

# Create 
rm -f ubootefi.var
./efivar.py set -i ubootefi.var -n pk -d PK.esl -t file
./efivar.py set -i ubootefi.var -n kek -d KEK.esl -t file
./efivar.py set -i ubootefi.var -n db -d db.esl -t file
./efivar.py set -i ubootefi.var -a ro,bs,rt -n AuditMode -d 0 -t u8
./efivar.py set -i ubootefi.var -a ro,bs,rt -n DeployedMode -d 1 -t u8
