#!/usr/bin/env python
## This python script was developed by Dan Fornika as a work of the BC Centre for Disease Control Public Health Laboratory: https://github.com/BCCDC-PHL/routine-sequence-qc/blob/main/bin/adjust_for_unclassified_reads.py
## This source file has been adapted to work within our pipeline.
## Please refer to the README for more information.

import argparse
import csv
import json


def parse_kraken_report(kraken_report_path):
    kraken_report = []

    fieldnames = [
        "percent_seqs_this_clade",
        "num_seqs_this_clade",
        "num_seqs_this_taxon",
        "taxonomic_level",
        "ncbi_taxonomy_id",
        "taxon_name",
    ]
    int_fields = [
        "num_seqs_this_clade",
        "num_seqs_this_taxon",
    ]
    float_fields = [
        "percent_seqs_this_clade",
    ]
    with open(kraken_report_path, "r") as f:
        reader = csv.DictReader(f, fieldnames=fieldnames, dialect="excel-tab")
        for row in reader:
            for field in int_fields:
                try:
                    row[field] = int(row[field])
                except ValueError as e:
                    row[field] = None
            for field in float_fields:
                try:
                    row[field] = float(row[field])
                except ValueError as e:
                    row[field] = None
            kraken_report.append(row)

    return kraken_report


def parse_bracken_abundances(bracken_abundances_path):
    bracken_abundances = []
    int_fields = [
        "kraken_assigned_reads",
        "added_reads",
        "new_est_reads",
    ]
    float_fields = [
        "fraction_total_reads",
    ]
    with open(bracken_abundances_path, "r") as f:
        reader = csv.DictReader(f, dialect="excel-tab")
        for row in reader:
            for field in int_fields:
                try:
                    row[field] = int(row[field])
                except ValueError as e:
                    row[field] = None
            for field in float_fields:
                try:
                    row[field] = float(row[field])
                except ValueError as e:
                    row[field] = None
            bracken_abundances.append(row)

    return bracken_abundances


def get_num_unclassified_seqs(parsed_kraken_report):
    unclassified_records = list(
        filter(lambda x: x["ncbi_taxonomy_id"] == "0", parsed_kraken_report)
    )
    num_unclassified_seqs = 0
    if len(unclassified_records) > 0:
        unclassified_record = unclassified_records[0]
        if "num_seqs_this_taxon" in unclassified_record:
            num_unclassified_seqs = unclassified_record["num_seqs_this_taxon"]

    return num_unclassified_seqs


def get_num_classified_seqs(parsed_kraken_report):
    root_records = list(
        filter(lambda x: x["ncbi_taxonomy_id"] == "1", parsed_kraken_report)
    )
    num_classified_seqs = 0
    if len(root_records) > 0:
        root_record = root_records[0]
        if "num_seqs_this_clade" in root_record:
            num_classified_seqs = root_record["num_seqs_this_clade"]

    return num_classified_seqs


def adjust_bracken_report(bracken_report, num_unclassified_seqs):
    adjusted_bracken_report = []
    unclassified_record = {
        "num_seqs_this_clade": num_unclassified_seqs,
        "num_seqs_this_taxon": num_unclassified_seqs,
        "taxonomic_level": "U",
        "ncbi_taxonomy_id": "0",
        "taxon_name": "unclassified",
    }
    root_bracken_records = list(
        filter(lambda x: x["ncbi_taxonomy_id"] == "1", bracken_report)
    )

    if len(root_bracken_records) > 0:
        root_bracken_record = root_bracken_records[0]
        num_classified_seqs = root_bracken_record["num_seqs_this_clade"]
        total_seqs = num_classified_seqs + num_unclassified_seqs
        if total_seqs > 0:
            unclassified_record["percent_seqs_this_clade"] = round(
                unclassified_record["num_seqs_this_clade"] / total_seqs * 100, 2
            )
            adjusted_bracken_report.append(unclassified_record)
            for bracken_report_record in bracken_report:
                bracken_report_record["percent_seqs_this_clade"] = round(
                    bracken_report_record["num_seqs_this_clade"] / total_seqs * 100, 2
                )
                adjusted_bracken_report.append(bracken_report_record)

    return adjusted_bracken_report


def adjust_bracken_abundances(
    bracken_abundances, num_total_seqs, num_unclassified_seqs
):
    adjusted_bracken_abundances = []
    unclassified_record = {
        "name": "unclassified",
        "taxonomy_id": "0",
        "taxonomy_lvl": "U",
        "kraken_assigned_reads": num_unclassified_seqs,
        "added_reads": 0,
        "new_est_reads": num_unclassified_seqs,
    }
    if num_total_seqs > 0:
        unclassified_record["fraction_total_reads"] = round(
            num_unclassified_seqs / num_total_seqs, 6
        )
        adjusted_bracken_abundances.append(unclassified_record)
        for bracken_abundance_record in bracken_abundances:
            bracken_abundance_record["fraction_total_reads"] = round(
                bracken_abundance_record["new_est_reads"] / num_total_seqs, 6
            )
            adjusted_bracken_abundances.append(bracken_abundance_record)

    return adjusted_bracken_abundances


def main(args):

    kraken_report = parse_kraken_report(args.kraken_report)
    num_unclassified_seqs = get_num_unclassified_seqs(kraken_report)
    num_classified_seqs = get_num_classified_seqs(kraken_report)
    num_total_seqs = num_unclassified_seqs + num_classified_seqs

    bracken_report = parse_kraken_report(args.bracken_report)
    adjusted_bracken_report = adjust_bracken_report(
        bracken_report, num_unclassified_seqs
    )
    bracken_abundances = parse_bracken_abundances(args.bracken_abundances)
    adjusted_bracken_abundances = adjust_bracken_abundances(
        bracken_abundances, num_total_seqs, num_unclassified_seqs
    )

    abundances_output_fieldnames = [
        "name",
        "taxonomy_id",
        "taxonomy_lvl",
        "kraken_assigned_reads",
        "added_reads",
        "new_est_reads",
        "fraction_total_reads",
    ]
    with open(args.adjusted_abundances, "w") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=abundances_output_fieldnames,
            dialect="unix",
            quoting=csv.QUOTE_MINIMAL,
        )
        writer.writeheader()
        for row in adjusted_bracken_abundances:
            writer.writerow(row)

    report_output_fieldnames = [
        "percent_seqs_this_clade",
        "num_seqs_this_clade",
        "num_seqs_this_taxon",
        "taxonomic_level",
        "ncbi_taxonomy_id",
        "taxon_name",
    ]
    with open(args.adjusted_report, "w") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=report_output_fieldnames,
            dialect="excel-tab",
            quoting=csv.QUOTE_MINIMAL,
        )
        for row in adjusted_bracken_report:
            writer.writerow(row)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-k", "--kraken-report")
    parser.add_argument("-b", "--bracken-report")
    parser.add_argument("-a", "--bracken-abundances")
    parser.add_argument("--adjusted-report")
    parser.add_argument("--adjusted-abundances")
    args = parser.parse_args()
    main(args)
