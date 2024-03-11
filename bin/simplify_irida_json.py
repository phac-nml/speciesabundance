#!/usr/bin/env python

import json
import argparse
import sys
import gzip
from mimetypes import guess_type
from functools import partial
from pathlib import Path


def flatten_dictionary(dictionary):
    result = {}

    def flatten(item, name=""):
        if type(item) is dict:
            for component in item:
                flatten(item[component], str(name) + str(component) + ".")

        elif type(item) is list:
            for i in range(len(item)):
                flatten(item[i], str(name) + str(i + 1) + ".")  # i + 1 because biologists

        else:
            result[str(name)[:-1]] = item  # [:-1] avoids the "." appended on the previous recursion

    flatten(dictionary)
    return result


def main():
    parser = argparse.ArgumentParser(
        description="Simplifies JSON files for use with IRIDA Next",
        epilog="Example: python simplify_irida_json.py --json-output output.json input.json",
    )
    parser.add_argument("input")
    parser.add_argument(
        "--json-output",
        action="store",
        dest="json_output",
        type=str,
        help="JSON output file",
        default=None,
        required=True,
    )

    args = parser.parse_args()

    json_output_location = Path(args.json_output)
    if json_output_location.exists():
        sys.stderr.write("Error: --json-output [{json_output_location}] exists!\n")
        return 1

    json_input_file = args.input

    # Handle GZIP and non-GZIP
    encoding = guess_type(json_input_file)[1]
    open_file = partial(gzip.open, mode="rt") if encoding == "gzip" else open  # partial (function pointer)

    with open_file(json_input_file) as input_file:
        input_json = json.load(input_file)

    # Flatten metadata:
    for sample in input_json["metadata"]["samples"]:
        input_json["metadata"]["samples"][sample] = flatten_dictionary(input_json["metadata"]["samples"][sample])

    json_data = json.dumps(input_json, sort_keys=True, indent=4)
    with open(json_output_location, "w") as output_file:
        output_file.write(json_data)

    print("Output written to " + str(json_output_location) + "!")

    return 0


if __name__ == "__main__":
    sys.exit(main())
