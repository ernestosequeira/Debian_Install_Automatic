#!/bin/bash
########### Autor: Ernesto Sequeira #############################
########### Team OpenLynx #######################################
########### Install Automatic Debian GNU/Linux ##################

PATH_FILES=/mnt/files
ISO_DEBIAN=http://cdimage.debian.org/debian-cd/7.1.0/i386/iso-cd/debian-7.1.0-i386-netinst.iso
CFG_PRESEES=http://ks.openlynx.com.ar/preseed.cfg

ISO_FILE=/mnt/files/debian-7.1.0-i386-netinst.iso
PATH_MOUNT=/mnt/deb_mount

PATH_NEW_ISO=/mnt/iso


PATH_ISOLINUX=/mnt/iso/isolinux
PATH_ISO_FINAL=/mnt/files/disk
PATH_VM=/home/$USER/VirtualBox VMs

ISO_NEW=trytoniso

VM_NAME=vm_tryton
VM_MEM=256
VM_DISK_NAME=disk_tryton
VM_SIZE=1024

# Colors constants
NONE="$(tput sgr0)"
RED="$(tput setaf 1)"
GREEN="$(tput setaf 2)"
YELLOW="\n$(tput setaf 3)"
BLUE="\n$(tput setaf 4)"

message() {
	# $1 : Message
	# $2 : Color
	# return : Message colorized
	local NOW="[$(date +%H:%M:%S)]"
	echo -e "${2}${NOW}${1}${NONE}"
}

download_debian_pressed(){
	clear
        local path_files="$1"
	local iso_debian="$2"
	local cfg_preseed="$3"
	mkdir -p ${path_files} 
	cd ${path_files}
	wget ${iso_debian}
	message ">> debian: download complete." ${GREEN}
	wget ${cfg_preseed}
	message ">> pressed: download complete." ${GREEN}
}


mount_iso(){
	local iso_file="$1"
   	local path_mount="$2"
	local ok = "$3"
	mkdir -p ${path_mount}
	mount -t iso9660 ${iso_file} ${path_mount} -o loop
	message ">> iso successfully prepared." ${GREEN}
}


prepare_new_iso(){
	local path_new_iso="$1"
	local path_file="$2"
	local path_mount="$3"
	mkdir -p ${path_new_iso}
	rsync -av ${path_mount}/ ${path_new_iso}
	cp ${path_file}/preseed.cfg ${path_new_iso}
	chmod -R 754 ${path_new_iso}
	umount ${path_mount}
	rm -rf ${path_mount}
	message ">> successfully mounted iso." ${GREEN}
}


change_menu_cfg(){
	local path_isolinux="$1"
	cd ${path_isolinux}

	if [ -e "menu.cfg" ]
		then
		echo “Archivo encontrado...”
		cat > menu.cfg << EOF
			menu hshift 7
	  		menu width 60
	 		menu title Debian GNU/Linux installer boot menu
	  		include txt.cfg
EOF
		message ">> successfully modified file menu.cfg." ${GREEN}
	else
		message ">> File menu.cfg not found." ${RED}
	fi
}


change_txt_cfg(){
	local path_isolinux="$1"
	cd ${path_isolinux}

	if [ -e "txt.cfg" ]
		then
		message "File found..." ${GREEN}
		cat > txt.cfg << EOF
			DEFAULT wheeze_tryton
   	    		LABEL wheeze_tryton
				menu label ^Debian Tryton
				kernel /install.386/vmlinuz
				append auto=true priority=critical vga=788 initrd=/install.386/initrd.gz file=/cdrom/preseed.cfg -- quiet
EOF
		message ">> successfully modified file txt.cfg." ${GREEN}
	else
		message ">> file txt.cfg not found." ${RED}
	fi
}


create_new_iso(){
	local path_iso_final="$1"
	local path_new_iso="$2"
	local iso_new="$3"
	aptitude install genisoimage -y
	mkdir -p ${path_iso_final}
	mkisofs -r -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ${path_iso_final}/${iso_new}.iso /${path_new_iso}
	rm -rf ${path_new_iso}
	message ">> iso created successfully." ${GREEN}
}


create_vm(){
	local vm_name="$1"
	local vm_mem="$2"
	local vm_disk_name="$3"
	local iso_new="$4"
	local vm_size="$5"
	local path_new_iso="$6"
	local path_iso_final="$7"
	local path_vm="$8"
	

	echo "Enter type of virtualizer (vbox or qemu):"
	read r
	if [ $r = "vbox" ];
		then
			#packages needed for virtualbox
			aptitude install virtualbox -y	
		
			#create vm
			VBoxManage createvm --name ${vm_name} --register
			VBoxManage modifyvm ${vm_name} --memory ${vm_mem} --acpi on --boot1 dvd
			VBoxManage modifyvm ${vm_name} --nic1 bridged --bridgeadapter1 eth0

			# add disk
			mkdir -p ${path_new_iso}
			VBoxManage createhd --filename ${path_vm}/${vm_disk_name}.vdi --size ${vm_size}
			VBoxManage storagectl ${vm_name} --name "IDE Controller" --add ide
			VBoxManage storageattach ${vm_name} --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium ${path_vm}/${vm_disk_name}.vdi
			VBoxManage storageattach ${vm_name} --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium ${path_iso_final}/${iso_new}.iso
			message ">> vm vbox created successfully." ${GREEN}

			#start Installation
			VBoxManage startvm ${vm_name} &
	else
		if [ $r = "qemu" ];
			then
			#packages needed for qemu
			aptitude install virtinst virt-manager virt-viewer libvirt-bin kvm qemu vde2 bridge-utils -y

			#adduser current for qemu			
			adduser $USER libvirtd	
			
			#add disk
			mkdir -p ${path_new_iso}
			qemu-img create -f qcow2 -o preallocation=metadata ${path_vm}/${vm_disk_name}.qcow2 ${vm_size}M

			#start Installation
			virt-install \
			--name=${vm_name} \
			--connect=qemu:///system \
			--ram=${vm_mem} \
			--hvm \
			--virt-type=kvm \
			--cdrom=${path_iso_final}/${iso_new}.iso \
			--file=${path_vm}/${vm_disk_name}.qcow2 \
			--graphics vnc,keymap=es
			message ">> vm qemu created successfully." ${GREEN}
		fi
	fi
}


#function calls

download_debian_pressed $PATH_FILES ${ISO_DEBIAN} ${CFG_PRESEES}

mount_iso ${ISO_FILE} ${PATH_MOUNT} ${GREEN}

prepare_new_iso ${PATH_NEW_ISO} ${PATH_FILES} ${PATH_MOUNT}

change_menu_cfg ${PATH_ISOLINUX}

change_txt_cfg ${PATH_ISOLINUX}

create_new_iso  ${PATH_ISO_FINAL} ${PATH_NEW_ISO} ${ISO_NEW}

create_vm ${VM_NAME} ${VM_MEM} ${VM_DISK_NAME} ${ISO_NEW} ${VM_SIZE} ${PATH_NEW_ISO} ${PATH_ISO_FINAL} ${PATH_VM}

message "\n>> Finnished.." ${GREEN}
exit 0
