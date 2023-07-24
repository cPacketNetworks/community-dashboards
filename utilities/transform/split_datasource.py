import json
import os
import sys


# The list of measurements that would map to the "flows
FLOW_MEASUREMENTS = ("flow_data_4_tuple",
                     "flows_summary_application_port",
                     "flows_summary_destination_ip",
                     "flows_summary_source_ip",
                     "flows_summary_vlan_tag_outer")
TCP_MEASUREMENTS = ("tcp_open_4_tuple",
                    "tcp_open_summary_application_port",
                    "tcp_open_summary_client_ip",
                    "tcp_open_summary_server_ip",
                    "tcp_open_summary_vlan_tag_outer",
                    "tcp_timeslice_4_tuple",
                    "tcp_timeslice_summary_application_port",
                    "tcp_timeslice_summary_client_ip",
                    "tcp_timeslice_summary_server_ip",
                    "tcp_timeslice_summary_vlan_tag_outer")
DS_MM_MAP = {"flows": FLOW_MEASUREMENTS, "tcp": TCP_MEASUREMENTS}
# The key of property to update value with
DS_KEY = "datasource"
# The datasource value to match/replace
DS_ORIGINAL = "indicators"
# The properties to search in json files to search and replace
SEARCH_PROPERTIES = ("annotations", "templating", "panels")
# The extension of the output file to rename to
OUTFILE_EXTENSION = "_converted.json"


# replace ds_ori with ds from ds_mm_map where any mm is matched
def find_match(dash_str):
    for key, value in DS_MM_MAP.items():
        for mm in value:
            if dash_str.count(mm) > 0:
                return False, True, key
    return False, False, ""


def replace(dash_obj, is_matched, ds_matched):
    if dash_obj and is_matched:
        if DS_KEY in dash_obj.keys() and dash_obj[DS_KEY] == DS_ORIGINAL:
            dash_obj[DS_KEY] = ds_matched
            return True, False, ""
    return False, is_matched, ds_matched


def split_datasource_json(dash_obj):
    """
    Depth First Search to find any matching measurement and back up the tree to update the nearest parent's "datasource"
    property to the matching split database.

    Returns:
        is_updated: if any node gets updated, it bubbles up to root so the dashboard json file will be rewritten
        is_matched: notifies each node's parent if there's a match to replace.
        ds_matched: the name of the matching datasource to replace with.
    """
    is_updated: bool = False
    is_matched: bool = False
    ds_matched: str = ""

    if dash_obj:
        if type(dash_obj) == list:
            for ls in dash_obj:
                temp_is_updated, is_matched, ds_matched = split_datasource_json(ls)
                if temp_is_updated:
                    is_updated = True
        elif type(dash_obj) == dict:
            # depth first
            for key, value in dash_obj.items():
                temp_is_updated, temp_is_matched, temp_ds_matched = split_datasource_json(value)
                if temp_is_updated:
                    is_updated = True
                if temp_is_matched:
                    is_matched = True
                    ds_matched = temp_ds_matched
            # update datasource
                temp_is_updated, is_matched, ds_matched = replace(dash_obj, is_matched, ds_matched)
                if temp_is_updated:
                    is_updated = True
        elif type(dash_obj) == str:
            temp_is_updated, is_matched, ds_matched = find_match(dash_obj)
            if temp_is_updated:
                is_updated = True
        else:
            pass  # do nothing with other types: int, float, bool, None
    return is_updated, is_matched, ds_matched


def split_datasource_file(file):
    is_updated = False
    with open(file, "r") as dash_json:
        dash_obj = json.load(dash_json)
    for prop in SEARCH_PROPERTIES:
        temp_is_updated, is_matched, ds_matched = split_datasource_json(dash_obj[prop])
        if temp_is_updated:
            is_updated = True
    if is_updated:
        with open(str(file)[:file.index(".json")] + OUTFILE_EXTENSION, "w") as f:
            json.dump(dash_obj, f, indent=4)


def split_datasource_folder(folder):
    for root, dirs, files in os.walk(folder):
        for file in files:
            try:
                if str(file).endswith(".json"):
                    split_datasource_file(root + "/" + file)
            except Exception:
                continue
        for sub_dir in dirs:
            split_datasource_folder(sub_dir)


# Press the green button in the gutter to run the script.
if __name__ == "__main__":
    split_datasource_folder(sys.argv[1])
