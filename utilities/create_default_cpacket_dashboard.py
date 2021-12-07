"""
a script to create a default dashboard with cpacket logo and the common variables
it also let's you add a dictionary of vlan names and ids for vlan names based dashboard

"""

import json
import os
import uuid
import getopt
import sys
from time import time

from cclear.collector.cstor_schema import APPLICATION_PORT_STR

INDICATORS_DATASOURCE = "indicators"


def dashboard_defaults(title, uid):
    test = {
        "annotations": {
            "list": [
                {
                    "builtIn": 1,
                    "datasource": "-- Grafana --",
                    "enable": True,
                    "hide": True,
                    "iconColor": "rgba(0, 211, 255, 1)",
                    "name": "Annotations & Alerts",
                    "type": "dashboard",
                }
            ]
        },
        "editable": True,
        "gnetId": None,
        "graphTooltip": 1,
        "id": 562,
        "iteration": 1635741277090,
        "links": [],
        "refresh": False,
        "schemaVersion": 26,
        "style": "dark",
        "tags": [],
        "time": {"from": "now-6h", "to": "now"},
        "timepicker": {
            "hidden": False,
            "refresh_intervals": ["5s", "10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"],
            "time_options": ["5m", "15m", "1h", "6h", "12h", "24h", "2d", "7d", "30d"],
        },
        "timezone": "",
        "title": title,
        "uid": uid,
        "version": 6,
    }
    return test


def html_panel(title, content):
    panel = {
        "datasource": INDICATORS_DATASOURCE,
        "fieldConfig": {"defaults": {"custom": {}}, "overrides": []},
        "gridPos": {"h": 3, "w": 24, "x": 0, "y": 0},
        "id": 186,
        "links": [],
        "options": {"content": content, "mode": "html"},
        "pluginVersion": "7.3.1",
        "title": title,
        "transparent": True,
        "type": "text",
    }
    return panel


def cpacket_logo_panel():
    title = ""
    html_content = (
        "<center style=\"background-color:black;padding:1rem\">"
        "<a href=\"http://www.cpacketnetworks.com\" target=\"_new\">"
        "<img width=\"220px\" src=\"/static/images/cpacket_white_text.svg\">"
        "</a></center>"
    )
    return html_panel(title, html_content)


def row(title="Download Packets"):
    panel = {
        "collapsed": True,
        "datasource": None,
        "gridPos": {"h": 1, "w": 24, "x": 0, "y": 3},
        "id": 53,
        "panels": [],
        "title": str(title),
        "type": "row",
    }
    return panel


def download_panel(title="Download Packets", measurement="tcp_active_sessions_4_tuple", field="active_sessions"):
    panel = {
        "datasource": None,
        "fieldConfig": {"defaults": {"custom": {}}, "overrides": []},
        "gridPos": {"h": 12, "w": 8, "x": 0, "y": 4},
        "id": 51,
        "options": {},
        "pluginVersion": "7.3.1",
        "targets": [
            {
                "alias": "<CSTOR_$tag_cstor_ip>",
                "groupBy": [
                    {"params": ["$__interval"], "type": "time"},
                    {"params": ["cstor_ip"], "type": "tag"},
                    {"params": ["null"], "type": "fill"},
                ],
                "measurement": str(measurement),
                "orderByTime": "ASC",
                "policy": "default",
                "refId": "A",
                "resultFormat": "time_series",
                "select": [[{"params": [str(field)], "type": "field"}, {"params": [], "type": "mean"}]],
                "tags": [],
            }
        ],
        "timeFrom": None,
        "timeShift": None,
        "title": str(title),
        "type": "cclear-pcap-panel-v2",
    }
    return panel


def piechart_panel_template(title, datasource=INDICATORS_DATASOURCE, description=""):
    panel = {
        "aliasColors": {},
        "breakPoint": "50%",
        "cacheTimeout": None,
        "combine": {"label": "Others", "threshold": "0.02"},
        "datasource": datasource,
        "description": str(description),
        "fieldConfig": {
            "defaults": {
                "custom": {"align": None, "filterable": False},
                "mappings": [],
                "thresholds": {
                    "mode": "absolute",
                    "steps": [{"color": "green", "value": None}, {"color": "red", "value": 80}],
                },
                "unit": "none",
            },
            "overrides": [],
        },
        "fontSize": "80%",
        "format": "decbytes",
        "gridPos": {"h": 9, "w": 8, "x": 0, "y": 5},
        "id": 115,
        "interval": None,
        "legend": {"show": True, "sort": "total", "sortDesc": True, "values": True},
        "legendType": "Right side",
        "links": [],
        "maxDataPoints": 3,
        "nullPointMode": "connected",
        "pieType": "pie",
        "pluginVersion": "7.3.1",
        "strokeWidth": 1,
        "targets": [],
        "timeFrom": None,
        "timeShift": None,
        "title": str(title),
        "transformations": [],
        "type": "grafana-piechart-panel",
        "valueName": "total",
    }
    return panel


