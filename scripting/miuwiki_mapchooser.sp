#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adminmenu>

#define PLUGIN_VERSION "1.0.0"

public Plugin myinfo =
{
	name = "[L4D2] Map chooser (use vpk name)",
	author = "Miuwiki",
	description = "Show workshop map in .vpk name on adminmenu change map",
	version = PLUGIN_VERSION,
	url = "http://www.miuwiki.site"
}


#define OFFICIAL_MAP  0
#define WORKSHOP_MAP  1
#define GAMEDATA      "miuwiki_mapchooser"

static char g_official_vpkname[][128] = 
{
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
Address g_Address_vecAddonMetadata;

TopMenuObject
    g_TopmenuCategroy_mapchoose,
    g_TopmenuItem_official,
    g_TopmenuItem_workshop;

enum struct MapInfo
{
    int  type;
    char missionfile[128];
    char missionname[128];
    char vpkname[128];

    ArrayList chapter;
}

ArrayList servermap;
StringMap workshopmap_vpkname;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if( GetEngineVersion() != Engine_Left4Dead2 ) // only support left4dead2
        return APLRes_SilentFailure;

    return APLRes_Success;
}

public void OnPluginStart()
{
    servermap           = new ArrayList(sizeof(MapInfo));
    workshopmap_vpkname = new StringMap();
    LoadGameData();
    LoadServerMap();
    
    // RegConsoleCmd("sm_showmap", Cmd_ShowMap);
    // RegAdminCmd("sm_maplist", Cmd_MapList, ADMFLAG_ROOT);

    if( !LibraryExists("adminmenu") )
        return;
    
    OnAdminMenuCreated(INVALID_HANDLE);
}



public void OnAdminMenuCreated(Handle pass)
{
    TopMenu adminmenu = GetAdminTopMenu();
    if( adminmenu == null )
    {
        LogError("Failed to create object in admin menu.");
        return;
    }

    g_TopmenuCategroy_mapchoose = adminmenu.AddCategory("l4d2_miuwiki_choosemap", TopMenuHandler_Category, "sm_miuwikichoosemap", ADMFLAG_CHEATS);
    g_TopmenuItem_official      = adminmenu.AddItem("l4d2_miuwiki_choosemap_official", TopMenuHandler_Item, g_TopmenuCategroy_mapchoose, "sm_miuwikichoosemap_official", ADMFLAG_CHEATS);
    g_TopmenuItem_workshop      = adminmenu.AddItem("l4d2_miuwiki_choosemap_workshop", TopMenuHandler_Item, g_TopmenuCategroy_mapchoose, "sm_miuwikichoosemap_workshop", ADMFLAG_CHEATS);
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
            if( object_id == g_TopmenuItem_official )
            {
                FormatEx(buffer, maxlength, "更换官方图");
            }
            else if( object_id == g_TopmenuItem_workshop )
            {
                FormatEx(buffer, maxlength, "更换三方图");
            }
        }
        // case of the category is open and the menu title is buffer.
        case TopMenuAction_SelectOption:
        {
            if( object_id == g_TopmenuItem_official )
            {
                // FormatEx(buffer, maxlength, "更换官方图");
                ShowMapList(param, OFFICIAL_MAP);
            }
            else if( object_id == g_TopmenuItem_workshop )
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

    if( mode == OFFICIAL_MAP )
        menu.SetTitle("★官方图\n——————————————");
    else
        menu.SetTitle("★三方图\n——————————————");

    MapInfo map;
    for(int i = 0; i < servermap.Length; i++)
    {
        servermap.GetArray(i, map);
        if( map.type != mode )
            continue;
        
        if( IsNullString(map.vpkname) )
            menu.AddItem(map.missionname, map.missionname);
        else
            menu.AddItem(map.missionname, map.vpkname);
    }

    menu.Display(client, 20);
}

int MenuHandler_ShowMapList(Menu menu, MenuAction action, int client, int index)
{
    if( action == MenuAction_Select )
    {
        char info[512];
        menu.GetItem(index, info, sizeof(info));

        // PrintToChat(client, "you choose map: %s", info);
        ShowChapterList(client, info);
    }
    else if( action == MenuAction_End )
    {
        delete menu;
    }

    return 0;
}

void ShowChapterList(int client, const char[] info)
{
    char temp[128];

    Menu menu = new Menu(MenuHandler_ChangeMap);
    FormatEx(temp, sizeof(temp), "★%s\n——————————————", info);
    menu.SetTitle(temp);

    MapInfo map;
    for(int i = 0; i < servermap.Length; i++) // 0,1 is the mission file name and mission name;
    {
        servermap.GetArray(i, map);
        if( strcmp(map.missionname, info) == 0 )
            break;
    }

    for(int i = 0; i < map.chapter.Length; i++)
    {
        map.chapter.GetString(i, temp, sizeof(temp));
        menu.AddItem(temp, temp);
    }

    menu.Display(client, 20);
}

int MenuHandler_ChangeMap(Menu menu, MenuAction action, int client, int index)
{
    if( action == MenuAction_Select )
    {
        char info[512];
        menu.GetItem(index, info, sizeof(info));

        ServerCommand("sm_map %s", info);
    }
    else if( action == MenuAction_End )
    {
        delete menu;
    }

    return 0;
}


