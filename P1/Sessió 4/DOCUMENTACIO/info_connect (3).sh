#!/bin/bash

#ALUMNES:

#ERIC MILLAN LOMBARTE
#MARC PASCUAL DESENTRE

clear
#----------------------------------------------------------------------------------------------
if [[ "$1" == "-d" ]]; then
    # Instalar paquetes necesarios
    apt install -y lsb-release ipcalc nmap dnsutils bc
fi
#----------------------------------------------------------------------------------------------
mostrar_ayuda() {
    echo "Este script se utilitza para analizar los recursos de la IP mediante un puerto y genera un informe."
    echo "El informe generado se llamará log_connect.log y se guardarà en el directorio donde se ejecute el script"
    echo ""
    echo "Es necesario descargar los siguientes paquetes:"
    echo ""
    echo "apt install lsb-release"
    echo "apt install ipcalc"
    echo "apt install dnsutils"
    echo "apt install nmap"
    echo "apt install bc"
    echo ""
    echo "Modo de ejecución:"
    echo "Para ejecutar el script hacen falta 3 parametros: adreça IP, port i protocol de transport"
    echo ""
    echo "./info_connect.sh IP_EQUIPO_DESTINO PUERTO/TCP-UDP"
    echo ""
    echo " Ejemplo--> ./info_connect.sh  147.83.2.135 80/tcp "
    echo ""
    echo ""
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda y salir"
    echo "  -d             Ejecutar el script instalando los paquetes necesarios"
    echo ""
    echo ""
    exit 0
}

#----------------------------------------------------------------------------------------------
# Comprobar si se proporcionó la opción de ayuda
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    mostrar_ayuda
fi
#----------------------------------------------------------------------------------------------
#Aseguramos que tenga 2 argumentos
if [ "$#" -ne 2 ]; then
    echo "Por favor, proporciona la dirección IP y el puerto como argumentos."
    exit 1
fi
#----------------------------------------------------------------------------------------------
#Elimina el archivo si existe
if [ -f "log_connect.log" ]; then
    rm log_connect.log
fi

#----------------------------------------------------------------------------------------------
# Crear el archivo log_connect.log en la ruta actual
touch log_connect.log

#----------------------------------------------------------------------------------------------
#Assignamos los argumentos dados a las variables
equipo_destino="$1"
puerto_protocolo="$2"

#Obtenemos el servei del puerto destino
puerto=$(echo "$puerto_protocolo"| cut -d '/' -f 1) 
protocolo=$(echo "$puerto_protocolo"| cut -d '/' -f 2)

# Verificar que el protocolo es tcp o udp
if [[ ! $protocolo =~ ^(tcp|udp)$ ]]; then
    echo "El protocolo $protocolo no es válido."
    exit 0
fi
# Verificar que el puerto es un numero
if [[ ! $puerto =~ ^[0-9]+$ ]]; then
    echo "El puerto $puerto no es un número válido."
    exit 0
fi

# Obtenemos el id
usuario=$(id)
#Obtenemos el hostname
equipo=$(hostname -f)
#Obtenemos la version de nuestro SO
sistema_operativo=$(lsb_release -ds)

#Obtenemos las fechas necesarias
fecha_inicio=$(date '+%Y-%m-%d')
hora_inicio=$(date '+%H:%M:%S')
hora_final=$(date '+%H:%M:%S')

#Obtenemos la ip del loopback
ip_mask=$(ip address show "lo" | grep -E "inet\b" | awk '{print $2}')
ip_sola=$(echo "$ip_mask" | cut -d '/' -f1)

#----------------------------------------------------------------------------------------------

echo " ╔════════════════════════════════════════════════════════════════════════════       "        >> log_connect.log
echo " ║                                                                                   "        >> log_connect.log
echo " ║  -----------------------------------------------------------------------------    "        >> log_connect.log
echo " ║   Anàlisi de connectivitat a l'equip ${equipo_destino} en el port ${puerto_protocolo}."    >> log_connect.log
echo " ║  -----------------------------------------------------------------------------    "        >> log_connect.log
echo " ║  Equip:                  ${equipo} [${ip_sola}]                                   "        >> log_connect.log
echo " ║  Usuari:                 ${usuario}                                               "        >> log_connect.log
echo " ║  Sistema operatiu:       ${sistema_operativo}                                     "        >> log_connect.log
echo " ║  Versió:                 info_connect.sh v.0.1 (09/03/2024)                       "        >> log_connect.log
echo " ║  Data d'inici:           ${fecha_inicio} a les ${hora_inicio}                     "        >> log_connect.log
echo " ║  Data de finalització:  " >> log_connect.log
echo " ║  Durada de les tasques: " >> log_connect.log
echo " ║  -----------------------------------------------------------------------------    "        >> log_connect.log
echo " ║                                                                                   "        >> log_connect.log
echo " ╚════════════════════════════════════════════════════════════════════════════       "        >> log_connect.log
echo "" >> log_connect.log
echo "" >> log_connect.log

