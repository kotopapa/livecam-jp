from tools.kjmap_regions import parse

JS = """
var kjmapList = [
  { name: "首都圏", folderName: "tokyo50", x: 1 },
  { name: "関東", folderName: "kanto", x: 2 }
];
var kjmapDataSet = new Object();
kjmapDataSet['tokyo50'] = new Object();
dataset = kjmapDataSet['tokyo50'] ;
dataset.age = new Array();
dataset.age.push({
  folderName:'01', start:1927, end:1939, scale:'1/25000', mapList: [
    {name:'A',north:35.70,west:139.30,south:35.60,east:139.40,note:'',list:''},
    {name:'B',north:35.60,west:139.40,south:35.50,east:139.50,note:'',list:''}
  ]});
dataset.age.push({
  folderName:'2man', start:1896, end:1909, scale:'1/20000', mapList: [
    {name:'C',north:35.75,west:139.25,south:35.65,east:139.35,note:'',list:''}
  ]});
kjmapDataSet['kanto'] = new Object();
dataset = kjmapDataSet['kanto'] ;
dataset.age = new Array();
dataset.age.push({
  folderName:'00', start:1894, end:1915, scale:'1/50000', mapList: [
    {name:'D',north:36.0,west:139.0,south:35.0,east:140.0,note:'',list:''}
  ]});
"""


def test_parse_regions_eras_and_bounds():
    regions = parse(JS)
    assert [r["id"] for r in regions] == ["tokyo50", "kanto"]
    t = regions[0]
    assert t["name"] == "首都圏" and t["zmax"] == 16
    # 時期は古い順、範囲は図郭の外接
    assert [e["f"] for e in t["eras"]] == ["2man", "01"]
    assert t["eras"][1] == {"f": "01", "start": 1927, "end": 1939, "n": 35.7, "w": 139.3, "s": 35.5, "e": 139.5}
    assert (t["n"], t["w"], t["s"], t["e"]) == (35.75, 139.25, 35.5, 139.5)
    assert regions[1]["zmax"] == 15  # 関東はズーム15まで
