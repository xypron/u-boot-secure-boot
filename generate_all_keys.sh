#!/bin/sh
## SPDX-License-Identifier: GPL-2.0-or-later

if test ! -f PK.key -a ! -f PK.crt; then

echo Creating PK, KEK, db

# Create the platform key (PK): 
openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=Test_PK/ \
        -keyout PK.key -out PK.crt -nodes -days 3650

cert-to-efi-sig-list -g 6b0b4667-d057-4729-9544-53b75fbf326b \
        PK.crt PK.esl;
sign-efi-sig-list -c PK.crt -k PK.key PK PK.esl PK.auth

# Create the key exchange key (KEK):
openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=Test_KEK/ \
        -keyout KEK.key -out KEK.crt -nodes -days 3650
cert-to-efi-sig-list -g 6b0b4667-d057-4729-9544-53b75fbf326b \
        KEK.crt KEK.esl
sign-efi-sig-list -c PK.crt -k PK.key KEK KEK.esl KEK.auth

# Create the secure boot signature store (db):
openssl req -x509 -sha256 -newkey rsa:2048 -subj /CN=Test_db/ \
        -keyout db.key -out db.crt -nodes -days 3650
cert-to-efi-sig-list -g 6b0b4667-d057-4729-9544-53b75fbf326b \
        db.crt db.esl
sign-efi-sig-list -c KEK.crt -k KEK.key db db.esl db.auth

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
