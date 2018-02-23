#!/bin/bash

read -p "Thing to fix> " IT
read -p "Who will pay> " THEM
read -p "Is who will pay plural? (Y/N)> " PLURAL

HASHTAG="#Make$(echo -n $IT | sed -e 's/\b\([a-z]\)/\U\1/g' -e 's/ //g')GreatAgain"

if echo $PLURAL | grep -qi '^y' ; then
	ISARE="are"
else
	ISARE="is"
fi	

cat <<-EOF
	People ask me about our $IT, they do.  And you know 
	what I tell them? ${THEM^} $ISARE not sending us their 
	best $IT. But when I'm president, I'm going to get rid of 
	$IT, and build a wall to keep them out. And I'm going 
	to make $THEM pay for it. $HASHTAG
EOF

