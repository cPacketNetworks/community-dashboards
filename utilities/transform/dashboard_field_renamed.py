import json
import os
import sys

# The key of property to update value with
CONVERTED_PATH_NAME = "converted"
RENAMED_MAP = {"bytes_per_s": "bytes",
               "fragments_per_s": "fragments",
               "packets_per_s": "packets",
               "resolution_s": "resolution"};


def convert_dashboard(dash_parent_obj, dash_obj_key, dash_obj):
    """
    Depth First Search to find any string value and replace the matching old value with its specified new value. With any
    value matching and updated, the update is done using dash_parent_obj and dash_obj_key. Thus it doesn't have to bubble
    up to its parent for update.

    :param dash_parent_obj: The parent element that owns this element being inspected.
    :param dash_obj_key: The key of the element being inspected.
    :param dash_obj: The value of the element being inspected.

    :return:
    """
    is_updated: bool = False
    if type(dash_obj) == list:
        for ls in dash_obj:
            temp_is_updated = convert_dashboard(dash_parent_obj, dash_obj_key, ls)
            if temp_is_updated:
                is_updated = True
    elif type(dash_obj) == dict:
        for key, value in dash_obj.items():
            temp_is_updated = convert_dashboard(dash_obj, key, value)
            if temp_is_updated:
                is_updated = True
    elif type(dash_obj) == str:
        # print(f'key: {dash_obj_key}, value: {dash_obj}')
        is_matched = False
        for old_value, new_value in RENAMED_MAP.items():
            if old_value in dash_obj:
                dash_obj = dash_obj.replace(old_value, new_value)
                is_matched = True
        if is_matched:
            dash_parent_obj[dash_obj_key] = dash_obj
            is_updated = True
    else:
        pass  # do nothing with other types: int, float, bool, None
    return is_updated


def convert_file(file):
    with open(file, "r") as dash_json:
        dash_obj = json.load(dash_json)
    is_updated = convert_dashboard(dash_obj, "root", dash_obj)
    if is_updated:
        if not os.path.exists(("{}/converted".format(os.path.dirname(file)))):
            os.mkdir("{}/converted".format(os.path.dirname(file)))
        filename = os.path.basename(file).replace(":", "").replace("___", "_").replace("__", "_")
        with open(os.path.dirname(file) + "/" + CONVERTED_PATH_NAME + "/" + filename, "w") as f:
            json.dump(dash_obj, f, indent=2)
            print('Converted to file: {}'.format(f))


def convert_folder(folder):
    for root, dirs, files in os.walk(folder):
        for file in files:
            try:
                if str(file).endswith(".json"):
                    convert_file(root + "/" + file)
            except Exception as e:
                print(f"Exception converting file {file}: {e}")
                continue
        for sub_dir in dirs:
            convert_folder(sub_dir)


# Press the green button in the gutter to run the script.
if __name__ == "__main__":
    convert_folder(sys.argv[1])
