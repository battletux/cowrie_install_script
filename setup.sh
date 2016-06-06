
#!/bin/bash
if [[ $EUID -ne 0 ]]; then
echo "This script must be run as root"
   exit 2
fi
apt-get install debconf-utils -y
echo -n "Please provide a root password for MySQL > "
read -r mysql_root_pw
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password $mysql_root_pw'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password $mysql_root_pw'
echo "Now to install the required packages."
#if put error check in... if $? dont equal 0 then fail
        apt-get install python-twisted python-crypto python-pyasn1 python-gmpy2 python-mysqldb python-zope.interface git python-dev python-openssl openssh-server python-pyasn1 python-twisted authbind mysql-server python-mysqldb -y
        
# Now to create the cowrie user. The extension --gecos in the adduser bit stops chfn asking for finger info.
echo "Creating honeypot user 'cowrie'."
echo "This user is created with a disabled password for security."
adduser --disabled-password --gecos "" cowrie

#This sets authbind for port 22 so that cowrie can monitor the standard ssh port without root permissions
touch /etc/authbind/byport/22
chown cowrie /etc/authbind/byport/22
chmod 777 /etc/authbind/byport/22

echo -n "Please enter a new port number to use for SSH (Choose between 1024-65535)"
read -r ssh_port
if (( ("$ssh_port" > 1024) && ("$ssh_port" < 65535) )); then
        #sed the sshd config file to change the port.
        sed -i 's/Port /# Port /' /etc/ssh/sshd_config
        echo "Port $ssh_port" >> /etc/ssh/sshd_config
        echo "SSH port has been changed to: $ssh_port."
else
        echo "Port chosen is incorrect."
        exit 1
fi

service ssh restart
# create the cowrie user
echo "Now to setup the MySQL user and database."
#mysql -u root -p"$mysql_root_pw" << EOF
#CREATE DATABASE cowrie;
#GRANT ALL ON cowrie.* TO cowrie@localhost IDENTIFIED BY 'secret123';
#EOF
mysql -h localhost -u "root" -p "${mysql_root_pw}" -e "CREATE DATABASE cowrie"
mysql -h localhost -u "root" -p "${mysql_root_pw}" -e "GRANT ALL ON cowrie.* TO cowrie@localhost IDENTIFIED BY 'secret123'"


#create the cowrie database
mysql -u cowrie -p"secret123" << EOF
USE cowrie;
source https://github.com/micheloosterhof/cowrie/blob/master/doc/sql/mysql.sql
EOF


echo "Now to install cowrie"

IP=$(ifconfig eth0 | grep inet\ addr | cut -d':' -f2 | cut -d ' ' -f1)
NODE=$(nslookup "$IP" | grep name\ \= | cut -d' ' -f3 | sed s/.$//)
HOST=$(echo "$NODE" | cut -d'.' -f1)

sudo su - cowrie
git clone https://github.com/cowrie/cowrie.git /home/cowrie
mv /home/cowrie/cowrie/cowrie.cfg.dist /home/cowrie/cowrie/cowrie.cfg
sed -i 's/#listen_port = 2222/listen_port = 22/' /home/cowrie/cowrie/cowrie.cfg
sed -i "s/hostname = svr04/hostname = $HOST" /home/cowrie/cowrie/cowrie.cfg
sed -i "s/#sensor_name=myhostname/sensor_name=$NODE" /home/cowrie/cowrie/cowrie.cfg
sed -i 's/#[output_mysql]/[output_mysql]/' /home/cowrie/cowrie/cowrie.cfg
sed -i 's/#host = localhost/host = localhost/' /home/cowrie/cowrie/cowrie.cfg
sed -i 's/#database = cowrie/database = cowrie/' /home/cowrie/cowrie/cowrie.cfg
sed -i 's/#username = cowrie/username = cowrie/' /home/cowrie/cowrie/cowrie.cfg
sed -i 's/#password = secret/password = secret123/' /home/cowrie/cowrie/cowrie.cfg
sed -i 's/#port = 3306/port = 3306/' /home/cowrie/cowrie/cowrie.cfg
sed -i 's/#[output_virustotal]/[output_virustotal]/' /home/cowrie/cowrie/cowrie.cfg
sed -i 's/#api_key = 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef/api_key = 1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx1/' /home/cowrie/cowrie/cowrie.cfg

echo "Now to enable authbind (we are almost there!)"

sed -i 's/AUTHBIND_ENABLED=no/AUTHBIND_ENABLED=yes/' /home/cowrie/cowrie/start.sh

echo "All done. run ./start.sh as the cowrie user to start."





