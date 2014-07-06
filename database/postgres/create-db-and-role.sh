#!/bin/bash

myfile=/pg/tmp/db.lock

# check if file exist
if [[ -e $myfile ]];then
	var=$(head -n 1 $myfile | awk -F"|" '{print $1,$2,$3}')
	set -- $var
	DBNAME=$(echo $1)
	USERNAME=$(echo $2)
	PASSWORD=$(echo $3)
fi
rm $myfile

psql -d postgres <<< "create role $USERNAME with password '$PASSWORD';"
psql -d postgres <<< "alter role  $USERNAME with login;"
psql -d postgres <<< "alter role $USERNAME with createdb;"
psql -d postgres <<< "\q"
createdb $DBNAME -U $USERNAME
psql -d postgres <<< "alter role $USERNAME with nocreatedb;"
psql -d postgres <<< "\q"
