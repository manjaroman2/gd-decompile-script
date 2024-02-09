#!/bin/bash
source patch.txt
if [[ -z "$exdir" ]] || [[ -z "$gitpatch" ]] || [[ ! -z "$pck_file" ]]; then 
    echo "supply exdir, gitpatch and pck_file in patch.txt" 
    exit 1
fi
name=$(basename ${gitpatch})
name="${name%.*}"
echo exdir=$exdir 
echo gitpatch=$gitpatch
echo name=$name
git clone $gitpatch && chmod +x $name/setup.sh 

./decomp-3.5.3.sh $pck_file $exdir

chmod +x $name/setup.sh 
$name/setup.sh 

echo "python $2/apply.py" 
echo "python $2/create_patch.py" 
