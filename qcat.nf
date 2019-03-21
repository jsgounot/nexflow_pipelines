#!/usr/bin/env nextflow

params.path = './'
params.lib = params.path.split("/").last().split("_")[0];

reads = Channel.fromPath(params.path + "/*fastq.gz")


process qcat {
    input:
    file x from reads;
    output:
    file 'qcat/*' into qcat_res
    
    """
    zcat $x | /mnt/software/unstowable/anaconda/envs/nanopore_py3/bin/qcat -b qcat
    """    
}


process compress_fastq {
    input:
    file fq from qcat_res.flatten()
    output:
    file "${fq}.gz" into qcat_compress_res

    """
    gzip -c ${fq} > ${fq}.gz
    """
}


qcat_compress_res
    .map { file -> tuple( file.name.split("\\.")[0], file ) }
    .groupTuple()
    .set { groupped_by_barcode}

process combine {
  executor 'local'
  publishDir params.lib, mode: 'move'
  
  input:
  set barcode, file("${barcode}.fastq.gz") from groupped_by_barcode  
  output: 
  set barcode, file("${params.lib}_${barcode}/${params.lib}_${barcode}.fastq.gz") into combine_ch

  """
  mkdir ${params.lib}_${barcode}
  cat *.fastq.gz* > ${params.lib}_${barcode}/${params.lib}_${barcode}.fastq.gz
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
