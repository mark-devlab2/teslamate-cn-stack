import json
import sys
from pathlib import Path


DASHBOARD_TITLE_MAP = {
    "overview.json": "01 总览",
    "trip.json": "02 行程轨迹",
    "visited.json": "03 到访地点",
    "charges.json": "04 充电记录",
    "drives.json": "05 行驶记录",
    "statistics.json": "06 统计分析",
    "locations.json": "07 地址与地点",
    "charging-stats.json": "08 充电统计",
    "drive-stats.json": "09 行驶统计",
    "battery-health.json": "10 电池健康",
    "charge-level.json": "11 电量变化",
    "timeline.json": "12 时间线",
    "states.json": "13 车辆状态",
    "updates.json": "14 车辆更新",
}

PANEL_TITLE_MAP = {
    "Dashboards": "仪表盘",
    "Releases": "版本更新",
    "# of Addresses": "地址总数",
    "# of Cities": "城市数量",
    "# of States": "省级区域数量",
    "# of Countries": "国家数量",
    "Drive Stats": "行驶统计",
    "Charging Stats": "充电统计",
    "Statistics": "统计分析",
    "Locations": "地点分布",
    "Visited": "到访地点",
    "Trip": "行程轨迹",
    "Overview": "总览",
    "Timeline": "时间线",
}


def patch_geomap(panel: dict) -> None:
    if panel.get("type") != "geomap":
        return
    options = panel.setdefault("options", {})
    options["basemap"] = {
        "type": "xyz",
        "name": "China Proxy",
        "config": {
            "url": "/tiles/{z}/{x}/{y}.png",
            "attribution": "OpenStreetMap contributors",
            "maxZoom": 19,
        },
    }


def walk_panels(panels: list[dict]) -> None:
    for panel in panels:
        title = panel.get("title")
        if isinstance(title, str) and title in PANEL_TITLE_MAP:
            panel["title"] = PANEL_TITLE_MAP[title]
        patch_geomap(panel)
        nested = panel.get("panels")
        if isinstance(nested, list):
            walk_panels(nested)


def patch_dashboard(path: Path) -> None:
    doc = json.loads(path.read_text(encoding="utf-8"))
    if path.name in DASHBOARD_TITLE_MAP:
        doc["title"] = DASHBOARD_TITLE_MAP[path.name]

    links = doc.get("links")
    if isinstance(links, list):
        for link in links:
            title = link.get("title")
            if isinstance(title, str) and title in PANEL_TITLE_MAP:
                link["title"] = PANEL_TITLE_MAP[title]

    panels = doc.get("panels")
    if isinstance(panels, list):
        walk_panels(panels)

    path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    for raw in sys.argv[1:]:
        root = Path(raw)
        for path in sorted(root.glob("*.json")):
            patch_dashboard(path)
        for path in sorted(root.glob("*/*.json")):
            patch_dashboard(path)


if __name__ == "__main__":
    main()

