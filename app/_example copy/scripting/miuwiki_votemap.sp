#pragma semicolon 1
#pragma newdecls required
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <maplist>

#define PLUGIN_VERSION "1.0.0"

ArrayList g_maplist;

ConVar
    cvar_l4d2_votetime,
    cvar_l4d2_showinterval;
    

char 
    g_votemap[128];

bool 
    g_isvoting;

int  
    g_clientvote[MAXPLAYERS + 1] = {-1, ...};

float
    g_showinterval,
    g_lastshowtime,

    g_votetime,
    g_startvotetime;

public Plugin myinfo =
{
    name = "[L4D2] Map Vote",
    author = "Miuwiki",
    description = "Vote to change map",
    version = PLUGIN_VERSION,
    url = "http://www.miuwiki.site"
}

public void OnAllPluginsLoaded()
{
    if( !LibraryExists("maplist") )
        SetFailState("Couldn't find request plugin \"miuwiki_mapchooser.smx\", check it is running or not.");

}

public void OnPluginStart()
{
    cvar_l4d2_showinterval = CreateConVar("l4d2_showinterval", "0.5", "How many seconds is the interval between displaying voting information.", 0, true, 0.1);
    cvar_l4d2_votetime     = CreateConVar("l4d2_votetime", "20.0", "How many seconds will the voting result be calculated.", 0, true, 1.0);
    
    cvar_l4d2_showinterval.AddChangeHook(HookCvarChange);
    cvar_l4d2_votetime.AddChangeHook(HookCvarChange);


    RegConsoleCmd("sm_mapv", CMD_VoteMap);
    // AutoExecConfig(true);
}

public void OnConfigsExecuted()
{
    CvarChange();
}

void HookCvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    CvarChange();
}

void CvarChange()
{
    g_showinterval = cvar_l4d2_showinterval.FloatValue;
    g_votetime = cvar_l4d2_votetime.FloatValue;

}

public void OnClientConnected(int client)
{
    if( IsFakeClient(client) )
        return;
    
    g_clientvote[client] = -1;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    // PrintHintTextToAll("%N SAY %s, command %s", client, sArgs, command);
    if( client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) )
        return Plugin_Continue;
   
    if( !g_isvoting || g_clientvote[client] != -1 || strlen(sArgs) != 1)
        return Plugin_Continue;

    int type = StringToInt(sArgs);
    if( type < 0 || type > 2 )
        return Plugin_Continue;
    
    // check again for failed.
    if( type == 0 && strcmp(sArgs, "0") == 0 )
    {
        g_clientvote[client] = type;
        return Plugin_Continue;
    }

    g_clientvote[client] = type;
    return Plugin_Continue;
}

Action CMD_VoteMap(int client, int args)
{
    if( client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) )
        return Plugin_Handled;
    
    if( g_isvoting )
    {
        PrintToChat(client, "服务器已经在投票了, 请等待这一轮投票结束!");
        return Plugin_Handled;
    }

    Menu menu = new Menu(MenuHandler_ShowMap);
    menu.SetTitle("★投票更换地图\n——————————————");
    int flag = GetUserFlagBits(client);

    if( flag & (ADMFLAG_CHANGEMAP|ADMFLAG_ROOT) )
        menu.AddItem("workshop" ,"更换三方图");
    else
        menu.AddItem("non", "更换三方图(您非管理员无法使用)", ITEMDRAW_DISABLED);
    
    menu.AddItem("official", "更换官方图");

    menu.Display(client, 20);
    return Plugin_Handled;
    // ArrayList maplist = M_GetMapList(OFFICIAL_MAP);
}

