#!/bin/bash
#
# Мониторинг 1С Предприятия 8.3 (общие переменные и функции)
#
# (c) 2019-2020, Алексей Ю. Федотов
#
# Email: fedotov@kaminsoft.ru
#

# Вывести сообщение об ошибке переданное в аргументе и выйти с кодом 1
function error {
    echo "ОШИБКА: ${1}" >&2 ; exit 1
}

# Системный пользователь для запуска сервера 1С Предприятия
export USR1CV8="usr1cv8"

# Тип операционной системы GNU/Linux или MS Windows
[[ "$(uname -s)" != "Linux" ]] && IS_WINDOWS=1

# Имя сервера, используемое в кластере 1С Предприятия
[[ -z ${IS_WINDOWS} ]] && HOSTNAME=$(hostname -s) || HOSTNAME=$(hostname)
export HOSTNAME

# Добавление пути к бинарным файлам 1С Предприятия
[[ -z ${IS_WINDOWS} ]] && RAC_PATH="$( { find /opt/1C/v8* /opt/1cv8/ -name rac ; } 2>/dev/null | tail -n1 )" ||
    RAC_PATH="$(ls -d /c/Program\ Files*/1cv8/8.* | tail -n1)/bin/"
export RAC_PATH

[[ -n ${RAC_PATH} ]] && export PATH="${PATH}:${RAC_PATH%/*}" || error "Не найдена платформа 1С Предприятия!"

# Проверить инициализацию переменной TMPDIR
[[ -z ${TMPDIR} ]] && export TMPDIR="/tmp"

# Файл списка кластеров
export CLSTR_CACHE="${TMPDIR}/1c_clusters_cache"

# Параметры взаимодействия с сервисом RAS
RAS_PORT="1545"
RAS_TIMEOUT="1.5"
RAS_AUTH=""

# Максимальное число параллельных потоков
MAX_THREADS=$(( $(nproc) / 2 )) && [[ ${MAX_THREADS} -eq 0 ]] && MAX_THREADS=1 

# Общие для всех скрпитов тексты ошибок
ERROR_UNKNOWN_MODE="Неизвестный режим работы скрипта!"
ERROR_UNKNOWN_PARAM="Неизвестный параметр для данного режима работы скрипта!"

# Вывести разделительную строку длинной ${1} из символов ${2}
# По-умолчанию раделительная строка - это 80 символов "-"
function put_brack_line {
    [[ -n ${1} ]] && LIMIT=${1} || LIMIT=80
    [[ -n ${2} ]] && CHAR=${2} || CHAR="-"

    printf "%*s\n" ${LIMIT} ${CHAR} | sed "s/ /${CHAR}/g"
}

