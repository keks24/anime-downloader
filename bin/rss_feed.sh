#!/bin/bash
script_directory_path="${0%/*}"
script_name="${0##*/}"
configuration_name="${script_name/\.sh/.cfg}"
anime_names=($(< $script_directory_path/anime_names))

source "$script_directory_path/$configuration_name"

mkdir -p "$rss_output_path"
for i in "${anime_names[@]}"
do
    # custom - 20190310 - rfischer: implement "awk 'NR >= 3'" into the other awk command somehow
    curl --silent "$rss_address$fansub_name+$i+$episode_quality" | awk '/<title>|<link>|<pubDate>|<nyaa:seeders>|<nyaa:leechers>|<nyaa:infoHash>|<nyaa:size>/ && gsub("^\t+|</.+>$", "")' | awk 'NR >= 3' > $rss_output_path/rss_output_$i
    echo -e "\e[01;37mFetched information from address: $rss_address$fansub_name+$i+$episode_quality\e[0m"
done
