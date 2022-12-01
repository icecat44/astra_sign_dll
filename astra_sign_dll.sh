#!/bin/bash

if [ -z $1 ]; then echo -en "Скрипт для подписи ELF файлов.\nПредварительно необходимо импортировать в систему закрытый ключ.\nUsage: sudo $0 /full/dir/to/spo/ \n"; exit 1; fi
if [ "$EUID" -ne 0 ]; then  echo -e "\033[5m\033[41m\033[1m   !!!!!    Please run as root   !!!!!   \033[0m ";  exit 1; fi
key_id=$(gpg -K | grep 8765AB22442504443439D81D6996F29E4B30123345 | awk '{print $1}')
pass_file="/home/user/company_password.txt"
if [ -z $key_id ]; then echo -e "\033[0;31m Закрытый ключ не найден! \nПредварительно необходимо импортировать закрытый ключ компании. \033[0m"; exit 1; else
mkdir -p /tmp/spo_update
dir=$1
    cd $dir

# Создание сценариея предложенного РусБИТех-ом
# https://wiki.astralinux.ru/pages/viewpage.action?pageId=103024910
cat << EOF >> signdll
#!/usr/bin/python3
import sys
import shutil
import subprocess
import argparse
import xattr
DIGSIG_ELF_SIG_SIZE = 512
parser = argparse.ArgumentParser()
parser.add_argument('dll', metavar='filename.dll', help='path to dll to sign')
parser.add_argument('-p', '--pgoptions', help='pass options to the privacy guard program')
parser.add_argument('-R', '--replace', help='replace original file', action='store_true')
args = parser.parse_args()
name = args.dll
try:
    if args.replace:
        new_name = name
    else:
        if not name.endswith(('.dll', '.exe')):
            print("[Error] Must have filename.dll as an argument")
            sys.exit(1)
        new_name = name[:-4] + '_signed' + name[-4:]
        shutil.copyfile(name, new_name)
    with open(new_name, mode='ab') as f:
        f.write(b'\x00' * DIGSIG_ELF_SIG_SIZE)
    bsign_args = ['bsign', '--sign', '--xattr', new_name]
    if args.pgoptions is not None:
        if '--batch' in args.pgoptions:
            bsign_args.append('--nopass')
        bsign_args.extend(['-p', args.pgoptions])
    if subprocess.call(bsign_args):
        print("[Error] Calling bsign failure")
        sys.exit(1)
    sig = xattr.getxattr(new_name, 'user.sig')
    xattr.removexattr(new_name, 'user.sig')
    with open(new_name, mode='r+b') as f:
        f.seek(-DIGSIG_ELF_SIG_SIZE, 2)
        f.write(sig)
except Exception as e:
    print(str(e))
    sys.exit(1)
EOF
chmod +x signdll

# Обработка DLL файлов сценарием предложенным РусБИТех-ом
find . -name "*.dll" -exec  ./signdll -R --pgoptions="--batch --pinentry-mode=loopback --passphrase-file=$pass_file --default-key=$key_id" {} \;
rm -f signdll

# Подпись всех файлов СПО стандартной процедурой bsign.
   for file in `find . -type f` ; do
     bsign -N -s --pgoptions="--batch --pinentry-mode=loopback --passphrase-file=$pass_file --default-key=$key_id" $file
     ((count++))
   done
echo -e "\033[36m Signed $count files. \033[0m"

# Архив для переноса подписанного СПО с расширенными атрибутами.
now=$(date +%H%M%S_%d-%m-%Y)
tar --xattrs --acls -cvzf /tmp/spo_update/spo-signed_$now.tar.gz $dir
echo -en "\n\033[33;1;44m Для переноса СПО на другую систему без потери расширенных атрибутов используйте следующие команды:\033[0m \n"
cat <<_EOF_

echo 1 | sudo tee /parsecfs/unsecure_setxattr
sudo /usr/sbin/execaps -c 0x1000 -- tar --xattrs --xattrs-include=security.'*.*' --acls -xzf spo-signed_$now.tar.gz -C /
echo 0 | sudo tee /parsecfs/unsecure_setxattr

_EOF_

fi