int MenuHandler_ShowMap(Menu menu, MenuAction action, int client, int index)
{
    if(action == MenuAction_Select)
    {
        char info[128];
        menu.GetItem(index, info, sizeof(info));

        if( strcmp(info, "workshop") == 0 )
            ShowMapList(client, WORKSHOP_MAP);
        else if( strcmp(info, "official") == 0 )
            ShowMapList(client, OFFICIAL_MAP);
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

void ShowMapList(int client, int mode)
{
    Menu menu = new Menu(MenuHandler_ShowChapterList);
    g_maplist = mode == OFFICIAL_MAP ? M_GetMapList(OFFICIAL_MAP) : M_GetMapList(WORKSHOP_MAP);
    
    if(mode == OFFICIAL_MAP)
        menu.SetTitle("★官方图\n——————————————");
    else
        menu.SetTitle("★三方图\n——————————————");

    MapInfo map; char info[8];
    for(int i = 0; i < g_maplist.Length; i++)
    {
        
        g_maplist.GetArray(i, map);
        
        FormatEx(info, sizeof(info), "%d", i);
        if( strcmp(map.vpkname, "") == 0 )
            menu.AddItem(info, map.missionname);
        else
            menu.AddItem(info, map.vpkname);
        // map.vpkname()
        // menu.AddItem()
    }

    menu.Display(client, 20);
}
int MenuHandler_ShowChapterList(Menu menu, MenuAction action, int client, int index)
{
    if(action == MenuAction_Select)
    {
        char info[128];
        menu.GetItem(index, info, sizeof(info));
        ShowChapterList(client, StringToInt(info));
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}
void ShowChapterList(int client, int index)
{
    Menu menu = new Menu(MenuHandler_VoteMap);
    MapInfo map;
    g_maplist.GetArray(index, map);

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

int MenuHandler_VoteMap(Menu menu, MenuAction action, int client, int index)
{
    if(action == MenuAction_Select)
    {
        if( g_isvoting )
        {
            PrintToChat(client, "服务器已经在投票了, 请等待这一轮投票结束!");
            return 0;
        }

        g_isvoting = true;
        g_startvotetime = GetGameTime();
        menu.GetItem(index, g_votemap, sizeof(g_votemap));
        PrintToChatAll("\x04[服务器]\x05正在举行投票换图, 聊天框输入\x040反对\x05, 1赞成, \x012弃权\x05.");
    }
    else if(action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

public void OnGameFrame()
{
    float time = GetGameTime();
    // check vote result.
    if( g_startvotetime != 0 && time - g_startvotetime >= g_votetime )
    {
        CheckResult();
        return;
    }
    
    if( !g_isvoting || time - g_lastshowtime <= g_showinterval )
        return;
    
    int data[3];
    for(int client = 1; client <= MaxClients; client++)
    {
        if( !IsClientInGame(client) || IsFakeClient(client) )
            continue;
        
        if( g_clientvote[client] == 0 )
            data[0]++;
        else if( g_clientvote[client] == 1 )
            data[1]++;
        else if( g_clientvote[client] == 2)
            data[2]++;
    }

    static char info[512];
    for(int client = 1; client <= MaxClients; client++)
    {
        if( !IsClientInGame(client) || IsFakeClient(client) )
            continue;
        
        if( g_clientvote[client] == -1 )
        {
            FormatEx(info, sizeof(info), "★正在投票换图到:%s\n \
                                        赞成: %d \\\\ 反对: %d \\\\ 弃权: %d\n \
                                        您还未投票!", g_votemap, data[1], data[0], data[2]);
        }
        else if( g_clientvote[client] == 0 )
        {
            FormatEx(info, sizeof(info), "★正在投票换图到:%s\n \
                                        赞成:%d \\\\ 反对:%d \\\\ 弃权:%d\n \
                                        您已投反对票!", g_votemap, data[1], data[0], data[2]);
        }
        else if( g_clientvote[client] == 1 )
        {
            FormatEx(info, sizeof(info), "★正在投票换图到:%s\n \
                                        赞成:%d \\\\ 反对:%d \\\\ 弃权:%d\n \
                                        您已投赞成票!", g_votemap, data[1], data[0], data[2]);
        }
        else if( g_clientvote[client] == 2 )
        {
            FormatEx(info, sizeof(info), "★正在投票换图到:%s\n \
                                        赞成:%d \\\\ 反对:%d \\\\ 弃权:%d\n \
                                        您已投弃权票!", g_votemap, data[1], data[0], data[2]);
        }

        PrintHintText(client, "%s", info);
    }

    g_lastshowtime = time;
}

void CheckResult()
{
    int data[3];
    for(int client = 1; client <= MaxClients; client++)
    {
        if( !IsClientInGame(client) || IsFakeClient(client) )
            continue;
        
        if( g_clientvote[client] == 0 )
            data[0]++;
        else if( g_clientvote[client] == 1 )
            data[1]++;
        else if( g_clientvote[client] == 2)
            data[2]++;
        
        g_clientvote[client] = -1;
    }

    if( data[1] > data[0] )
    {
        PrintHintTextToAll("投票获得通过!\n正在更换地图到%s!", g_votemap);
        PrintToChatAll("\x04[服务器]\x05投票获得通过! 正在更换地图到\x04%s\x05!", g_votemap);
        ServerCommand("sm_map %s", g_votemap);
    }
    else if( data[0] >= data[1] )
    {
        PrintHintTextToAll("投票未获得通过!");
        PrintToChatAll("\x04[服务器]\x05投票未获得通过!");
    }

    g_isvoting = false;
    g_votemap = "";
    g_startvotetime = 0.0;
    g_lastshowtime = 0.0;
    delete g_maplist;
}