def vlan_data():
    query = (
        "SELECT sum(\"bytes_client\"), sum(\"bytes_server\") "
        "FROM \"tcp_4_tuple\" WHERE (\"vlan\" =~ /^${vlan}$/) AND $timeFilter "
        "GROUP BY time($resolution), \"server_ip\", \"client_ip\" fill(0)"
    )
    alias = "vlan: $tag_vlan_tag_outer $col"
    measurement = "tcp_4_tuple"
    vlan_bytes_target = {
        "alias": str(alias),
        "groupBy": [
            {"params": ["$resolution"], "type": "time"},
            {"params": ["vlan_tag_outer"], "type": "tag"},
            {"params": ["0"], "type": "fill"},
        ],
        "measurement": str(measurement),
        "orderByTime": "ASC",
        "policy": "default",
        "query": str(query),
        "rawQuery": False,
        "refId": "A",
        "resultFormat": "time_series",
        "select": [
            [
                {"params": ["bytes_client"], "type": "field"},
                {"params": [], "type": "sum"},
                {"params": ["client"], "type": "alias"},
            ],
            [
                {"params": ["bytes_server"], "type": "field"},
                {"params": [], "type": "sum"},
                {"params": ["server"], "type": "alias"},
            ],
        ],
        "tags": [{"key": "vlan_tag_outer", "operator": "=~", "value": "/^$vlan_names$/"}],
    }
    title = "VLAN based Data for $vlan_names "
    panel = piechart_panel_template(title)
    targets = panel["targets"]
    targets.append(vlan_bytes_target)
    return panel


def resolution_var():
    var = {
        "auto": True,
        "auto_count": "20",
        "auto_min": "10s",
        "current": {"selected": False, "text": "auto", "value": "$__auto_interval_resolution"},
        "error": None,
        "hide": 0,
        "label": None,
        "name": "resolution",
        "options": [
            {"selected": True, "text": "auto", "value": "$__auto_interval_resolution"},
            {"selected": False, "text": "1s", "value": "1s"},
            {"selected": False, "text": "10s", "value": "10s"},
            {"selected": False, "text": "1m", "value": "1m"},
            {"selected": False, "text": "10m", "value": "10m"},
            {"selected": False, "text": "30m", "value": "30m"},
            {"selected": False, "text": "1h", "value": "1h"},
            {"selected": False, "text": "6h", "value": "6h"},
            {"selected": False, "text": "12h", "value": "12h"},
            {"selected": False, "text": "1d", "value": "1d"},
            {"selected": False, "text": "7d", "value": "7d"},
            {"selected": False, "text": "30d", "value": "30d"},
        ],
        "query": "1s,10s,1m,10m,30m,1h,6h,12h,1d,7d,30d",
        "queryValue": "",
        "refresh": 2,
        "skipUrlSync": False,
        "type": "interval",
    }
    return var


def simple_query_variable(datasource, label, var_name, query):
    var = {
        "allValue": None,
        "current": {"selected": False, "text": [], "value": []},
        "datasource": str(datasource),
        "definition": "",
        "error": None,
        "hide": 0,
        "includeAll": True,
        "label": str(label),
        "multi": True,
        "name": str(var_name),
        "options": [],
        "query": str(query),
        "refresh": 1,
        "regex": "",
        "skipUrlSync": False,
        "sort": 0,
        "tagValuesQuery": "",
        "tags": [],
        "tagsQuery": "",
        "type": "query",
        "useTags": False,
    }
    return var


def network_monitor_var():
    label = "Network Monitors to Display"
    var_name = "Network Monitors to Display"
    query = "show tag values with key = \"network_monitor_name\""
    return simple_query_variable(INDICATORS_DATASOURCE, label, var_name, query)


def vlan_var():
    label = "vlan"
    var_name = "vlan"
    query = "show tag values with key=~/vlan_.*/"
    return simple_query_variable(INDICATORS_DATASOURCE, label, var_name, query)


def cvu_var():
    label = "cvu"
    var_name = "cvu"
    query = "show tag values with key=\"device\""
    return simple_query_variable(INDICATORS_DATASOURCE, label, var_name, query)


def port_var():
    label = "cvu port name"
    var_name = "port"
    query = "show tag values with key=\"p_nm\""
    return simple_query_variable(INDICATORS_DATASOURCE, label, var_name, query)


def cburst_group_name_var():
    label = "cburst group name"
    var_name = "group"
    query = "show tag values with key=\"cb_group_name\""
    return simple_query_variable(INDICATORS_DATASOURCE, label, var_name, query)