#----------------------------------------------------------------------------------------------

echo " ┌─────────────────────────────────────────────────────────────────────────────────────       " >> log_connect.log
echo " │                                                                                            " >> log_connect.log
echo " │  ---------------------------------------------------------------------------               " >> log_connect.log
echo " │                       Estat dels recursos per defecte.                                     " >> log_connect.log
echo " │  ---------------------------------------------------------------------------               " >> log_connect.log

#----------------------------------------------------------------------------------------------
#Obtenemos la interficie por defecto
interficie_def=$(ip route show | grep "default" | awk '{print $5}')

#Obtenemos la mac de la interficie por defecto
mac_def=$(ip link show "$interficie_def" | grep link | awk '{print $2}') 

#Obtenemos el estado de la interficie por defecto
link_info=$( ip -brief link show "$interficie_def" | awk '{print $2}')

#Obtenemos la ip + mascara de la interficie por defecto
ip_mask=$(ip address show "$interficie_def" | grep -E "inet\b" | awk '{print $2}')

#Separamos la ip de la mascara
ip_sola=$(echo "$ip_mask" | cut -d '/' -f1)

#Obtenemos la adreca de red de la interficie por defecto
adreca_xarxa=$(ipcalc "$ip_mask" | grep "Network" | awk '{print $2}')

#Obtenemos el rtt de la interficie por defecto
rtt_def=$(ping -i 0.001 -I "$interficie_def" -w 5 "$equipo_destino"  | grep rtt | awk '{print $4}' | cut -d '/' -f 2 | cut -d '/' -f 1)
#----------------------------------------------------------------------------------------------
echo " │  Intefície per defecte definida:            [ok]    ${interficie_def}                      " >> log_connect.log
echo " │  Intefície per defecte adreça MAC:          [ok]    ${mac_def}                             " >> log_connect.log
echo " │  Intefície per defecte estat:               [ok]    ${link_info}                           " >> log_connect.log
echo " │  Intefície per defecte adreça IP:           [ok]    ${ip_sola}                             " >> log_connect.log
if [ -n "$rtt_def" ]; then
    echo " │  Intefície per defecte adreça IP respon:    [ok]    rtt ${rtt_def} ms                 " >> log_connect.log
else
    echo " │  Intefície per defecte adreça IP respon:    [ko]     << OMÈS >>            " >> log_connect.log
fi
echo " │  Intefície per defecte adreça de xarxa:     [ok]    ${adreca_xarxa}                        " >> log_connect.log
#----------------------------------------------------------------------------------------------
#Obtenemos la ip del router por defecto
router_def=$(ip route show | grep "default" | awk '{print $3}')

#Realizamos los pings al router y al internet
internet="1.1.1.1"
ping_router=$(ping -i 0.001 -I "$interficie_def" -w 5 "$router_def"  | grep rtt | awk '{print $4}' | cut -d '/' -f 2 | cut -d '/' -f 1)
ping_internet=$(ping -i 0.001 -I "$interficie_def" -w 5 "$internet"  | grep rtt | awk '{print $4}' | cut -d '/' -f 2 | cut -d '/' -f 1)

#----------------------------------------------------------------------------------------------
echo " │                                                                                             " >> log_connect.log
echo " │  Router per defecte definit:                [ok]    ${router_def}                           " >> log_connect.log
if [ -n "$ping_router" ]; then
    echo " │  Router per defecte respon:                 [ok]    rtt ${ping_router} ms               " >> log_connect.log
else 
    echo " │  Router per defecte respon:                 [KO]    << OMÈS >>                          " >> log_connect.log
fi
if [ -n "$ping_internet" ]; then
    echo " │  Router per defecte té accés a Internet:    [ok]    rtt ${ping_internet} ms (a ${internet})    " >> log_connect.log
else
    echo " │  Router per defecte té accés a Internet:    [KO]    <<  OMÈS  >>                               " >> log_connect.log
fi

#----------------------------------------------------------------------------------------------
#Obtenemos todas las ip de los servidores dns y las colocamos con ,
dns_def=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')

#Obtenemos todas las ip de los servidores dns y las colocamos en un string con \n
dns_di=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}')

#Realizamos un ping por cada nameserver disponible en el servidor
#El primero que responda se considerara el por defecto
dns_resp=""
for ip in $dns_di; do
    if ping -c 1 "$ip" >/dev/null 2>&1; then
        dns_resp="$ip"
        break
    fi
