#!/bin/bash
echo -e "\e[2;32mThis will disable the Selinux\e[0m"
sudo sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config
echo -e "\e[2;32mSelinux was disabled\e[0m"
if  grep -xqFe  "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf; then
   echo "line was present"
else
echo net.ipv6.conf.all.disable_ipv6 = 1 >> /etc/sysctl.conf ; cat /etc/sysctl.conf ;
fi
if grep -xqFe "net.ipv6.conf.default.disable_ipv6 = 1" /etc/sysctl.conf; then
echo "line was present"
else
echo net.ipv6.conf.default.disable_ipv6 = 1 >> /etc/sysctl.conf ; cat /etc/sysctl.conf ;
fi

echo -e "\e[2;32mIpv6 has been disabled\e[0m"

echo -e "\e[2;32mNow we have to update\e[0m"

yum update -y 
echo -e "\e[2;32mupdate was done \e[0m"

echo -e "\e[2;32mYum Update and Selinux and IPV6 was done\e[0m"


echo -e "\e[2;32msystemc will reboot\e[0m"


echo -e -n "\e[2;32mDo you want to reboot the system ? [yes or no]: \e[0m"
read yno
case $yno in

        [yY] | [yY][Ee][Ss] )
                reboot
                ;;

        [nN] | [n|N][O|o] )
                echo "reboot was canceled"
                exit 1
                ;;
        *) echo "Invalid input"
            ;;
esac
