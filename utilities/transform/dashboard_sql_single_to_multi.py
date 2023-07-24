import json
import os
import sys

# The key of property to update value with
DS_KEY = "datasource"
DS_TYPE_KEY = "type"
DS_UID_KEY = "uid"
DS_GRAFANA_KEY = "grafana"
CONVERTED_PATH_NAME = "converted"

# Depth First Search to find any matching measurement and back up the tree to update the nearest parent's "datasource"
# property to the matching split database
def convert_dashboard(dash_obj):
    is_updated: bool = False

    if type(dash_obj) == list:
        for ls in dash_obj:
            temp_is_updated = convert_dashboard(ls)
            if temp_is_updated:
                is_updated = True
    elif type(dash_obj) == dict:
        # depth first
        for key, value in dash_obj.items():
            try:
                if (key == DS_KEY):
                    if (value[DS_TYPE_KEY] and value[DS_UID_KEY]):
                        #print('original: {}'.format(dash_obj[key]))
                        if (value[DS_UID_KEY]==DS_GRAFANA_KEY):
                            dash_obj[key] = "-- Grafana --"
                        else:
                            dash_obj[key] = value[DS_UID_KEY]
                        #print('converted: {}'.format(dash_obj[key]))
                        is_updated = True
                else:
                    temp_is_updated = convert_dashboard(value)
                    if temp_is_updated:
                        is_updated = True
            except TypeError:
                #print('Type error: {}:{}'.format(key, value))
                # do nothing
                pass
    else:
        pass  # do nothing with other types: int, float, bool, None
    return is_updated


def convert_file(file):
    is_updated = False
    #print('file: {}'.format(file))
    with open(file, "r") as dash_json:
        dash_obj = json.load(dash_json)
    temp_is_updated = convert_dashboard(dash_obj)
    if temp_is_updated:
        is_updated = temp_is_updated
    if is_updated:
        if not os.path.exists(("{}/converted".format(os.path.dirname(file)))):
            os.mkdir("{}/converted".format(os.path.dirname(file)))
        #name process
        filename = os.path.basename(file)
        filename = filename.replace(":", "")
        filename = filename.replace("___", "_")
        filename = filename.replace("__", "_")
        with open(os.path.dirname(file) + "/" + CONVERTED_PATH_NAME + "/" + filename, "w") as f:
            json.dump(dash_obj, f, indent=2)
            print('Write to file: {}'.format(f))
def convert_folder(folder):
    for root, dirs, files in os.walk(folder):
        for file in files:
            if str(file).endswith(".json"):
                convert_file(root + "/" + file)
        for sub_dir in dirs:
            convert_folder(sub_dir)


# Press the green button in the gutter to run the script.
if __name__ == "__main__":
    convert_folder(sys.argv[1])
