#!/bin/bash

logfile="/home/felix/logs/plexstats.log"
db="/var/lib/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db"
echo "$(date "+%d.%m.%Y %T") PLEX LIBRARY STATS" | tee -a $logfile
echo "Media items in Libraries" | tee -a $logfile
query="SELECT Library, Items \
                        FROM ( SELECT name AS Library, \
                        COUNT(duration) AS Items \
                        FROM media_items m  \
                        LEFT JOIN library_sections l ON l.id = m.library_section_id  \
                        WHERE library_section_id > 0 GROUP BY name );"
sqlite3 -header -line "$db" "$query" | tee -a $logfile
echo " " | tee -a

query="select count(*) from media_items"
result=$(sqlite3 -header -line "$db" "$query")
echo "${result:11} files in library" | tee -a $logfile

query="select count(*) from media_items where bitrate is null"
result=$(sqlite3 -header -line "$db" "$query")
echo "${result:11} files missing analyzation info" | tee -a $logfile

query="SELECT count(*) FROM media_parts WHERE deleted_at is not null"
result=$(sqlite3 -header -line "$db" "$query")
echo "${result:11} media_parts marked as deleted" | tee -a $logfile

query="SELECT count(*) FROM metadata_items WHERE deleted_at is not null"
result=$(sqlite3 -header -line "$db" "$query")
echo "${result:11} metadata_items marked as deleted" | tee -a $logfile

query="SELECT count(*) FROM directories WHERE deleted_at is not null"
result=$(sqlite3 -header -line "$db" "$query")
echo "${result:11} directories marked as deleted" | tee -a $logfile

query="select count(*) from metadata_items meta \
                        join media_items media on media.metadata_item_id = meta.id \
                        join media_parts part on part.media_item_id = media.id \
                        where part.extra_data not like '%deepAnalysisVersion=2%' \
                        and meta.metadata_type in (1, 4, 12) and part.file != '';"
result=$(sqlite3 -header -line "$db" "$query")
echo "${result:11} files missing deep analyzation info." | tee -a $logfile

echo " " | tee -a

query="select count(*) from media_parts mp join media_items mi on mi.id = mp.media_item_id where mi.library_section_id = 2 and mp.extra_data like '%intros=%';"
result=$(sqlite3 -header -line "$db" "$query")
echo "${result:11} analyzed for intros" | tee -a $logfile

query="select count(*) from media_parts mp join media_items mi on mi.id = mp.media_item_id where mi.library_section_id = 2 and mp.extra_data not like '%intros=%';"
result=$(sqlite3 -header -line "$db" "$query")
echo "${result:11} not analyzed for intros" | tee -a $logfile

query="select count(*) from media_parts mp join media_items mi on mi.id = mp.media_item_id where mi.library_section_id = 2 and mp.extra_data like '%intros=%%7B%';"
result=$(sqlite3 -header -line "$db" "$query")
echo "${result:11} have intros" | tee -a $logfile

exit
