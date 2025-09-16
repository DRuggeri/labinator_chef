#!/bin/bash
user=`hostname`
for user in root $user;do
  homedir=`grep "^$user:" /etc/passwd | cut -d ':' -f 6`
  test -d $homedir/.ssh || mkdir -p $homedir/.ssh
  echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDgX3hnqTTMMYjbwmHy9QqvnG9HNDTSDiHS6bU6Z2QImoRZWd5B0nc8HfSvEj1qhLKVyV45ARKXFDbh8D5dcMe9G9ZysEFdTeKZI8ovjfwAtlz4THbaDArz9woLDsZx1dcSVLnhXXo/bT8GqrNPxki3Zgf/LNYmqTKcaWlZIXME4B4J2Y3KwvqZo8T+Q6V33Y/jH/TzZucFguVsG3SGg0QXhXfi1757GXpYVYSxrVsURJ6QXaa2i4e2zkjV7+J7xufdF6og265wLDAJgXyldPRo377O3cMwo0I3QuAtzw21GpcAGn2BdEULZdBGiSuG9FsykBzGB6CG+QkYKBfkaD67 Danimal@Danimal-PC
' > $homedir/.ssh/authorized_keys
  chmod 600 $homedir/.ssh/authorized_keys $homedir/.ssh
  chown $user:$user $homedir/.ssh/authorized_keys $homedir/.ssh
done

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y rsync wget apt-transport-https lsb-release gnupg

REL=`lsb_release -sc`
if [ "$REL" = "bookworm" -o "$REL" = "trixie" ];then
  REL="bullseye"
fi

wget -O - https://packages.chef.io/chef.asc | gpg --dearmor > /usr/share/keyrings/chef-archive-keyring.gpg
echo "Types: deb
URIs: https://packages.chef.io/repos/apt/stable
Suites: $REL
Components: main
Signed-By: /usr/share/keyrings/chef-archive-keyring.gpg
" > /etc/apt/sources.list.d/chef-stable.sources
rm -f /etc/apt/sources.list.d/chef-stable.list
apt-get update


DEBIAN_FRONTEND=noninteractive apt-get install -y chef
chef-client --chef-license accept  > /dev/null

mkdir -p /var/chef/cookbooks/labinator
