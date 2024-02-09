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


