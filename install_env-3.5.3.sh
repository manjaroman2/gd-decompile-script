#!/bin/bash

base=$PWD
godot_engine="3.5.3-stable"

godot_dirname="$base/godot_steam-$godot_engine"
gdnative_dir="$base/gdnative-$godot_engine"


if [ ! -f gdre_tools.x86_64 ] || [ ! -f gdre_tools.pck ]; then
    echo "missing gdre_tools ..."
    curl -LO https://github.com/bruvzg/gdsdecomp/releases/download/v0.6.2/GDRE_tools-v0.6.2-linux.zip
    unzip GDRE_tools-v0.6.2-linux.zip
    rm GDRE_tools-v0.6.2-linux.zip
    chmod +x gdre_tools.x86_64
fi

if [ ! -f steamworks_sdk_158a.zip ]; then
    echo "missing steamworks sdk ..."
    curl -LO https://partner.steamgames.com/downloads/steamworks_sdk_158a.zip
fi

echo "---------------- installing godot engine ----------------"
cd $base
git clone https://github.com/godotengine/godot.git -b $godot_engine $godot_dirname
cd $godot_dirname/modules 
git clone https://github.com/CoaguCo-Industries/GodotSteam.git -b godot3 godotsteam
cd godotsteam/sdk
unzip -o $base/steamworks_sdk_158a.zip -d .. >/dev/null
cd $godot_dirname
echo "compiling godot_steam-$godot_engine ..."
scons platform=x11 production=yes tools=yes target=release_debug >/dev/null
ln -s $godot_dirname/modules/godotsteam/sdk/redistributable_bin/* $godot_dirname/bin/ >/dev/null

echo "---------------- installing gdnative ----------------"
cd $base
git clone https://github.com/CoaguCo-Industries/GodotSteam.git -b gdnative $gdnative_dir 
cd $gdnative_dir
git clone --recurse-submodules https://github.com/godotengine/godot-cpp.git -b godot-$godot_engine godot-cpp
cd godot-cpp
echo "compiling godot-cpp ..."
scons platform=linux generate_bindings=yes target=release >/dev/null
cd $gdnative_dir
ln -s $godot_dirname/modules/godotsteam/sdk/public/ godotsteam/sdk/
ln -s $godot_dirname/modules/godotsteam/sdk/redistributable_bin/ godotsteam/sdk/
mkdir bin/
echo "compiling gdnative-$godot_engine ..."
scons platform=linux production=yes target=release >/dev/null
cp $gdnative_dir/bin/linuxbsd/libgodotsteam.so $godot_dirname/bin
# rm -rf $gdnative_dir

echo $godot_dirname
cd $base
 
# create decomp script 
cat <<'EOF' > decomp-3.5.3.sh 
if [ -z "$1" ]; then
    echo "provide a path to .pck file" 
    exit
fi
rc() {
    echo $1 
    eval "$1">/dev/null
}

rcv() {
    echo $1 
    eval "$1"
}

old_pwd=$PWD
game_pck=$1
if [[ ! $game_pck == *.pck ]]; then
    echo "not a .pck"
    exit
fi

if [ -z "$2" ]; then
    game_name="$(basename "$game_pck")"
    game_name=${game_name//[[:blank:]]/}
    game_name=${game_name%.pck}
    game_name=${game_name##*/}
    output_dir=$(dirname "$game_pck")
    output_dir=$(dirname "$output_dir")
    output_dir="$output_dir/"$game_name"_Extracted"
    output_dir=$(realpath $output_dir)
else
    output_dir=$2
    output_dir=$(realpath $output_dir)
fi
if [ ! -d "$output_dir" ]; then
    mkdir $output_dir
fi
if [ ! -w "$output_dir" ]; then
    echo "can't write to directory $output_dir"
    exit
fi
echo "output directory: $output_dir"

EOF
cat <<EOF >> decomp-3.5.3.sh
editor_bin="$godot_dirname/bin"
gdnative_dir="$gdnative_dir"
EOF
cat <<'EOF' >> decomp-3.5.3.sh 
editor_executable="$editor_bin/godot.x11.opt.tools.64"
libsteam_path="$output_dir/addons/godotsteam/x11"
key=$(cat key.txt)

rcv "rm -rf $output_dir"
rc "./gdre_tools.x86_64 --headless --recover=\"$game_pck\" --output-dir=\"$output_dir\" --key=$key"
rcv "python fix_gde.py --path=$output_dir"
rcv "mkdir -p $libsteam_path"
rcv "cp $gdnative_dir/bin/linuxbsd/libgodotsteam.so $libsteam_path"
rcv "cp $gdnative_dir/godotsteam/sdk/redistributable_bin/linux64/libsteam_api.so $libsteam_path"
rcv "cp $gdnative_dir/bin/linuxbsd/libgodotsteam.so $editor_bin"
rcv "cp $gdnative_dir/godotsteam/sdk/redistributable_bin/linux64/libsteam_api.so $editor_bin"
rcv "echo 2444170 > $editor_bin/steam_appid.txt" 

rc "cd $output_dir" 
rc "git init && git config core.autocrlf false && git config user.email null@null.x && git config user.name null"

cat <<EOF1 > .gitignore
bbcheat/
*.sh
*.log
*.import
*.godot
EOF1

rc "git add . && git commit -am \"init\""

cd .. 

cat <<EOF1 > run_editor.sh 
code $output_dir
$editor_executable -e --path $output_dir"
EOF1
chmod +x run_editor.sh

echo ""
echo "next steps:"
echo "use ./run_editor.sh to open godot"
EOF
chmod +x decomp-3.5.3.sh
echo "run ./decomp-3.5.3.sh"
