#!/usr/bin/env python
## This python script was developed by Dan Fornika as a work of the BC Centre for Disease Control Public Health Laboratory: https://github.com/BCCDC-PHL/taxon-abundance/blob/main/bin/adjust_bracken_percentages_for_unclassified_reads.py
## This source file has been adapted to work within our pipeline.
## Please refer to the README for more information.

import argparse
import csv
import json
import sys


def parse_bracken_abundances(bracken_abundances_path):
    bracken_abundances = []
    with open(bracken_abundances_path, "r") as f:
        reader = csv.DictReader(f, dialect="excel-tab")
        for row in reader:
            b = {}
            b["name"] = row["name"]
            b["taxonomy_id"] = row["taxonomy_id"]
            b["taxonomy_lvl"] = row["taxonomy_lvl"]
            b["kraken_assigned_reads"] = int(row["kraken_assigned_reads"])
            b["added_reads"] = int(row["added_reads"])
            b["new_est_reads"] = int(row["new_est_reads"])
            b["fraction_total_reads"] = float(row["fraction_total_reads"])
            bracken_abundances.append(b)

    return bracken_abundances


def parse_kraken_report(kraken_report_path):
    kraken_report = []
    with open(kraken_report_path, "r") as f:
        for line in f:
            kraken_line = {}
            [
                percentage,
                reads_total,
                reads_this_level,
                taxonomic_level,
                ncbi_taxid,
                taxon_name,
            ] = line.strip().split(None, 5)
            kraken_line["percentage"] = float(percentage)
            kraken_line["reads_total"] = int(reads_total)
            kraken_line["reads_this_level"] = int(reads_this_level)
            kraken_line["taxonomic_level"] = taxonomic_level
            kraken_line["ncbi_taxid"] = ncbi_taxid
            kraken_line["taxon_name"] = taxon_name
            kraken_report.append(kraken_line)

    return kraken_report


def main(args):
    kraken_report = parse_kraken_report(args.kraken_report)
    bracken_report = parse_kraken_report(
        args.bracken_report
    )  # bracken report has same format as kraken report
    bracken_abundances = parse_bracken_abundances(args.bracken_abundances)

    bracken_report_total_reads = list(
        filter(lambda x: x["taxon_name"] == "root", bracken_report)
    )[0]["reads_total"]
    kraken_report_unclassified_reads = list(
        filter(lambda x: x["taxon_name"] == "unclassified", kraken_report)
    )[0]["reads_this_level"]

    adjusted_total_reads = bracken_report_total_reads + kraken_report_unclassified_reads
    percent_unclassified = float(kraken_report_unclassified_reads) / float(
        adjusted_total_reads
    )

    bracken_unclassified_entry = {
        "name": "unclassified",
        "taxonomy_id": 0,
        "taxonomy_lvl": "U",
        "kraken_assigned_reads": kraken_report_unclassified_reads,
        "added_reads": 0,
        "new_est_reads": kraken_report_unclassified_reads,
        "fraction_total_reads": percent_unclassified,
    }

    bracken_abundances = [bracken_unclassified_entry] + bracken_abundances

    output_fieldnames = [
        "name",
        "taxonomy_id",
        "taxonomy_lvl",
        "kraken_assigned_reads",
        "added_reads",
        "new_est_reads",
        "fraction_total_reads",
    ]

    writer = csv.DictWriter(
        sys.stdout,
        fieldnames=output_fieldnames,
        dialect="unix",
        quoting=csv.QUOTE_MINIMAL,
    )
    writer.writeheader()

    for b in bracken_abundances:
        b["fraction_total_reads"] = round(
            float(b["new_est_reads"]) / float(adjusted_total_reads) * 100, 5
        )
        writer.writerow(b)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-k", "--kraken-report")
    parser.add_argument("-b", "--bracken-report")
    parser.add_argument("-a", "--bracken-abundances")
    args = parser.parse_args()
    main(args)
