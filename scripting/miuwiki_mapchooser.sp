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
#define MAP_SEPARATOR "^^"
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

enum struct ServerMapInfo
{
    ArrayList official_map; // data type: mission file^^mission.Name^^chapter1^^chapter2...
    ArrayList workshop_map;
    StringMap all_map;  // mission.Name => mission.Name^^mission file^^mission.Name^^chapter1^^chapter2...
    StringMap vpk_name; // mission file name => vpk name

    void SplitChapter(const char[] source = "", ArrayList arraystr) // use param not the return because it doesn't need to delete it in the loop, just Clear() instead.
    {
        char buffer[512], temp[512]; int split;
        FormatEx(buffer, sizeof(buffer), "%s", source);

        do
        {
            if( IsNullString(buffer) )
                break;

            split = SplitString(buffer, MAP_SEPARATOR, temp, sizeof(temp));

            if( split == -1 )
                break;

            arraystr.PushString(temp);
            Format(buffer, sizeof(buffer), "%s", buffer[split]);
        }
        while( split != -1 );
    }

    void SortOfficialMap()
    {
        ArrayList official_map_clone = this.official_map.Clone();
        ArrayList chapterlist        = new ArrayList(ByteCountToCells(128));

        char buffer[1024], mission_name[128];
        for(int i = 0; i < this.official_map.Length; i++)
        {
            this.official_map.GetString(i, buffer, sizeof(buffer));
            this.SplitChapter(buffer, chapterlist);
            chapterlist.GetString(1, mission_name, sizeof(mission_name));

            int index = StringToInt(mission_name[5]) - 1; // remove "L4D2C" so "L4D2C5" will be 5 instead.
                                                          // since map always start from 1 but arraylist start from 0, reduce 1 to adjust arraylist.
                                                          // the true name hasn't been effected by reduce 1.
            official_map_clone.SetString(index, buffer);
            chapterlist.Clear();
        }

        delete chapterlist;
        delete this.official_map;

        this.official_map = official_map_clone; // use clone handle as the new global official_map;
    }

    bool GetMissionVpkName()
    {
        // load official map vpkname.
        char official_mission_txt[128];
        for(int i = 0; i < sizeof(g_official_vpkname); i++)
        {
            FormatEx(official_mission_txt, sizeof(official_mission_txt), "campaign%d", i+1);
            this.vpk_name.SetString(official_mission_txt, g_official_vpkname[i]);
        }

        // load workshop map vpkname.
        int addonlist = GetAddonList();
        if( addonlist == 0 )
            return false;

        Address data = LoadFromAddress(g_Address_vecAddonMetadata, NumberType_Int32);
        int offset;
        char mission_txt[128], path[128];
        for(int i = 0; i < addonlist; i++)
        {
            LoadStringFromAddress(data + view_as<Address>(offset) + view_as<Address>(128), mission_txt, sizeof(mission_txt));
            LoadStringFromAddress(data + view_as<Address>(offset), path, sizeof(path));

            // type != 1, which is not mission
            if( LoadFromAddress(data + view_as<Address>(offset) + view_as<Address>(256), NumberType_Int8) != 1 )
            {
                // PrintToChatAll("this vpk path %s is not a mission.", path);
                offset += 264; // 128 + 128 + 8
                continue;
            }

            this.GetVpknameFromPath(path, sizeof(path));
            this.vpk_name.SetString(mission_txt, path);

            // PrintToChatAll("store mission vpk path %s to %s", path, mission_txt);
            offset += 264;
        }

        return true;
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
}

ServerMapInfo servermap;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if( GetEngineVersion() != Engine_Left4Dead2 ) // only support left4dead2
        return APLRes_SilentFailure;

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadGameData();

    servermap.official_map = new ArrayList(ByteCountToCells(1024));
    servermap.workshop_map = new ArrayList(ByteCountToCells(1024));
    servermap.all_map      = new StringMap();
    servermap.vpk_name     = new StringMap();
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

    LogMessage("create admin menu category.");

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
    Menu menu             = new Menu(MenuHandler_ShowMapList);
    ArrayList chapterlist = new ArrayList(ByteCountToCells(1024));

    ArrayList source = mode == OFFICIAL_MAP ? servermap.official_map : servermap.workshop_map;

    char buffer[512], mapname[128], filename[128], vpkname[128];
    
    if( mode == OFFICIAL_MAP )
        menu.SetTitle("★官方图\n——————————————");
    else
        menu.SetTitle("★三方图\n——————————————");

