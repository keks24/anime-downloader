#!/bin/bash
script_directory_path="${0%/*}"
script_name="${0##*/}"
configuration_name="${script_name/\.sh/.cfg}"
save_path="$script_directory_path/animes"
anime_names=($(< $script_directory_path/anime_names))

bash "$script_directory_path/rss_feed.sh"
source "$script_directory_path/$configuration_name"

for i in "${anime_names[@]}"
do
    anime_name="$i"
    anime_save_path="$save_path/$anime_name"
    rss_output_file="$rss_output_path/rss_output_$anime_name"

    if [[ -f $rss_output_file ]]
    then
        current_episode_file="$anime_save_path/current_episode"
        episode_numbers_file="$anime_save_path/episode_numbers"
        episode_links_file="$anime_save_path/episode_links"

        if [[ ! -d $anime_save_path ]]
        then
            mkdir $anime_save_path
        fi

        while [[ ! -f $current_episode_file ]]
        do
            if [[ $1 == "-c" ]]
            then
                echo "0" > $current_episode_file
                episode_count="-0"
                break
            fi

            read -p "Enter current downloaded episode of Anime $anime_name [0 = not downloaded yet and download all files]: " input

            if [[ $input =~ $is_numeric ]]
            then
                if [[ $input == 0 ]]
                then
                    echo "0" > $current_episode_file
                    episode_count="-0"
                    break

                else
                    echo "$input" > $current_episode_file
                    episode_count="-0"
                    break
                fi

            else
                echo -e "\e[01;31mInput: $input of Anime $anime_name is not numeric! \e[0m"
            fi
        done

        if [[ $(< $current_episode_file) == "0" ]]
        then
            episode_count="-0"
        fi

        grep "<title>" $rss_output_file | head -n $episode_count | sed "s/.*$anime_name_delimiter\([0-9]\{1,$episode_character_count\}\).*/\1/" > $episode_numbers_file
        awk -F "$link_delimiter" '/<link>/ { print $2 }' $rss_output_file | head -n $episode_count > $episode_links_file
        episode_count=$(awk '/episode_count=/ { print NR }' "$script_directory_path/$configuration_name")

        j=0
        for k in `cat $episode_links_file`
        do
            Link[$j]=$k
            (( j++ ))
        done

        j=0
        declare -A EpisodeAndLink
        for new_episode_number in `cat $episode_numbers_file`
        do
            if [[ $new_episode_number =~ $is_numeric ]]
            then
                EpisodeAndLink[$new_episode_number]="${Link[$j]}"
                (( j++ ))

            else
                echo -e "\e[01;31mEpisode \"$new_episode_number\" of Anime $anime_name is not numeric!.\e[0m"
                tid=`echo "${Link[$j]}" | sed "s/[^0-9]//g"`

                echo -e "\e[01;33mDeleting line with expression \"$new_episode_number\" in file $episode_numbers_file\e[0m"
                echo -e "\e[01;33mDeleting line with link \"${Link[$j]}\" in file $episode_links_file\e[0m"

                sed -i "/[^0-9].*/d" $episode_numbers_file
                sed -i "/.*$tid/d" $episode_links_file

                #Link[$j]=""
                (( j++ ))
                continue
            fi
        done

        new_episode=false
        current_episode=`cat $current_episode_file`
        for l in "${!EpisodeAndLink[@]}"
        do
            m=`echo "$l" | sed "s/^0*//g"`

            if (( $m > $current_episode ))
            then
                download_link="${EpisodeAndLink[$l]}"
                date=`date +%F`
                time=`date +%R`

                echo "$date - $time: Downloading $anime_name - Episode $l from: $download_link" >> $log_path/$log_file
                echo -e "\e[01;32mDownloading $anime_name - Episode $l from: $download_link\e[0m"

                #transmission-remote -a "$download_link" -s > /dev/null 2>&1

                /usr/bin/curl --silent "http://127.0.0.1:6800/jsonrpc" --header "Content-Type: application/json" --header "Accept: application/json" --data '
                {
                    "jsonrpc": "2.0",
                    "id": "'"${RANDOM}"'",
                    "method": "aria2.addUri",
                    "params": [
                                "token:<some_rpc_token>",
                                [
                                    "'"${download_link}"'"
                                ]
                              ]
                }' > /dev/null

                #echo '{ "jsonrpc": "2.0", "id": "'"${RANDOM}"'", "method": "aria2.addUri", "params": [ "token:<some_rpc_token>", [ "'"${download_link}"'" ] ] }' | /usr/bin/websocat "ws://127.0.0.1:6800/jsonrpc" > /dev/null

                sleep 0.5

                new_episode=true
                gpio_blink=true

            else
                echo -e "\e[01;31m$anime_name - Episode $l is not new.\e[0m"
            fi
        done
        unset EpisodeAndLink

        if [[ $new_episode == true ]]
        then
            new_episode_number=`head -n 1 $episode_numbers_file | sed "s/^0*//g"`
            echo $new_episode_number > $current_episode_file
        fi

    else
        echo -e "\e[01;31mFile $rss_output_path/$anime_name for Anime $anime_name not found. No reason to download.\e[0m"
        exit 1
    fi
done

# custom - 20191231 - rfischer: temporarily comment this, until a decent solution has been found
#if [[ "$1" == "-c" && $gpio_blink == true ]]
#then
#    period=$(( `date +%H%M` + 200 ))
#    echo "heartbeat" | sudo /usr/bin/tee /sys/class/leds/bananapro:green:usr/trigger > /dev/null
#
#    while [[ true ]]
#    do
#        current_time=`date +%H%M`
#        if (( $current_time >= $period ))
#        then
#            echo "none" | sudo /usr/bin/tee /sys/class/leds/bananapro:green:usr/trigger > /dev/null
#            sleep 0.1
#            break
#        fi
#
#        sleep 55
#    done
#
#    #while (( `date +%H%M` != $period ))
#    #do
#        #gpio -g write 4 1
#        #sleep 2
#        #gpio -g write 4 0
#        #sleep 2
#    #done
#fi
