/**
 * 
 * version 1.1.0
 * 1. 新增native 用于其他插件获取三方图和官图list.
 * 2. 修复adminmenu 无法正确识别的错误.
 * 3. 优化逻辑, 减少占用.
 */
#pragma semicolon 1
#pragma newdecls required
#include <adminmenu>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

#define PLUGIN_VERSION "1.1.0"

public Plugin myinfo =
{
    name = "[L4D2] Map chooser (use vpk name)",
    author = "Miuwiki",
    description = "Show workshop map in .vpk name on adminmenu change map",
    version = PLUGIN_VERSION,
    url = "http://www.miuwiki.site"
}


#define OFFICIAL_MAP 0
#define WORKSHOP_MAP 1
#define GAMEDATA "miuwiki_mapchooser"

static char g_official_vpkname[][128] = {
    "死亡中心",
    "黑色狂欢节",
    "沼泽激战",
    "暴风骤雨",
    "郊区",
    "短暂时刻",
    "牺牲",
    "毫不留情",
    "坠机险途",
    "死亡丧钟",
    "静寂时分",
    "血腥收获",
    "刺骨寒溪",
    "临死一搏"
};

/**
 * struct vecAddonMetadata
 * {
 *  char mission_txt[128];
 *  char path[128];
 *  int8 type;
 * }
 */
Address 
    g_Address_vecAddonMetadata,
    g_Address_vecAddonListCount;

TopMenuObject
    g_TopmenuCategroy_mapchoose,
    g_TopmenuItem_official,
    g_TopmenuItem_workshop;

enum struct MapInfo
{
    int type;
    char missionfile[128];
    char missionname[128];
    char vpkname[128];

    ArrayList chapter;
}

ArrayList
    g_officialmap,
    g_workshopmap;

StringMap 
    workshopmap_vpkname;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if(GetEngineVersion() != Engine_Left4Dead2) // only support left4dead2
        return APLRes_SilentFailure;


    RegPluginLibrary("maplist");
    CreateNative("M_GetMapList", Native_Miuwiki_GetMapList);
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_workshopmap = new ArrayList(sizeof(MapInfo));
    g_officialmap = new ArrayList(sizeof(MapInfo));

    workshopmap_vpkname = new StringMap();
    LoadGameData();
    LoadWorkShopMapVpkName();
    LoadServerMap();
    
    // RegConsoleCmd("sm_showmap", Cmd_ShowMap);
    // RegAdminCmd("sm_maplist", Cmd_MapList, ADMFLAG_ROOT);
    TopMenu adminmenu;

    if( LibraryExists("adminmenu") && ((adminmenu = GetAdminTopMenu()) != null) )
    {
        OnAdminMenuCreated(adminmenu);
    }
}

public void OnAdminMenuCreated(Handle topmenu)
{
    TopMenu adminmenu = GetAdminTopMenu(); // or TopMenu.FromHandle(topmenu)
    if(adminmenu == INVALID_HANDLE)
    {
        LogError("Failed to create object in admin menu.");
        return;
    }

    g_TopmenuCategroy_mapchoose = adminmenu.AddCategory("l4d2_miuwiki_choosemap", TopMenuHandler_Category, "sm_miuwikichoosemap", ADMFLAG_CHEATS);
    g_TopmenuItem_official = adminmenu.AddItem("l4d2_miuwiki_choosemap_official", TopMenuHandler_Item, g_TopmenuCategroy_mapchoose, "sm_miuwikichoosemap_official", ADMFLAG_CHEATS);
    g_TopmenuItem_workshop = adminmenu.AddItem("l4d2_miuwiki_choosemap_workshop", TopMenuHandler_Item, g_TopmenuCategroy_mapchoose, "sm_miuwikichoosemap_workshop", ADMFLAG_CHEATS);
}

void TopMenuHandler_Category(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    switch(action)
    {
        // case of show title in main admin menu.
        case TopMenuAction_DisplayOption:
        {
            FormatEx(buffer, maxlength, "★VPK换图");
        }
        // case of the category is open and the menu title is buffer.
        case TopMenuAction_DisplayTitle:
        {
            FormatEx(buffer, maxlength, "★VPK换图:\n——————————————");
        }
    }
}

void TopMenuHandler_Item(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    switch(action)
    {
        // case of show item name in category.
        case TopMenuAction_DisplayOption:
        {
            if(object_id == g_TopmenuItem_official)
            {
                FormatEx(buffer, maxlength, "更换官方图");
            }
            else if(object_id == g_TopmenuItem_workshop)
            {
                FormatEx(buffer, maxlength, "更换三方图");
            }
        }
        // case of the category is open and the menu title is buffer.
        case TopMenuAction_SelectOption:
        {
            if(object_id == g_TopmenuItem_official)
            {
                // FormatEx(buffer, maxlength, "更换官方图");
                ShowMapList(param, OFFICIAL_MAP);
            }
            else if(object_id == g_TopmenuItem_workshop)
            {
                // FormatEx(buffer, maxlength, "更换三方图");
                ShowMapList(param, WORKSHOP_MAP);
            }
        }
    }
}


