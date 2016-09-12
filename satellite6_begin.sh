#!/bin/bash
#### SCRIPT PARA AJUSTE DE NOMENCLATURA DE INTERFACE {CENTOS,RHEL}7 PARA ethX E REGISTRO NO SATELLITE6/KATELLO  
#### SCRIPT COM VERIFICAÇÃO SE O HOST JÁ ESTÁ INGRESSADO NO SATELLITE6/KATELLO E NO SUBSCRITO NO PUPPET

#VARIAVEIS
IFACE=`ip link |grep eth0 |awk '{print$2}'| awk -F':' '{print $1}' |sed s/[0-9]/\ /g`
ETHX=`ip link |grep eth0 |awk '{print$2}'| awk -F':' '{print $1}'`
SO=`cat /etc/redhat-release |awk '{ print $1}'`
DOMAIN='SUPERINTEROP.COM.BR'
GW='192.168.1.1'
NETMASK='23'
DNS1='192.168.1.14'
DNS2='192.168.1.15'
SAT_SERVER='katello.interop.com.br'
ORG_DEFAULT='Default_Organization'
AK_SAT='CentOS7'

get_hostname(){
  echo -n "Entre com um hostname válido sem o domínio (trf4.jus.br) e com no máximo 15 caracteres [`hostname -s`]: "
  read HOSTNAME

   if [[ -n $HOSTNAME ]]; then
    echo -e " \033[0;33m Hostname server alterado para: $HOSTNAME.${DOMAIN} \033[0m"
    NEWHOSTNAME=$HOSTNAME.${DOMAIN}
    sleep 2
    hostnamectl set-hostname $NEWHOSTNAME
    echo -e " \033[1;32m Alteração executada com sucesso \033[0m"

   else
     echo -e " \033[0;33m Hostname será mantido o atual `hostname`\033[0m"
     NEWHOSTNAME=`hostname`
   fi
}

get_ip(){
  echo -n "Entre com um IP válido (ex. 10.1.X.X), depois pressione ENTER [$OLDIP]: "
  read NEWIP

    if [[ "$NEWIP" =~ ^10{1,2}\.1\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e " \033[0;33m Alterando o IP address de $ETHX para $NEWIP \033[0m" 
    sleep 2
    nmcli con mod $ETHX ipv4.method manual ipv4.addresses $NEWIP\/${NETMASK} ipv4.gateway ${GW} ipv4.dns ${DNS1},${DNS2} ipv4.dns-search ${DOMAIN}
    nmcli con up $ETHX
    systemctl restart NetworkManager
    echo -e " \033[1;32m Alteração executada com sucesso \033[0m"

    else
      OLDIP=`nmcli con show eth0 |grep ipv4.addresses |awk '{print $2}' |awk -F'/' '{print $1}'`
      echo -e " \033[0;33m Mantendo o mesmo IP $OLDIP \033[0m"
    fi   
}

get_yes(){
  echo -e " \033[1;33m Você tem certeza? (yes|no): \033[0m"
  echo -n ""
  read READY
}

get_passwd(){

  echo -e "Digite a nova senha (A mudança é irreversível):" 
  read -s NEWPASSWD

   if [[ -n $NEWPASSWD ]]; then
     get_casepasswd
   else
     echo -e " \033[0;31m Senha não pode ser nula ou vazia. \033[0m"
     get_passwd
   fi
}

get_casepasswd(){
  get_yes
  case $READY in
    yes|YES)
       echo -e "\033[1;32m"
       echo $NEWPASSWD | passwd --stdin root
       echo -e "\033[0m"
       ;;
    no|NO)
       echo -e " \033[1;33m Digite a senha novamente.\033[0m"
       get_passwd
       ;;
    *)
       echo -e " \033[0;31m Por Favor use YES ou NO.\033[0m"
       get_casepasswd
       ;;
  esac
}

get_so(){

  case $SO in 
    CentOS)
    echo -e " \033[1;32m O Sistema Operacional é: \033[1;34m `cat /etc/redhat-release` \033[0m"
    echo -e " \033[1;32m Pre Configuração do S.O. \033[0m"
    get_centosinstall
    ;;
    Red)
    echo -e " \033[1;32m O Sistema Operacional é: \033[1;31m `cat /etc/redhat-release` \033[0m"
    echo -e " \033[1;32m Pre Configuração do S.O. \033[0m"
    get_validsubscription
    ;;
    *)
    echo -e " \033[0;31m S.O não suportado pelo script.\033[0m"
    exit 0
    ;;
  esac
}

get_centosinstall(){
  
: ' CASO USE PROXY SETAR ABAIXO.
  echo "proxy=http://proxy.server:3128/" >> /etc/yum.conf
  echo "proxy_username=user" >> /etc/yum.conf
  echo "proxy_password=pass" >> /etc/yum.conf 
'

  yum install -y subscription-manager
  sed -i /proxy.*/d /etc/yum.conf
  mkdir /etc/yum.repos.d/old
  mv /etc/yum.repos.d/Cent* /etc/yum.repos.d/old
  yum clean all
  get_validsubscription

}