void LoadServerMap()
{
    char path[128];

    DirectoryListing missionlist = OpenDirectory("missions", true);
    if( missionlist == null )
    {
        SetFailState("Failed to open missions folder, game error!");
    }

    while( missionlist.GetNext( path, sizeof(path)) )
    {
        if( strcmp(path[strlen(path) - 4], ".txt") != 0 ) // just confirm the last 4 byte is ".txt" or not.
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
        if( !kv.JumpToKey("coop") || strcmp(map.missionname, "credits" ) == 0 ) // we only collect the map which have coop mode but not credits.
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

            // if( map.type )
            //     LogMessage("Get official map: %s, file: %s, chapter: %s", map.missionname, map.missionfile, path);
            // else
            //     LogMessage("Get workshop map: %s, file: %s, chapter: %s", map.missionname, map.missionfile, path);
        }
        while( kv.GotoNextKey() );

        servermap.PushArray(map);
        delete kv;
    }

    SortOfficialMap();
    GetWorkshopMapVpkName();
    SetMissionVpkName();

    delete missionlist;

    // LogMessage("Finish Map Load. Get %d official map, %d workshop map", servermap.official_map.Length, servermap.workshop_map.Length);
}


int GetAddonList()
{
    int addonlist;
    KeyValues kv = new KeyValues("");
    kv.ImportFromFile("addonlist.txt");

    if( !kv.GotoFirstSubKey(false) )
    {
        LogMessage("No workshop addon load in addonlist.txt, stop getting addon meta data");
        delete kv;
        return 0;
    }

    int temp;
    do
    {
        temp = kv.GetNum(NULL_STRING, -1);
        if( temp == 0 ) // which mod is not load.
            continue;

        addonlist++;
    }
    while( kv.GotoNextKey(false) );
    delete kv;

    return addonlist;
}
void SortOfficialMap()
{
    int index;
    MapInfo map;
    for(int i = 0; i < servermap.Length; i++)
    {
        servermap.GetArray(i, map);
        if( map.type != OFFICIAL_MAP )
            continue;
        
        index = StringToInt(map.missionname[5]) - 1;
        if( index != i )
        {
            // swap current index to the campaign index and keep check current index.
            servermap.SwapAt(i, index);
            i--;
        }
            
    }
}
void GetWorkshopMapVpkName()
{
    // load workshop map vpkname.
    int addonlist = GetAddonList();
    if( addonlist == 0 )
        return;

    Address data = LoadFromAddress(g_Address_vecAddonMetadata, NumberType_Int32);
    int offset, type;
    char missionfile[128], path[128];
    for(int i = 0; i < addonlist; i++)
    {
        type = LoadFromAddress(data + view_as<Address>(offset) + view_as<Address>(256), NumberType_Int8);

        if( type < 0 || type > 2 )  // addonlist by read addonlist.txt count is not correct since there is mutli pack vpk map.  
            break;                  // to reduce the situtation of over read, check type before it is over.

        // type != 1, which is not mission
        if( type != 1 )
        {
            offset += 264; // 128 + 128 + 8
            continue;
        }
        
        LoadStringFromAddress(data + view_as<Address>(offset) + view_as<Address>(128), missionfile, sizeof(missionfile));
        LoadStringFromAddress(data + view_as<Address>(offset), path, sizeof(path));

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
    for(int i = 0; i < len; i++)
    {
        // PrintToChatAll("comparing %s", buffer[len - i]);
        if( strncmp(buffer[len - i], "/", 1) == 0 )
            break;
        
        index++;
    }

    Format(buffer, size, "%s", buffer[len - index + 1]);
    SplitString(buffer, ".vpk", buffer, size);
}
void SetMissionVpkName()
{
    MapInfo map;
    for(int i = 0; i < servermap.Length; i++)
    {
        servermap.GetArray(i, map);

        if( map.type == OFFICIAL_MAP )
        {
            int index = StringToInt(map.missionname[5]); // remove L4D2C and add campaign
            FormatEx(map.vpkname, sizeof(map.vpkname), "%s", g_official_vpkname[index - 1]); // mission name start from 1, so reduce 1 to adjust the char array.
        }

        else if( map.type == WORKSHOP_MAP )
        {
            if( workshopmap_vpkname.ContainsKey(map.missionfile) )
                workshopmap_vpkname.GetString(map.missionfile, map.vpkname, sizeof(map.vpkname));
        }

        LogMessage("total servermap %d set vpkname of map %s, vpkname %s",servermap.Length, map.missionname, map.vpkname);
        servermap.SetArray(i, map);
    }
}

void LoadGameData()
{
    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);

    if( !FileExists(sPath) ) 
        SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

    GameData hGameData = new GameData(GAMEDATA);
    if(hGameData == null) 
        SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

    if( GetAddonList() == 0 )
    {
        LogMessage("server doesn't have workshop map, please add it.");
        return;
    }

    g_Address_vecAddonMetadata  = hGameData.GetMemSig("vecAddonMetadata");
    if( g_Address_vecAddonMetadata == Address_Null )
        SetFailState("Failed to load \"vecAddonMetadata\" address");
}

stock int LoadStringFromAddress(Address addr, char[] buffer, int maxlen, bool &bIsNullPointer = false)
{
    if( !addr )
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
    }
    while (ch && ++c < maxlen - 1);
    return c;
}