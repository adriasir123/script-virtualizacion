#!/bin/bash
banner() {
  echo "+------------------------------------------+"
  printf "| %-40s |\n" "$(date)"
  echo "|                                          |"
  printf "|$(tput bold) %-40s $(tput sgr0)|\n" "$@"
  echo "+------------------------------------------+"
}

banner "$(printf '\xF0\x9F\x91\xBD')$(printf '\xF0\x9F\x91\xBD')$(printf '\xF0\x9F\x91\xBD') Script de Adrián Jaramillo $(printf '\xF0\x9F\x91\xBD')$(printf '\xF0\x9F\x91\xBD')$(printf '\xF0\x9F\x91\xBD')"
sleep 2

###################
# EJERCICIO 1
# Crear un volumen nuevo, con bullseye-base-sparse.qcow2 como imagen base y tenga 5 GiB de tamaño máximo. Esta imagen se denominará maquina1.qcow2.
###################

if [ ! -f maquina1.qcow2 ]; then
  banner "Creando volumen ligero maquina1.qcow2"
  qemu-img create -f qcow2 -F qcow2 -b bullseye-base-sparse.qcow2 maquina1.qcow2 >/dev/null
  sleep 2
  banner "Redimensionando maquina1.qcow2 a 5G"
  qemu-img resize maquina1.qcow2 5G
  cp maquina1.qcow2 maquina1-copy.qcow2
  virt-resize --expand /dev/vda1 maquina1.qcow2 maquina1-copy.qcow2 >/dev/null
  rm maquina1.qcow2 && mv maquina1-copy.qcow2 maquina1.qcow2
  sleep 2
else
  banner "Ya existe el volumen maquina1.qcow2"
  sleep 2
fi

###################
# EJERCICIO 2
# Crea una red interna de nombre intra con salida al exterior mediante NAT que utilice el direccionamiento 10.10.20.0/24
###################

virsh -c qemu:///system net-list --all | grep intra >/dev/null
existered=$?

if [ $existered -ne 0 ]; then
  banner "Creando la red NAT intra"
  virsh -c qemu:///system net-define intra.xml >/dev/null
  virsh -c qemu:///system net-start intra
  sleep 2
else
  banner "Ya existe la red NAT intra"
  sleep 2
fi

###################
# EJERCICIO 3
# Crea una VM de características:
#   - Nombre: maquina1
#   - Red: intra
#   - RAM: 1 GiB
#   - Disco: maquina1.qcow2
# Luego:
#   - Hacer que se inicie automáticamente
#   - Modificar el hostname a maquina1
###################

virsh -c qemu:///system list --all | grep maquina1 >/dev/null
existemaquina=$?

if [ $existemaquina -ne 0 ]; then
  banner "Creando maquina1"
  virt-install --connect qemu:///system --virt-type kvm --name maquina1 --os-variant debian10 --network network=intra --disk maquina1.qcow2 --import --memory 1024 --vcpus 2 --noautoconsole >/dev/null
  virsh -c qemu:///system autostart maquina1 >/dev/null
  banner "Esperando a que la IP se reconozca"
  sleep 13
  export IPMAQUINA1=$(virsh -c qemu:///system domifaddr maquina1 | grep 10.10.20 | awk '{print $4}' | sed 's/...$//')
  banner "Cambiando el hostname"
  ssh-keyscan $IPMAQUINA1 >>~/.ssh/known_hosts 2>/dev/null
  ssh -i script debian@$IPMAQUINA1 'sudo hostnamectl set-hostname maquina1'
  sleep 2
else
  banner "Ya existe maquina1"
  export IPMAQUINA1=$(virsh -c qemu:///system domifaddr maquina1 | grep 10.10.20 | awk '{print $4}' | sed 's/...$//')
  sleep 2
fi

##########################################
# EJERCICIO 4                            #
# Crear un volumen de características:   #
#   - Pool: default                      #
#   - Tamaño: 1 GiB de tamaño            #
#   - Formato: RAW                       #
##########################################

virsh -c qemu:///system vol-list default | grep adicional.raw >/dev/null
existevolumen=$?

if [ $existevolumen -ne 0 ]; then
  banner "Creando el volumen adicional"
  virsh -c qemu:///system vol-create-as default adicional.raw --format raw 1G >/dev/null
  sleep 2
else
  banner "Ya existe el volumen adicional"
  sleep 2
fi

##########################################
# EJERCICIO 5                            #
# - Conectar el volumen raw a maquina1
# - Formatear como XFS
# - Crear /var/www/html con propietarios www-data
# - Montarlo en /var/www/html
##########################################

ssh -i script debian@$IPMAQUINA1 'lsblk | grep vdb' >/dev/null
rawconectado=$?

if [ $rawconectado -ne 0 ]; then
  banner "Conectando el raw"
  virsh -c qemu:///system attach-disk maquina1 /var/lib/libvirt/images/adicional.raw vdb --driver=qemu --type disk --subdriver raw --persistent >/dev/null
  sleep 2
  banner "Formateando a XFS"
  ssh -i script debian@$IPMAQUINA1 'sudo mkfs.xfs /dev/vdb' >/dev/null
  sleep 2
  banner "Creando /var/www/html"
  ssh -i script debian@$IPMAQUINA1 'sudo mkdir -p /var/www/html'
  sleep 2
  banner "Modificando propietarios"
  ssh -i script debian@$IPMAQUINA1 'sudo chown -R www-data:www-data /var/www'
  sleep 2
  banner "Montando el raw"
  ssh -i script debian@$IPMAQUINA1 'sudo mount -t xfs /dev/vdb /var/www/html'
  sleep 2
else
  banner "Ya está el raw conectado"
  sleep 2
fi

##########################################
# EJERCICIO 6                            #
# Instala en maquina1 el servidor web apache2
# Copia un fichero index.html a la máquina virtual.
##########################################

existeapache=$(ssh -i script debian@$IPMAQUINA1 'apt-cache policy apache2 | grep Installed | awk "{print \$2}"')

if [ "$existeapache" == "(none)" ]; then
  banner "Instalando apache2"
  ssh -i script debian@$IPMAQUINA1 'sudo apt-get install apache2'
  sleep 2
  banner "Pasando index.html"
  scp -i script index.html debian@$IPMAQUINA1:/home/debian
  ssh -i script debian@$IPMAQUINA1 'sudo mv /home/debian/index.html /var/www/html/index.html'
  sleep 2
else
  banner "Apache ya está instalado"
  sleep 2
fi
