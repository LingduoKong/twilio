#!/bin/bash

m=""
for i in $*
do
    m="$m  $i";
    echo $m;
done
git add -A
git commit -m "$m"
git push -u origin master
