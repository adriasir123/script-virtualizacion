#!/bin/bash

############################################################
# Banner que usaré para cada sección del output del script #
############################################################

banner() {
  echo "+------------------------------------------+"
  printf "| %-40s |\n" "$(date)"
  echo "|                 $(printf '\xF0\x9F\x92\x80')$(printf '\xF0\x9F\x92\x80')$(printf '\xF0\x9F\x92\x80')$(printf '\xF0\x9F\x92\x80')                 |"
  printf "|$(tput bold) %-40s $(tput sgr0)|\n" "$@"
  echo "+------------------------------------------+"
}

####################
# Inicio de script #
####################

banner "$(printf '\xF0\x9F\x91\xBD')$(printf '\xF0\x9F\x91\xBD')$(printf '\xF0\x9F\x91\xBD') Script de Adrián Jaramillo $(printf '\xF0\x9F\x91\xBD')$(printf '\xF0\x9F\x91\xBD')$(printf '\xF0\x9F\x91\xBD')"
sleep 2

###############################################
# EJERCICIO 1                                 #
# Crear un volumen de características:        #
#   - Imagen base: bullseye-base-sparse.qcow2 #
#   - Tamaño: 5 GB                            #
#   - Nombre: maquina1.qcow2                  #
###############################################

if [ ! -f maquina1.qcow2 ]; then
  banner "Creando volumen ligero maquina1.qcow2"
  qemu-img create -f qcow2 -F qcow2 -b bullseye-base-sparse.qcow2 maquina1.qcow2 >/dev/null
  sleep 2
  banner "Redimensionando maquina1.qcow2 a 5G"
  sleep 2
  banner "Paciencia, este proceso puede tardar"
  qemu-img resize maquina1.qcow2 5G >/dev/null
  cp maquina1.qcow2 maquina1-copy.qcow2
  virt-resize --expand /dev/vda1 maquina1.qcow2 maquina1-copy.qcow2 >/dev/null
  rm maquina1.qcow2 && mv maquina1-copy.qcow2 maquina1.qcow2
  sleep 2
else
  banner "Ya existe el volumen maquina1.qcow2"
  sleep 2
fi

#######################################
# EJERCICIO 2                         #
# Crear una red de características    #
#   - Tipo: interna NAT               #
#   - Nombre: intra                   #
#   - Direccionamiento: 10.10.20.0/24 #
#######################################

virsh -c qemu:///system net-list --all | grep intra >/dev/null
existered=$?

if [ $existered -ne 0 ]; then
  banner "Creando la red NAT intra"
  virsh -c qemu:///system net-define intra.xml >/dev/null
  virsh -c qemu:///system net-start intra >/dev/null
  sleep 2
else
  banner "Ya existe la red NAT intra"
  sleep 2
fi

########################################
# EJERCICIO 3                          #
# Crear una VM de características:     #
#   - Nombre: maquina1                 #
#   - Red: intra                       #
#   - RAM: 1 GiB                       #
#   - Disco: maquina1.qcow2            #
# Luego:                               #
#   - Inicio automático                #
#   - Modificar el hostname a maquina1 #
########################################

virsh -c qemu:///system list --all | grep maquina1 >/dev/null
existemaquina=$?
export IPMAQUINA1

