version 1.0

import "modules/bcftools.wdl" as bcftools
import "modules/jvarkit.wdl" as jvarkit
import "modules/GATK4.wdl" as GATK4
import "modules/deepvariant.wdl" as deepvariant

workflow DeepVariant {
	meta {
		author: "Charles VAN GOETHEM"
		email: "c-vangoethem(at)chu-montpellier.fr"
		version: "0.1.0"
		date: "2026-09-16"
	}

	input {
		String sample

		## WARNING ALL PATH MUST BE ABSOLUTE PATH
		File fasta
		File bam

		File? dbsnp

		File bed
		Int LowCoverage = 30
		
		Array[Pair[String, String]] filters = [
			("LowCoverage", "DP < ~{LowCoverage}")
		]

		String outputPath
	}

	Object Fasta = {
		"fasta" : fasta,
		"fasta_index": fasta + ".fai",
		"fasta_dict": sub(fasta, "(.*).(fa|fasta)", "$1.dict")
	}


	call deepvariant.deepvariant {
		input:
			threads = 12,
			refFasta = fasta,
			bam = bam,
			outputPath = "~{outputPath}/",
			subdir = "1-deepvariant/",
			bed = bed
	}

	call bcftools.view {
		input:
			threads = 12,
			vcf = deepvariant.outputVcf,
			outputPath = "~{outputPath}/",
			subdir = "2-filtering/",
			suffix = ".filter",
			include = "FILTER!='RefCall'"
	}

	call bcftools.sort {
		input:
			threads = 12,
			vcf = view.outputvcf,
			outputPath = "~{outputPath}/",
			subdir = "3-sort/"
	}

	call jvarkit.vcfpolyx {
		input:
			vcf = sort.outputvcf,
			outputPath = "~{outputPath}/",
			subdir = "4-JVK-PolyX",
			refFasta = Fasta.fasta
	}

	call GATK4.variantFiltration {
		input:
			threads = 12,
			outputPath = "~{outputPath}/",
			subdir = "5-filtering/",
			vcf = vcfpolyx.output_vcf,
			filters = filters
	}

	call bcftools.norm {
		input:
			threads = 12,
			name = sample,
			suffix="",
			outputPath = "~{outputPath}/",
			refFasta = Fasta.fasta,
			subdir = "final/",
			vcf = variantFiltration.output_vcf,
			splitMA = true
	}

	output {
		File vcf = norm.outputvcf
		File? idx = norm.outputidx
	}
	
	parameter_meta {
		sample: {
			description: 'Sample name to use for output file name [default: sub(basename(fastqR1),subString,"")]',
			category: 'Output path/name option'
		}
		fasta: {
			description: 'Path to the reference file (format: fasta)',
			category: 'Required'
		}
		bam: {
			description: 'bam file',
			category: 'Input'
		}
		bed: {
			description: 'Path to a file containing genomic intervals over which to operate. (format: bed or GATK intervals list)',
			category: 'Input'
		}
		LowCoverage: {
			description: 'Define low coverage threshold (default: 30)',
			category: 'Input (optional)'
		}
		filters: {
			description: 'Array of filters applied',
			category: 'Input (optional)'
		}
		outputPath: {
			description: 'Output path where files will be generated. [default: pwd()]',
			category: 'Output path/name option'
		}
	}
}
