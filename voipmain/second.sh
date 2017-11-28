#!/bin/bash
systemctl stop firewalld
echo -e "\e[2;32mFirewalld was disabled\e[0m"
echo -e "\e[2;32mFreeswitch Installation\e[0m"
yum install -y http://files.freeswitch.org/freeswitch-release-1-6.noarch.rpm epel-release -y
echo -e "\e[2;32mCreated the epel repo\e[0m"
echo -e "\e[2;32mNext,Installing the Dependencies\e[0m"
yum install -y deltarpm vim git alsa-lib-devel autoconf automake bison broadvoice-devel bzip2 curl-devel e2fsprogs-devel flite-devel g722_1-devel gcc-c++ gdbm-devel gnutls-devel ilbc2-devel ldns-devel libcodec2-devel libcurl-devel libedit-devel libidn-devel libjpeg-devel libmemcached-devel libogg-devel libsilk-devel libsndfile-devel libtheora-devel libtiff-devel libtool libuuid-devel libvorbis-devel libxml2-devel lua-devel lzo-devel ncurses-devel net-snmp-devel openssl-devel opus-devel pcre-devel perl perl-ExtUtils-Embed pkgconfig portaudio-devel python-devel soundtouch-devel speex-devel sqlite-devel unbound-devel unixODBC-devel wget which yasm zlib-devel lame lame-devel mpg123-devel libshout-deve -y 
echo -e "\e[2;32mInstalled the Dependencies\e[0m"
echo -e "\e[2;32mCopying the desired files\e[0m"
while  sourcefile=./conffiles/JSON.lua   destfile=/usr/share/lua/5.1
do
      cp $sourcefile $destfile
      if [ -s $destfile ] ; then
         echo -e "\e[2;32m$destfile copied successfully from $sourcefile\e[0m"
         break  
      fi
done
echo "\e[2;32mClonening and Copying the freeswitch source code to src directory\e[0m"
file="./freeswitch"
if [ -s "$file" ]
then
  echo -e "\e[2;32m$file was present\e[0m"
else
  git clone -b v1.6 https://freeswitch.org/stash/scm/fs/freeswitch.git freeswitch
fi

while  sourcefile=./freeswitch   destfile=/usr/local/src
do
      cp -r $sourcefile $destfile
      if [ -s $destfile ] ; then
         echo -e "\e[2;32m$destfile copied successfully from $sourcefile\e[0m"
         break  
      fi
done

echo -e "\e[2;32mNow rpm packages will install\e[0m"


rpm -iah libsmpp34-0-1.10.27-1.1.x86_64.rpm

rpm -iah libsmpp34-0-devel-1.10.27-1.1.x86_64.rpm

echo -e "\e[2;32mRPM packages installed sucessfully\e[0m"



while  sourcefile=./conffiles/modules.conf destfile=/usr/local/src/freeswitch
do
      cp $sourcefile $destfile
      if [ -s $destfile ] ; then
         echo -e "\e[2;32m$destfile copied successfully from $sourcefile\e[0m"  
          break 
       fi
done

while  sourcefile=./conffiles/httapi.conf.xml  destfile=/usr/local/src/freeswitch/src/mod/applications/mod_httapi/conf/autoload_configs/
do
      cp $sourcefile $destfile
      if [ -s $destfile ] ; then
           echo -e "\e[2;32m$destfile copied successfully from $sourcefile\e[0m"
          break
      fi

done

while  sourcefile=./conffiles/mod_httapi.c  destfile=/usr/local/src/freeswitch/src/mod/applications/mod_httapi/
do
      cp $sourcefile $destfile
      if [ -s $destfile ] ; then
          echo -e "\e[2;32m$destfile copied successfully from $sourcefile\e[0m"
         break
      fi
done
cd /usr/local/src/freeswitch/
echo -e "\e[2;32m Now bootstrap will be done\e[0m"
./bootstrap.sh -j
echo -e "\e[2;32m Bootstrap done\e[0m"
echo -e "\e[2;32m Configuration will be done\e[0m"
./configure -C --prefix=/usr/voip
echo -e "\e[2;32m Configuration was successfull\e[0m" 
echo -e "\e[2;32m Building the freeswitch\e[0m" 
make
echo -e "\e[2;32m Building freeswitch finished\e[0m" 
make install
echo -e "\e[2;32m Installation of freeswitch \e[0m" 
echo -e "\e[2;32m Installing the sounds\e[0m" 
make cd-sounds-install
make cd-moh-install
echo -e "\e[2;32m Sounds installation was finished\e[0m" 
make CFLAGS='-lasound' mod_flite
make CFLAGS='-lasound' mod_flite-install
field="${default_password}" expression="^12345$"
sed -i  's/field="${default_password}" expression="^1234$"/field="${default_password}" expression="^12345$"/g'  /usr/voip/etc/freeswitch/dialplan/default.xml /usr/voip/etc/freeswitch/dialplan/default.xml
sed -i  's/name="listen-ip" value="::"/name="listen-ip" value="127.0.0.1"/g'  /usr/voip/etc/freeswitch/autoload_configs/event_socket.conf.xml /usr/voip/etc/freeswitch/autoload_configs/event_socket.conf.xml
sed -i  's/*.xml"/internal.xml"/g'  /usr/voip/etc/freeswitch/autoload_configs/sofia.conf.xml /usr/voip/etc/freeswitch/autoload_configs/sofia.conf.xml
echo -e "\e[2;32mEND OF THE Installation and Copying of files\e[0m"

echo -e "\e[2;32mNext we need to enter the Ip which was needed to out freeswitch\e[0m"

read  -p 'Enter the IP for vars.xml: ' ip
  if [ "$ip" != "0" ]; then
    sed -i  's/bind_server_ip=auto/bind_server_ip='$ip'/g'  /usr/voip/etc/freeswitch/vars.xml /usr/voip/etc/freeswitch/vars.xml
    sed -i  's/external_rtp_ip=stun:stun.freeswitch.org/external_rtp_ip='$ip'/g'  /usr/voip/etc/freeswitch/vars.xml /usr/voip/etc/freeswitch/vars.xml
    sed -i  's/external_sip_ip=stun:stun.freeswitch.org/external_sip_ip='$ip'/g'  /usr/voip/etc/freeswitch/vars.xml /usr/voip/etc/freeswitch/vars.xml
    echo -e "\e[2;32mIp was changed successfully in vars.xml file\e[0m"
  else
   echo -e "\e[2;32mplease enter the correct ip\e[0m"
  fi