# Выполнить серию команд ${1} с параметром, являющимся элементом массива ${@}, следующим за ${1}
function execute_tasks {
    [[ ${#@} -le 1 ]] && exit # Если список задач пуст, то выходим
    TASK_CMD=${1}
    shift
    export -f ${TASK_CMD}
    echo ${@} | xargs -d' ' -n1 -P${MAX_THREADS} -i bash -c "${TASK_CMD} \${@}" _ {}
}

# Проверить наличие ring license и вернуть путь до ring
function check_ring_license {
    [[ -z ${IS_WINDOWS} ]] && RING_CONF="/etc/1C/1CE/ring-commands.cfg" ||
         RING_CONF="/C/ProgramData/1C/1CE/ring-commands.cfg"
    [[ ! -f ${RING_CONF} ]] &&  error "Не установлена утилита ring!"
    LIC_TOOL=$(grep license-tools "${RING_CONF}" | sed -r 's/.+file: //; s/\\/\//g; s/^(.{1}):/\/\1/')

    [[ -z ${LIC_TOOL} ]] && error "Не установлена утилита license-tools!"

    ls "${LIC_TOOL%\/*\/*}"/*ring*/ring*
}

# Получить список имен установленных программных лицензий
# в качестве параметра ${1} указать путь до ring
function get_license_list {
    "${1}" license list --send-statistics false | sed -re 's/^([0-9\-]+).*/\1/'
}

# Установить параметры взаимодействия с сервисом RAS
#  Метод устанавливает значения, указанные в параметрах:
#  * ${1} - номер порта RAS
#  * ${2} - максимальное время ожидания ответа RAS
#  * ${3} - пользователь администратор кластрера
#  * ${4} - пароль пользователя администратора кластера
function make_ras_params {

    [[ -n ${1} ]] && RAS_PORT=${1}

    [[ -n ${2} ]] && RAS_TIMEOUT=${2}

    [[ -n ${3} ]] && RAS_AUTH="--cluster-user=${3}"
    [[ -n ${4} ]] && RAS_AUTH+=" --cluster-pwd=${4}"

    export RAS_PORT RAS_TIMEOUT RAS_AUTH

}

# Сохранить список кластеров во временный файл
function push_clusters_list {

    # Сохранить список UUID кластеров во временный файл
    function push_clusters_uuid {
        CURR_CLSTR=$( timeout -s HUP ${RAS_TIMEOUT} rac cluster list \
            ${1%%:*}:${RAS_PORT} 2>/dev/null | awk '/^($|cluster|name|port)/' | \
            perl -pe "s/.*: /,/; s/(.+)\n/\1/;" | sed 's/^,//' | \
            awk "/${1##*:}/" | perl -pe 's/\n/;/' )

        [[ -n ${CURR_CLSTR} ]] && echo "${1%%:*}:${CURR_CLSTR}" >> ${CLSTR_CACHE}
    }

    cat /dev/null > ${CLSTR_CACHE}

    execute_tasks push_clusters_uuid ${@}

}

# Вывести список кластеров из временного файла:
#  - если в первом параметре указано self, то выводится только список кластеров текущего сервера
function pop_clusters_list {

    [[ ! -f ${CLSTR_CACHE} ]] && error "Не найден файл списка кластеров!"

    ( [[ -n ${1} && ${1} == "self" ]] && \
        grep -i "^${HOSTNAME}" "${CLSTR_CACHE}" | cut -f2 -d: || cat "${CLSTR_CACHE}" ) | sed 's/ /<sp>/g; s/"//g'

}

# Проверить актуальность файла списка кластеров
function check_clusters_cache {

    # Получим список менеджеров кластеров, в которых участвует данный сервер, следующего вида:
    #   <имя_сервера>:<номер_порта_0>[|<номер_порта_1>[|..<номер_порта_N>]]
    RMNGR_LIST=( $( if [ -z ${IS_WINDOWS} ]; then pgrep -ax rphost; else
        wmic path win32_process where "caption like 'rphost%'" get CommandLine | grep rphost; fi |
        sed -r 's/.*-regport ([^ ]+).*/\0|\1/; s/.*-reghost ([^ ]+).*\|/\1:/' | sort -u |
        awk -F: '{ if ( clstr_list[$1]== "" ) { clstr_list[$1]=$2 } \
            else { clstr_list[$1]=clstr_list[$1]"|"$2 } } \
            END { for ( i in clstr_list ) { print i":"clstr_list[i]} }' ) )

    # Проверка необходимости обновления временного файла:
    #   - если временный файл не существует
    #   - если количество строк во временном файле отличается от количества элементов
    #     списка менеджеров кластеров
    #   - если временный файл старше 1 часа
    if [[ -e ${CLSTR_CACHE} ]]; then
        if [[ ${1} == "lost" ]]; then
            cp ${CLSTR_CACHE} ${CLSTR_CACHE}.${$} && trap "rm -f ${CLSTR_CACHE}.${$}; exit 1" 1 2 3 15
            for CURR_RMNGR in ${RMNGR_LIST[@]}; do
                CURR_LOST=$( grep "^${CURR_RMNGR%:*}" ${CLSTR_CACHE}.${$} | \
                    sed -re "s/[^:^;]+,(${CURR_RMNGR#*:}),[^;]+;//" )
                sed -i -re "s/^${CURR_RMNGR%:*}.*$/${CURR_LOST}/; /[^:]+:$/d" ${CLSTR_CACHE}.${$}
            done
            grep -v "^$" ${CLSTR_CACHE}.${$} || [[ ${#RMNGR_LIST[@]} -ne $(grep -vc "^$" ${CLSTR_CACHE}) ]] && 
                push_clusters_list ${RMNGR_LIST[@]}
            rm -f ${CLSTR_CACHE}.${$} &>/dev/null
        elif [[ ${#RMNGR_LIST[@]} -ne $(grep -vc "^$" ${CLSTR_CACHE}) ||
            $(date -r ${CLSTR_CACHE} "+%s") -lt $(date -d "last hour" "+%s") ]]; then
            push_clusters_list ${RMNGR_LIST[@]}
        fi
    else
        push_clusters_list ${RMNGR_LIST[@]}
    fi

}

function get_processes_perfomance {

    CLSTR_LIST=${1#*:}
    [[ $( expr index ${1} : ) -eq 0 ]] && RAS_HOST=${HOSTNAME} || RAS_HOST=${1%:*}

    for CURR_CLSTR in ${CLSTR_LIST//;/ }; do
        timeout -s HUP ${RAS_TIMEOUT} rac process list --cluster=${CURR_CLSTR%%,*} \
            ${RAS_AUTH} ${RAS_HOST}:${RAS_PORT} 2>/dev/null | \
            awk '/^(host|available-perfomance|$)/' | perl -pe "s/.*: ([^.]+).*\n/\1:/" | \
            awk -F: '{ apc[$1]+=1; aps[$1]+=$2 } END { for (i in apc) { print i":"aps[i]/apc[i] } }'
    done

}

# Получить каталог кластера (при условии одного сервиса 1С)
# TODO: Обрабатывать ситуацию с несколькоими сервисами 1С
function get_server_directory {
    if [ -z ${IS_WINDOWS} ]; then
        SRV1CV8_DATA="$(pgrep -a ragent | sed -r 's/.*-d ([^ ]+).*/\1/' )"
        # Если каталог кластера не задан в параметре, то установим значение по умолчанию
        [[ -z ${SRV1CV8_DATA} ]] && SRV1CV8_DATA="$(awk -v uid="^$(awk '/Uid/ {print $2}' /proc/$(pgrep ragent)/status 2>/dev/null)$" -F: \
            '$3 ~ uid {print $6}' /etc/passwd)/.1cv8/1C/1cv8"
    else
        SRV1CV8_DATA="$(wmic path win32_process where "caption like 'ragent.exe'" get commandline /format:csv | \
            awk -F, '/ragent/ { print $2 }' | sed -re 's/.*-d "([^"]+).*/\1/; s/^/\//; s/\\/\//g; s/://')"
        #TODO: Задавать значение SRV1CV8_DATA в случае если не удалось определить из строки запуска
        #        (такое возможно при ручном запуске ragent)
    fi
    echo "${SRV1CV8_DATA}"
}
