# L4D2plugin Map Vpk Chooser
> win签名由@Paimon-Kawaii 提供, 非常感谢.

在管理员菜单新增了本插件的换图方式, 菜单选项直接使用**VPK名称**进行替代, 无需使用配置文件手动汉化了ヾ(^∀^)ﾉ
* * * 
## 使用: 
打开管理员菜单即可.

* * *
## 注意: 

* 管理员菜单没生成的话, 请查看sourcemod 的log, 是否有报错以及其他问题.
* 插件在[sourcemod 1.11 6968](http://www.sourcemod.net/downloads.php)平台编译, 提示code too new 是由于你的服务器版本低于我编译的版本, 请自行编译源码即可.
* 本地服务器不支持该插件, 请使用专用服务器以运行该插件.

* * *
## 版本:
* version 1.1.1
* * 修复windows路径为"/"导致无法正确识别vpk名称
* * 新增指令!smap, 用于快速筛选符合字符的三方图, 带空格以及中文的vpk名称请使用""包裹名称, 例如: !smap "我的地图1"
* version 1.1.0
* * 新增Native以供其他插件调用本插件的Mapinfo以获取地图的vpk名称.
* * 修复adminmenu报错.
* * 优化菜单逻辑减少运算.
* version 1.0.0
* * 插件发布.

* * *
## 插件拓展app:
* VoteMap(version 1.1.0以上)
* * 提供基于该插件地图列表的投票换图插件, 三方图需要g权限(changemap)或者root权限才可以使用.
* * 投票方式为聊天框输入0, 1, 2(反对, 赞成, 弃权). 赞成票必须超过反对票投票才可通过.
* * 指令!mapv可附带参数, 用法同!smap, 受权限影响, 权限不够将无法使用.