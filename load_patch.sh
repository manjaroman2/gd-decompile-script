#!/bin/bash
source patch.txt
if [[ -z "$exdir" ]] || [[ -z "$gitpatch" ]]; then 
    echo "supply exdir and gitpatch in patch.txt" 
    exit 1
fi
setup_args="$exdir $name"
if [[ ! -z "$pck_file" ]]; then 
    setup_args="$setup_args $pck_file" 
fi
name=$(basename ${gitpatch})
name="${name%.*}"
echo exdir=$exdir 
echo gitpatch=$gitpatch
echo name=$name
mkdir $exdir && cd $exdir && git clone $gitpatch && chmod +x $name/setup.sh && $name/setup.sh $setup_args
