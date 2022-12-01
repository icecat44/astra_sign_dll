# Пакетное подписывание СПО

Для подписи используем выделенную ВМ с установленной Астра Linux, и комплект ПО указанный в инструкции:
(https://wiki.astralinux.ru/pages/viewpage.action?pageId=103024910)

А именно:
```
sudo apt install python3 python3-pip python3-dev python-dev build-essential libssl-dev libxml2-dev libffi-dev libxslt1-dev zlib1g-dev
pip3 install xattr
pip3 install cffi
```
Питоновский скрипт из статьи копировать не надо, он будет сделан автоматически.
**Не забываем, что на этой ВМ должен быть импортирован открытый и закрытый ключ!**
Внимательно изучаем скрипт и подгоняем расположение нужных файлов. :)
Для переноса подписанных файлов на другой сервер без потери расширенных атрибутов, необходимо произвести следующие действия:
**На сервере источнике:**
```
sudo tar --xattrs --acls -czf spo_signed.tar.gz /spo/
```
**На сервере приемнике:**
```
echo 1 | sudo tee /parsecfs/unsecure_setxattr
sudo /usr/sbin/execaps -c 0x1000 -- tar --xattrs --xattrs-include=security.'*.*' --acls -xzf spo_signed.tar.gz -C /spo/
echo 0 | sudo tee /parsecfs/unsecure_setxattr
```
