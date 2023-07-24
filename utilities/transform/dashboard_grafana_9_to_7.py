import json
import os
import sys

# The key of property to update value with
DS_KEY = "datasource"
DS_TYPE_KEY = "type"
DS_UID_KEY = "uid"
DS_GRAFANA_KEY = "grafana"
DS_GRAFANA_VALUE_7 = "-- Grafana --"
CONVERTED_PATH_NAME = "converted"


def convertDatasource(dash_obj, key, value):
    """
    Update datasource element from Grafana 9 format to Grafana 7.

    :param dash_obj: the parent element that ows this datasource element to update with
    :param key: the key of the datasource element ("datasource")
    :param value: the value of the datasource element in Grafana 9 format: { "type": <type>, "uid": <uid>}

    :return: is_updated: True if successfully replaced, False otherwise.
    """
    if value[DS_UID_KEY]:  # if (value[DS_TYPE_KEY] or value[DS_UID_KEY]):
        # print('original: {}'.format(dash_obj[key]))
        if value[DS_UID_KEY] == DS_GRAFANA_KEY:
            dash_obj[key] = DS_GRAFANA_VALUE_7
        else:
            dash_obj[key] = value[DS_UID_KEY]
        # print('converted: {}'.format(dash_obj[key]))
        return True
    return False


def convert_dashboard(dash_obj):
    """
    Depth First Search to find any "datasource" element and update its value format from a dict to a string value
    as its UID value.

    Returns:
        is_updated: if any node gets updated, it bubbles up to root so the dashboard json file will be rewritten.
    """
    is_updated = False
    if type(dash_obj) == list:
        for ls in dash_obj:
            temp_is_updated = convert_dashboard(ls)
            if temp_is_updated:
                is_updated = True
    elif type(dash_obj) == dict:
        for key, value in dash_obj.items():
            try:
                if key == DS_KEY:
                    temp_is_updated = convertDatasource(dash_obj, key, value)
                else:
                    temp_is_updated = convert_dashboard(value)
                if temp_is_updated:
                    is_updated = True
            except TypeError:
                # print('Type error: {}:{}'.format(key, value))
                pass
    else:
        pass  # do nothing with other types: int, float, bool, None
    return is_updated


def convert_file(file):
    with open(file, "r") as dash_json:
        dash_obj = json.load(dash_json)
    is_converted = convert_dashboard(dash_obj)

    if not is_converted:
        return

    # rewrite json file
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
