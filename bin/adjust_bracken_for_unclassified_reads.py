#!/usr/bin/env python
## This python script was developed by Dan Fornika as a work of the Publich Health Bioinformatics
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
            b["kraken_assigned_seqs"] = int(row["kraken_assigned_reads"])
            b["bracken_assigned_seqs"] = int(row["new_est_reads"])
            b["bracken_fraction_total_seqs"] = float(row["fraction_total_reads"])
            bracken_abundances.append(b)

    return bracken_abundances


def parse_kraken_report(kraken_report_path):
    kraken_report = []
    with open(kraken_report_path, "r") as f:
        for line in f:
            kraken_line = {}
            [
                percentage,
                seqs_total,
                seqs_this_level,
                taxonomic_level,
                ncbi_taxid,
                taxon_name,
            ] = line.strip().split(None, 5)
            kraken_line["percentage"] = float(percentage)
            kraken_line["seqs_total"] = int(seqs_total)
            kraken_line["seqs_this_level"] = int(seqs_this_level)
            kraken_line["taxonomic_level"] = taxonomic_level
            kraken_line["ncbi_taxid"] = ncbi_taxid
            kraken_line["taxon_name"] = taxon_name
            kraken_report.append(kraken_line)

    return kraken_report


def main(args):
    kraken_report = parse_kraken_report(args.kraken_report)
    bracken_abundances = parse_bracken_abundances(args.bracken_abundances)

    try:
        kraken_report_unclassified_seqs = list(
            filter(lambda x: x["taxon_name"] == "unclassified", kraken_report)
        )[0]["seqs_this_level"]
    except IndexError as e:
        kraken_report_unclassified_seqs = 0
    kraken_report_classified_seqs = list(
        filter(lambda x: x["taxon_name"] == "root", kraken_report)
    )[0]["seqs_total"]

    total_seqs = kraken_report_classified_seqs + kraken_report_unclassified_seqs
    fraction_unclassified = float(kraken_report_unclassified_seqs) / float(total_seqs)

    output_fieldnames = [
        "name",
        "taxonomy_id",
        "taxonomy_lvl",
        "kraken_assigned_seqs",
        "bracken_assigned_seqs",
        "total_seqs",
        "kraken_fraction_total_seqs",
        "bracken_fraction_total_seqs",
    ]

    writer = csv.DictWriter(
        sys.stdout, fieldnames=output_fieldnames, dialect="excel-tab"
    )
    writer.writeheader()

    for b in bracken_abundances:
        b["total_seqs"] = total_seqs
        kraken_adjusted_fraction_total_seqs = float(b["kraken_assigned_seqs"]) / float(
            total_seqs
        )
        b["kraken_fraction_total_seqs"] = "{:.6f}".format(
            kraken_adjusted_fraction_total_seqs
        )
        bracken_adjusted_fraction_total_seqs = float(
            b["bracken_assigned_seqs"]
        ) / float(total_seqs)
        b["bracken_fraction_total_seqs"] = "{:.6f}".format(
            bracken_adjusted_fraction_total_seqs
        )

    bracken_unclassified_entry = {
        "name": "unclassified",
        "taxonomy_id": 0,
        "taxonomy_lvl": "U",
        "kraken_assigned_seqs": kraken_report_unclassified_seqs,
        "bracken_assigned_seqs": kraken_report_unclassified_seqs,
        "total_seqs": total_seqs,
        "kraken_fraction_total_seqs": "{:.6f}".format(fraction_unclassified),
        "bracken_fraction_total_seqs": "{:.6f}".format(fraction_unclassified),
    }

    bracken_abundances = sorted(
        bracken_abundances, key=lambda x: x["bracken_fraction_total_seqs"], reverse=True
    )
    bracken_abundances = [bracken_unclassified_entry] + bracken_abundances
    for b in bracken_abundances:
        writer.writerow(b)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-k", "--kraken-report")
    parser.add_argument("-a", "--bracken-abundances")
    args = parser.parse_args()
    main(args)
