#!/usr/bin/env nextflow

params.path = './'
params.lib = params.path.split("/").last().split("_")[0];

reads = Channel.fromPath(params.path + "/*fastq.gz")


process porechop {
    input:
    file x from reads;
    output:
    file 'porechop/*' into porechop_res
    
    """
    /mnt/software/unstowable/anaconda/envs/nanopore_py3/bin/porechop -i $x --format fastq.gz -v 0 -b porechop
    """    
}

porechop_res
    .flatten()
    .map { file -> tuple( file.name.substring(0,4), file ) }
    .groupTuple()
    .set { groupped_by_barcode }

process combine {
  executor 'local'
  publishDir params.lib, mode: 'move'
  
  input:
  set barcode, file('*.fastq.gz') from groupped_by_barcode  
  output: 
  set barcode, file("${params.lib}_${barcode}/${params.lib}_${barcode}.fastq.gz") into combine_ch 

  """
  mkdir ${params.lib}_${barcode}
  cat *.fastq.gz > ${params.lib}_${barcode}/${params.lib}_${barcode}.fastq.gz
  """
} 

combine_ch.println() 

workflow.onComplete {
    def msg = """\
    Pipeline execution summary
    ---------------------------
    Completed at: ${workflow.complete}
    Duration    : ${workflow.duration}
    Success     : ${workflow.success}
    workDir     : ${workflow.workDir}
    exit status : ${workflow.exitStatus}
    """.stripIndent()
 
    sendMail(from: 'lich@gis.a-star.edu.sg', to: 'lich@gis.a-star.edu.sg', subject: 'Nextflow execution completed', body: msg)
    file('work').deleteDir()
}
workflow.onError {
    def msg = """\
    Pipeline execution summary
    ---------------------------
    Failed at   : ${workflow.complete}
    Duration    : ${workflow.duration}
    Success     : ${workflow.success}
    workDir     : ${workflow.workDir}
    exit status : ${workflow.exitStatus}
    """.stripIndent()
    sendMail(from: 'lich@gis.a-star.edu.sg', to: 'lich@gis.a-star.edu.sg', subject: 'Nextflow execution failed', body: msg)
}
