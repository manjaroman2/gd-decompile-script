#!/bin/bash

godot_engine="3.5.3-stable"
base=$PWD

VERBOSE=false

godot_dirname=""
scons_args="" # use_llvm=yes linker=lld
editor_executable="godot.x11.opt.tools.64"

print_usage() {
    printf "Usage: $(basename "$0") [options] \n"
    echo "    -g|--godot=<path to godot> "
    echo "    -h|--help  Display help"
    echo "    --clang    Use clang for compilation"
    echo "    --lld      Use lld for compilation"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --clang*)
            scons_args="$scons_args use_llvm=yes"
            editor_executable="godot.x11.opt.tools.64.llvm"
            ;; 
        --lld*)
            scons_args="$scons_args linker=lld"
            ;; 
        --ld*)
            scons_args="$scons_args linker=default"
            ;;
        -g=*|--godot=*)
            godot_dirname="${1#*=}"
            if [ -z "$godot_dirname" ]; then 
                echo "no godot directory supplied" 
                exit 1
            fi 
            ;;
        -h|--help*)
            print_usage
            exit 1
            ;;
        *)
            echo "invalid argument $1"
            print_usage
            exit 1
            ;;
    esac
    shift
done

check_godot() {
    godot_engine=$1
    godot_dirname=$2 
    realp=$(realpath $godot_dirname)
    if [ ! -d $godot_dirname ]; then
        echo "$realp is not a directory"
        return 0 
        # exit 1
    else
        if [[ ! $godot_dirname == *$godot_engine ]]; then
            echo "$realp does not end with $godot_engine"
            return 0 
            # exit 1
        else
            if [ ! -d $godot_dirname/.git ]; then
                echo "$realp is not a git repo"
                return 0 
                # exit 1
            else
                r=$(grep -n "url = https://github.com/godotengine/godot.git" $godot_dirname/.git/config)
                if [ -z "$r" ]; then
                    echo "$godot_dirname is not a godot repo"
                    return 0 
                    # exit 1
                fi
            fi
        fi
    fi
    return 1 
}

if [ -z "$godot_dirname" ]; then
    godot_dirname="$base/godot_steam-$godot_engine"
    # has_godot=$(check_godot $godot_engine $godot_dirname)
    # if [ has_godot = true ]; then
    #     echo "$godot_dirname repo exists, skipping download" 
        
else
    has_godot=$(check_godot $godot_engine $godot_dirname)
    if ! $has_godot; then 
        exit 1
    fi
fi



gdnative_dir="$base/gdnative-$godot_engine"

echo Godot Engine $godot_engine: $(realpath $godot_dirname)
echo GDNative $godot_engine: $(realpath $gdnative_dir)
echo Scons arguments: $scons_args

pyston_version="pyston_2.3.5"
scons_cmd() {
    cmd="$base/$pyston_version/bin/scons $@" # --config=force -j1
    if [ "$VERBOSE" = true ]; then 
        cmd="$cmd verbose=yes LINKFLAGS=\"--verbose\""
    else
        cmd="$cmd >/dev/null"
    fi 
    echo $cmd 
    eval $cmd 
}

if [ ! -d "$pyston_version" ]; then
    echo "installing $pyston_version locally ..."
    curl -LO https://github.com/pyston/pyston/releases/download/pyston_2.3.5/pyston_2.3.5_portable_amd64.tar.gz
    tar xf pyston_2.3.5_portable_amd64.tar.gz
    rm pyston_2.3.5_portable_amd64.tar.gz
    cd pyston_2.3.5
    ./pyston -m pip install scons
else
    echo "Pyston: $(realpath $pyston_version)"
fi

if [ ! -f gdre_tools.x86_64 ] || [ ! -f gdre_tools.pck ]; then
    echo "missing gdre_tools ..."
    curl -LO https://github.com/bruvzg/gdsdecomp/releases/download/v0.6.2/GDRE_tools-v0.6.2-linux.zip
    unzip GDRE_tools-v0.6.2-linux.zip
    rm GDRE_tools-v0.6.2-linux.zip
    chmod +x gdre_tools.x86_64
