import json
import os
import sys
import traceback

CONVERTED_PATH_NAME = "converted"
TYPE_KEY = "type"
NAME_KEY = "name"
CURRENT_KEY = "current"
DEFAULT_QUERY = {
    "selected": False,
    "text": "",
    "value": ""
}
DEFAULT_RESOLUTION = {
    "selected": True,
    "text": "auto",
    "value": "$__auto_interval_resolution"
}


# Depth First Search to find any matching measurement and back up the tree to update the nearest parent's "datasource"
# property to the matching split database
def convert_dashboard(dash_parent_obj, dash_key, dash_obj):
    """
    Loop through template variables and update their default values.

    :param dash_parent_obj: The parent element that owns this element being inspected.
    :param dash_key: The key of the element being inspected.
    :param dash_obj: The value of the element being inspected.

    :return:
    """
    is_updated: bool = False
    if type(dash_obj) == list:
        for ls in dash_obj:
            temp_is_updated = convert_dashboard(dash_parent_obj, dash_key, ls)
            if temp_is_updated:
                is_updated = True
    elif type(dash_obj) == dict:
        # for key, value in dash_obj.items():
        try:
            if dash_obj[TYPE_KEY] == "query":
                dash_obj[CURRENT_KEY] = DEFAULT_QUERY
                is_updated = True
            elif dash_obj[TYPE_KEY] == "interval" and dash_obj[NAME_KEY] == "resolution":
                dash_obj[CURRENT_KEY] = DEFAULT_RESOLUTION
                is_updated = True
            else:
                pass  # do nothing about the rest
        except TypeError:
            print('Type error: {}:{}'.format(dash_key, dash_obj))
    else:
        pass  # do nothing
    return is_updated


def convert_file(file):
    with open(file, "r") as dash_json:
        dash_obj = json.load(dash_json)
    inspect_obj = dash_obj['templating']['list']
    inspect_key = "list"
    is_updated = convert_dashboard(dash_obj['templating'], inspect_key, inspect_obj)

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
                traceback.print_exc()
                continue
        for sub_dir in dirs:
            convert_folder(sub_dir)


# Press the green button in the gutter to run the script.
if __name__ == "__main__":
    convert_folder(sys.argv[1])
