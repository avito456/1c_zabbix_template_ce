# Установка шаблона на Windows host (Ev) #



🔴Установить шаблоны в Zabbix из папки ./configs
<pre>
1c_central_server.xml
1c_license_server.xml
1c_work_server.xml 
</pre>



🔴 Настроить технологический журнал 1С  [logcfg.xml](../configs/logcfg_win.xml)




## Настройка Zabbix agent
Добавить userparameter в файл настроек Zabbix agent в файл 'zabbix_agentd.conf'

### Настройка UserParameter 

🔸 Центральный сервер 1С
<pre>
UserParameter=1c.cs.ib.availability[*]      ,bash ./scripts/1c_central_server.sh ib_status $1
UserParameter=1c.cs.sessions[*]             ,bash ./scripts/1c_central_server.sh sessions $1 $2 $3 $4
UserParameter=1c.cs.ib.restrictions[*]      ,bash ./scripts/1c_central_server.sh ib_restrict

UserParameter=1c.cs.clusters.discovery[*]   ,bash ./scripts/1c_central_server.sh clusters
UserParameter=1c.cs.infobases.discovery[*]  ,bash ./scripts/1c_central_server.sh infobases $1 $2 $3 $4 $5
</pre>

🔸 Рабочий сервер 1С
<pre>
UserParameter=1c.ws.locks[*]    ,bash ./scripts/1c_work_server.sh locks $1 $2 $3 $4 $5 $6
UserParameter=1c.ws.calls[*]    ,bash ./scripts/1c_work_server.sh calls $1 $2 $3
UserParameter=1c.ws.memory[*]   ,bash ./scripts/1c_work_server.sh memory
UserParameter=1c.ws.ram[*]      ,bash ./scripts/1c_work_server.sh ram
UserParameter=1c.ws.excps[*]    ,bash ./scripts/1c_work_server.sh excps $1
UserParameter=1c.ws.dump_logs[*],bash ./scripts/1c_work_server.sh dump_logs $1 $2
UserParameter=1c.ws.perfs[*]    ,bash ./scripts/1c_work_server.sh perfomance $1 $2 $3 $4
</pre>

🔸 Cервер лицензирования 1С
<pre>
UserParameter=1c.ls.sessions[*]             ,bash ./scripts/1c_license_server.sh used $1 $2 $3 $4
UserParameter=1c.ls.check[*]                ,bash ./scripts/1c_license_server.sh check

UserParameter=1c.ls.clusters.discovery[*]   ,bash ./scripts/1c_license_server.sh clusters
</pre>

**ВАЖНО:** Перестартовать сервис Zabbix agent! 

**ВАЖНО:** Указывать имя каталога в макросе *{$LOG_DIR}* требуется в виде
<pre>/c/Logs</pre>
вместо привычных
<pre>C:\Logs</pre>
Имена каталогов чувствительны к регистру!





## Примеры запуска скриптов из командной строки

🔸 Рабочий сервер 1С
<pre>
Key=1c.ws.locks
bash ./scripts/1c_work_server.sh locks  $1 $2 $3 $4 $5 $6

{$LOG_DIR},
{$MAX_LOCK_WAIT},
{$RAS_PORT},
{$RAS_TIMEOUT},
{$RAS_USER},
{$RAS_PASS}
</pre>

🔸 [1С/Серверные вызовы] Топы :)
<pre>
Key=1c.ws.calls
bash ./scripts/1c_work_server.sh calls $1 $2 $3

