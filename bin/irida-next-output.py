#!/usr/bin/env python

import json
from pathlib import Path
from mimetypes import guess_type
from functools import partial
import gzip
import sys
import argparse
import os
import glob


def get_open(f):
    if "gzip" == guess_type(str(f))[1]:
        return partial(gzip.open)
    else:
        return open


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Creates example output JSON for loading into IRIDA Next",
        epilog="Example: python irida-next-output.py --json-output output.json *.json *.json.gz",
    )
    parser.add_argument("files", nargs="+")
    parser.add_argument(
        "--summary-file",
        action="store",
        dest="summary_file",
        type=str,
        help="pipeline summary file",
        default=None,
        required=True,
    )
    parser.add_argument(
        "--json-output",
        action="store",
        dest="json_output",
        type=str,
        help="JSON output file",
        default=None,
        required=True,
    )

    args = parser.parse_args(argv)

    json_output_file = Path(args.json_output)
    if json_output_file.exists():
        sys.stderr.write(f"Error: --json-output [{json_output_file}] exists")
        return 1

    # Not checking for the existance of the summary file
    # because the path may be relative to the outdir, which we don't have here.

    input_files = args.files
    if isinstance(input_files, str):
        input_files = [input_files]

    output_dict = {
        "files": {
            "summary": {},
            "samples": {},
        },
        "metadata": {
            "samples": {},
        },
    }

    output_metadata = {
        "files": {"global": [{"path": str(args.summary_file)}], "samples": {}},
        "metadata": {"samples": {}},
    }

    for f in input_files:
        _open = get_open(f)
        with _open(f, "r") as fh:
            sample_metadata = json.load(fh)
            output_metadata["files"]["samples"] |= sample_metadata["files"]["samples"]
            output_metadata["metadata"]["samples"] |= sample_metadata["metadata"]["samples"]

    data_json = json.dumps(output_metadata, sort_keys=True, indent=4)
    _open = get_open(json_output_file)
    with _open(json_output_file, "wt") as oh:
        oh.write(data_json)

    print(f"Output written to [{json_output_file}]")

    return 0


if __name__ == "__main__":
    sys.exit(main())
