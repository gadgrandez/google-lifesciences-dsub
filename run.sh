#!/bin/bash

typeset -A config
config=(
    [REGION]="us-east1"
    [VCPUS]=4
    [RAM]=8
    [DISKSIZE]=500
    [BUCKET_LOG]="gs://EMPTY/log"
    [BUCKET_INPUT]="gs://EMTPY/input"
    [BUCKET_OUTPUT]="gs://EMPTY/output"
    [DOCKER_IMAGE]="hello:latest"
    [SCRIPT_PATH]="$HOME/example.sh"
)

clear

echo "Verificando la activación de las APIs"

gcloud services enable compute.googleapis.com
gcloud services enable genomics.googleapis.com
gcloud services enable lifesciences.googleapis.com
gcloud services enable storage-api.googleapis.com


PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)

head() {
    echo "Ejecutando en $PROJECT"
    echo ""
    echo "Use “gcloud config set project [PROJECT_ID]” para cambiar a un proyecto diferente"
    echo ""
}

read_config() {

    echo "Leyendo configuración..."
    CONFIG_FILE=$HOME/.cdsub.conf
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi

    while read line
    do
        if echo $line | grep -F = &>/dev/null
        then
            varname=$(echo "$line" | cut -d '=' -f 1)
            config[$varname]=$(echo "$line" | cut -d '=' -f 2-)
        fi
    done < $HOME/.cdsub.conf
    return 0
}

instance_config() {
    echo ""
    echo "CONFIGURANDO INSTANCIA"
    echo ""
    read -p 'Ingrese la región >_: ' regionvar

    config[REGION]=$regionvar

    read -p 'Ingrese el número de vCPUs a usar >_: ' vcpusvar

    config[VCPUS]=$vcpusvar

    read -p 'Ingrese la cantidad de RAM a usar >_: ' ramvar

    config[RAM]=$ramvar

    read -p 'Elija la cantidad de almacenamiento (en GB) >_: ' diskvar

    config[DISKSIZE]=$diskvar
}

bucket_config() {
    echo ""
    echo "CONFIGURANDO BUCKET"
    echo ""
    read -p 'Ruta para el registro (log) >_: ' bucketlogvar

    config[BUCKET_LOG]=$bucketlogvar

    read -p 'Ruta del archivo de ingreso (con variable) >_: ' bucketinputvar

    config[BUCKET_INPUT]=$bucketinputvar

    read -p 'Ruta del archivo de salida (con variable) >_: ' bucketoutputvar

    config[BUCKET_OUTPUT]=$bucketoutputvar
}

image_config() {
    echo ""
    echo "ESTABLECIENDO LA IMAGEN DE EJECUCIÓN"
    echo ""
    read -p 'Ingrese la imagen a usar >_: ' imagevar

    config[DOCKER_IMAGE]=$imagevar
}

script_path() {
    echo ""
    echo "ESTABLECIENDO EL SCRIPT DE EJECUCIÓN"
    echo ""
    read -p 'Ingrese la ruta al script >_: ' scriptpathvar

    if [ ! -f "$scriptpathvar" ]; then
        echo ""
        echo "La ruta del script no existe.."
        echo ""
        echo "-------------------------------------------"
        script_path
    fi

    config[SCRIPT_PATH]=$scriptpathvar
}

start_pipeline() {
    clear
    head
    echo "Iniciando pipeline"
    dsub \
        --provider google-cls-v2 \
        --project $PROJECT \
        --regions ${config[REGION]} \
        --logging ${config[BUCKET_LOG]} \
        --input ${config[BUCKET_INPUT]} \
        --output ${config[BUCKET_OUTPUT]} \
        --image ${config[DOCKER_IMAGE]} \
        --min-cores ${config[VCPUS]} \
        --min-ram ${config[RAM]} \
        --disk-size ${config[DISKSIZE]} \
        --script ${config[SCRIPT_PATH]}
}

print_config() {
    echo ""
    echo "CONFIGURACIÓN DE INSTANCIA"
    echo "Región: ${config[REGION]}"
    echo "vCPUs a usar: ${config[VCPUS]}"
    echo "RAM a usar: ${config[RAM]}"
    echo "Tamaño del disco: ${config[DISKSIZE]}"
    echo ""
    echo "CONFIGURACIÓN DEL BUCKET"
    echo "Bucket para registro: ${config[BUCKET_LOG]}"
    echo "Archivo de ingreso (con variable): ${config[BUCKET_INPUT]}"
    echo "Archivo de salida (con variable): ${config[BUCKET_OUTPUT]}"
    echo ""
    echo "CONFIGURACIÓN DE LA IMAGEN DE EJECUCIÓN"
    echo "Imagen: ${config[DOCKER_IMAGE]}"
    echo ""
    echo "CONFIGURACIÓN DEL SCRIPT"
    echo "Ruta del script: ${config[SCRIPT_PATH]}"
}

save_config() {
    CONFIG_FILE=$HOME/.cdsub.conf
    if [ ! -f "$CONFIG_FILE" ]; then
        touch $CONFIG_FILE
    fi

    echo "" > $CONFIG_FILE

    for index in ${!config[*]}
    do
        echo "$index=${config[$index]}" >> $CONFIG_FILE
    done
}

modify_config() {
    echo ""
    echo "Elije lo que desees modificar"
    echo ""
    echo "1. Configuración de instancia"
    echo "2. Configuración del Bucket"
    echo "3. Cambiar la imagen de ejecución"
    echo "4. Cambiar la ruta del script"
    echo ""
    read -p 'Elije un número >_: ' continuevar

    case $continuevar in
        "1")
            instance_config
            summary
            ;;
        "2")
            bucket_config
            summary
            ;;
        "3")
            image_config
            summary
            ;;
        "4")
            script_path
            summary
            ;;
        *)
            echo "Elija una opción válida"
            sleep 2
            summary
            ;;
    esac
}
summary() {
    clear
    echo "Esta es la configuración"
    echo "---------------------------------------"

    print_config

    echo ""
    read -p '¿Es correcto? s/n: ' continuevar

    case $continuevar in
        s)
            echo "Guardando configuración e iniciando"
            save_config
            #start_pipeline
            ;;
        n)
            modify_config
            ;;
        *)
            echo "Elija Sí (s) o No (n)"
            sleep 3
            summary
            ;;
    esac
}
run_config() {
    clear
    head
    echo "Iniciando configuración"
    echo ""
    instance_config
    bucket_config
    image_config
    script_path

    summary
}

load() {

    head

    read_config

    if [ $? == 0 ]; then
        echo "Hay una configuración anterior"

        print_config

        echo ""
        read -p '¿Usar esta configuración? s/n: ' continuevar

        case $continuevar in
            s)
                echo "Usando la configuración guardada"
                start_pipeline
                ;;
            n)
                modify_config
                ;;
            *)
                echo "Elija Sí (s) o No (n)"
                sleep 5
                clear
                load
                ;;
        esac
    elif [ $? == 1 ]; then
        run_config
    else
        echo "Ha ocurrido un error, saliendo..."
        sleep 3
        exit 1
    fi
}

install_dsub() {
    pip3 install dsub -U
}

which dsub

if [ $? == 1 ]; then
    echo "No se encontró dsub"
    read -p "¿Desea instalarlo ahora? s/n: " installdsubvar

    case $installdsubvar in
        s)
            echo ""
            echo "Instalando dsub e iniciando..."
            install_dsub
            clear
            load
            ;;
        n)
            echo ""
            echo "Es necesario tener instalado dsub para continuar"
            echo "Saliendo..."
            sleep 1
            clear
            exit 1
    esac
else 
    load
fi