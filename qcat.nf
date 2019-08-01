#!/usr/bin/env nextflow

params.help = false
params.path = false
params.lib  = false
params.min_score = 60
params.qcat_path = '/mnt/software/unstowable/miniconda3-4.6.14/envs/qcat-1.1.0/bin/qcat'

def helpMessage() {
  // adapted from nf-core
  //  log.info nfcoreHeader()
    log.info"""
    =========================================================================================================================================
    Usage:
    The typical command for running the pipeline is as follows:
      nextflow run qcat.nf  --path PATH_TO_READS
    Mandatory arguments:
      --path                        Path to a folder containing all input fastq files (this will be recursively searched for *fastq.gz files)
    Optional arguments:
      --lib                         Libary prefix after demux (default: Automatically detected from the file name NXXX_FLO-XXX_SQK-XXX ==> NXXX)
    Parameters for qcat:
      --min_score                   Minimum barcode score. Barcode calls with a lower score will be discarded. Must be between 0 and 100. (default: 60)
      --qcat_path                   The path for qcat executable (This will be fixed after nextflow 19.07. See: https://github.com/nextflow-io/nextflow/issues/1195)
    AWSBatch:
      ==== Under construction ====
      --awsqueue                    The AWSBatch JobQueue that needs to be set when running on AWSBatch
      --awsregion                   The AWS Region for your AWS Batch job to run on
    =========================================================================================================================================
    """.stripIndent()
}
if (params.help){
    helpMessage()
    exit 0
}
if (!params.path){
   helpMessage()
   log.info"""
   [Error] --path is required
   """.stripIndent()
   exit 0
}

if (!params.lib){
    try{
	params.lib = (params.path =~ /N[0-9]+_[A-Z0-9\-]+_[A-Z0-9\-]+/)[0].split("_")[0]
    } catch(Exception ex) {
        log.info"""
        [Error] Cannot detect the required pattern NXXX_{FLOWCELL-ID}_{KIT-ID}. Please specify output prefix using --lib.
        """
        exit 0
    }
   //params.path.split("/")[4].split("_")[0]
}

ch_reads = Channel.fromPath(params.path + "*fastq.gz")

process qcat {
    tag "$x"
    label 'process_lowCPU_highRAM'        
    //conda '/mnt/software/unstowable/miniconda3-4.6.14/envs/qcat-1.1.0/'
    
    input:
    file x from ch_reads;
    output:
    file 'qcat/*' into ch_qcat_res 
    
    """
    zcat $x | ${params.qcat_path} -b qcat --trim --min-score ${params.min_score} -t $task.cpus
    """    
}


process compress_fastq {
    tag "$fq"
    label 'process_low'
    
    input:
    file fq from ch_qcat_res.flatten()
    output:
    file "${fq}.gz" into ch_qcat_compress_res

    """
    gzip -c ${fq} > ${fq}.gz
    """
}

ch_qcat_compress_res
    .map { file -> tuple( file.name.split("\\.")[0], file ) }
    .groupTuple()
    .set { ch_groupped_by_barcode}

process combine {
    tag "$file"
    label 'process_low'

    publishDir params.lib, mode: 'move'
  
    input:
    set barcode, file("${barcode}.fastq.gz") from ch_groupped_by_barcode  
    output: 
    set barcode, file("${params.lib}_${barcode}/${params.lib}_${barcode}.fastq.gz") into ch_combine

    """
    mkdir ${params.lib}_${barcode}
    cat *.fastq.gz* > ${params.lib}_${barcode}/${params.lib}_${barcode}.fastq.gz
    """
} 

ch_combine.println() 


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
