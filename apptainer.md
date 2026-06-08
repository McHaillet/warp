Create the apptainer:

```
sudo apptainer build warp.sif warp.def
```

Install WarpTools into the apptainer:

```
singularity exec --nv \
  --bind /home/mchaillet/software/warp:/warp \
  warp.sif bash -c '
    source /opt/conda/etc/profile.d/conda.sh
    conda activate warp_build
    cd /warp
    bash scripts/build-native.sh -j 8
    bash scripts/publish-unix.sh
  '
```
