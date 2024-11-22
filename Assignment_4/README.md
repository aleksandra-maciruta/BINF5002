You need anaconda to run this.

```shell
# Initialize anaconda environment
anaconda
# Create a new conda environment
conda create --prefix ./conda-env
# Activate conda environment
conda activate ./conda-env
# Update conda channels
conda update -n base -c conda-forge conda bioconda
# Install the necessary dependencies
conda install --yes --file ./conda-requirements.txt
```
