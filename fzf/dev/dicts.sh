#!/bin/bash

# https://stackoverflow.com/questions/6149679/multidimensional-associative-arrays-in-bash

declare -A PERSONS

declare -A PERSONS=(\
	[3]='([FNAME]="3" [LNAME]="Memering" )'\
	[2]='([FNAME]="1" [LNAME]="Murray" )'\
	[1]='([FNAME]="2" [LNAME]="Andrew" )' )
declare -p PERSONS

for KEY in "${!PERSONS[@]}"; do
   printf "$KEY - ${PERSONS["$KEY"]}\n"
#   eval "declare -A PERSON=${PERSONS["$KEY"]}"
   declare -A PERSON=${PERSONS["$KEY"]}
   printf "${PERSONS["$KEY"]}\n"
   for KEY in "${!PERSON[@]}"; do
      printf "INSIDE $KEY - ${PERSON["$KEY"]}\n"
   done
done