get_validsubscription(){

  echo -e " \033[1;33m Verificando subscrição no Satellite 6 \033[0m"

  if subscription-manager status |grep -E "Overall Status: Current" &> /dev/null; then
    echo -e " \033[1;33m Sistema já subscrito ao Satellite 6 \033[0m"
    echo -e " \033[1;33m Realizando o clean da subscrição antiga.\033[0m"
    subscription-manager clean
    get_subscription
  else
    get_subscription
  fi

}

get_subscription(){

  rpm -Uvh http://${SAT_SERVER}/pub/katello-ca-consumer-latest.noarch.rpm > /dev/null 2> /dev/null
  echo -e " \033[1;33m Registrando Máquina [1;33mno Satellite: \033[0m"
  subscription-manager register  --org="${ORG_DEFAULT}" --activationkey="${AK_SAT}"

  get_validpuppet

}

get_validpuppet(){

  echo -e " \033[1;33m Verificando subscrição puppet no Satellite 6 \033[0m"

  if rpm -qa |grep -i puppet &> /dev/null; then

    echo -e " \033[1;33m Sistema já subscrito no puppet do Satellite 6 \033[0m"
    echo -e " \033[1;33m Realizando o clean da subscrição puppet no Satellite 6.\033[0m"

     test -f /var/lib/puppet/ssl/certs/$HOSTNAME.pem 
       if [[ $? = 0 ]]; then 
         rm -rf /var/lib/puppet/ssl
       fi
     get_puppet

  else
    get_puppet
  fi
   
}

get_puppet(){

  echo -e " \033[1;32m Instalando, habilitando e inicializando Puppet ... \033[0m"
  yum install katello-agent puppet -y

  systemctl start puppet goferd 2> /dev/null
  systemctl enable puppet goferd 2> /dev/null

  echo -e " \033[1;32m Executando Puppet pela primeira vez ... \033[0m"
  echo -e " \033[1;32m Não esqueça de aceitar o certificado no Satellite. \033[0m"
  puppet config set server ${SAT_SERVER} --section agent
  puppet config set hostname $NEWHOSTNAME --section agent
  #FOR DEBUG 
  #puppet config print
}

get_grub(){

  NEWGRUB=`cat /etc/default/grub |grep GRUB_CMDLINE_LINUX |cut -f2-  -d'=' |sed 's/"//g' | awk '{print "\"" $0 " net.ifnames=0 biosdevname=0\" "}'`
  echo -e " \033[1;33m Ajustando no grub o nome das interfaces.\033[0m"
  sed -i /GRUB_CMDLINE_LINUX.*/d /etc/default/grub
  echo GRUB_CMDLINE_LINUX\=$NEWGRUB >> /etc/default/grub  

}

get_reboot(){

  grub2-mkconfig -o /boot/grub2/grub.cfg > /dev/null 2> /dev/null

  IFACE_OLD=`ip link |awk '{print $2}' |grep 'eno' | awk -F':' '{print $1}'| head -n1`

  echo -e " \033[1;33m Finalizando Serviço de DHCLIENT.\033[0m"
  kill -9 $(pidof dhclient) 2> /dev/null

  echo -e " \033[1;33m Habilitando auto connect na interface.\033[0m"
  nmcli con mod $IFACE_OLD connection.autoconnect yes
  cp /etc/sysconfig/network-scripts/ifcfg-$IFACE_OLD /root 2> /dev/null
  sed -i s/$IFACE_OLD/eth0/g /etc/sysconfig/network-scripts/ifcfg-$IFACE_OLD 2> /dev/null
  mv /etc/sysconfig/network-scripts/ifcfg-$IFACE_OLD /etc/sysconfig/network-scripts/ifcfg-eth0 2> /dev/null
  rm -f /etc/sysconfig/network-scripts/ifcfg-$IFACE_OLD* 2> /dev/null
  sed -i s/ONBOOT=.*/ONBOOT=\"yes\"/g /etc/sysconfig/network-scripts/ifcfg-eth0 2> /dev/null

  sleep 1
  echo -e " \033[1;33m Server rebootando para aplicar a nova interface.\033[0m"
  echo -e "\033[0;31m"
  echo 'Servidor rebootando em 5'
  sleep 1
  echo 'Servidor rebootando em 4'
  sleep 1
  echo 'Servidor rebootando em 3'
  sleep 1
  echo 'Servidor rebootando em 2'
  sleep 1
  echo 'Servidor rebootando em 1'
  sleep 1
  echo -e "\033[0m"

  reboot

}

#INICIANDO O SCRIPT

if [ $IFACE == 'eth' ] 2> /dev/null ;then
  
  echo -e " \033[1;33m Interface está padrão: $ETHX\033[0m"
  get_hostname
  get_ip
  get_passwd
  get_so

  echo -e " \033[1;33m Esta máquina está sendo rebootada e subirá com o novo IP configurado: $NEWIP \033[0m"
  reboot 
  sleep 10

else 	

  echo -e " \033[1;33m Vamos ajustar as interfaces.\033[0m"

  grep 'net.ifnames=0 biosdevname=0'  /etc/default/grub > /dev/null 2> /dev/null
  if [ $? -eq 1 ];then
    get_grub
    get_reboot
  else
    get_reboot
  fi

fi
