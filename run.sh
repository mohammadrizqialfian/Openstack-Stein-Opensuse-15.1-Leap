#!/bin/bash

#reset warna
color_off='\033[0m'
#beri warna
blue='\033[0;94m'

printf '=%.0s' {1..75}; echo -e "\n"
echo -e "\t\tMenjalankan Bash Script Openstack Stein\n"
printf '=%.0s' {1..75}; echo -e "\n"
while :
do
	echo -e "$blue y = mengganti variable di config.conf secara interactive $color_off"
	echo -e "$blue n / lain = lewati, pastikan anda sudah mengganti variable tersebut secara manual di config.conf $color_off"
	read -p "Apakah anda ingin merubah isi variable di config.conf(y/n): " jawab1
	if [[ $jawab1 == "y" ]]
	then
		read -sp "Masukkan password untuk user admin : " passwordadmin ; echo ""
		sed -i "s/ADMINLOG=.*/ADMINLOG=$passwordadmin/" config.conf
		read -sp "Masukkan password root database : " passworddb ; echo ""
		sed -i "s/DBPASSWORD=.*/DBPASSWORD=$passworddb/" config.conf
		read -p "Masukkan IP Management Controller(ex: 192.168.137.10) : " ipmanagement
		sed -i "s/IPMANAGEMENT=.*/IPMANAGEMENT=$ipmanagement/" config.conf
		read -p "Masukkan Hostname Controller(ex: controller) : " hostcontroller
		sed -i "s/HOSTCONTROLLER=.*/HOSTCONTROLLER=$hostcontroller/" config.conf
		read -p "Masukkan Network Management(ex: 192.168.137.0/24) : " netmanagement
		sed -i "s|NETMANAGEMENT=.*|NETMANAGEMENT=$netmanagement|" config.conf
		read -p "Masukkan nama Interface Management(ex: eth0) : " intmanagement
		sed -i "s/INTMANAGEMENT=.*/INTMANAGEMENT=$intmanagement/" config.conf
		read -p "Masukkan nama Interface External(ex: eth1) : " intexternal
		sed -i "s/INTEXTERNAL=.*/INTEXTERNAL=$intexternal/" config.conf
		if [[ $intmanagement == $intexternal ]]
		then
			read -p "Masukkan Netmask Interface Management(ex: 255.255.255.0) : " netmaskmanagement
			sed -i "s/NETMASKMANAGEMENT=.*/NETMASKMANAGEMENT=$netmaskmanagement/" config.conf
			read -p "Masukkan IP Gateway(ex: 192.168.137.1) : " ipgateway
			sed -i "s/IPGATEWAY=.*/IPGATEWAY=$ipgateway/" config.conf
		fi
		read -p "Masukkan nama drive/partisi untuk cinder(ex: sdb / sdc1) : " cinderdev
		sed -i "s/CINDERDEV=.*/CINDERDEV=$cinderdev/" config.conf
		echo -e "$blue CONTOH: Drive untuk swift: sdb sdc sdd sde $color_off"
		read -p "Masukkan nama drive/partisi untuk swift(ex: sdc / sdd1) : " swiftdev
		sed -i "s/SWIFTDEV=.*/SWIFTDEV=\"$swiftdev\"/" config.conf
		read -p "Masukkan jumlah replikasi setiap object swift : " replikasi
		sed -i "s/REPLIKASI=.*/REPLIKASI=$replikasi/" config.conf
		read -p "Masukkan tipe virtualisasi untuk compute(ex: kvm / qemu) : " typevirt
		sed -i "s/TYPEVIRT=.*/TYPEVIRT=$typevirt/" config.conf
		if [[ $typevirt == "kvm" ]]
		then
			read -p "Aktifkan Nested Virtualization(y/n) : " nested
			if [[ $nested == "y" ]]
			then
				sed -i "s/#cpu_mode/cpu_mode/" 04-nova.sh
				read -p "apa jenis processor anda (intel/amd) : " proc
				if [[ $proc == "intel" ]]
					sed -i "s/#intel/ /" 04-nova.sh
				else
					sed -i "s/#amd/ /" 04-nova.sh
				fi
			fi
		fi
		echo -e "\n"
		echo -e "\n"
		echo -e "$blue y = generate password random untuk service openstack $color_off"
		echo -e "$blue n / lain = atur 1 password yang sama untuk semua service openstack $color_off"
		read -p "Apakah anda ingin menggunakan random password (y/n): " jawab2
		if [[ $jawab2 == "y" ]]
		then
			rabbitpass=$(openssl rand -hex 12)
			sed -i "s/RABBITPASS=.*/RABBITPASS=$rabbitpass/" config.conf
			keystonedbpass=$(openssl rand -hex 12)
			sed -i "s/KEYSTONEDBPASS=.*/KEYSTONEDBPASS=$keystonedbpass/" config.conf
			glancedbpass=$(openssl rand -hex 12)
			sed -i "s/GLANCEDBPASS=.*/GLANCEDBPASS=$glancedbpass/" config.conf
			glancepass=$(openssl rand -hex 12)
			sed -i "s/GLANCEPASS=.*/GLANCEPASS=$glancepass/" config.conf
			novadbpass=$(openssl rand -hex 12)
			sed -i "s/NOVADBPASS=.*/NOVADBPASS=$novadbpass/" config.conf
			novapass=$(openssl rand -hex 12)
			sed -i "s/NOVAPASS=.*/NOVAPASS=$novapass/" config.conf
			metadatapass=$(openssl rand -hex 12)
			sed -i "s/METADATAPASS=.*/METADATAPASS=$metadatapass/" config.conf
			neutrondbpass=$(openssl rand -hex 12)
			sed -i "s/NEUTRONDBPASS=.*/NEUTRONDBPASS=$neutrondbpass/" config.conf
			neutronpass=$(openssl rand -hex 12)
			sed -i "s/NEUTRONPASS=.*/NEUTRONPASS=$neutronpass/" config.conf
			placementpass=$(openssl rand -hex 12)
			sed -i "s/PLACEMENTPASS=.*/PLACEMENTPASS=$placementpass/" config.conf
			placementdbpass=$(openssl rand -hex 12)
			sed -i "s/PLACEMENTDBPASS=.*/PLACEMENTDBPASS=$placementdbpass/" config.conf
			cinderdbpass=$(openssl rand -hex 12)
			sed -i "s/CINDERDBPASS=.*/CINDERDBPASS=$cinderdbpass/" config.conf
			cinderpass=$(openssl rand -hex 12)
			sed -i "s/CINDERPASS=.*/CINDERPASS=$cinderpass/" config.conf
			swiftpass=$(openssl rand -hex 12)
			sed -i "s/SWIFTPASS=.*/SWIFTPASS=$swiftpass/" config.conf
			swiftprefix=$(openssl rand -hex 12)
			sed -i "s/SWIFT_HASH_PREFIX=.*/SWIFT_HASH_PREFIX=$swiftprefix/" config.conf
			swiftsuffix=$(openssl rand -hex 12)
			sed -i "s/SWIFT_HASH_SUFFIX=.*/SWIFT_HASH_SUFFIX=$swiftsuffix/" config.conf
		else
			read -sp "Masukkan Password: " jawab3 ; echo ""
			sed -i "s/RABBITPASS=.*/RABBITPASS=$jawab3/" config.conf
			sed -i "s/KEYSTONEDBPASS=.*/KEYSTONEDBPASS=$jawab3/" config.conf
			sed -i "s/GLANCEDBPASS=.*/GLANCEDBPASS=$jawab3/" config.conf
			sed -i "s/GLANCEPASS=.*/GLANCEPASS=$jawab3/" config.conf
			sed -i "s/NOVADBPASS=.*/NOVADBPASS=$jawab3/" config.conf
			sed -i "s/NOVAPASS=.*/NOVAPASS=$jawab3/" config.conf
			sed -i "s/METADATAPASS=.*/METADATAPASS=$jawab3/" config.conf
			sed -i "s/NEUTRONDBPASS=.*/NEUTRONDBPASS=$jawab3/" config.conf
			sed -i "s/NEUTRONPASS=.*/NEUTRONPASS=$jawab3/" config.conf
			sed -i "s/PLACEMENTPASS=.*/PLACEMENTPASS=$jawab3/" config.conf
			sed -i "s/PLACEMENTDBPASS=.*/PLACEMENTDBPASS=$jawab3/" config.conf
			sed -i "s/CINDERDBPASS=.*/CINDERDBPASS=$jawab3/" config.conf
			sed -i "s/CINDERPASS=.*/CINDERPASS=$jawab3/" config.conf
			sed -i "s/SWIFTPASS=.*/SWIFTPASS=$jawab3/" config.conf
			sed -i "s/SWIFT_HASH_PREFIX=.*/SWIFT_HASH_PREFIX=$jawab3/" config.conf
			sed -i "s/SWIFT_HASH_SUFFIX=.*/SWIFT_HASH_SUFFIX=$jawab3/" config.conf
		fi
	fi
	break
