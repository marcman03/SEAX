#!/bin/bash
#librerias necesarias:
# apt install lsb-release
# apt install wget
# apt instal whois
# apt install mtr
# apt install ipcalc
clear

if [[ "$1" == "-d" ]]; then
    # Instalar paquetes necesarios
    apt update
    apt install -y lsb-release wget whois mtr ipcalc
fi

mostrar_ayuda() {
    echo "Este script se utilitza para analizar las interficies de tu ordenador y genera un informe."
    echo ""
    echo "Es necesario descargar los siguientes paquetes:"
    echo ""
    echo "apt install lsb-release"
    echo "apt install wget"
    echo "apt instal whois"
    echo "apt install mtr"
    echo "apt install ipcalc"
    echo ""
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda y salir"
    echo "  -d             Ejecutar el script instalando los paquetes necesarios"
    echo ""
    echo ""
    exit 0
}

# Comprobar si se proporcionó la opción de ayuda
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mostrar_ayuda
fi

#Elimina el archivo si existe
if [ -f "log_inet.log" ]; then
    rm log_inet.log
fi
# Crear el archivo log_inet.log en la ruta actual
touch log_inet.log

# Asignar las llamadas del sistema a variables
usuario=$(whoami)
equipo=$(hostname)
sistema_operativo=$(lsb_release -ds)
version_script="version 1.1"
fecha_compilacion=$(date -r "$0" '+%d/%m/%Y')
fecha_inicio=$(date '+%Y-%m-%d')
hora_inicio=$(date '+%H:%M:%S')


# Esta función convierte una máscara CIDR en una máscara de subred
cidr_to_subnet() {
    # Se calcula la máscara de subred utilizando el CIDR pasado como argumento
    local mask=$(( 0xffffffff ^ ((1 << (32 - $1)) - 1) ))
    # Se formatea la máscara de subred en formato de dirección IP con cuatro octetos separados por puntos
    printf "%d.%d.%d.%d\n" $(($mask >> 24 & 255)) $(($mask >> 16 & 255)) $(($mask >> 8 & 255)) $(($mask & 255))
}

