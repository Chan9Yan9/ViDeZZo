#!/bin/bash

function usage() {
  cat << HEREDOC
Usage: $0 -t TARGET_PATH -c CRASH_PATH -s SEEDS_PATH

positional arguments:
  -t, TARGET_PATH absolute pathname of the fuzz target
  -c, CRASH_PATH   absolute pathname of the crashing test case
  -s, SEEDS_PATH   absolute pathname of the corpus

optional arguments:
  -h, --help               show this help message and exit

HEREDOC
  exit 1
}

while getopts ":t:c:s:" o; do
  case "${o}" in
    t)
      target=${OPTARG}
      ;;
    c)
      crash=${OPTARG}
      ;;
    s)
      seeds=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -z $target ]]; then
    echo "[-] -t is missing"
    exit 1
fi

if [[ -z $crash ]]; then
    echo "[-] -c is missing"
    exit 1
fi

if [[ -z $seeds ]]; then
    echo "[-] -s is missing"
    exit 1
fi

echo "[-] target = $target"
echo "[-] crash  = $crash"
echo "[-] seeds  = $seeds"

# step 1: create a private directory
ws=$(mktemp -d)
echo [-] working in $ws

# step 2: create a tester script
echo "#!/bin/bash" > $ws/picire_tester.sh
echo "export ASAN_OPTIONS=detect_leaks=0" >> $ws/picire_tester.sh
echo "$target $crash -pre_seed_inputs=@\$1 2>&1 | grep -q -e \"ERROR\" -e \"runtime error\";" >> $ws/picire_tester.sh
chmod +x $ws/picire_tester.sh
echo [-] created $ws/picire_tester.sh
echo "#!/bin/bash" > $ws/picire_reproduce.sh
echo "export ASAN_OPTIONS=detect_leaks=0" >> $ws/picire_reproduce.sh
echo "$target $crash -pre_seed_inputs=@\$1" >> $ws/picire_reproduce.sh
chmod +x $ws/picire_reproduce.sh
echo [-] created $ws/picire_reproduce.sh
echo "#!/bin/bash" > $ws/picire_latest.sh
echo "export ASAN_OPTIONS=detect_leaks=0" >> $ws/picire_latest.sh
echo "$target $crash -pre_seed_inputs=@\$1" >> $ws/picire_latest.sh
chmod +x $ws/picire_latest.sh
echo [-] created $ws/picire_latest.sh

# step 3: create an input
n=$(awk -F"/" '{print NF + 1}' <<< $seeds)
find $seeds -type f | sort -t/ -k$n > $ws/picire_inputs
echo [-] created $ws/picire_inputs

# step 4: let's start dd
echo [-] starting delta debugging!
time picire --input=$ws/picire_inputs --test=$ws/picire_tester.sh \
	--parallel --subset-iterator=skip --complement-iterator=backward

echo [-] saved output to $ws/picire_inputs.*/picire_inputs
echo [-] run $ws/picire_reproduce.sh $ws/picire_inputs.*/picire_inputs
echo [-] modify and run $ws/picire_latest.sh $ws/picire_inputs.*/picire_inputs