done

while :
do
	source config.conf
	echo -e "\n"
	printf '=%.0s' {1..40}; echo -e "\n"
	echo -e "$blue y = menjalankan keseluruhan script(0-8) $color_off"
	echo -e "$blue 0 = jalankan Script Environment $color_off"
	echo -e "$blue 1 = jalankan Script Keystone(Identity) $color_off"
	echo -e "$blue 2 = jalankan Script Glance(Image) $color_off"
	echo -e "$blue 3 = jalankan Script Placement $color_off"
	echo -e "$blue 4 = jalankan Script Nova(Compute) $color_off"
	echo -e "$blue 5 = jalankan Script Neutron(Networking) $color_off"
	echo -e "$blue 6 = jalankan Script Horizon(Dashboard) $color_off"
	echo -e "$blue 7 = jalankan Script Cinder(Block Storage) $color_off"
	echo -e "$blue 8 = jalankan Script Swift(Object Storage) $color_off"
	echo -e "$blue 9 = jalankan Script untuk menambahkan compute baru $color_off"
	echo -e "$blue n / lain = batalkan script $color_off \n"
	printf '=%.0s' {1..40}; echo -e "\n"
	read -p "Apakah anda yakin ingin menjalankan script ini(y/n): " input1
	if [[ $input1 == "y" ]]
	then 
		chmod +x 00-environment.sh 01-keystone.sh 02-glance.sh 03-placement.sh 04-nova.sh 05-neutron.sh 06-horizon.sh 07-cinder.sh 08-swift.sh 
		./00-environment.sh
		./01-keystone.sh
		./02-glance.sh
		./03-placement.sh
		./04-nova.sh
		./05-neutron.sh
		./06-horizon.sh
		./07-cinder.sh
		./08-swift.sh
		echo -e "$blue semua script berhasil dijalankan $color_off"
		echo -e "$blue Anda diwajibkan untuk merestart server controller anda agar service berjalan normal $color_off"
		read -p "Apakah anda ingin merestart server anda sekarang (y/n): " input2
		if [[ $input2 == "y" ]]
		then
			ssh root@$IPMANAGEMENT reboot
		fi
		break
	elif [[ $input1 == 0 ]]
	then
		chmod +x 00-environment.sh
		./00-environment.sh
		echo -e "$blue script environment selesai dijalankan $color_off"
		echo -e "$blue Anda diwajibkan untuk merestart server controller setelah menjalankan script environment namun anda juga bisa merestartnya nanti setelah menjalankan script lainnya $color_off"
		read -p "Apakah anda ingin merestart server anda sekarang (y/n): " input4
		if [[ $input4 == "y" ]]
		then
			ssh root@$IPMANAGEMENT reboot
		fi
		continue
	elif [[ $input1 == 1 ]]
	then
		chmod +x 01-keystone.sh
		./01-keystone.sh
		echo -e "$blue script keystone selesai dijalankan $color_off"
		continue
	elif [[ $input1 == 2 ]]
	then
		chmod +x 02-glance.sh
		./02-glance.sh
		echo -e "$blue script glance selesai dijalankan $color_off"
		continue
	elif [[ $input1 == 3 ]]
	then
		chmod +x 03-placement.sh
		./03-placement.sh
		echo -e "$blue script placement selesai dijalankan $color_off"
		continue
	elif [[ $input1 == 4 ]]
	then
		chmod +x 04-nova.sh
		./04-nova.sh
		echo -e "$blue script nova selesai dijalankan $color_off"
		continue
	elif [[ $input1 == 5 ]]
	then
		chmod +x 05-neutron.sh
		./05-neutron.sh
		echo -e "$blue scipt neutron selesai dijalankan $color_off"
		continue
	elif [[ $input1 == 6 ]]
	then
		chmod +x 06-horizon.sh
		./06-horizon.sh
		echo -e "$blue script horizon selesai dijalankan $color_off"
		continue
	elif [[ $input1 == 7 ]]
	then
		chmod +x 07-cinder.sh
		./07-cinder.sh
		echo -e "$blue script cinder selesai dijalankan $color_off"
		continue
	elif [[ $input1 == 8 ]]
	then
		chmod +x 08-swift.sh
		./08-swift.sh
		echo -e "$blue script swift selesai dijalankan $color_off"
		continue
	elif [[ $input1 == 9 ]]
	then
		chmod +x 09-newcompute.sh
		read -p "Masukkan IP Management Compute(ex: 192.168.137.10) : " ipcompute
		sed -i "s/IPCOMPUTE=.*/IPCOMPUTE=$ipcompute/" config.conf
		read -p "Masukkan Hostname Compute(ex: compute) : " hostcompute
		sed -i "s/HOSTCOMPUTE=.*/HOSTCOMPUTE=$hostcompute/" config.conf
		read -p "Masukkan nama Interface Management(ex: eth0) : " intmancompute
		sed -i "s/INTMANAGEMENTCOMPUTE=.*/INTMANAGEMENTCOMPUTE=$intmancompute/" config.conf
		read -p "Masukkan nama Interface External(ex: eth1) : " intextcompute
		sed -i "s/INTEXTERNALCOMPUTE=.*/INTEXTERNALCOMPUTE=$intextcompute/" config.conf
		if [[ $intmancompute == $intextcompute ]]
		then
			read -p "Masukkan Netmask Interface Management(ex: 255.255.255.0) : " netmaskmancompute
			sed -i "s/NETMASKMANAGEMENTCOMPUTE=.*/NETMASKMANAGEMENTCOMPUTE=$netmaskmancompute/" config.conf
			read -p "Masukkan IP Gateway(ex: 192.168.137.1) : " ipgatecompute
			sed -i "s/IPGATEWAYCOMPUTE=.*/IPGATEWAYCOMPUTE=$ipgatecompute/" config.conf
		fi
		if [[ $TYPEVIRT == "kvm" ]]
		then
			read -p "Aktifkan Nested Virtualization(y/n) : " nested
			if [[ $nested == "y" ]]
			then
				sed -i "s/#cpu_mode/cpu_mode/" 09-newcompute.sh
				read -p "apa jenis processor anda (intel/amd) : " proc
				if [[ $proc == "intel" ]]
					sed -i "s/#intel/ /" 09-newcompute.sh
				else
					sed -i "s/#amd/ /" 09-newcompute.sh
				fi
			fi
		fi
		./09-newcompute.sh
		echo -e "$blue script newcompute selesai dijalankan $color_off"
		echo -e "$blue Anda diwajibkan untuk merestart server compute anda agar service berjalan normal $color_off"
		read -p "Apakah anda ingin merestart server anda sekarang (y/n): " input3
		if [[ $input3 == "y" ]]
		then
			ssh root@$IPCOMPUTE reboot
		fi
	fi
	break
done