else
    echo "GDRE_Tools: $(realpath gdre_tools.x86_64)"
fi

if [ ! -f steamworks_sdk.zip ]; then
    echo "missing steamworks_sdk.zip ..."
    curl -L https://partner.steamgames.com/downloads/steamworks_sdk_158a.zip -o $base/steamworks_sdk.zip
else
    echo "Steamworks sdk: $(realpath steamworks_sdk.zip)"
fi

# ARG1=${@:$OPTIND:1}
echo "no godot engine supplied, downloading ..."
echo "---------------- installing godot engine ----------------"
cd $base
git clone https://github.com/godotengine/godot.git -b $godot_engine $godot_dirname
git config advice.detachedHead false
cd $godot_dirname/modules
git clone https://github.com/CoaguCo-Industries/GodotSteam.git -b godot3 godotsteam
cd godotsteam/sdk
unzip -o $base/steamworks_sdk.zip -d .. >/dev/null
cd $godot_dirname
echo "compiling godot_steam-$godot_engine ..."
scons_cmd platform=x11 production=yes tools=yes target=release_debug $scons_args
ln -s $godot_dirname/modules/godotsteam/sdk/redistributable_bin/* $godot_dirname/bin/ >/dev/null

echo "---------------- installing gdnative ----------------"
cd $base
git clone https://github.com/CoaguCo-Industries/GodotSteam.git -b gdnative $gdnative_dir
cd $gdnative_dir
git clone --recurse-submodules https://github.com/godotengine/godot-cpp.git -b godot-$godot_engine godot-cpp
cd godot-cpp
echo "compiling godot-cpp ..."
scons_cmd platform=linux generate_bindings=yes target=release $scons_args
cd $gdnative_dir
ln -s $godot_dirname/modules/godotsteam/sdk/public/ godotsteam/sdk/
ln -s $godot_dirname/modules/godotsteam/sdk/redistributable_bin/ godotsteam/sdk/
mkdir bin/
echo "compiling gdnative-$godot_engine ..."
scons_cmd platform=linux production=yes target=release $scons_args
cp $gdnative_dir/bin/linuxbsd/libgodotsteam.so $godot_dirname/bin
# rm -rf $gdnative_dir

cd $base

# create decomp script
cat <<'EOF' >decomp-3.5.3.sh
if [ -z "$1" ]; then
    echo "provide a path to .pck file" 
    exit
fi

create_py() {
    cat <<'EOF1' > fix_gde.py
    from argparse import ArgumentParser
    from pathlib import Path

    p = ArgumentParser()
    p.add_argument("--path", help="Path to game directory", type=Path)

    args = p.parse_args()

    if not args.path:
        p.print_help()
        quit()


    path: Path = args.path

    i = 0
    for x in path.glob("**/*"):
        if x.as_posix().endswith("gd.remap"):
            nn = f"{x.as_posix().split('.')[0]}.gde"
            x.rename(nn)
            i += 1

    print(f"renamed #{i} .gd.remap -> .gde")
EOF1
}

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
cat <<EOF >>decomp-3.5.3.sh
editor_bin="$godot_dirname/bin"
gdnative_dir="$gdnative_dir"
editor_executable="$editor_executable"
EOF
cat <<'EOF' >>decomp-3.5.3.sh
editor_executable="$editor_bin/$editor_executable"
libsteam_path="$output_dir/addons/godotsteam/x11"
key=$(cat key.txt)

# rcv "rm -rf $output_dir"
rc "./gdre_tools.x86_64 --headless --recover=\"$game_pck\" --output-dir=\"$output_dir\" --key=$key"
if [ ! -f fix_gde.py ]; then 
    create_py
fi
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
.vscode/
EOF1

rc "git add . && git commit -am \"init\""

cd .. 

cat <<EOF1 > run_editor.sh 
code "$output_dir"
$editor_executable -e --path "$output_dir"
EOF1
chmod +x run_editor.sh

echo ""
echo "next steps:"
echo "use ./run_editor.sh to open godot"
EOF
chmod +x decomp-3.5.3.sh
echo "run ./decomp-3.5.3.sh"