    for(int i = 0; i < source.Length; i++)
    {
        source.GetString(i, buffer, sizeof(buffer));
        servermap.SplitChapter(buffer, chapterlist);
        chapterlist.GetString(0, filename, sizeof(filename)); // this one is mission file name
        chapterlist.GetString(1, mapname, sizeof(mapname)); // this one is mission name

        if( servermap.vpk_name.GetString(filename, vpkname, sizeof(vpkname) ) ) // get vpkname from servermap.vpk_name
            FormatEx(buffer, sizeof(buffer), "%s", vpkname);
        else
            FormatEx(buffer, sizeof(buffer), "%s", mapname);

        menu.AddItem(mapname, buffer);
        chapterlist.Clear();
    }

    menu.Display(client, 20);
    delete chapterlist;
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
    Menu menu             = new Menu(MenuHandler_ChangeMap);
    ArrayList chapterlist = new ArrayList(ByteCountToCells(1024));

    char buffer[1024], vpkname[128];
    servermap.all_map.GetString(info, buffer, sizeof(buffer));
    servermap.SplitChapter(buffer, chapterlist);
    chapterlist.GetString(0, buffer, sizeof(buffer));

    if( servermap.vpk_name.GetString(buffer, vpkname, sizeof(vpkname) ) ) // get vpkname from servermap.vpk_name
        FormatEx(buffer, sizeof(buffer), "%s", vpkname);
        
    Format(buffer, sizeof(buffer), "★%s\n——————————————", buffer);
    menu.SetTitle(buffer);

    for(int i = 2; i < chapterlist.Length; i++) // 0,1 is the mission file name and mission name;
    {
        chapterlist.GetString(i, buffer, sizeof(buffer));
    
        menu.AddItem(buffer, buffer);
    }

    menu.Display(client, 20);
    delete chapterlist;
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

void LoadServerMap()
{
    bool official;
    char path[1024];
    char mission_filename[128];
    char mission_name[128];
    char chapter_name[128];

    DirectoryListing missionlist = OpenDirectory("missions", true);
    if( missionlist == null )
    {
        SetFailState("Failed to open missions folder, game error!");
    }

    while( missionlist.GetNext( mission_filename, sizeof(mission_filename)) )
    {
        if( strcmp(mission_filename[strlen(mission_filename) - 4], ".txt") != 0 ) // just confirm the last 4 byte is ".txt" or not.
            continue;

        FormatEx(path, sizeof(path), "missions/%s", mission_filename);
        KeyValues kv = new KeyValues("");
        kv.ImportFromFile(path);
        kv.GetString("Name", mission_name, sizeof(mission_name));

        SplitString(mission_filename, ".txt", mission_filename, sizeof(mission_filename)); // remove .txt in the end.

        // now we use path as a buffer to store map info.
        // this will become mission_filename^^mission_name^^
        // after do that it store each chapter name in order to sort the chapter.
        FormatEx(path, sizeof(path), "%s%s%s%s", mission_filename, MAP_SEPARATOR, 
                                                 mission_name, MAP_SEPARATOR);    

        official = strncmp(mission_name, "L4D2C", 5) == 0 ? true : false; // whatever, if the Name of the mission can be l4d2c with workshop map, i don't know how to identify it.

        kv.JumpToKey("modes");
        if( !kv.JumpToKey("coop") || strcmp(mission_name, "credits" ) == 0 ) // we only collect the map which have coop mode but not credits.
        {
            delete kv;
            continue;
        }
            
        kv.GotoFirstSubKey();
        do
        {
            kv.GetString("Map", chapter_name, sizeof(chapter_name));
            Format(path, sizeof(path), "%s%s%s", path, chapter_name, MAP_SEPARATOR);

            if( official )
                LogMessage("Get official map: %s, chapter: %s", mission_name, chapter_name);
            else
                LogMessage("Get workshop map: %s, chapter: %s", mission_name, chapter_name);
        }
        while( kv.GotoNextKey() );

        if( official )
            servermap.official_map.PushString(path);
        else
            servermap.workshop_map.PushString(path);
        
        servermap.all_map.SetString(mission_name, path);
        delete kv;
    }

    servermap.SortOfficialMap();
    servermap.GetMissionVpkName();
    delete missionlist;
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

    g_Address_vecAddonMetadata = hGameData.GetMemSig("vecAddonMetadata");
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