{$LOG_DIR}, lazy    ,{$TOP_LIST_SIZE} //  [1С/Серверные вызовы] ТОП25 "ленивых" вызовов
{$LOG_DIR}, memory  ,{$TOP_LIST_SIZE} //  [1С/Серверные вызовы] ТОП25 по максимальной памяти за вызов
{$LOG_DIR}, dur_avg ,{$TOP_LIST_SIZE} //  [1С/Серверные вызовы] ТОП25 по средней длительности
{$LOG_DIR}, duration,{$TOP_LIST_SIZE} //  [1С/Серверные вызовы] ТОП25 по суммарной длительности
{$LOG_DIR}, iobytes ,{$TOP_LIST_SIZE} //  [1С/Серверные вызовы] ТОП25 по суммарному вводу-выводу
{$LOG_DIR}, count   ,{$TOP_LIST_SIZE} //  [1С/Серверные вызовы] ТОП25 по суммарному количеству
{$LOG_DIR}, cpu     ,{$TOP_LIST_SIZE} //  [1С/Серверные вызовы] ТОП25 по суммарному процессорному времени

</pre>

🔸 [1С/Рабочий сервер] Объем памяти процессов
<pre>
Key=1c.ws.memory
bash ./scripts/1c_work_server.sh memory
</pre>

🔸 [1С/Рабочий сервер] Объем памяти сервера
<pre>
Key=1c.ws.ram
bash ./scripts/1c_work_server.sh ram
</pre>

🔸 [1С/Рабочий сервер] Ошибки процессов
<pre>
Key=1c.ws.excps    
bash ./scripts/1c_work_server.sh excps $1

    {$LOG_DIR} // В формате '/c/logs/...'
</pre>

🔸 ????
<pre>
bash ./scripts/1c_work_server.sh dump_logs $1 $2
</pre>

🔸 [1С/Рабочий процесс] Доступная производительность
<pre>
bash ./scripts/1c_work_server.sh perfomance $1 $2 $3 $4

    {$RAS_PORT},
    {$RAS_TIMEOUT},
    {$RAS_USER},
    {$RAS_PASS}
</pre>


### Центральный сервер 1С

🔸 [1С/Центральный сервер] Текущие сеансы [1С/Сеансы]
<pre>
    - [1С/Сеансы] Количество http-сервисов		                    Key=1c.cs.sessions.http
    - [1С/Сеансы] Количество активных		                        Key=1c.cs.sessions.as
    - [1С/Сеансы] Количество веб-сервисов		                    Key=1c.cs.sessions.ws
    - [1С/Сеансы] Количество спящих                                 Key=1c.cs.sessions.hb
    - [1С/Сеансы] Количество фоновых заданий		                Key=1c.cs.sessions.bg
    - [1С/Сеансы] Общее количество		                            Key=1c.cs.sessions.total
    - [1С/Сеансы] Текущая длительность вызова http-сервиса		    Key=1c.cs.sessions.hsd
    - [1С/Сеансы] Текущая длительность вызова веб-сервиса		    Key=1c.cs.sessions.wsd
    - [1С/Сеансы] Текущая длительность вызова фонового задания	    Key=1c.cs.sessions.bgd
</pre>

🔸 [1С/Центральный сервер] Текущие сеансы
<pre>
Key=1c.cs.sessions
bash ./scripts/1c_central_server.sh sessions $1 $2 $3 $4

    {$RAS_PORT},
    {$RAS_TIMEOUT},
    {$RAS_USER},
    {$RAS_PASS}
</pre>

🔸 Ограничения
<pre>
key=1c.cs.ib.restrictions
bash ./scripts/1c_central_server.sh ib_restrict
</pre>

🔸 Обнаружение кластеров ???
<pre>
key=1c.cs.clusters.discovery
bash ./scripts/1c_central_server.sh clusters
</pre>


### Сервер лицензирования 1С

🔸 Активные сеансы
<pre>
key=1c.ls.sessions
bash ./scripts/1c_license_server.sh used $1 $2 $3 $4

    {$RAS_PORT},
    {$RAS_TIMEOUT},
    {$RAS_USER},
    {$RAS_PASS}]
</pre>

🔸 Проверка кластеров
<pre>
key=1c.ls.check
bash ./scripts/1c_license_server.sh check
</pre>

🔸 Поиск кластеров ???
<pre>
Key=1c.ls.clusters.discovery
bash ./scripts/1c_license_server.sh clusters
</pre>

[Назад](../README.md)