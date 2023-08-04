#!/bin/bash

get_seeded_random()
{
  seed="$1"
  openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt \
    </dev/zero 2>/dev/null
  }

# extract_configurations()
# {
#
# }

# Default values
xms=1024m
xmx=15360m
initial_evolution=0
samples=100
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Usage: ./evolutionAwareVerification.sh <SPL> <Maximum evolution> [JAR1] [JAR2]"
    exit 0
fi

spl=$1
final_evolution=$2

if [ $# -eq 2 ]
  then
    REANA_JAR="reana.jar"
    REANAE_JAR="reanaE.jar"
  else
    REANA_JAR=$3
    REANAE_JAR=$4
fi

COMMAND_REANA="java -Xms$xms -Xmx$xmx -jar $REANA_JAR"
COMMAND_REANAE="java -Xms$xms -Xmx$xmx -jar $REANAE_JAR"

# Path were we dump and read ADDs for previous analyses
PERSISTED_ANALYSES_PATH=Verification/$spl

# Path were we save analysis stats
LOGS_DIR=$PERSISTED_ANALYSES_PATH/logs
RESULTS_DIR=$PERSISTED_ANALYSES_PATH/results
CONFIGURATIONS_DIR=$PERSISTED_ANALYSES_PATH/configurations

# results separator in log files
separator="========================================="

# 1st step: perform the analysis of the original spl
echo "1st step - analysis of the original spl"
rm -rf "$PERSISTED_ANALYSES_PATH"
# TODO: we have to parameterize the variableStore's location
rm variableStore.add

mkdir -p "$PERSISTED_ANALYSES_PATH"
mkdir -p "$LOGS_DIR"
mkdir -p "$LOGS_DIR/reana"
mkdir -p "$LOGS_DIR/reanaE"
mkdir -p "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR/reana"
mkdir -p "$RESULTS_DIR/reanaE"
mkdir -p "$CONFIGURATIONS_DIR"

eval "$COMMAND_REANA --all-configurations                                \
  --uml-model=$spl/bm$spl$initial_evolution.xml       \
  --feature-model=$spl/fm$spl$initial_evolution.txt   \
  >> $LOGS_DIR/bootstrap.out"

# Extract the results of the initial model

awk "/$separator/{flag=1;next}/$separator/{flag=0;next}flag" "$LOGS_DIR/bootstrap.out" | head -n -3 >> "$RESULTS_DIR/bootstrap.out"

# Extract the configurations of the initial model

CONFIGURATIONS=configurations$initial_evolution.txt
grep -Po "(?<=\[).*?(?=\])" "$RESULTS_DIR/bootstrap.out" | tr -d " \t\r" | shuf -n "$samples" | sort >> "$CONFIGURATIONS_DIR/$CONFIGURATIONS"

# 2nd step: perform the analysis of the evolutions

for e in $(seq $((initial_evolution)) $final_evolution); do
  CONFIGURATIONS=configurations$e.txt
  echo "---------- Evolution $e ----------"
  # Run Reana
  # Run ReanaE
  eval "$COMMAND_REANA --configurations-file=$CONFIGURATIONS_DIR/$CONFIGURATIONS  \
    --uml-model=$spl/bm$spl$e.xml                              \
    --feature-model=$spl/fm$spl$e.txt                          \
    >> $LOGS_DIR/reana/evolution$e.out"
      eval "$COMMAND_REANAE --configurations-file=$CONFIGURATIONS_DIR/$CONFIGURATIONS  \
    --uml-model=$spl/bm$spl$e.xml                              \
    --feature-model=$spl/fm$spl$e.txt                          \
    --persisted-analyses=$PERSISTED_ANALYSES_PATH              \
    >> $LOGS_DIR/reanaE/evolution$e.out"

  # extract results
  # we need to cut out some leftover lines (number of configurations and so on)
  # that are left over after the awk command
  headNReana=3
  headNReanaE=2
  if ((e == 0)); then
    headNReana=3
    headNReanaE=3
  fi

  awk "/$separator/{flag=1;next}/$separator/{flag=0;next}flag" "$LOGS_DIR/reana/evolution$e.out" | head -n -"$headNReana" >> "$RESULTS_DIR/reana/evolution$e.out"
  awk "/$separator/{flag=1;next}/$separator/{flag=0;next}flag" "$LOGS_DIR/reanaE/evolution$e.out" | head -n -"$headNReanaE" >> "$RESULTS_DIR/reanaE/evolution$e.out"

  # extract configurations and add new features for next evolution
  CONFIGURATIONS=configurations$((e+1)).txt
  NEW_CONFIGURATIONS=configurations$((e+1)).txt.new
  grep -Po "(?<=\[).*?(?=\])" "$RESULTS_DIR/reana/evolution$e.out" | tr -d " \t\r" | sort > "/tmp/$CONFIGURATIONS"
  sed "s/$/,o_$((e+1))/" "/tmp/$CONFIGURATIONS" > "/tmp/$NEW_CONFIGURATIONS"
  cat "/tmp/$CONFIGURATIONS" "/tmp/$NEW_CONFIGURATIONS" >> "$CONFIGURATIONS_DIR/$CONFIGURATIONS"
  # cat "/tmp/$CONFIGURATIONS" >> "$CONFIGURATIONS_DIR/$CONFIGURATIONS"

  echo "Comparing results of evolution $e"
  diff "$RESULTS_DIR/reana/evolution$e.out" "$RESULTS_DIR/reanaE/evolution$e.out" > /dev/null
  if $?; then
    echo -e "${RED}WARNING: Found difference between results for Reana and ReanaE (evolution $e) ${NC}"
  else
    echo -e "${GREEN}Results for evolutions Reana and ReanaE match (evolution $e) ${NC}"
  fi


done
