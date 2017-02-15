#include <sourcemod>
#include <adminmenu>
#include <csgo_colors> /* for colors csgo */
#include <morecolors> /* for any game colors, but no csgo */

#pragma newdecls required

#define SGT(%0) SetGlobalTransTarget(%0)
#define CID(%0) GetClientOfUserId(%0)
#define CUD(%0) GetClientUserId(%0)
#define VERSION "1.2-fix"
/* Global variables */
TopMenu hTopMenu;
int iViewPly[MAXPLAYERS+1];
bool bMenu;
bool bAdmin;
/* bool bLogging; */
ConVar version_plugin;
/* Info of plugin */
public Plugin myinfo = 
{
    version     = VERSION,
    author      = "Rabb1t",
    name        = "[SM] Info about players",
    description = "Draw information of players",
    url         = "http://hlmod.ru/resources/player-information.279/"
};

public void OnPluginStart() 
{   /* For ALL players */
    RegConsoleCmd("sm_info", Cmd_Info);
    RegConsoleCmd("sm_players", Cmd_Info);
    RegConsoleCmd("sm_infop", Cmd_Info);
    RegConsoleCmd("sm_playersinfo", Cmd_Info);
    /* For ONLY admins */
    RegAdminCmd("sm_infop_version", Cmd_Info_Version, ADMFLAG_ROOT); /* For only admin with flag Z */
    /* NO WORK!! RegAdminCmd("sm_infoa", Cmd_Info_Admin, "Same <sm_info>, but only for admins"); */
    
    LoadTranslations("infoply.phrases");

    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
        OnAdminMenuReady(topmenu);
    /* Type draw */
    ConVar cv;
    cv = CreateConVar("sm_infoplayers_type", "1", "Draw player information with menu, if value equal 1, or print to console.", 0, true, 0.0, true, 1.0);
    cv.AddChangeHook(onCvarUpdated);
    onCvarUpdated(cv, NULL_STRING, "1");
    delete cv;
    /* Cvar for check version plugin */
    version_plugin = CreateConVar("sm_infoplayers_version", VERSION, "Info about players version", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_CHEAT);
    delete version_plugin;
    /* Player check IP other players */
    ConVar padm;
    padm = CreateConVar("sm_infoplayers_players_check_ip", "0", "Show the players IP to the other players", 0, true, 0.0, true, 1.0); 
    padm.AddChangeHook(CvarUpdater);
    CvarUpdater(padm, NULL_STRING, "0"); //что бы игроки не могли видеть чужой IP
    delete padm;
    /* Logging */
    /*ConVar lg;
    lg = CreateConVar("sm_infoplayers_logging", "0", "Logging to file logs on SourceMod", 0, true, 0.0, true, 1.0);
    lg.AddChangeHook(ConVarUpdated);
    ConVarUpdated(lg, NULL_STRING, "0");
    delete lg; */
    AutoExecConfig(true, "Info_Players");
}

public void CvarUpdater(ConVar padm, const char [] aV, const char [] mV)
{
    bAdmin = (mV[0] == '1');
}

public void onCvarUpdated(ConVar cv, const char[] oV, const char[] nV) 
{
    bMenu = (nV[0] == '1');
}

/*public void ConVarUpdated( ConVar lg, const char [] iV, const char [] hV)
{
    bLogging = StrEqual(hV, "1")
} */

public Action Cmd_Info(int client, int args) 
{
    if (client)
        RenderPlayersMenu(client);
    else
        ReplyToCommand(client, "[SM] Use this command in-game");
    return Plugin_Handled;
}

public void OnAdminMenuReady(Handle aTopMenu) 
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

    if (topmenu == hTopMenu)
        return;

    hTopMenu = topmenu;

    TopMenuObject plycommands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
    if (plycommands != INVALID_TOPMENUOBJECT)
        hTopMenu.AddItem("sm_info", AdminMenu_Info, plycommands, "sm_info", ADMFLAG_BAN);
}

public void AdminMenu_Info(TopMenu topmenu, TopMenuAction action, TopMenuObject objId, int param, char[] buffer, int maxlength) 
{
    if (action == TopMenuAction_DisplayOption)
        FormatEx(buffer, maxlength, "%T", "plyinfo_adminmenu", param);
    else if (action == TopMenuAction_SelectOption)
        RenderPlayersMenu(param, true);
}