done
#----------------------------------------------------------------------------------------------
echo " │                                                                                           " >> log_connect.log
echo " │  Servidor DNS per defecte definit:          [ok]    ${dns_def}                            " >> log_connect.log
if [ -n "$dns_resp" ]; then
    echo " │  Servidor DNS per defecte respon:           [ok]    ${dns_resp}                       " >> log_connect.log
else
    echo " │  Servidor DNS per defecte respon:           [ko]                                      " >> log_connect.log
fi
echo " │  ---------------------------------------------------------------------------              " >> log_connect.log
echo " │                                                                                           " >> log_connect.log
echo " │                                                                                           " >> log_connect.log
echo " │  ----------------------------------------------------------------------                   " >> log_connect.log
echo " │                      Estat dels recursos dedicats.                                        " >> log_connect.log
echo " │  ----------------------------------------------------------------------                   " >> log_connect.log
#----------------------------------------------------------------------------------------------

#Obtenemos la interficie de recursos dedicados 
interficie_rd=$(ip route get "$equipo_destino" | grep "dev" | awk '{print $5}')

#Obtenemos la mac de la interficie de recursos dedicados 
mac_rd=$(ip link show "$interficie_rd" | grep link | awk '{print $2}') 

#Obtenemos el estado de la interficie de recursos dedicados 
link_rd=$( ip -brief link show "$interficie_rd" | awk '{print $2}')

#Obtenemos la ip + mascara de la interficie de recursos dedicados 
ip_mask_rd=$(ip address show "$interficie_rd" | grep -E "inet\b" | awk '{print $2}')

#Separamos la ip de la mascara
ip_sola_rd=$(echo "$ip_mask_rd" | cut -d '/' -f1)

#Obtenemos la adreca de red
adreca_xarxa_rd=$(ipcalc "$ip_mask_rd" | grep "Network" | awk '{print $2}')

#Obtenemos el rtt de la interficie dedicada
rtt_rd=$(ping -i 0.001 -I "$interficie_rd" -w 5 "$equipo_destino"  | grep rtt | awk '{print $4}' | cut -d '/' -f 2 | cut -d '/' -f 1)
#----------------------------------------------------------------------------------------------
echo " │  Interfície de sortida cap al destí:        [ok]    ${interficie_rd}           " >> log_connect.log
echo " │  Interfície de sortida adreça MAC:          [ok]    ${mac_rd}                  " >> log_connect.log
echo " │  Interfície de sortida estat:               [ok]    ${link_rd}                 " >> log_connect.log
echo " │  Interfície de sortida adreça IP:           [ok]    ${ip_sola_rd}              " >> log_connect.log

if [ -n "$rtt_rd" ]; then
    echo " │  Interfície de sortida adreça IP respon:    [ok]    rtt ${rtt_rd} ms       " >> log_connect.log
else 
    echo " │  Interfície de sortida adreça IP respon:    [ko]    << OMÈS >>             " >> log_connect.log
fi
echo " │  Interfície de sortida adreça de xarxa:     [ok]    ${adreca_xarxa_rd}         " >> log_connect.log
#----------------------------------------------------------------------------------------------

#Obtenemos el router del equipo destino
router_rd=$(ip route get "$equipo_destino" | grep "via" | awk '{print $3}')

#----------------------------------------------------------------------------------------------
echo " │                                                                                   " >> log_connect.log

#Si no existe el router quiere decir que es de la misma red
if [ -n "$router_rd" ]; then
    echo " │  Router de sortida cap al destí:            [ok]    ${router_rd}               " >> log_connect.log
    #Realizamos pruebas de ping para ver si tiene conectividad el router
    ping_router_rd=$(ping -i 0.001 -I "$interficie_rd" -w 5 "$router_rd"  | grep rtt | awk '{print $4}' | cut -d '/' -f 2 | cut -d '/' -f 1)
    
    #Realizamos pruebas de ping para ver si el router tiene conexion a internet
    ping_internet_rd=$(ping -i 0.001 -I "$interficie_rd" -w 5 "$internet"  | grep rtt | awk '{print $4}' | cut -d '/' -f 2 | cut -d '/' -f 1)
    
    if [ -n "$ping_router_rd" ]; then
        echo " │  Router de sortida cap al destí respon:     [ok]    rtt ${ping_router_rd} ms              " >> log_connect.log
    else
        echo " │  Router de sortida cap al destí respon:     [ko]    << Omès >>                            " >> log_connect.log
    fi
    if [ -n "$ping_internet_rd" ]; then
         echo " │  Router de sortida té accés a Internet:     [ok]    rtt ${ping_internet_rd} ms           " >> log_connect.log
    else 
        echo " │  Router de sortida té accés a Internet:     [ko]    << Omès >>                            " >> log_connect.log
    fi
