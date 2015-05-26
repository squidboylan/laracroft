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

# function that takes two args; a string to check and a regex pattern to look for
function has {
	$(echo "$1" | grep -Pi "$2" > /dev/null)
}

# function that takes two args; a channel destination and the message to send
function say {
	send "PRIVMSG $1 :$2"
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
    	nick="`echo $irc | cut -d '!' -f1`"
        chan="`echo $irc | cut -d ' ' -f3`"
        message="`echo $irc | tr -d '\r' | cut -d ' ' -f4- | cut -c 2-`"
        set -- $message # tokenizes each word of $message into the positional params $1, $2, ..., etc.
	
	# if the message starts with the bot's name
	if has "$1" "^laracroft: " ; then
		if has "$2" "^help$" ; then
			# if the message starts with "laracroft: help" then reply with a help message.
			say $chan "This is a replacement bot for Indianajones. \"?who is alive\",  \"?who is dead\", and \"?free ips\" to use it or \"?help \$command\" for more info. Message squ1d if there are any bugs."
		elif has "$2" "^source$" ; then
			# if the message starts with "laracroft: source" then reply with source info.
			say $chan "My source is now available at https://github.com/squidboylan/laracroft it is pretty bad though so be careful."
		elif has "$2 $3 " "^([a-zA-Z]+[-]*[a-zA-Z]*) is " ; then
			# if the message is "laracroft: $box is " store the following text in a file with the box's name
			box="$2"
			info=`echo $message | cut -d ' ' -f4-`
			echo $info > boxinfo/$box
			say $chan "done o7"
		fi
	
	#if the message starts with asking for help
	elif has "$1" "^\?help$" ; then
		# help message for the "?who is alive" command
		if has "$2 $3 $4" "^who is alive$" ; then
			say $chan "?who is alive shows what ips are up and their name in DNS"
			
		# help message for the "?who is dead" command	
		elif has "$2 $3 $4" "^who is dead$" ; then
			say $chan "?who is dead shows what ips in DNS are down"
		
		# help message for the "?free ips" command
		elif has "$2 $3" "^free ips$" ; then
			say $chan "?free ips shows what ips are down"
			
		fi
        
        # use arp-scan to check what boxes are alive on the local subnet.
        elif has "$1 $2 $3" "^\?who is alive$" ; then
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
			say $chan "$ip $name"
			sleep .6
			
			# if the IP isn't in DNS report that instead of saying nothing about its name.
			else
			ip=`echo $i | cut -d '.' -f4`
			say $chan "$ip (is alive but not in DNS)"
			sleep .6
			
                	fi
                done

        # Use arp-scan to figure out what IPs are available on the local subnet.
        elif has "$1 $2" "^\?free ips$" ; then
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
                    say $chan "$ip is not responding but is \"$name\" in DNS"
                    sleep .6 
		else 
                    ip=`echo "$i" | cut -d '.' -f4`
                    send "PRIVMSG $chan :$ip is not responding and is not in DNS"
                    sleep .6
                fi
            done

        # Use arp-scan to find IPs that dont respond but that have a hostname associated with them.
        # Almost identical to "?free ips".
        elif has "$1 $2 $3" "^\?who is dead$" ; then
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
                    say $chan "$ip, $name is dead"
                    sleep .6
                fi
            done

        # The next 4 things are just replying to things are just replying to different messages, nothing crazy.
        elif has "$message" "^\?who is your master$" ; then say $chan "The almighty squ1d is my master"
        elif has "$message" "^\?who am i$" ; then say $chan "You are $nick"
        elif has "$message" "^\?who are you$" ; then say $chan "I am laracroft, and I have been raiding (ca)t(ac)ombs since 1996"
	elif has "$message" "^\?who is nibz$" ; then say $chan "nibz is an awesome cat"

        # Retrieve info about a box by looking for the box in boxinfo/ and then sending the contents of its file
        # to the channel.
        elif has "$message" "^\?who is" ; then
            box="$3"
            if  [ -f boxinfo/$box ]; then
                echo "boxinfo/$file"
                response=`cat boxinfo/$box`
                say $chan "$box is $response"
                sleep .6
            else
            	say $chan "huh?"
            fi
        fi # finally
        set -- # reset positional params, just 'cuz
    fi #end of "if PRIVMSG block"
done
