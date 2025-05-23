include .env # sets PARTITION

_conda = conda
ENV_NAME = kp

workdir = ./
scripts_dir = ${workdir}
slurm_dir = ${workdir}slurm/
logs_dir = ${workdir}logs/

TIMESTAMP := $(shell date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE_PREFIX = ${logs_dir}${TIMESTAMP}
output_file = ${LOG_FILE_PREFIX}_res.txt
err_file = ${LOG_FILE_PREFIX}_err.txt

SBATCH = $(_conda) run -n ${ENV_NAME} sbatch

# Usage: make train CONFIG=config_train.yaml
.PHONY: train
train:
	${SBATCH} \
	--mem=64GB \
	--partition=$(PARTITION) \
	--nodes=1 \
	--gres=gpu:1 \
	--output="$(output_file)" \
	--error="$(err_file)" \
	$(slurm_dir)train.slurm

# Usage: make create_datasets CONFIG=config_datasets.yaml
.PHONY: create_datasets
create_datasets:
	${SBATCH} \
	--partition=$(PARTITION) \
	--output="$(output_file)" \
	--error="$(err_file)" \
	$(slurm_dir)create_datasets.slurm

# Usage: make experiment CONFIG=config_experiments.yaml PATCH_CONFIG=config_patches.yaml
# SINGLE_RUN=0 to do baseline eval
# Also note: Using the eval command changes the context so need to explicity pass variables
.PHONY: experiment
experiment:
	$(eval NOW := $(or $(TIMESTAMP),$(shell date +"%Y-%m-%d_%H-%M-%S")))
	$(eval LOG_FILE_PREFIX := ${logs_dir}${NOW})
	$(eval output_file := ${LOG_FILE_PREFIX}_res.txt)
	$(eval err_file := ${LOG_FILE_PREFIX}_err.txt)
	$(eval ARRAY_RANGE := $(if $(SINGLE_RUN),$(SINGLE_RUN),0-5))
	$(eval TIME_LIMIT := $(if $(filter-out false,$(SMOKE_TEST)),00:20:00,01:00:00))
	$(eval OVERRIDE_LAYERS := $(if $(OVERRIDE_LAYERS),1,0))
	$(eval EXPERIMENTS_DIR_ADDENDUM := $(if $(EXPERIMENTS_DIR_ADDENDUM),$(EXPERIMENTS_DIR_ADDENDUM),))
	$(eval JOB_ID := $(shell ${SBATCH} --parsable \
		--partition=$(PARTITION) \
		--output="$(output_file)" \
		--error="$(err_file)" \
		--array=$(ARRAY_RANGE) \
		--time=$(TIME_LIMIT) \
		--export=ALL,TIMESTAMP=$(NOW),CONFIG=$(CONFIG),PATCH_CONFIG=$(PATCH_CONFIG),MODEL=$(MODEL),MODEL_DIR=$(MODEL_DIR),DATASET=$(DATASET),DATASET_DIR=$(DATASET_DIR),DIRECTION=$(DIRECTION),SMOKE_TEST=$(SMOKE_TEST),LM_HEAD_CONFIG=$(LM_HEAD_CONFIG),OVERRIDE_LAYERS=$(OVERRIDE_LAYERS),EXPERIMENTS_DIR_ADDENDUM=$(EXPERIMENTS_DIR_ADDENDUM) \
		$(slurm_dir)run_experiment.slurm))
	@echo "Submitted run_experiment job: $(JOB_ID)"

# ${SBATCH} \
# --dependency=afterok:$(JOB_ID) \
# --partition=$(PARTITION) \
# --output="$(output_file)" \
# --error="$(err_file)" \
# --export=ALL,TIMESTAMP=$(NOW),MODEL=$(MODEL),DATASET=$(DATASET),DIRECTION=$(DIRECTION),DATASET_DIR=$(DATASET_DIR),MODEL_DIR=$(MODEL_DIR) \
# $(slurm_dir)analyze_experiment.slurm