# nexflow_pipelines

## Requirements:

 - nextflow (19.04)
 - JAVA >= 1.8 (Add this to your .bashrc: `export NXF_JAVA_HOME=/etc/alternatives/java_sdk_1.8.0/`)

To run the qcat pipeline:
```
nextflow qcat.nf --path s3://gis-nanopore-archive/GRIDION/N253_FLO-MIN106_SQK-LSK109/20190709_0628_GA30000_FAK66486_eb66a08d/fastq_pass/
```


## porechop is officially retired
To run the pipeline:

```sh
nextflow  porechop.nf --path /mnt/seq/gridion/N101_FLO-MIN106_SQK-LSK108/ -resume
```