/* Handlers */
public int PlyMenuHandler(Menu menu, MenuAction action, int param1, int param2) 
{
    if (action == MenuAction_Select) 
    {
        char szBuffer[6];
        menu.GetItem(param2, szBuffer, sizeof(szBuffer));
        int iTarget = CID(StringToInt(szBuffer));
        if (iTarget)
            RenderPlayerInformation(param1, iTarget);
        else 
        {
                SGT(param1);
                if(GetEngineVersion() == Engine_CSGO)
                    CGOPrintToChat(param1, "[SM] %t", "plyinfo_playerexited");
                else
                    CPrintToChat(param1, "[SM] %t", "plyinfo_playerexited");
                
                RenderPlayersMenu(param1);
        }
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack && hTopMenu)
        hTopMenu.Display(param1, TopMenuPosition_LastCategory);
}

public int AboutPlyHandler(Menu menu, MenuAction action, int param1, int param2) 
{
    if (action == MenuAction_Select && param2 == 5) 
    {
        int iTarget = CID(iViewPly[param1]);
        if (iTarget)
            RenderPlayerProfile(param1, iTarget);
        else 
        {
            SGT(param1);
            if(GetEngineVersion() == Engine_CSGO)
                CGOPrintToChat(param1, "[SM] %t", "plyinfo_playerexited");
            else
                CPrintToChat(param1, "[SM] %t", "plyinfo_playerexited");
        }
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
        RenderPlayersMenu(param1);
}

/* Renders */
void RenderPlayersMenu(int client, bool fromAdmin = false) 
{
    SGT(client);

    Menu menu = new Menu(PlyMenuHandler);

    menu.SetTitle("%t:\n ", "plyinfo_menutitle");
    if (fromAdmin)
        menu.ExitBackButton = true;
    else
        menu.ExitButton = true;
    AddTargetsToMenu2(menu, 0, COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS);

    menu.Display(client, MENU_TIME_FOREVER);
}

void RenderPlayerInformation(int client, int target) 
{
    SGT(client);
    iViewPly[client] = CUD(target);

    char szBuffer[80];
    char szAuth[32];
    char szPlayerIP[16];
    char szConnectTime[15];
    Menu hMenu;
    
    if (bMenu)
        hMenu = new Menu(AboutPlyHandler);

    if (bMenu)
        hMenu.SetTitle("%t:\n ", "plyinfo_plytitle_menu");
    else
    {
        if(GetEngineVersion() == Engine_CSGO)
            CGOPrintToChat(client, "%t:\n ", "plyinfo_plytitle");
        else
            CPrintToChat(client, "%t:\n ", "plyinfo_plytitle");
    }

    /**
     * 1. Username: Newbie
     * 2. SteamID: STEAM_0:1:1337
     * 3. IP: 127.0.0.1
     * 4. Connect time: 2 min., 28 sec.
     * 
     * 6. Show user profile in MOTD
     */

    /* Player username */
    FormatEx(szBuffer, sizeof(szBuffer), "%t", "plyinfo_nickname_menu", target);
    if (bMenu)
        hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
    else
    {
        if(GetEngineVersion() == Engine_CSGO)
            CGOPrintToChat(client, "%t", "plyinfo_nickname", target);
        else
            CPrintToChat(client, "%t", "plyinfo_nickname", target);
    }
    
    /* Status Client (Admin or player) */
    if(GetUserAdmin(client) != INVALID_ADMIN_ID) /* Client Admin */
    {
        FormatEx(szBuffer, sizeof(szBuffer), "%t", "plyinfo_status_admin");
        if(bMenu)
            hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
        else
        {
            if(GetEngineVersion() == Engine_CSGO)
                CGOPrintToChat(client, "%t", "plyinfo_status_admin_chat");
            else
                CPrintToChat(client, "%t", "plyinfo_status_admin_chat");
        }
    }
    else /* Client Player */
    {
        FormatEx(szBuffer, sizeof(szBuffer), "%t", "plyinfo_status_player");
        if(bMenu)
            hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
        else
        {
            if(GetEngineVersion() == Engine_CSGO)
                CGOPrintToChat(client, "%t", "plyinfo_status_player_chat");
            else
                CPrintToChat(client, "%t", "plyinfo_status_player_chat");
        }
    }
    
    /* SteamID */
    if (!GetClientAuthId(target, AuthId_Steam2, szAuth, sizeof(szAuth)))
    strcopy(szAuth, sizeof(szAuth), "STEAM_ID_PENDING");

    if (bMenu)
    {
        FormatEx(szBuffer, sizeof(szBuffer), "%t", "steamid_phrase_menu", szAuth);
        hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
    }
        else
        {
            if(GetEngineVersion() == Engine_CSGO)
                CGOPrintToChat(client, "%t", "steamid_phrase_chat", szAuth);
            else
                CPrintToChat(client, "%t", "steamid_phrase_chat", szAuth);
        }

    /* IP */
    if (bAdmin || GetUserAdmin(client) != INVALID_ADMIN_ID) /* IP now Draw to players, only admins */
    {
        if (!GetClientIP(target, szPlayerIP, sizeof(szPlayerIP)))
            strcopy(szPlayerIP, sizeof(szPlayerIP), "127.0.0.1");
        Format(szBuffer, sizeof(szBuffer), "%t", "plyinfo_ip_menu", szPlayerIP);
        if (bMenu)
            hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
        else
        {
            if(GetEngineVersion() == Engine_CSGO)
                CGOPrintToChat(client, "%t", "plyinfo_ip", szPlayerIP);
            else
                CPrintToChat(client, "%t", "plyinfo_ip", szPlayerIP);
        }
    }
    
    /* Connection time */
    PrepareTime(szConnectTime, sizeof(szConnectTime), RoundToFloor(GetClientTime(target)));
    Format(szBuffer, sizeof(szBuffer), "%t", "plyinfo_connected_menu", szConnectTime);
    if (bMenu)
        hMenu.AddItem(NULL_STRING, szBuffer, ITEMDRAW_DISABLED);
    else
    {
        if(GetEngineVersion() == Engine_CSGO)
            CGOPrintToChat(client, "%t", "plyinfo_connected", szConnectTime);
        else
            CPrintToChat(client, "%t", "plyinfo_connected", szConnectTime);
    }
    
   /* if (bLogging) // Logging Connection time 
        LogMessage(szBuffer); */ 
    
    /* Spacer and MOTD */
    if ((GetEngineVersion() != Engine_CSGO)) /* OFF on CS:GO */
    {
    if (bMenu) {
        hMenu.AddItem(NULL_STRING, NULL_STRING, ITEMDRAW_SPACER);
        FormatEx(szBuffer, sizeof(szBuffer), "%t", "plyinfo_showprofile");
        hMenu.AddItem(NULL_STRING, szBuffer);
    }
    }
    
    /* DRAW, IF THE MENU. */
    if (bMenu)
        hMenu.Display(client, MENU_TIME_FOREVER);
}

void RenderPlayerProfile(int client, int target) 
{
    char szBuffer[64];
    if (GetClientAuthId(target, AuthId_SteamID64, szBuffer, sizeof(szBuffer))) 
    {
        Format(szBuffer, sizeof(szBuffer), "https://steamcommunity.com/profiles/%s/", szBuffer);
        
        ShowMOTDPanel(client, "Steam Profile", szBuffer, MOTDPANEL_TYPE_URL);
    }
}

/* Helpers */
int PrepareTime(char[] buff, int buffLength, int iTime) {
    int iMinute =   iTime/60; 
    int iHour   =   (iTime-(iMinute*60))/60;
    int iSecond =   iTime-((iHour*3600)+iMinute*60);
    
    return FormatEx(buff, buffLength, "%d:%d:%d", iHour, iMinute, iSecond);
}
/* Вывод квара (версии)*/
public Action Cmd_Info_Version(int client, int args)
{
    if (client >= 1 && IsClientInGame(client))
        ReplyToCommand(client, "Version of plugin = {darkred}%s", VERSION); 
    return Plugin_Handled;
}
