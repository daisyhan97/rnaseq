//
// Gene/transcript quantification with RSEM
//

params.calculateexpression_options = [:]
params.samtools_sort_options       = [:]
params.samtools_index_options      = [:]
params.samtools_stats_options      = [:]
params.merge_counts_options        = [:]

include { RSEM_CALCULATEEXPRESSION } from '../../modules/nf-core/modules/rsem/calculateexpression/main' addParams( options: params.calculateexpression_options )
include { RSEM_MERGE_COUNTS        } from '../../modules/local/rsem_merge_counts'                       addParams( options: params.merge_counts_options        )
include { BAM_SORT_SAMTOOLS        } from '../nf-core/bam_sort_samtools'                                addParams( sort_options: params.samtools_sort_options, index_options: params.samtools_index_options, stats_options: params.samtools_stats_options )

workflow QUANTIFY_RSEM {
    take:
    reads // channel: [ val(meta), [ reads ] ]
    index // channel: /path/to/rsem/index/

    main:

    ch_versions = Channel.empty()

    //
    // Quantify reads with RSEM
    //
    RSEM_CALCULATEEXPRESSION ( reads, index )
    ch_versions = ch_versions.mix(RSEM_CALCULATEEXPRESSION.out.versions.first())

    //
    // Sort, index BAM file and run samtools stats, flagstat and idxstats
    //
    BAM_SORT_SAMTOOLS ( RSEM_CALCULATEEXPRESSION.out.bam_star )
    ch_versions = ch_versions.mix(BAM_SORT_SAMTOOLS.out.versions)

    //
    // Merge counts across samples
    //
    RSEM_MERGE_COUNTS (
        RSEM_CALCULATEEXPRESSION.out.counts_gene.collect{it[1]},       // [meta, counts]: Collect the second element (counts files) in the channel across all samples
        RSEM_CALCULATEEXPRESSION.out.counts_transcript.collect{it[1]}
    )
    ch_versions = ch_versions.mix(RSEM_MERGE_COUNTS.out.versions)

    emit:
    counts_gene              = RSEM_CALCULATEEXPRESSION.out.counts_gene       // channel: [ val(meta), counts ]
    counts_transcript        = RSEM_CALCULATEEXPRESSION.out.counts_transcript // channel: [ val(meta), counts ]
    stat                     = RSEM_CALCULATEEXPRESSION.out.stat              // channel: [ val(meta), stat ]
    logs                     = RSEM_CALCULATEEXPRESSION.out.logs              // channel: [ val(meta), logs ]
    bam_star                 = RSEM_CALCULATEEXPRESSION.out.bam_star          // channel: [ val(meta), bam ]
    bam_genome               = RSEM_CALCULATEEXPRESSION.out.bam_genome        // channel: [ val(meta), bam ]
    bam_transcript           = RSEM_CALCULATEEXPRESSION.out.bam_transcript    // channel: [ val(meta), bam ]

    bam                      = BAM_SORT_SAMTOOLS.out.bam                      // channel: [ val(meta), [ bam ] ]
    bai                      = BAM_SORT_SAMTOOLS.out.bai                      // channel: [ val(meta), [ bai ] ]
    csi                      = BAM_SORT_SAMTOOLS.out.csi                      // channel: [ val(meta), [ csi ] ]
    stats                    = BAM_SORT_SAMTOOLS.out.stats                    // channel: [ val(meta), [ stats ] ]
    flagstat                 = BAM_SORT_SAMTOOLS.out.flagstat                 // channel: [ val(meta), [ flagstat ] ]
    idxstats                 = BAM_SORT_SAMTOOLS.out.idxstats                 // channel: [ val(meta), [ idxstats ] ]

    merged_counts_gene       = RSEM_MERGE_COUNTS.out.counts_gene              //    path: *.gene_counts.tsv
    merged_tpm_gene          = RSEM_MERGE_COUNTS.out.tpm_gene                 //    path: *.gene_tpm.tsv
    merged_counts_transcript = RSEM_MERGE_COUNTS.out.counts_transcript        //    path: *.transcript_counts.tsv
    merged_tpm_transcript    = RSEM_MERGE_COUNTS.out.tpm_transcript           //    path: *.transcript_tpm.tsv

    versions                 = ch_versions                                    // channel: [ versions.yml ]
}