def ip_var():
    label = "ip"
    var_name = "ip"
    query = "show tag values with key=~/.*_ip/ LIMIT 100"
    return simple_query_variable(INDICATORS_DATASOURCE, label, var_name, query)


def application_var():
    label = "application port"
    var_name = "application"
    query = f"show tag values with key= {APPLICATION_PORT_STR}"
    return simple_query_variable(INDICATORS_DATASOURCE, label, var_name, query)


def single_vlan_var(vlan_name, vlan_tag_id):
    # this is an alternative way to generate named vlans to vlan_pairs_var
    var = {
        "current": {"selected": False, "text": str(vlan_tag_id), "value": str(vlan_tag_id)},
        "error": None,
        "hide": 2,
        "label": None,
        "name": str(vlan_name),
        "options": [{"selected": True, "text": str(vlan_tag_id), "value": str(vlan_tag_id)}],
        "query": str(vlan_tag_id),
        "skipUrlSync": False,
        "type": "constant",
    }
    return var


def vlan_names_var(vlan_keys, var_name="vlan_names", label="VLAN Names"):
    # this is an alternative way to generate named vlans to vlan_pairs_var
    var = {
        "allValue": None,
        "current": {"selected": True, "tags": [], "text": [], "value": []},
        "error": None,
        "hide": 0,
        "includeAll": True,
        "label": str(label),
        "multi": True,
        "name": str(var_name),
        "options": [],
        "query": "",
        "queryValue": "",
        "skipUrlSync": False,
        "type": "custom",
    }

    first = True
    for vlan_name in vlan_keys:
        var["query"] += f"{', ' if not first else ''} {vlan_name}"
        first = False
        var["current"]["text"].append(vlan_name)
        var["current"]["value"].append(vlan_name)
        option = {"selected": True, "text": vlan_name, "value": vlan_name}
        var["options"].append(option)
    return var


def vlan_pairs_var(vlan_list, var_name="vlan_names", label="VLAN Names"):
    var = {
        "allValue": None,
        "current": {"selected": True, "text": [], "value": []},
        "error": None,
        "hide": 0,
        "includeAll": True,
        "label": str(label),
        "multi": True,
        "name": str(var_name),
        "options": [],
        "query": "",
        "queryValue": "",
        "skipUrlSync": False,
        "type": "custom",
    }

    first = True
    for vlan_name in vlan_list:
        if first:
            var["query"] += f"{vlan_name}:{vlan_list[vlan_name]}"
            var["current"]["text"].append(vlan_name)
            var["current"]["value"].append(vlan_list[vlan_name])
        else:
            var["query"] += f"{', ' if not first else ''} {vlan_name}:{vlan_list[vlan_name]}"
        option = {"selected": False, "text": vlan_name, "value": vlan_list[vlan_name]}
        var["options"].append(option)
        first = False
    return var


def main(args):
    vlan_list = None
    dashboard_title = "cpacket default dashboard"
    current_path = os.path.dirname(os.path.realpath(__file__))

    # parse command line arguments
    options, remainder = getopt.gnu_getopt(args, 'v:t:')
    for opt, arg in options:
        if opt in ('-v', '--vlan_list'):
            vlan_list_file_name = arg
            with open(vlan_list_file_name, "r") as fp:
                vlan_list = json.load(fp)
                current_path = os.path.dirname(os.path.realpath(vlan_list_file_name))
        elif opt in ('-t', '--title'):
            dashboard_title = arg

    # initialize the dashboard
    dashboard = {"panels": [], "templating": {'list': []}}
    uid = str(uuid.uuid4())[0:8]
    dashboard.update(dashboard_defaults(dashboard_title, uid))

    # initialize the rows and panels
    panels = dashboard["panels"]
    panels.append(cpacket_logo_panel())
    panels.append(row())
    download_row_panels = panels[-1]["panels"]
    download_row_panels.append(download_panel())

    # initialize the variables (templating)
    templating = dashboard["templating"]
    var_list = templating['list']
    var_list.append(resolution_var())
    var_list.append(network_monitor_var())
    var_list.append(vlan_var())
    var_list.append(cvu_var())
    var_list.append(port_var())
    var_list.append(cburst_group_name_var())
    var_list.append(ip_var())
    var_list.append(application_var())
    if vlan_list is not None:
        var_list.append(vlan_pairs_var(vlan_list))
        # the alternative is to use the following
        # for vlan_name in vlan_list:
        #     var_list.append(single_vlan_var(vlan_name, vlan_list[vlan_name]))
        # var_list.append(vlan_names_var(vlan_list.keys()))

    dashboard_out_file_name = os.path.join(current_path, f"{dashboard_title}-{int(time())}.json")
    print(f"saving dashboard to: {dashboard_out_file_name}")
    with open(dashboard_out_file_name, "w") as f:
        json.dump(dashboard, f, indent=4)


if __name__ == '__main__':
    main(sys.argv[1:])
