#!/bin/bash
#SBATCH --job-name=kg_datasets
#SBATCH --mem=120G
#SBATCH --time=00:30:00

# Note: This enables passing the config file as an argument to the script from the Makefile
CONFIG_FILE=${CONFIG:-config_data_generation.yaml}

python src/kg/scripts/create_dataset.py --config $CONFIG_FILE