else
    echo " │  Router de sortida cap al destí:            [ok]    << Mateixa xarxa >>                   " >> log_connect.log
    echo " │  Router de sortida cap al destí respon:     [ko]    << Omès >>                            " >> log_connect.log
    echo " │  Router de sortida té accés a Internet:     [ko]    << Omès >>                            " >> log_connect.log
fi

echo " │  ----------------------------------------------------------------------                   " >> log_connect.log
echo " │                                                                                           " >> log_connect.log
echo " │                                                                                           " >> log_connect.log
echo " │  --------------------------------------------------------------------------------------   " >> log_connect.log
echo " │                                 Estat de l'equip destí.                                   " >> log_connect.log
echo " │  --------------------------------------------------------------------------------------   " >> log_connect.log
#----------------------------------------------------------------------------------------------
#Obtenemos el servicio del puerto dependiendo de si es udp o tcp
#Tambien obtenemos la version del servicio si existe
if [ "$protocolo" = "udp" ]; then
    servei=$(nmap -sU -p"$puerto" "$equipo_destino" | grep "$puerto_protocolo " | awk '{print $3}')
    versio_serv=$(nmap -sU -p"$puerto" "$equipo_destino" | grep "$puerto" | awk '{print $4}')
else
    servei=$(nmap -sV -p"$puerto" "$equipo_destino" | grep "$puerto_protocolo " | awk '{print $3}')
    versio_serv=$(nmap -sV -p"$puerto" "$equipo_destino" | grep "$puerto" | awk '{print $4}')
fi


#Obtenemos el dns del equipo destino
dns=$(dig +short -x "$equipo_destino")
#----------------------------------------------------------------------------------------------
echo " │  Destí nom DNS:                             [ok]    ${dns:--}                             " >> log_connect.log
echo " │  Destí adreça IP:                           [ok]    ${equipo_destino}                     " >> log_connect.log
echo " │  Destí port servei:                         [ok]    ${puerto_protocolo} ${servei:-}       " >> log_connect.log
#----------------------------------------------------------------------------------------------
#Comprovamos que se puede acceder al destino con un ping
desti_ab=$(ping -i 0.001 -w 5 "$equipo_destino"  | grep rtt | awk '{print $4}' | cut -d '/' -f 2 | cut -d '/' -f 1)

#Comprovamo si se puede acceder al puerto del destino
desti_servei=$(nmap -sV -p"$puerto" "$equipo_destino" | grep "latency" | awk '{print $4}' | cut -d '(' -f 2 | cut -d 's' -f 1)
#----------------------------------------------------------------------------------------------
echo " │                                                                                             " >> log_connect.log
if [ -n "$desti_ab" ]; then
    desti_ab=$(echo "$desti_ab * 1000" | bc)
    echo " │  Destí abastable:                           [ok]    latència ${desti_ab} us             " >> log_connect.log
else
    echo " │  Destí abastable:                           [ko]    << L'equip no respon >>             " >> log_connect.log
fi
if [ -n "$desti_servei" ]; then
    desti_servei=$(echo "$desti_servei * 1000000" | bc)
    echo " │  Destí respon al servei:                    [ok]    latència ${desti_servei} us          " >> log_connect.log
else
    echo " │  Destí respon al servei:                    [ko]    << El port no respon >>              " >> log_connect.log
fi
if [ -n "$versio_serv" ]; then
    echo " │  Destí versió del servei:                   [ok]    ${servei} - ${versio_serv}            " >> log_connect.log
else
    echo " │  Destí versió del servei:                   [ko]    << Versió no identificada >>          ">> log_connect.log
fi
echo " │  --------------------------------------------------------------------------------------   " >> log_connect.log
echo " │                                                                                           " >> log_connect.log
echo " └────────────────────────────────────────────────────────────────────────────────────────── " >> log_connect.log
#----------------------------------------------------------------------------------------------
#Obtenemos la fecha final del script
fecha_final=$(date '+%Y-%m-%d')
hora_final=$(date '+%H:%M:%S')
# Convertir las horas a segundos
inicio_seg=$(date -d "$fecha_inicio $hora_inicio" '+%s')
final_seg=$(date -d "$fecha_final $hora_final" '+%s')
#----------------------------------------------------------------------------------------------
# calculamos el tiempo de ejecucion del script
duracion=$((final_seg - inicio_seg))
#----------------------------------------------------------------------------------------------
# Ponemos el tiempo final y la duracion en la cabecera(linea 11 i 12)
sed -i '11s/.*/& '"$fecha_final a les $hora_final"'/g' "log_connect.log"
sed -i '12s/.*/& '"${duracion}s"'/g' "log_connect.log"

