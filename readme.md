# L4D2plugin Map Vpk Chooser
> win签名由@Paimon-Kawaii 提供, 非常感谢.

在管理员菜单新增了本插件的换图方式, 菜单选项直接使用**VPK名称**进行替代, 无需使用配置文件手动汉化了ヾ(^∀^)ﾉ
* * * 
## 使用: 
打开管理员菜单即可.

* * *
## 注意: 

* 管理员菜单没生成的话, 请查看sourcemod 的log, 是否有报错以及其他问题.
* 插件在[sourcemod 1.11 6911](http://www.sourcemod.net/downloads.php)平台编译, 提示code too new 是由于你的服务器版本低于我编译的版本, 请自行编译源码即可.
* 本地服务器不支持该插件, 请使用专用服务器以运行该插件.

* * *
## 版本:
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