#!/bin/bash
source patch.txt
if [[ -z "$exdir" ]] || [[ -z "$gitpatch" ]] || [[ -z "$pck_file" ]]; then 
    echo "supply exdir, gitpatch and pck_file in patch.txt" 
    exit 1
fi

exdir=$(realpath $exdir)
./decomp-3.5.3.sh $pck_file $exdir

name=$(basename ${gitpatch})
name="${name%.*}"
echo exdir=$exdir 
echo gitpatch=$gitpatch
echo name=$name
git clone $gitpatch

cat <<EOF >$name/common.py
exdir="$(realpath $exdir)"
EOF

chmod +x $name/setup.sh 
$name/setup.sh $exdir $(realpath $name)

echo "python $name/apply.py" 
echo "python $name/create_patch.py" 
