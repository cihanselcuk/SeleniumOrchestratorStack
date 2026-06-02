#echo ----- change ssh port to 8086
#sudo sed -i 's/#Port 22/Port 8086/' /etc/ssh/sshd_config

#echo ----- add devops user
#sudo adduser devops
#sudo adduser devops sudo

#echo ----- disable root login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

#docker builder prune --all

echo ----- initial update
sudo apt update
sudo apt upgrade --yes
sudo apt autoremove --yes

echo ----- install apt-transport-https ca-certificates
sudo apt install apt-transport-https ca-certificates curl software-properties-common --yes

echo ----- curl -ubuntu key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

echo ----- add apt repo
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"

echo ----- docker-ce policy
apt-cache policy docker-ce

echo ----- install docker
sudo apt install docker-ce --yes