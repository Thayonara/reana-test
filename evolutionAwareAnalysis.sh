#!/bin/bash

JAR="reanaE.jar"
xms=1024m
xmx=15360m
spl=$1
initial_evolution=0
final_evolution=$2
iterations=$3

COMMAND="java -Xms$xms -Xmx$xmx -jar $JAR"
# Path were we dump and read ADDs for previous analyses
ANALYSES_PATH=Analyses
PERSISTED_ANALYSES_PATH=PersistedAnalyses/$spl
rm -rf "$PERSISTED_ANALYSES_PATH"
# Path were we save analysis stats
LOGS_DIR=$ANALYSES_PATH/logs/tmp
DATA_DIR=$ANALYSES_PATH/logs/data
MEMORY_DIR=$DATA_DIR/memory_usage
TIME_DIR=$DATA_DIR/running_time

MEMORY_LOG_FILE=$MEMORY_DIR/totalMemory${spl}ReanaE.out
TIME_LOG_FILE=$TIME_DIR/totalTime${spl}ReanaE.out

# cleanup previous run

rm -rf $LOGS_DIR

# 1st step: perform the analysis of the original spl
echo "1st step - analysis of the original spl"
# TODO: we have to parameterize the variableStore's location
rm variableStore.add

mkdir -p "$PERSISTED_ANALYSES_PATH"
mkdir -p "$ANALYSES_PATH"
mkdir -p "$LOGS_DIR"
mkdir -p "$MEMORY_DIR"
mkdir -p "$TIME_DIR"

eval "$COMMAND --stats \
  --all-configurations \
  --uml-model=$spl/bm$spl$initial_evolution.xml \
  --feature-model=$spl/fm$spl$initial_evolution.txt \
  --persisted-analyses=$PERSISTED_ANALYSES_PATH"


# 2nd step: perform the analysis of the evolutions

for i in $(seq 1 $iterations ); do
	for e in $(seq $(expr $initial_evolution + 1) $final_evolution); do
		mkdir -p "$LOGS_DIR/$i"
		echo "----------   Iteration $i     Evolution $e   ----------"
		eval "$COMMAND --stats \
      --all-configurations \
      --uml-model=$spl/bm$spl$e.xml \
      --feature-model=$spl/fm$spl$e.txt \
      --persisted-analyses=$PERSISTED_ANALYSES_PATH >> $LOGS_DIR/$i/evolution$e.out"
	done
done

# 3rd step: recover all analyses and total times of all evolutions
for e in $(seq $(expr $initial_evolution + 1) $final_evolution); do
	echo "---------- Evolution $e ----------" >> "$LOGS_DIR/analysisTime.out"
	echo "---------- Evolution $e ----------" >> "$MEMORY_LOG_FILE"
	echo "---------- Evolution $e ----------" >> "$TIME_LOG_FILE"
	for i in $(seq 1 $iterations ); do
		cat "$LOGS_DIR/$i/evolution$e.out" | grep "Total analysis" | awk '{print $4}' >> "$LOGS_DIR/analysisTime.out"
		cat "$LOGS_DIR/$i/evolution$e.out" | grep "Total running" | awk '{print $4}' >> "$TIME_LOG_FILE"
		cat "$LOGS_DIR/$i/evolution$e.out" | grep "Maximum memory" | awk '{print $4}' >> "$MEMORY_LOG_FILE"
	done
done
