#!/bin/bash
#librerias necesarias:
# apt install lsb-release
# apt install wget
# apt instal whois

clear

if [[ "$1" == "-d" ]]; then
    # Instalar paquetes necesarios
    apt update
    apt install -y lsb-release wget whois
fi

mostrar_ayuda() {
    echo "Este script se utilitza para analizar las interficies de tu ordenador y genera un informe."
    echo ""
    echo "Es necesario descargar los siguientes paquetes:"
    echo "apt install lsb-release"
    echo "apt install wget"
    echo "apt instal whois"
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
version_script=$(basename "$0")
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
    if [[ "$interface" == "lo" ]]; then 
        #obtenemos la mac
        mac_address=$(ip link show "$interface" | grep link | awk '{print $2}') 
        #----------------------------------------------------------------------------------------------
        #obtenemos el estado de la interficie
        link_info=$( ip -brief link show "$interface" | awk '{print $2}')
        #----------------------------------------------------------------------------------------------
        #obtenemos el mtu
         mtu=$(ip link show "$interface" | awk '/mtu/ {print $5}')
        #----------------------------------------------------------------------------------------------
        #obtenemos que tipo de adreçament
        adrecament=$(cat /etc/network/interfaces | grep "$interface inet" | awk '{printf $4}')
        #----------------------------------------------------------------------------------------------
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
        adreca_xarxa=$(whois "${ip_sola}" | grep NetRange | awk '{printf $2}')
        #----------------------------------------------------------------------------------------------
        #obtenemos la adreça del broadcast 
        broadcast=$(whois "${ip_sola}" | grep NetRange | awk '{printf $4}')
        #----------------------------------------------------------------------------------------------
        #quitamos los numeros que no sean 255
        normalized_broadcast=$(convertir_a_broadcast "$broadcast")
        #----------------------------------------------------------------------------------------------
        #obtenemos el gateway por defecto
        gatewayd=$(ip route | grep default | awk '{printf $3}')
        #----------------------------------------------------------------------------------------------
        #optenemos el output entero de la informacion de la interfaz
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
        output_final=$(ip -s link show "$interfaz")

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
        echo " ┌───────────────────────────────────────────────────────────────────────────────────────────────────────────" >> log_inet.log
        echo " │                                                                                             " >> log_inet.log
        echo " │  ---------------------------------------------------------------------------------------------------------" >> log_inet.log
        echo " │                               Configuració de la interfície $interface.                     " >> log_inet.log
        echo " │  ---------------------------------------------------------------------------------------------------------" >> log_inet.log  
        echo " │  Interfície:                 $interface" >> log_inet.log
        echo " │  Adreça MAC:                 ${mac_address:-N/A}">> log_inet.log
        echo " │  Estat de la interfície:     ${link_info:-N/A} (responent...)" >> log_inet.log
        echo " │  Mode de la interfície:      normal, amb mtu ${mtu:-N/A}" >> log_inet.log
        echo " |" >> log_inet.log 
        echo " |  Adrecament:                 ${adrecament} (fitxer /etc/network/interfaces)"  >> log_inet.log
        echo " |  Adreça IP / màscara:        ${ip_mask} ( ${ip_sola} ${subnet_mask})" >> log_inet.log
        echo " │  Adreça de xarxa:            ${adreca_xarxa}/${cidr} (${adreca_xarxa+1})" >> log_inet.log
        echo " |  Adreça broadcast:           ${broadcast} ($normalized_broadcast)" >> log_inet.log
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
    
    
    
    else
        #----------------------------------------------------------------------------------------------
        #obtenemos el nombre original
        nombre_original=$(ip link show "$interface" | grep altname | awk  '{print $2}')
        # Estado de la interfície
        nombre_actual=$(ip -s link show "$interface" | awk '/state/ {print $2}')
        nombre_actual="${nombre_actual%?}"
        if [ -z "$nombre_original" ]; then
            nombre_original="$nombre_actual"
        fi
        #----------------------------------------------------------------------------------------------

        # obtenemos al fabricante
        manufacturer=$(udevadm info /sys/class/net/$interface | grep ID_MODEL_FROM | cut -d '=' -f2-)

        #----------------------------------------------------------------------------------------------

        # Dirección MAC
        mac_address=$(ip link show "$interface" | awk '/link\/ether/ {print $2}')

        #----------------------------------------------------------------------------------------------

        # Estado del enlace
        link_info=$( ip -brief link show "$interface" | awk '{print $2}')

        #----------------------------------------------------------------------------------------------

        # MTU
        mtu=$(ip link show "$interface" | awk '/mtu/ {print $5}')

        #----------------------------------------------------------------------------------------------

        # Dirección IP
        ip_info=$(ip address show "$interface" | awk '/inet / {print $2}')
        
        #----------------------------------------------------------------------------------------------
        #obtenemos el adreçament
        adrecament=$(cat /etc/network/interfaces | grep "$interface inet" | awk '{printf $4}')
        #obtenemos la ip y la mascara, y las dividimos en dos partes la ip y el numero mascara
        #----------------------------------------------------------------------------------------------
        ip_mask=$(ip address show "$interface" | grep -E "inet\b" | awk '{print $2}')
        ip_sola=$(echo $ip_mask | cut -d '/' -f1)
        cidr=$(echo $ip_mask | cut -d'/' -f2)        
        # el numero de mascara lo pasamos a ip
        subnet_mask=$(cidr_to_subnet $cidr)
            
        #----------------------------------------------------------------------------------------------

        #obtenemos la adreça de xarxa
        adreca_xarxa=$(whois "${ip_sola}" | grep NetRange | awk '{printf $2}')

        #----------------------------------------------------------------------------------------------
        #obtenemos la ip broadcast
        broadcast=$(whois "${ip_sola}" | grep NetRange | awk '{printf $4}')
        
        #----------------------------------------------------------------------------------------------
        
        # los numeros que no son 255 ponemos 0 
        normalized_broadcast=$(convertir_a_broadcast "$broadcast")

        #----------------------------------------------------------------------------------------------
        
        #obtenemos el gateway
        gatewayd=$(ip route | grep default | awk '{printf $3}')
        
        #----------------------------------------------------------------------------------------------

        #obtenemos el nombre dns
        dns=$(dig +short -x $ip_sola)
        
        #----------------------------------------------------------------------------------------------
        #obtenemos la ip publica que nos la dan desde el exterior 
       
        ip_publica=$(wget -qO- https://ifconfig.me/ip)
        domini=$(dig +short -x $ip_publica)
                
        #----------------------------------------------------------------------------------------------

        #obtenemos el nombre de la xarxa entitat
        xentitat=$(whois "${ip_publica}" | grep netname | awk '{printf $2}')
        xroute=$(whois "${ip_publica}" | grep route | awk '{printf $2}')
        #obtenemso el rango de adreces
        range=$(whois "${ip_publica}" | grep inetnum | awk '{printf $2 $3 $4}')

        #----------------------------------------------------------------------------------------------

        propietari=$(whois "${ip_publica}" | grep descr | head -n 1 | cut -d ' ' -f2- |  sed 's/ \+/ /g')
        country=$(whois "${ip_publica}" |  grep country | awk '{printf $2}')
        
        #----------------------------------------------------------------------------------------------

        #obtenemos el output completo
        output=$(ip -s link show "$interface")

        bytes_recibidos=$(echo "$output" | awk '/RX:/{getline; print $1}')
        bytes_enviados=$(echo "$output" | awk '/TX:/{getline; print $1}')

        # Extraer el número de paquetes recibidos y enviados
        paquetes_recibidos=$(echo "$output" | awk '/RX:/{getline; print $2}')
        paquetes_enviados=$(echo "$output" | awk '/TX:/{getline; print $2}')

        errores_recibidos=$(echo "$output" | awk '/RX:/{getline; print $3}')
        errores_enviados=$(echo "$output" | awk '/TX:/{getline; print $3}')

        miss_recibidos=$(echo "$output" | awk '/RX:/{getline; print $3}')
        miss_enviados=$(echo "$output" | awk '/TX:/{getline; print $3}')

        loss_recibidos=$(echo "$output" | awk '/RX:/{getline; print $4}')
        col_enviados=$(echo "$output" | awk '/TX:/{getline; print $4}')
        # Calcular el total de paquetes

        # Esperar 1 segundo (puedes ajustar este valor según tus necesidades)
        sleep 1

        # Obtener las estadísticas nuevamente después de 1 segundo
        output_final=$(ip -s link show "$interfaz")

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
        echo " ┌─────────────────────────────────────────────────────────────────────────────────────────────────────────── " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log
        echo " │  --------------------------------------------------------------------------------------------------------- " >> log_inet.log
        echo " │                               Configuració de la interfície $interface.                                    " >> log_inet.log
        echo " │  --------------------------------------------------------------------------------------------------------- " >> log_inet.log
        echo " │  Interfície:                 ${nombre_actual:-N/A} [${nombre_original:-N/A}]                                 " >> log_inet.log
        echo " │  Fabricant:                  ${manufacturer:-N/A}                                                            " >> log_inet.log
        echo " │  Adreça MAC:                 ${mac_address:-N/A}                                                             " >> log_inet.log
        echo " │  Estat de la interfície:     ${link_info:-N/A}                                                               " >> log_inet.log
        echo " │  Mode de la interfície:      normal, amb mtu ${mtu:-N/A}                                                     " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log
        echo " │  Dirección IP:               ${ip_info:-N/A}                                                                " >> log_inet.log
        echo " │  Adrecament:                 ${adrecament} (fitxer /etc/network/interfaces)                                 " >> log_inet.log
        echo " │  Adreça IP / màscara:        ${ip_mask:--} ( ${ip_sola} ${subnet_mask})                                     " >> log_inet.log
        echo " │  Adreça de xarxa:            ${adreca_xarxa:--}/${cidr} (${adreca_xarxa+1})                                  " >> log_inet.log
        echo " │  Adreça broadcast:           ${broadcast:--} ($normalized_broadcast)                                        " >> log_inet.log
        echo " │  Gateway per defecte:        ${gatewayd:--}                                                                 " >> log_inet.log
        echo " │  Adreça IP pública:          ${ip_publica:--}[${domini:--}]                                                  " >> log_inet.log
        echo " │  Nom DNS:                    ${dns:--}                                                                      " >> log_inet.log
        echo " │                                                                                                            " >> log_inet.log 
        echo " │  Detecció de NAT:                                                                                          " >> log_inet.log
        echo " │  Nom del domini:             ${domini}                                                                       " >> log_inet.log
        echo " │  Xarxes de l'entitat:        ${xentitat} ${xroute} (${range:--})                                             " >> log_inet.log
        echo " │  Entitat propietària:        ${propietari} [$country]                                                        " >> log_inet.log
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


