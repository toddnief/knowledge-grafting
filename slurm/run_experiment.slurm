#!/bin/bash
#SBATCH --job-name=kp_experiments
#SBATCH --mem=256G
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --constraint="a100|h100"
#SBATCH --time=03:00:00 # Note: this is overriden by the Makefile
#SBATCH --array=0-5 # Default; overridden dynamically by Makefile if SINGLE_RUN is set

# Note: Some models require this to be set to load from Huggingface
export HF_AUTO_MODEL_TRUST_REMOTE_CODE=1

# Environment variables passed from Makefile
TIMESTAMP=${TIMESTAMP:-$(date +"%Y%m%d_%H%M%S")}
CONFIG_FILE=${CONFIG:-config_experiments.yaml}
PATCH_CONFIG_FILE=${PATCH_CONFIG:-all_tokens_attn_ffn_all.yaml}

# These should be passed via --export in make
MODEL=${MODEL}
MODEL_DIR=${MODEL_DIR}
DATASET=${DATASET}
DATASET_DIR=${DATASET_DIR}
PATCH_DIRECTION=${DIRECTION}

# Setup dropout experiment param sweep
DROPOUT_RATES=(0.0 0.2 0.4 0.6 0.8 1.0)
DROPOUT=${DROPOUT_RATES[$SLURM_ARRAY_TASK_ID]}

echo "[$SLURM_ARRAY_TASK_ID] Model: $MODEL | Dataset: $DATASET | Patch: $PATCH_CONFIG_FILE | Dropout: $DROPOUT"

# Add overrides if they exist
OVERRIDES=()
[ -n "$MODEL" ] && OVERRIDES+=("model.pretrained=$MODEL")
[ -n "$DATASET" ] && OVERRIDES+=("paths.dataset_name=$DATASET")
[ -n "$DATASET_DIR" ] && OVERRIDES+=("paths.dataset_dir=$DATASET_DIR")
[ -n "$MODEL_DIR" ] && OVERRIDES+=("paths.both_directions_parent=$MODEL_DIR")
[ -n "$PATCH_DIRECTION" ] && OVERRIDES+=("model.patch_direction=$PATCH_DIRECTION")
[ -n "$LM_HEAD_CONFIG" ] && OVERRIDES+=("inference_config.patch_lm_head=$LM_HEAD_CONFIG")
if [ "$SMOKE_TEST" = "true" ] || [ "$SMOKE_TEST" = "1" ]; then
    OVERRIDES+=("smoke_test=1")
else
    OVERRIDES+=("smoke_test=0")
fi
if [ "$OVERRIDE_LAYERS" = "1" ]; then
    OVERRIDES+=("inference_config.override_layers=1")
fi
if [ -n "$EXPERIMENTS_DIR_ADDENDUM" ]; then
    OVERRIDES+=("paths.experiments_dir_addendum=$EXPERIMENTS_DIR_ADDENDUM")
fi
OVERRIDES+=("inference_config.dropout_rate=$DROPOUT")

python src/kp/scripts/run_experiment.py \
  --timestamp "$TIMESTAMP" \
  --experiment-config "$CONFIG_FILE" \
  --patch-config "$PATCH_CONFIG_FILE" \
  --override "${OVERRIDES[@]}"