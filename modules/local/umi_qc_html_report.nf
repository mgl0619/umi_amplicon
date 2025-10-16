process UMI_QC_HTML_REPORT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/umi_qc_html_report_environment.yml"
    container "quay.io/biocontainers/python:3.11"

    input:
    tuple val(meta), path(pre_dedup_txt), path(pre_dedup_json), path(post_dedup_json)

    output:
    tuple val(meta), path("*.umi_qc_report.html"), emit: html_report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def sample = meta.id
    def pre_txt_arg = pre_dedup_txt ? "--pre-dedup-txt ${pre_dedup_txt}" : ""
    def pre_json_arg = pre_dedup_json ? "--pre-dedup-json ${pre_dedup_json}" : ""
    """
    generate_umi_report_plotly.py \\
        ${pre_txt_arg} \\
        ${pre_json_arg} \\
        --post-dedup-json ${post_dedup_json} \\
        --sample ${sample} \\
        --output ${sample}.umi_qc_report.html
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        plotly: \$(python -c "import plotly; print(plotly.__version__)")
    END_VERSIONS
    """

    stub:
    """
    touch ${sample}.umi_qc_report.html
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "3.11"
        plotly: "5.18.0"
    END_VERSIONS
    """
}
