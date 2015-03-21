#! /bin/bash

# get config stuff from files in ./config/
key=`cat config/key`
myip=`hostname -I | cut -d " " -f1`
server="`cat config/server`"


# function that sends its first arg to the irc server
function send {
    echo "-> $1"
    echo "$1" >> .botfile
}

IFS=$'\n'

rm .botfile
mkfifo .botfile
# connect to the irc server
tail -f .botfile | openssl s_client -connect $server:6697 | while true; do
    if [[ -z $started ]] ; then
        # join irc channels
        send "USER laracroft laracroft laracroft :laracroft"
        send "NICK laracroft"
        send "JOIN #squidtest"
        send "JOIN #catacombs $key"
        started="yes"
    fi

    read irc
    echo "<- $irc"

    # reply to PINGs
    if `echo $irc | cut -d ' ' -f 1 | grep PING > /dev/null`; then
        send "PONG"
    fi

    if `echo $irc | grep PRIVMSG > /dev/null`; then
        chan="`echo $irc | cut -d ' ' -f3`"
        message="`echo $irc | tr -d '\r' | cut -d ' ' -f4-`"

        # if the message starts with ":laracroft: help" then reply with a help message.
        if `echo "$message" | egrep '^:laracroft: help$' > /dev/null`; then
            send "PRIVMSG $chan :This is a replacement bot for Indianajones. \"?who is alive\",  \"?who is dead\", and \"?free ips\" to use it or \"?help \$command\" for more info. Message squ1d if there are any bugs"

        # if the message starts with ":laracroft: source" then reply with source info.
        elif `echo "$message" | egrep '^:laracroft: source$' > /dev/null`; then
            send "PRIVMSG $chan :My source is now available at https://github.com/squidboylan/laracroft it is pretty bad though so be careful."

        # if the message is ":laracroft: $box is " store the following text in a file with the box's name
        elif `echo "$message" | egrep '^:laracroft: ([a-zA-Z]+[-]*[a-zA-Z]*) is ' > /dev/null`; then
            box=`echo $message|tr -d '\r' | cut -d ' ' -f2`
            info=`echo $message | cut -d ' ' -f4-`
            echo $info > boxinfo/$box
            send "PRIVMSG $chan :done o7"

        # help message for the "?who is alive" command
        elif `echo "$message" | egrep '^:\?help who is alive$' > /dev/null`; then
            send "PRIVMSG $chan :?who is alive shows what ips are up and their name in DNS"

        # help message for the "?who is dead" command
        elif `echo "$message" | egrep '^:\?help who is dead$' > /dev/null`; then
            send "PRIVMSG $chan :?who is dead shows what ips in DNS are down"

        # help message for the "?free ips" command
        elif `echo "$message" | egrep '^:\?help free ips$' > /dev/null`; then
            send "PRIVMSG $chan :?free ips shows what ips are down"
        
        # use arp-scan to check what boxes are alive on the local subnet.
        elif `echo $message | egrep '^:\?who is alive$' > /dev/null`; then

            # store the alive IPs in "temp" (this should get changed to use `tempfile` at some point)
            `sudo arp-scan -I eth0 --localnet > temp`

            # store this box's IP in a temp
            echo $myip >> temp

            # sort the contents of temp and also delete duplicate IPs
            `egrep '^131' temp | cut -f1 | sort | uniq > temp2`
            reply="`cat temp2`"

            # for every IP in temp2 get its hostname and send that to the channel
            for i in $reply; do
                if `host $i > /dev/null`; then
                    name=`host $i | cut -d $'\n' -f2 | cut -d ' ' -f5 | cut -d '.' -f1`
                    ip=`echo $i | cut -d '.' -f4`
                    send "PRIVMSG $chan :$ip $name"
                    sleep 1
                # if the IP isn't in DNS report that instead of saying nothing about its name.
                else
                    ip=`echo $i | cut -d '.' -f4`
                    send "PRIVMSG $chan :$ip (is alive but not in DNS)" 
                    sleep 1
                fi
            done

        # Use arp-scan to figure out what IPs are available on the local subnet.
        elif `echo $message | egrep '^:\?free ips$' > /dev/null`; then

            `sudo arp-scan -I eth0 --localnet > temp`
            echo $myip >> temp

            `egrep '^131' temp | cut -f1 | sort | uniq > temp2`
            
            ips="`cat temp2`"

            # The IPs on this subnet are stored in config/ips there must be a better way to do this, but I don't
            # know it.
            `cat config/ips > temp3`

            # For every IP that is alive, do an inverse grep through temp3 to get rid of the ip, when the loop is
            # done temp3 will only contain IPs that are available.
            for i in $ips; do
                `grep -v "$i" temp3  > temp4`
                `cat temp4 > temp3`
            done
            
            reply="`cat temp3`"

            # For every ip that is available, check if it has a hostname and send it to the channel.
            for i in $reply; do
                if `host $i > /dev/null`; then
                    name=`host $i | cut -d $'\n' -f2 | cut -d ' ' -f5 | cut -d '.' -f1`
                    ip=`echo "$i" | cut -d '.' -f4`
                    send "PRIVMSG $chan :$ip is not responding but is \"$name\" in DNS"
                    sleep 1 
		        else 
                    ip=`echo "$i" | cut -d '.' -f4`
                    send "PRIVMSG $chan :$ip is not responding and is not in DNS"
                    sleep 1
                fi
            done

        # Use arp-scan to find IPs that dont respond but that have a hostname associated with them.
        # Almost identical to "?free ips".
        elif `echo $message | egrep '^:\?who is dead$' > /dev/null`; then
            `sudo arp-scan -I eth0 --localnet > temp`
            echo $myip >> temp

            `egrep '^131' temp | cut -f1 | sort | uniq > temp2`
            
            ips="`cat temp2`"

            `cat config/ips > temp3`
            for i in $ips; do
                `grep -v "$i" temp3  > temp4`
                `cat temp4 > temp3`

            done
                
            reply="`cat temp3`"
            for i in $reply; do
                if `host $i > /dev/null`; then
                    name=`host $i | cut -d $'\n' -f2 | cut -d ' ' -f5 | cut -d '.' -f1`
                    ip=`echo "$i" | cut -d '.' -f4`
                    send "PRIVMSG $chan :$ip, $name is dead"
                    sleep 1
                fi
            done

        # The next 4 things are just replying to things are just replying to different messages, nothing crazy.
        elif `echo $message | egrep  "^:\?who is your master$" > /dev/null`; then
            send "PRIVMSG $chan :The almighty squ1d is my master"

        elif `echo $message | egrep  "^:\?who am i$" > /dev/null`; then
            user="`echo $irc | cut -d ':' -f2 | cut -d '!' -f1`"
            send "PRIVMSG $chan :You are $user"

        elif `echo $message | egrep  "^:\?who are you$" > /dev/null`; then
            send "PRIVMSG $chan :I am laracroft, and I have been raiding (ca)t(ac)ombs since 1996"

        elif `echo $message | egrep  "^:\?who is nibz$" > /dev/null`; then
            send "PRIVMSG $chan :nibz is an awesome cat" 

        # Retrieve info about a box by looking for the box in boxinfo/ and then sending the contents of its file
        # to the channel.
        elif `echo $message | egrep "^:\?who is" > /dev/null`; then
            box="`echo $message|tr -d '\r' | cut -d ' ' -f3 | cut -d '/' -f1`"
            if  [ -f boxinfo/$box ]; then
                echo "boxinfo/$file"
                response=`cat boxinfo/$box`
                send "PRIVMSG $chan :$box is $response"
                sleep 1
            else
                send "PRIVMSG $chan :huh?"
            fi
        fi
    fi
done