# Esta función convierte una dirección IP en su dirección de broadcast correspondiente
function convertir_a_broadcast() {
  # Se obtiene la dirección IP como argumento de la función
  ip_address=$1

  # Validar la entrada para asegurarse de que la dirección IP sea válida
  if ! [[ "$ip_address" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    echo "Error: Dirección IP no válida: $ip_address" >&2
    return 1
  fi

  # Convertir la dirección IP en una lista de octetos separados por espacio
  octetos=$(echo "$ip_address" | tr '.' ' ')

  # Reemplazar los octetos diferentes de 255 por 0 para obtener la dirección de broadcast
  broadcast_address=$(echo "$octetos" | awk '{
    for (i=1; i<=NF; i++) {
      if ($i != 255) {
        printf "0."
      } else {
        printf "%s.", $i
      }
    }
  }')

  # Eliminar el último punto de la dirección de broadcast
  broadcast_address="${broadcast_address::-1}"

  # Imprimir la dirección de broadcast resultante
  echo "$broadcast_address"
}


echo " ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════════  " >> log_inet.log
echo " ║                                                                                                             " >> log_inet.log
echo " ║  ---------------------------------------------------------------------------------------------------------  " >> log_inet.log
echo " ║  Analisi de les interficies del sistema realitzada per l'usuari $usuario de l'equip $equipo.                " >> log_inet.log
echo " ║  Sistema operatiu $sistema_operativo.                                                                       " >> log_inet.log
echo " ║  Versió del script $version_script compilada el $fecha_compilacion.                                         " >> log_inet.log
echo " ║  Analisi iniciada en data $fecha_inicio a les $hora_inicio"                                                  >> log_inet.log
echo " ║  ---------------------------------------------------------------------------------------------------------  " >> log_inet.log
echo " ║                                                                                                             " >> log_inet.log
echo " ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════════  " >> log_inet.log
echo "" >> log_inet.log
echo "" >> log_inet.log

# Leer la salida del comando 'ip -br link show' y asignarla a la variable interfaces
# Almacenar la salida del comando en una variable
interfaces=$(ip -br link show | awk '{printf $1 " "}')

# Convertir la cadena en una lista separada por espacios
read -r -a interfaces_array <<< "$interfaces"

# Recorremos todas las interfaces
for interface in "${interfaces_array[@]}"; do    
  # Verificar si la interfaz es "lo" (loopback)
      #----------------------------------------------------------------------------------------------
    nombre_original=$(ip link show "$interface" | grep altname | awk  '{print $2}')
    # Estado de la interfície
    nombre_actual=$(ip -s link show "$interface" | awk '/state/ {print $2}')
    nombre_actual="${nombre_actual%?}"
    if [ -z "$nombre_original" ]; then
        nombre_original="$nombre_actual"
    fi
    #echo "$nombre_original"
    # obtenemos al fabricante
    manufacturer=$(udevadm info /sys/class/net/$interface | grep ID_VENDOR_FROM | cut -d '=' -f2-)

    #----------------------------------------------------------------------------------------------

    #obtenemos la mac
    mac_address=$(ip link show "$interface" | grep link | awk '{print $2}') 
    #----------------------------------------------------------------------------------------------
    #Para saber si UP/DOWN/UNKNOWN
    link_info=$( ip -brief link show "$interface" | awk '{print $2}')

    #Encontramos la linea con la informacion de la interfaz simplificada con el brief i hemos cojido la ultima palabra del comando que sera LOWER_UP 
    #en el caso de que la interficie este conectada i saldra otra palabra si no esta conectada
    lower_info=$(ip -brief link show "$interface" | awk '{print $4}' | awk -F ',' '{print $NF}' | cut -d ">" -f 1)
    if [ "$link_info" = "UNKNOWN" ]&& [ "$lower_info" = "LOWER_UP" ]; then
      responent=" (responent...)"
    elif [ "$link_info" = "UP" ]&& [ "$lower_info" = "LOWER_UP" ]; then
      responent=" (responent...)"
    
    #Hemos supuesto si la interfaz esta conectada por el cable pero desactivada entonces esta respondiendo pero sin señal
    elif [ "$link_info" = "DOWN" ] && [ "$lower_info" = "LOWER_UP" ]; then
      responent=" (responent... sense senyal)"
    else

    #el el caso donde no este conectada por cable, aunque este UP la interficie, no estara respondiendo
      responent=" (no responent...)"
    fi
    #----------------------------------------------------------------------------------------------
    #obtenemos el mtu
    mtu=$(ip link show "$interface" | awk '/mtu/ {print $5}')
    #----------------------------------------------------------------------------------------------
    #obtenemos que tipo de adreçament
    if [ -f "/var/lib/dhcp/dhclient.$nombre_original.leases" ]; then
      serverdhcp=$(cat /var/lib/dhcp/dhclient.$nombre_original.leases | grep dhcp-server | head -n 1 | awk '{print $3}' | cut -d ";" -f 1)
      adrecament="dinàmic (DHCP $serverdhcp)"
    else
      adrecament=$(grep "$nombre_original inet" /etc/network/interfaces | awk '{print $4}')
      if [ -n "$adrecament" ]; then
        adrecament="$adrecament (fitxer /etc/network/interfaces)"
      else
        adrecament=$(ip addr show "$interface" | grep "inet " | awk '{print $7}')
        echo "dentro $adrecament"
        if [ -n "$adrecament" ] && [ "$adrecament" != "dynamic" ]; then

          adrecament="estàtic (des de consola)"
        fi
      fi
    fi
    #----------------------------------------------------------------------------------------------
    if [ -n "$adrecament" ]; then
      #obtenemso la ip i la mascara
      ip_mask=$(ip address show "$interface" | grep -E "inet\b" | awk '{print $2}')
      #----------------------------------------------------------------------------------------------
      #dejamos la ip sola sin la mascara
      ip_sola=$(echo $ip_mask | cut -d '/' -f1)
      #----------------------------------------------------------------------------------------------
      #dejamos el numero de la mascara
      cidr=$(echo $ip_mask | cut -d'/' -f2)
      #----------------------------------------------------------------------------------------------
      #pasamos de numero de mascara a ip de la mascara
      subnet_mask=$(cidr_to_subnet $cidr)
      #----------------------------------------------------------------------------------------------
      #obtenemos la adreça de la xarxa
      #adreca_xarxa=$(whois "${ip_sola}" | grep NetRange | awk '{printf $2}')
      adreca_xarxa=$(ipcalc $ip_mask | grep "Network" | awk '{print $2}')
      #----------------------------------------------------------------------------------------------
      #obtenemos la adreça del broadcast 
      #broadcast=$(whois "${ip_sola}" | grep NetRange | awk '{printf $4}')
      broadcast=$(ipcalc $ip_mask | grep "Broadcast" | awk '{print $2}')
      #----------------------------------------------------------------------------------------------
      nextadreca=$(ipcalc $ip_mask | grep "HostMin" | awk '{print $2}')
      previousadreca=$(ipcalc $ip_mask | grep "HostMax" | awk '{print $2}')
      #----------------------------------------------------------------------------------------------
      #quitamos los numeros que no sean 255
      normalized_broadcast=$(convertir_a_broadcast "$broadcast")
      #----------------------------------------------------------------------------------------------
      #obtenemos el gateway por defecto
      gatewayd=$(ip route | grep default | awk '{printf $3}')
      #----------------------------------------------------------------------------------------------
      #obtenemos el nombre dns
      dns=$(dig +short -x $ip_sola)
      #----------------------------------------------------------------------------------------------
      #optenemos el output entero de la informacion de la interfaz

    else 
    #obtenemso la ip i la mascara
      ip_mask=""
      #----------------------------------------------------------------------------------------------
      #dejamos la ip sola sin la mascara
      ip_sola=""
      #----------------------------------------------------------------------------------------------
      #dejamos el numero de la mascara
      cidr=""
      #----------------------------------------------------------------------------------------------
      #pasamos de numero de mascara a ip de la mascara
      subnet_mask=""
      #----------------------------------------------------------------------------------------------
      #obtenemos la adreça de la xarxa
      adreca_xarxa=""
      #----------------------------------------------------------------------------------------------
      #obtenemos la adreça del broadcast 
      broadcast=""
      #----------------------------------------------------------------------------------------------
      #quitamos los numeros que no sean 255
      normalized_broadcast=""
      #----------------------------------------------------------------------------------------------
      #obtenemos el gateway por defecto
      gatewayd=""
      #----------------------------------------------------------------------------------------------
      #----------------------------------------------------------------------------------------------
      #obtenemos el nombre dns
      dns=""
      #----------------------------------------------------------------------------------------------
      #optenemos el output entero de la informacion de la interfaz
      nextadreca=""
      previousadreca=""


    fi

    output=$(ip -s link show "$interface")
    #obtenemos los bytes recibidos
    bytes_recibidos=$(echo "$output" | awk '/RX:/{getline; print $1}')
    #obtenemos los bytes enviados
    bytes_enviados=$(echo "$output" | awk '/TX:/{getline; print $1}')
    # Extraer el número de paquetes recibidos y enviados
    paquetes_recibidos=$(echo "$output" | awk '/RX:/{getline; print $2}')
    paquetes_enviados=$(echo "$output" | awk '/TX:/{getline; print $2}')
    #Obtenemos los paquetes con errores enviados y recibidos
    errores_recibidos=$(echo "$output" | awk '/RX:/{getline; print $3}')
    errores_enviados=$(echo "$output" | awk '/TX:/{getline; print $3}')

    #obtenemos los paquetes que fallan enviados y recibidos
    miss_recibidos=$(echo "$output" | awk '/RX:/{getline; print $3}')
    miss_enviados=$(echo "$output" | awk '/TX:/{getline; print $3}')

    #obtenemos los paquetes descartados y colisionados
    loss_recibidos=$(echo "$output" | awk '/RX:/{getline; print $4}')
    col_enviados=$(echo "$output" | awk '/TX:/{getline; print $4}')
      
    #----------------------------------------------------------------------------------------------

    # Esperar 1 segundo 
    sleep 1
    # Obtener las estadísticas nuevamente después de 1 segundo
    output_final=$(ip -s link show "$interface")
    # Extraer los bytes y paquetes recibidos y enviados en el segundo instante de tiempo
    bytes_recibidos_final=$(echo "$output_final" | awk '/RX:/{getline; print $1}')
    bytes_enviados_final=$(echo "$output_final" | awk '/TX:/{getline; print $1}')
    paquetes_recibidos_final=$(echo "$output_final" | awk '/RX:/{getline; print $2}')
    paquetes_enviados_final=$(echo "$output_final" | awk '/TX:/{getline; print $2}')
    # Calcular la diferencia de bytes y paquetes recibidos y enviados entre los dos instantes de tiempo
    diferencia_bytes_recibidos=$((bytes_recibidos_final - bytes_recibidos))
    diferencia_bytes_enviados=$((bytes_enviados_final - bytes_enviados))
    diferencia_paquetes_recibidos=$((paquetes_recibidos_final - paquetes_recibidos))
    diferencia_paquetes_enviados=$((paquetes_enviados_final - paquetes_enviados))
    #----------------------------------------------------------------------------------------------  
    
    if [[ "$nombre_original" == "lo" ]]; then 

        echo " ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────" >> log_inet.log
        echo " │                                                                                             " >> log_inet.log
        echo " │  ---------------------------------------------------------------------------------------------------------" >> log_inet.log
        echo " │                               Configuració de la interfície $interface.                     " >> log_inet.log
        echo " │  ---------------------------------------------------------------------------------------------------------" >> log_inet.log  
        echo " │  Interfície:                 $interface" >> log_inet.log
        echo " │  Fabricant:                  ${manufacturer:--}                                                            " >> log_inet.log
        echo " │  Adreça MAC:                 ${mac_address:--}">> log_inet.log
        echo " │  Estat de la interfície:     ${link_info:--} ${responent:-}" >> log_inet.log
        echo " │  Mode de la interfície:      normal, amb mtu ${mtu:--}" >> log_inet.log
        echo " |" >> log_inet.log 
        echo " |  Adrecament:                 ${adrecament} "  >> log_inet.log
        echo " |  Adreça IP / màscara:        ${ip_mask} ( ${ip_sola} ${subnet_mask})" >> log_inet.log
        echo " │  Adreça de xarxa:            ${adreca_xarxa} (${nextadreca:-} - ${previousadreca:-})" >> log_inet.log
        echo " |  Adreça broadcast:           ${broadcast:--} ($normalized_broadcast)" >> log_inet.log
        echo " |  Gateway per defecte:        ${gatewayd}" >> log_inet.log
        echo " │  Nom DNS:                    localhost.                                        ">> log_inet.log
        echo " │                                                                            " >> log_inet.log
        echo " │  Tràfic rebut:               ${bytes_recibidos}  bytes  [${paquetes_recibidos}  paquets] (${errores_recibidos} errors, ${miss_recibidos} descartats i ${loss_recibidos} perduts)" >> log_inet.log
        echo " │  Tràfic transmès:            ${bytes_enviados}   bytes  [${paquetes_enviados}   paquets] (${errores_enviados} errors, ${miss_enviados} descartats i ${col_enviados} colisions)">> log_inet.log
        echo " │  Velocitat de Recepció:      $diferencia_bytes_recibidos bytes/s [$diferencia_paquetes_recibidos paquetes/s]" >> log_inet.log
        echo " │  Velocitat de Transmissió:   $diferencia_bytes_enviados bytes/s [$diferencia_paquetes_enviados paquetes/s]" >> log_inet.log
        echo " │  -----------------------------------------------------------------------------------------  " >> log_inet.log                                                                                                              
        echo " └─────────────────────────────────────────────────────────────────────────────────────────────" >> log_inet.log
        echo "" >> log_inet.log
        echo "" >> log_inet.log

#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------    
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------    
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    elif [[ "${nombre_original:0:3}" == "enp" ]]; then
        
        #----------------------------------------------------------------------------------------------
        #obtenemos la ip publica que nos la dan desde el exterior 
        ip_publica=$(wget -qO- https://ifconfig.me/ip)
        domini=$(dig +short -x $ip_publica)
                
        #----------------------------------------------------------------------------------------------
        #deteccio NAT: si la ip publica es diferente a la ip de la interficie significa que hay una nat
        if [ "$ip_publica" != "$ip_sola" ]; then
          routers=$(mtr -r $ip_publica | grep . | tail -n 1 | awk -F "." '{print $1}')
          routers=$((routers - 1))
          nat_detectat="NAT detectat, $routers router involucrat [$ip_publica ($domini)]"

        else
          nat_detectat="NAT no detectat"
        fi

        #----------------------------------------------------------------------------------------------
        #obtenemos el nombre de la xarxa entitat
        xentitat=$(whois "${ip_publica}" | grep netname | awk '{printf $2}')
        xroute=$(whois "${ip_publica}" | grep route | awk '{printf $2}')
        #obtenemso el rango de adreces
        range=$(whois "${ip_publica}" | grep inetnum | awk '{printf $2 $3 $4}')

        #----------------------------------------------------------------------------------------------

        propietari=$(whois "${ip_publica}" | grep descr | head -n 1 | cut -d ' ' -f2- |  sed 's/ \+/ /g')
        country=$(whois "${ip_publica}" |  grep country | awk '{printf $2}')
        #Veure si existeixen rutes involucrades
        rutas_in=$(ip route | grep "$interface")

        #----------------------------------------------------------------------------------------------

        echo " ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────── " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log
        echo " │  --------------------------------------------------------------------------------------------------------- " >> log_inet.log
        echo " │                               Configuració de la interfície $interface.                                    " >> log_inet.log
        echo " │  --------------------------------------------------------------------------------------------------------- " >> log_inet.log
        echo " │  Interfície:                 ${nombre_actual:--} [${nombre_original:-N/A}]                                 " >> log_inet.log
        echo " │  Fabricant:                  ${manufacturer:--}                                                            " >> log_inet.log
        echo " │  Adreça MAC:                 ${mac_address:--}                                                             " >> log_inet.log
        echo " │  Estat de la interfície:     ${link_info:--} ${responent:-}                                                              " >> log_inet.log
        echo " │  Mode de la interfície:      normal, amb mtu ${mtu:--}                                                     " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log
        echo " │  Adrecament:                 ${adrecament:-"No configurat"}                                  " >> log_inet.log
        if [ -n "$ip_mask" ]; then
          echo " │  Adreça IP / màscara:        ${ip_mask:--} ( ${ip_sola:-} ${subnet_mask:-})                                     " >> log_inet.log
        else 
          echo " | Adreça IP / màscara:         -" >>log_inet.log
        fi
        if [ -n "$adreca_xarxa" ]; then
          echo " │  Adreça de xarxa:            ${adreca_xarxa:--} (${nextadreca:-} - ${previousadreca:-})" >> log_inet.log
        else 
          echo " |  Adreça de xarxa:            -" >>log_inet.log
        fi
        if [ -n "$broadcast" ]; then
          echo " │  Adreça broadcast:           ${broadcast:--} ($normalized_broadcast)                                        " >> log_inet.log
        else
          echo " |  Adreça broadcast:           -" >>log_inet.log
        fi
        echo " │  Gateway per defecte:        ${gatewayd:--}                                                                 " >> log_inet.log
        echo " │  Nom DNS:                    ${dns:--}                                                                      " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log 
        echo " │  Adreça IP pública:          ${ip_publica:--}[${domini:--}]                                                  " >> log_inet.log
        echo " │  Detecció de NAT:            ${nat_detectat}                                                                                  " >> log_inet.log
        echo " │  Nom del domini:             ${domini:--}                                                                       " >> log_inet.log
        echo " │  Xarxes de l'entitat:        ${xentitat} ${xroute} (${range:--})                                             " >> log_inet.log
        echo " │  Entitat propietària:        ${propietari} [$country]                                                        " >> log_inet.log
        if [ -n "$rutas_in" ]; then 
          isFirstLine=true
          while IFS= read -r line; do
            if [ -n "$line" ]; then
              if [ "$isFirstLine" = true ]; then
                echo " │                              " >> log_inet.log 
                echo " │  Rutas involucradas:         ${line}" >> log_inet.log
                isFirstLine=false
              else
                echo " |                              ${line}" >> log_inet.log
              fi
            fi
          done <<< "$rutas_in"
        fi
        echo " │                                                                                                            " >> log_inet.log
        echo " │  Tràfic rebut:               ${bytes_recibidos}  bytes  [${paquetes_recibidos}  paquets] (${errores_recibidos} errors, ${miss_recibidos} descartats i ${loss_recibidos} perduts) " >> log_inet.log
        echo " │  Tràfic transmès:            ${bytes_enviados}   bytes  [${paquetes_enviados}   paquets] (${errores_enviados} errors, ${miss_enviados} descartats i ${col_enviados} colisions)   " >> log_inet.log
        echo " │  Velocitat de Recepció:      $diferencia_bytes_recibidos bytes/s [$diferencia_paquetes_recibidos paquetes/s] " >> log_inet.log
        echo " │  Velocitat de Transmissió:   $diferencia_bytes_enviados bytes/s [$diferencia_paquetes_enviados paquetes/s]   " >> log_inet.log
        echo " │  -----------------------------------------------------------------------------------------                 " >> log_inet.log                                                                                                               
        echo " │                                                                                                            " >> log_inet.log
        echo " └─────────────────────────────────────────────────────────────────────────────────────────────               " >> log_inet.log
        echo "" >> log_inet.log
        echo "" >> log_inet.log

#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    elif [[ "${nombre_original:0:2}" == "wl" ]]; then        
        #----------------------------------------------------------------------------------------------
        #obtenemos la ip publica que nos la dan desde el exterior 
        ip_publica=$(wget -qO- https://ifconfig.me/ip)
        domini=$(dig +short -x $ip_publica)
                
        #----------------------------------------------------------------------------------------------
        #deteccio NAT: si la ip publica es diferente a la ip de la interficie significa que hay una nat
        if [ "$ip_publica" != "$ip_sola" ]; then
          routers=$(mtr -r $ip_publica | grep . | tail -n 1 | awk -F "." '{print $1}')
          routers=$((routers - 1))
          nat_detectat="NAT detectat, $routers router involucrat [$ip_publica ($domini)]"

        else
          nat_detectat="NAT no detectat"
        fi

        #----------------------------------------------------------------------------------------------
        disp_wifi=phy$(iw dev $interface info | grep "phy" | awk '{print $2}') 
        mode_treball_wifi=$(iw dev | grep "type"| awk '{print $2}')
        potencia_wifi=$(iw dev | grep "txpower" | awk '{print $2 " " $3}')
        #----------------------------------------------------------------------------------------------


        #----------------------------------------------------------------------------------------------
        #obtenemos el nombre de la xarxa entitat
        xentitat=$(whois "${ip_publica}" | grep netname | awk '{printf $2}')
        xroute=$(whois "${ip_publica}" | grep route | awk '{printf $2}')
        #obtenemso el rango de adreces
        range=$(whois "${ip_publica}" | grep inetnum | awk '{printf $2 $3 $4}')

        #----------------------------------------------------------------------------------------------

        propietari=$(whois "${ip_publica}" | grep descr | head -n 1 | cut -d ' ' -f2- |  sed 's/ \+/ /g')
        country=$(whois "${ip_publica}" |  grep country | awk '{printf $2}')
        rutas_in=$(ip route | grep "$interface")

        #----------------------------------------------------------------------------------------------

        echo " ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────── " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log
        echo " │  --------------------------------------------------------------------------------------------------------- " >> log_inet.log
        echo " │                               Configuració de la interfície $interface.                                    " >> log_inet.log
        echo " │  --------------------------------------------------------------------------------------------------------- " >> log_inet.log
        echo " │  Interfície:                 ${nombre_actual:--} [${nombre_original:-N/A}]                                 " >> log_inet.log
        echo " │  Fabricant:                  ${manufacturer:--}                                                            " >> log_inet.log
        echo " │  Adreça MAC:                 ${mac_address:--}                                                             " >> log_inet.log
        echo " │  Estat de la interfície:     ${link_info:--} ${responent:-}                                                              " >> log_inet.log
        echo " │  Mode de la interfície:      normal, amb mtu ${mtu:--}                                                     " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log
        echo " │  Dispositiu Wi-Fi:           ${disp_wifi}                                                                  " >> log_inet.log
        echo " │  Mode de treball:            ${mode_treball_wifi:--}                                                       " >> log_inet.log
        echo " │  Potència de transmissió:    ${potencia_wifi:--}                                                           " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log
        conn_wifi=$(iw dev $interface link | grep "Not connected")
        if [ "$conn_wifi" = "Not cnnected" ]; then  
          echo " │  Connexió a xarxa:           No associat" >> log_inet.log
        else
          #------------------------------------------------------------------------------------------------------
          ssid_wifi=$(iw dev $interface link | grep "SSID" | awk '{print $2 " " $3}')
          canal_treball_wifi=$(iw dev $interface info | grep "channel" | awk '{print $2 " " $3 $4}'| cut -d ',' -f 1) 
          senyal_wifi=$(iw dev $interface info | grep "txpower" | awk '{print $2 " " $3}')
          punt_acces_wifi=$(iw dev $interface link | grep "Connected to" | awk '{print $3}')
          vel_wifi_rec=$(iw dev $interface link | grep "rx bitrate:" | awk '{print $3 " " $4}')
          vel_wifi_trans=$(iw dev $interface link | grep "tx bitrate:" | awk '{print $3 " " $4}')
          #------------------------------------------------------------------------------------------------------
          echo " │  SSID de la xarxa:           ${ssid_wifi}                                                           " >> log_inet.log
          echo " │  Canal de treball:           ${canal_treball_wifi}                          " >> log_inet.log
          echo " │  Nivell de senyal:           ${senyal_wifi}                                                           " >> log_inet.log
          echo " │  Punt d'accés associat:      ${punt_acces_wifi}                                                           " >> log_inet.log
          echo " │  Vel. Wi-Fi Recepció:        ${vel_wifi_rec}                                                           " >> log_inet.log
          echo " │  Vel. Wi-Fi Transmissió:     ${vel_wifi_trans}                                                           " >> log_inet.log
        fi
        echo " │                                                                                                            " >> log_inet.log
        echo " │  Adrecament:                 ${adrecament:-"No configurat"}                                  " >> log_inet.log
        if [ -n "$ip_mask" ]; then
          echo " │  Adreça IP / màscara:        ${ip_mask:--} ( ${ip_sola:-} ${subnet_mask:-})                                     " >> log_inet.log
        else 
          echo " | Adreça IP / màscara:         -                                                                    " >>log_inet.log
        fi
        if [ -n "$adreca_xarxa" ]; then
          echo " │  Adreça de xarxa:            ${adreca_xarxa:--} (${nextadreca:-} - ${previousadreca:-})" >> log_inet.log
        else 
          echo " |  Adreça de xarxa:            -" >>log_inet.log
        fi
        if [ -n "$broadcast" ]; then
          echo " │  Adreça broadcast:           ${broadcast:--} ($normalized_broadcast)                                        " >> log_inet.log
        else
          echo " |  Adreça broadcast:           -" >>log_inet.log
        fi
        echo " │  Gateway per defecte:        ${gatewayd:--}                                                                 " >> log_inet.log
        echo " │  Nom DNS:                    ${dns:--}                                                                      " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log 
        echo " │  Adreça IP pública:          ${ip_publica:--}[${domini:--}]                                                  " >> log_inet.log
        echo " │  Detecció de NAT:            ${nat_detectat}                                                                                  " >> log_inet.log
        echo " │  Nom del domini:             ${domini:--}                                                                       " >> log_inet.log
        echo " │  Xarxes de l'entitat:        ${xentitat} ${xroute} (${range:--})                                             " >> log_inet.log
        echo " │  Entitat propietària:        ${propietari} [$country]                                                        " >> log_inet.log
        if [ -n "$rutas_in" ]; then 
          isFirstLine=true
          while IFS= read -r line; do
            if [ -n "$line" ]; then
              if [ "$isFirstLine" = true ]; then
                echo " │                              " >> log_inet.log 
                echo " │  Rutas involucradas:         ${line}" >> log_inet.log
                isFirstLine=false
              else
                echo " |                              ${line}" >> log_inet.log
              fi
            fi
          done <<< "$rutas_in"
        fi
        echo " │                                                                                                            " >> log_inet.log
        echo " │  Tràfic rebut:               ${bytes_recibidos}  bytes  [${paquetes_recibidos}  paquets] (${errores_recibidos} errors, ${miss_recibidos} descartats i ${loss_recibidos} perduts) " >> log_inet.log
        echo " │  Tràfic transmès:            ${bytes_enviados}   bytes  [${paquetes_enviados}   paquets] (${errores_enviados} errors, ${miss_enviados} descartats i ${col_enviados} colisions)   " >> log_inet.log
        echo " │  Velocitat de Recepció:      $diferencia_bytes_recibidos bytes/s [$diferencia_paquetes_recibidos paquetes/s] " >> log_inet.log
        echo " │  Velocitat de Transmissió:   $diferencia_bytes_enviados bytes/s [$diferencia_paquetes_enviados paquetes/s]   " >> log_inet.log
        echo " │  -----------------------------------------------------------------------------------------                 " >> log_inet.log                                                                                                               
        echo " │                                                                                                            " >> log_inet.log
        echo " └─────────────────────────────────────────────────────────────────────────────────────────────               " >> log_inet.log
        echo "" >> log_inet.log
        echo "" >> log_inet.log

        #wpa_cli scan
        #output=$(wpa_cli scan_results)
        touch salida_scan.log
        output_scan=$(iw dev $interface scan)
        echo "$output_scan" >> salida_scan.log


        ssid_scan=$(echo "$output_scan" | grep "SSID: "| awk '{print $2}')
        lista_ssid=($(echo "$ssid_scan" | tr '\n' ' '))

        freq_scan=$(echo "$output_scan" | grep "freq: "| awk '{print $2}') 
        lista_freq=($(echo "$freq_scan" | tr '\n' ' '))

        canal_scan=$(echo "$output_scan" | grep "primary channel: " | awk '{print $4}')
        lista_canal=($(echo "$canal_scan" | tr '\n' ' '))
        num_nombres_unicos=$(printf '%s\n' "${lista_canal[@]}" | sort | uniq -c | wc -l)

        senyal_scan=$(echo "$output_scan" | grep "signal: " | awk '{print $2 $3}' )
        lista_senyal=($(echo "$senyal_scan" | tr '\n' ' '))

        v_scan=$(echo "$output_scan" | grep "upported rates: " | awk '{print $NF}')
        lista_v=($(echo "$v_scan" | tr '\n' ' '))

        mac_scan=$(echo "$output_scan" | grep "$interface" | awk '{print $2}' | cut -d "(" -f 1 )
        lista_mac=($(echo "$mac_scan" | tr '\n' ' '))

        auto_scan=$(echo "$output_scan" | grep "Authentication suites: " | awk '{print $4}')
        lista_auto=($(echo "$auto_scan" | tr '\n' ' '))

        pair_scan=$(echo "$output_scan" | grep "Pairwise ciphers: " | awk '{print $4}')
        lista_pair=($(echo "$pair_scan" | tr '\n' ' '))

        group_scan=$(echo "$output_scan" | grep "Group cipher: " | awk '{print $4}')
        lista_group=($(echo "$group_scan" | tr '\n' ' '))
        
        touch salida_wpa.log
        wpa_cli scan > /dev/null
        sleep 5
        output_wpa=$(wpa_cli scan_results) 
        echo "$output_wpa" >> salida_wpa.log

        combined_data=" │ SSID   canal   freqüència   senyal   v.max.   xifrat   algorismes_de_xifrat   Adreça_MAC   fabricant │ "$'\n'
        combined_data+=" │ ---   ---   ----   ----   ---   ---   -------   -----   ----- │ "$'\n'
        scan_size=$(echo "$ssid_scan" | wc -l)
        
        for ((i=0; i<${scan_size}; i++)); do
          fabricante_scan=$(wget -qO- "https://api.macvendors.com/$(echo "${lista_mac[$i]}" | tr -d ':')" | sed 's/ /_/g')
          xifrat_wpa=$(echo "$output_wpa" | grep "${lista_mac[$i]}" | awk '{print $4}' | cut -d "-" -f 1 | cut -d "[" -f 2)
          combined_data+=" | ${lista_ssid[$i]:--}   ${lista_canal[$i]}   ${lista_freq[$i]}   ${lista_senyal[$i]}   ${lista_v[$i]}Mbps   ${xifrat_wpa:-"sense"}   ${lista_auto[$i]:-"."}-${lista_pair[$i]:-}-${lista_group[$i]:-}   ${lista_mac[$i]}   ${fabricante_scan:-"desconegut"} │ "$'\n'
          
        done
        # Escribir el encabezado en el archivo de log

        echo " ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────  " >> log_inet.log
        echo " │                                                                                                           " >> log_inet.log
        echo " │ ---------------------------------------------------------------------------------------------------------------------------------------------------------   " >> log_inet.log
        echo " │                                      S'ha detectat $scan_size xarxes en $num_nombres_unicos canals a la interfície $interface.           " >> log_inet.log
        echo " │ ---------------------------------------------------------------------------------------------------------------------------------------------------------   " >> log_inet.log
        # Escribir los datos combinados en el archivo de log
        echo "$(column -t -s ' ' <<<"$combined_data")" >> log_inet.log
        echo " │ ---------------------------------------------------------------------------------------------------------------------------------------------------------   " >> log_inet.log
        echo " │    " >> log_inet.log
        echo " └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────  " >> log_inet.log


    fi
done
#obtenemos el tiempo final(cuando se acaba el script)
fecha_final=$(date '+%Y-%m-%d')
hora_final=$(date '+%H:%M:%S')
# Convertir las horas a segundos
inicio_seg=$(date -d "$fecha_inicio $hora_inicio" '+%s')
final_seg=$(date -d "$fecha_final $hora_final" '+%s')

# calculamos el tiempo de ejecucion del script
duracion=$((final_seg - inicio_seg))

# Ponemos el tiempo final en la cabecera(linea 7)
sed -i '7s/.*/& '"i finalitzada en data $fecha_final a les $hora_final [${duracion}s]."'/g' "log_inet.log"