if [ $existemaquina -ne 0 ]; then
  banner "Creando la VM maquina1"
  virt-install --connect qemu:///system --virt-type kvm --name maquina1 --os-variant debian10 --network network=intra --disk maquina1.qcow2 --import --memory 1024 --vcpus 2 --noautoconsole >/dev/null
  virsh -c qemu:///system autostart maquina1 >/dev/null
  banner "Esperando a que se reconozca la IP "
  sleep 2
  banner "Paciencia, este proceso puede tardar"
  sleep 21
  IPMAQUINA1=$(virsh -c qemu:///system domifaddr maquina1 | grep 10.10.20 | awk '{print $4}' | sed 's/...$//')
  banner "Cambiando el hostname de maquina1"
  ssh-keyscan "$IPMAQUINA1" >>~/.ssh/known_hosts 2>/dev/null
  ssh -i script debian@"$IPMAQUINA1" 'sudo hostnamectl set-hostname maquina1'
  ssh -i script debian@"$IPMAQUINA1" 'sudo sh -c "echo '127.0.0.1 maquina1' >> /etc/hosts"' 2>/dev/null
  sleep 2
else
  banner "Ya existe maquina1"
  IPMAQUINA1=$(virsh -c qemu:///system domifaddr maquina1 | grep 10.10.20 | awk '{print $4}' | sed 's/...$//')
  sleep 2
fi

##########################################
# EJERCICIO 4                            #
# Crear un volumen de características:   #
#   - Pool: default                      #
#   - Tamaño: 1 GiB                      #
#   - Formato: RAW                       #
##########################################

virsh -c qemu:///system vol-list default | grep adicional.raw >/dev/null
existevolumen=$?

if [ $existevolumen -ne 0 ]; then
  banner "Creando un volumen adicional raw"
  virsh -c qemu:///system vol-create-as default adicional.raw --format raw 1G >/dev/null
  sleep 2
else
  banner "Ya existe el volumen adicional raw"
  sleep 2
fi

##########################################
# EJERCICIO 5                            #
# - Conectar el volumen raw a maquina1   #
# - Formatear como XFS                   #
# - Crear /var/www/html                  #
# - Montarlo en /var/www/html            #
##########################################

ssh -i script debian@"$IPMAQUINA1" 'lsblk | grep vdb' >/dev/null
rawconectado=$?

if [ $rawconectado -ne 0 ]; then
  banner "Conectando el raw a maquina1"
  virsh -c qemu:///system attach-disk maquina1 /var/lib/libvirt/images/adicional.raw vdb --driver=qemu --type disk --subdriver raw --persistent >/dev/null
  sleep 2
  banner "Formateando el raw a XFS"
  ssh -i script debian@"$IPMAQUINA1" 'sudo mkfs.xfs /dev/vdb' >/dev/null
  sleep 2
  banner "Creando /var/www/html en maquina1"
  ssh -i script debian@"$IPMAQUINA1" 'sudo mkdir -p /var/www/html'
  sleep 2
  banner "Montando el raw en /var/www/html"
  diskuuid=$(ssh -i script debian@"$IPMAQUINA1" 'sudo blkid /dev/vdb | awk "{print \$2}" | sed "s/\"//g"')
  ssh -i script debian@"$IPMAQUINA1" 'sudo sh -c "echo '"$diskuuid" /var/www/html xfs noatime,x-systemd.automount,x-systemd.device-timeout=10,x-systemd.idle-timeout=1min 0 2' >> /etc/fstab"'
  ssh -i script debian@"$IPMAQUINA1" 'sudo mount -a'
  sleep 2
else
  banner "Ya está el raw conectado                "
  sleep 2
fi

####################################
# EJERCICIO 6                      #
# - Instalar apache2 en maquina1   #
# - Pasar un index.html a maquina1 #
# - Modificar propietarios         #
####################################

existeapache=$(ssh -i script debian@"$IPMAQUINA1" 'apt-cache policy apache2 | grep Installed | awk "{print \$2}"')

if [ "$existeapache" == "(none)" ]; then
  banner "Instalando apache2 en maquina1"
  sleep 2
  banner "Paciencia, este proceso puede tardar"
  ssh -i script debian@"$IPMAQUINA1" 'sudo apt-get install apache2 -y' >/dev/null 2>&1
  sleep 2
  banner "Pasando index.html a maquina1"
  scp -i script index.html debian@"$IPMAQUINA1":/home/debian >/dev/null
  ssh -i script debian@"$IPMAQUINA1" 'sudo mv /home/debian/index.html /var/www/html/index.html'
  sleep 2
  banner "Modificando propietarios"
  ssh -i script debian@"$IPMAQUINA1" 'sudo chown -R www-data:www-data /var/www'
  sleep 2
else
  banner "Apache ya está instalado                "
  sleep 2
fi

############################################
# EJERCICIO 7                              #
# - Mostrar por pantalla la IP de máquina1 #
# - Pausar el script                       #
# - Comprobar el acceso a la web           #
############################################

banner "La IP de maquina1 es $IPMAQUINA1"
sleep 2
banner "Accede a la web: http://$IPMAQUINA1/"
sleep 2
read -rp "Presiona [Enter] cuando hayas comprobado que puedes acceder a la web..."

#################################################
# EJERCICIO 8                                   #
# - Instalar LXC                                #
# - Crear un linux container llamado container1 #
#################################################

existelxc=$(ssh -i script debian@"$IPMAQUINA1" 'apt-cache policy lxc | grep Installed | awk "{print \$2}"')

if [ "$existelxc" == "(none)" ]; then
  banner "Instalando LXC en maquina1"
  sleep 2
  banner "Paciencia, este proceso puede tardar"
  ssh -i script debian@"$IPMAQUINA1" 'sudo apt-get install lxc -y' >/dev/null 2>&1
  sleep 2
  banner "Creando container1"
  sleep 2
  banner "Paciencia, este proceso puede tardar"
  ssh -i script debian@"$IPMAQUINA1" 'sudo lxc-create -n container1 -t debian -- -r bullseye' >/dev/null 2>&1
  sleep 2
else
  banner "LXC ya está instalado                   "
  sleep 2
fi

###################################################
# EJERCICIO 9                                     #
# - Añadir una interfaz bridge a maquina1 con br0 #
###################################################

ssh -i script debian@"$IPMAQUINA1" 'ip a | grep enp8s0' >/dev/null
existebridge=$?

if [ $existebridge -ne 0 ]; then
  banner "Apagando maquina1"
  virsh -c qemu:///system shutdown maquina1 >/dev/null
  sleep 10
  banner "Añadiendo una interfaz bridge a maquina1"
  virsh -c qemu:///system attach-interface maquina1 bridge br0 --model virtio --persistent >/dev/null
  sleep 2
  banner "Arrancando maquina1"
  virsh -c qemu:///system start maquina1 >/dev/null
  sleep 15
  banner "Modificando /etc/network/interfaces"
  ssh -i script debian@"$IPMAQUINA1" 'sudo sed -i "s/allow-hotplug enp2s0/allow-hotplug enp8s0/g" /etc/network/interfaces && sudo sed -i "s/iface enp2s0 inet dhcp/iface enp8s0 inet dhcp/g" /etc/network/interfaces'
  sleep 2
  banner "Levantando la interfaz bridge"
  ssh -i script debian@"$IPMAQUINA1" 'sudo ifup enp8s0' >/dev/null 2>&1
  sleep 2
else
  banner "Ya existe la interfaz bridge"
  sleep 2
fi

####################################
# EJERCICIO 10                     #
# - Mostrar la nueva IP del bridge #
####################################

ipbridge=$(ssh -i script debian@"$IPMAQUINA1" 'ip a | grep inet | grep enp8s0 | awk "{print \$2}" | sed "s/...$//"')
banner "IP del bridge: $ipbridge"
sleep 2

##################################
# EJERCICIO 11                   #
# - Apagar maquina1              #
# - Aumentar la RAM a 2 GiB      #
# - Volver a arrancar la máquina #
##################################

maxmem=$(virsh -c qemu:///system dominfo maquina1 | grep 'Max memory' | awk '{print $3}')
usedmem=$(virsh -c qemu:///system dominfo maquina1 | grep 'Used memory' | awk '{print $3}')

if [ "$maxmem" -ne 2097152 ] && [ "$usedmem" -ne 2097152 ]; then
  banner "Apagando maquina1"
  virsh -c qemu:///system shutdown maquina1 >/dev/null
  sleep 10
  banner "Aumentando RAM a 2 GiB"
  virsh -c qemu:///system setmaxmem maquina1 2G >/dev/null
  virsh -c qemu:///system setmem maquina1 2G --config >/dev/null
  sleep 2
  banner "Arrancando maquina1"
  virsh -c qemu:///system start maquina1 >/dev/null
  sleep 2
else
  banner "Maquina1 ya tiene 2 GiB de RAM"
  sleep 2
fi

#####################################
# EJERCICIO 12                      #
# - Crear un snapshot de maquina1   #
#####################################

virsh -c qemu:///system snapshot-list maquina1 | grep snapshot1 >/dev/null
existesnapshot=$?

if [ $existesnapshot -ne 0 ]; then
  banner "Apagando maquina1"
  virsh -c qemu:///system shutdown maquina1 >/dev/null
  sleep 10
  banner "Haciendo snapshot"
  virsh -c qemu:///system snapshot-create-as maquina1 --name snapshot1 --description "Configuración terminada" --atomic --disk-only >/dev/null
  sleep 2
else
  banner "Ya se hizo la snapshot"
  sleep 2
fi

###################
# Final de script #
###################

banner "Script completado satisfactoriamente $(printf '\xF0\x9F\x91\x8D') "