void ShowMapList(int client, int mode)
{
    Menu menu = new Menu(MenuHandler_ShowMapList);
    ArrayList maplist = mode == OFFICIAL_MAP ? g_officialmap : g_workshopmap;
    MapInfo map;
    
    if( maplist.Length == 0 )
    {
        if( mode == OFFICIAL_MAP )
            PrintHintText(client, "服务器还没有官方图!");
        else
            PrintHintText(client, "服务器还没有三方图!");

        return;
    }

    if(mode == OFFICIAL_MAP)
        menu.SetTitle("★官方图\n——————————————");
    else
        menu.SetTitle("★三方图\n——————————————");
    
    
    char info[128];
    for(int i = 0; i < maplist.Length; i++)
    {
        maplist.GetArray(i, map);

        FormatEx(info, sizeof(info), "%d-%d", mode, i);

        if( strcmp(map.vpkname, "") == 0 )
            menu.AddItem(info, map.missionname);
        else
            menu.AddItem(info, map.vpkname);
    }

    menu.Display(client, 20);
}

int MenuHandler_ShowMapList(Menu menu, MenuAction action, int client, int index)
{
    if(action == MenuAction_Select)
    {
        char info[128], message[2][8];
        menu.GetItem(index, info, sizeof(info));
        ExplodeString(info, "-", message, sizeof(message), sizeof(message[]));

        ShowChapterList(client, StringToInt(message[0]), StringToInt(message[1]));
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void ShowChapterList(int client, int mode, int index)
{
    Menu menu = new Menu(MenuHandler_ChangeMap);
    ArrayList maplist = mode == OFFICIAL_MAP ? g_officialmap : g_workshopmap;
    MapInfo map;
    maplist.GetArray(index, map);

    char info[128];
    if(IsNullString(map.vpkname))
        FormatEx(info, sizeof(info), "★%s\n——————————————", map.missionname);
    else
        FormatEx(info, sizeof(info), "★%s\n——————————————", map.vpkname);

    menu.SetTitle(info);

    for(int i = 0; i < map.chapter.Length; i++)
    {
        map.chapter.GetString(i, info, sizeof(info));
        menu.AddItem(info, info);
    }

    menu.Display(client, 20);
}

int MenuHandler_ChangeMap(Menu menu, MenuAction action, int client, int index)
{
    if(action == MenuAction_Select)
    {
        char info[512];
        menu.GetItem(index, info, sizeof(info));

        ServerCommand("sm_map %s", info);
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void LoadServerMap()
{
    char path[128];

    DirectoryListing missionlist = OpenDirectory("missions", true);
    if(missionlist == null)
    {
        SetFailState("Failed to open missions folder, game error!");
    }

    while(missionlist.GetNext(path, sizeof(path)))
    {
        if(strlen(path) < 4)
            continue;

        if(strcmp(path[strlen(path) - 4], ".txt") != 0) // just confirm the last 4 byte is ".txt" or not.
            continue;

        MapInfo map;
        FormatEx(map.missionfile, sizeof(map.missionfile), "%s", path);

        Format(path, sizeof(path), "missions/%s", path);
        KeyValues kv = new KeyValues("");
        kv.ImportFromFile(path);
        kv.GetString("Name", map.missionname, sizeof(map.missionname));

        SplitString(map.missionfile, ".txt", map.missionfile, sizeof(map.missionfile)); // remove .txt in the end.

        map.type = strncmp(map.missionname, "L4D2C", 5) == 0 ? OFFICIAL_MAP : WORKSHOP_MAP; // whatever, if the Name of the mission can be l4d2c with workshop map, i don't know how to identify it.

        kv.JumpToKey("modes");
        if(!kv.JumpToKey("coop") || strcmp(map.missionname, "credits") == 0) // we only collect the map which have coop mode but not credits.
        {
            delete kv;
            continue;
        }

        map.chapter = new ArrayList(ByteCountToCells(128));
        kv.GotoFirstSubKey();
        do
        {
            kv.GetString("Map", path, sizeof(path));
            map.chapter.PushString(path);

            if(map.type == OFFICIAL_MAP)
                LogMessage("Get official map: %s, file: %s, chapter: %s", map.missionname, map.missionfile, path);
            else if(map.type == WORKSHOP_MAP)
                LogMessage("Get workshop map: %s, file: %s, chapter: %s", map.missionname, map.missionfile, path);
        } 
        while(kv.GotoNextKey());

        if( map.type == OFFICIAL_MAP )
            g_officialmap.PushArray(map);
        else
            g_workshopmap.PushArray(map);

        delete kv;
    }

    SetMissionVpkName();

    delete missionlist;

    // LogMessage("Finish Map Load. Get %d official map, %d workshop map", servermap.official_map.Length, servermap.workshop_map.Length);
}

void LoadWorkShopMapVpkName()
{
    if( !HasAddonMetadata() )
        return;

    // load workshop map vpkname.
    int addoncount = LoadFromAddress(g_Address_vecAddonListCount, NumberType_Int32);

    Address data = LoadFromAddress(g_Address_vecAddonMetadata, NumberType_Int32);

    int offset, type;
    char missionfile[128], path[128];
    for(int i = 0; i < addoncount; i++)
    {
        type = LoadFromAddress(data + view_as<Address>(offset) + view_as<Address>(256), NumberType_Int8);

        // type != 1, which is not mission
        if(type != 1)
        {
            offset += 264; // 128 + 128 + 8
            continue;
        }

        LoadStringFromAddress(data + view_as<Address>(offset), path, sizeof(path));
        LoadStringFromAddress(data + view_as<Address>(offset) + view_as<Address>(128), missionfile, sizeof(missionfile));

        GetVpknameFromPath(path, sizeof(path));
        workshopmap_vpkname.SetString(missionfile, path);

        LogMessage("store mission vpk path %s to %s", path, missionfile);
        offset += 264;
    }
}

void GetVpknameFromPath(char[] buffer, int size) // can use to get the byte start the str end.
{
    int len = strlen(buffer);
    int index;
    char split[] = "/";
    for(int i = 0; i < len; i++)
    {
        // PrintToChatAll("comparing %s", buffer[len - i]);
        if(strncmp(buffer[len - i], split, strlen(split)) == 0)
        {
            index = len - i + strlen(split); 
            break;
        }

        index++;
    }

    if( index == 0 )
        return;

    Format(buffer, size, "%s", buffer[index]);
    SplitString(buffer, ".vpk", buffer, size);
}

bool HasAddonMetadata()
{
    KeyValues kv = new KeyValues("");
    
    if( !kv.ImportFromFile("addonlist.txt") || !kv.GotoFirstSubKey(false))
    {
        delete kv;
        return false;
    }

    int temp;
    do
    {
        temp = kv.GetNum(NULL_STRING, -1);
        if( temp == 1 ) // it is -1 that mean get falied, 0 means it is not used.
        {
            delete kv;
            return true;
        }
    } 
    while(kv.GotoNextKey(false));

    delete kv;
    return false;
}

void SetMissionVpkName()
{
    MapInfo map;
    int missionindex;
    for(int i = 0; i < g_officialmap.Length; i++)
    {
        g_officialmap.GetArray(i, map);
        // change L4D2C name to chinese  in map.vpkname
        missionindex = StringToInt(map.missionname[5]) - 1;                                 // remove L4D2C and reduce 1 to make it adjust the char array.
        FormatEx(map.vpkname, sizeof(map.vpkname), "%s", g_official_vpkname[missionindex]); // mission name start from 1, so reduce 1 to adjust the char array.
        g_officialmap.SetArray(i, map);

        // change the index of this official map
        if(missionindex != i)
        {
            // swap current index to the campaign index and keep check current index.
            g_officialmap.SwapAt(i, missionindex);
            i--;
        }
    }

    for(int i = 0; i < g_workshopmap.Length; i++)
    {
        g_workshopmap.GetArray(i, map);
        if(workshopmap_vpkname.ContainsKey(map.missionfile))
        {
            workshopmap_vpkname.GetString(map.missionfile, map.vpkname, sizeof(map.vpkname));
            g_workshopmap.SetArray(i, map);
        }
    }
}

void LoadGameData()
{
    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);

    if(!FileExists(sPath))
        SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

    GameData hGameData = new GameData(GAMEDATA);
    if(hGameData == null)
        SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

    if( !HasAddonMetadata() )
    {
        LogMessage("server doesn't have workshop map, please add it.");
        return;
    }

    g_Address_vecAddonListCount = hGameData.GetAddress("AddonListCount");
    if(g_Address_vecAddonListCount == Address_Null)
        SetFailState("Failed to load \"AddonListCount\" address");

    g_Address_vecAddonMetadata = hGameData.GetAddress("vecAddonMetadata");
    if(g_Address_vecAddonMetadata == Address_Null)
        SetFailState("Failed to load \"vecAddonMetadata\" address");

    delete hGameData;
}

stock int LoadStringFromAddress(Address addr, char[] buffer, int maxlen, bool &bIsNullPointer = false)
{
    if(!addr)
    {
        bIsNullPointer = true;
        return 0;
    }

    int c;
    char ch;
    do
    {
        ch = view_as<int>(LoadFromAddress(addr + view_as<Address>(c), NumberType_Int8));
        buffer[c] = ch;
    } while(ch && ++c < maxlen - 1);
    return c;
}

any Native_Miuwiki_GetMapList(Handle plugin, int arg_num)
{
    int mode = GetNativeCell(1);
    ArrayList temp = mode == OFFICIAL_MAP ? g_officialmap.Clone() : g_workshopmap.Clone();
    
    return temp;
}