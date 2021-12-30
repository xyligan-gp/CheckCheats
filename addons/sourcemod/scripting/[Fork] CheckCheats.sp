#pragma tabsize 0
#pragma semicolon 1
#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS

#include <cstrike>
#include <sourcemod>
#include <adminmenu>
#include <sdktools>
#include <morecolors>
#include <csgo_colors>
#include <sourcebanspp>
#include <materialadmin>

#define CHECKCHEATS_MAINMENU "CheckCheats_MainMenu"

#define PLUGIN_NAME "[Fork] CheckCheats"
#define PLUGIN_AUTHOR "xyligan"
#define PLUGIN_DESCRIPTION "Плагин для проверки игроков на читы"
#define PLUGIN_VERSION "3.2 [BETA]"
#define PLUGIN_URL "https://hlmod.ru/resources/check-cheats-fork.3012/"

enum struct player {
    char ActionSelect[64];
    int ActionPlayer;
    bool BlockSpec;
    int StatusCheck;
    char Discord[64];
}

enum StatusCheckEnum {
    STATUS_WAITCOMMUNICATION = 0,
    STATUS_WAITCALL = 1,
    STATUS_CHECKING = 2,
    STATUS_RESULT = 3
}

TopMenu g_hTopMenu;
EngineVersion g_EngineVersion;
player g_iPlayerInfo[MAXPLAYERS + 1];
int g_iBanTime, g_iMessenger[MAXPLAYERS + 1], g_iBanEnabled, g_iWaitMessengerTime[MAXPLAYERS + 1], g_iWaitTime;
bool g_bHideAdmins, g_bPlayerChecking[MAXPLAYERS + 1];
ConVar g_cPluginTag, g_cHideAdmins, g_cSoundPath, g_cBanTime, g_cMessengers, g_cOverlayPath, g_cBanReason, g_cDownloadsPath, g_cBanEnabled, g_cWaitMessengerTime;
char g_sTag[256], g_sSoundPath[256], g_sBanSystem[256], g_sMessenger[256], g_sOverlayPath[256], g_sBanReason[256], g_sDownloadsPath[256];

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
}

public void OnPluginStart() {
    g_EngineVersion = GetEngineVersion();

    g_cPluginTag = CreateConVar("checkcheats_tag", "[CheckCheats]", "Префикс плагина в чате.");
    g_cWaitMessengerTime = CreateConVar("checkcheats_wait_time", "1", "Время в минутах отведённое на ожидание данных игрока для связи. [0 - без лимита]");
    g_cBanEnabled = CreateConVar("checkcheats_ban_enabled", "1", "Бан игроков при наличии читов/выходе с сервера. [0 - Выключить | 1 - Включить]");
    g_cDownloadsPath = CreateConVar("checkcheats_downloads_path", "data/checkcheats/downloads.txt", "Путь к файлу загрузок плагина. [без папки addons/sourcemod]");
    g_cBanReason = CreateConVar("checkcheats_ban_reason", "Отказ пройти проверку на читы", "Причина бана игроков при отказе от проверки.");
    g_cHideAdmins = CreateConVar("checkcheats_admins_hide", "1", "Скрытие администраторов в списке на проверку. [0 - Выключить | 1 - Включить]");
    g_cSoundPath = CreateConVar("checkcheats_sound_path", "check_cheats/man.mp3", "Путь к звуку, который будет проигрываться у игрока во время вызова на проверку. [пустое поле отключает функцию]");
    g_cBanTime = CreateConVar("checkcheats_ban_time", "0", "Время бана игроков в минутах.");
    g_cMessengers = CreateConVar("checkcheats_messengers", "All", "Мессенджеры используемые для связи с игроком. [Доступные значения: Discord, Skype и All (Discord и Skype)]");
    g_cOverlayPath = CreateConVar("checkcheats_overlay_path", "overlay_cheats/ban_cheats", "Путь к оверлею, который будет отображаться у игрока во время проверки. [без папки materials]");

    AutoExecConfig(true, "CheckCheats");
    GetConVarsValues();
    LoadTranslations("CheckCheats.phrases");

    HookConVarChange(g_cPluginTag, OnConVarChanged);
    HookConVarChange(g_cWaitMessengerTime, OnConVarChanged);
    HookConVarChange(g_cBanEnabled, OnConVarChanged);
    HookConVarChange(g_cDownloadsPath, OnConVarChanged);
    HookConVarChange(g_cBanReason, OnConVarChanged);
    HookConVarChange(g_cHideAdmins, OnConVarChanged);
    HookConVarChange(g_cSoundPath, OnConVarChanged);
    HookConVarChange(g_cBanTime, OnConVarChanged);
    HookConVarChange(g_cMessengers, OnConVarChanged);
    HookConVarChange(g_cOverlayPath, OnConVarChanged);

    if(LibraryExists("adminmenu")) {
        TopMenu hTopMenu;

        if((hTopMenu = GetAdminTopMenu()) != null) {
            OnAdminMenuReady(hTopMenu);
        }
    }

    CreateTimer(0.1, Timer_GiveOverlay, _, TIMER_REPEAT);
	
	AddCommandListener(Command_JoinTeam, "jointeam");
}

public void OnClientConnected(int iClient) {
    g_iWaitMessengerTime[iClient] = 0;
	g_iMessenger[iClient] = 0;
    g_bPlayerChecking[iClient] = false;
	g_iPlayerInfo[iClient].Discord[0] = 0;
    g_iPlayerInfo[iClient].ActionSelect[0] = 0;
	g_iPlayerInfo[iClient].ActionPlayer = 0;
	g_iPlayerInfo[iClient].BlockSpec = false;
    g_iPlayerInfo[iClient].StatusCheck = 0;
}

public void OnClientDisconnect(int iClient) {
    char sMessage[256];
    int iClientChoose;

	if(StrEqual(g_iPlayerInfo[iClient].ActionSelect, "CheckCheats")) {
		iClientChoose = GetClientOfUserId(g_iPlayerInfo[iClient].ActionPlayer);

		if(iClientChoose) {
            FormatEx(sMessage, sizeof sMessage, "%T", "CheckLeaveAdmin", iClientChoose);
            CC_PrintLog(iClient, iClientChoose, "CheckLeaveAdmin", "", "");
            CC_PrintToChat(iClientChoose, sMessage);

            g_iWaitMessengerTime[iClientChoose] = 0;
            g_bPlayerChecking[iClientChoose] = false;
			g_iPlayerInfo[iClientChoose].BlockSpec = false;
			g_iPlayerInfo[iClientChoose].Discord[0] = 0;
			g_iMessenger[iClientChoose] = 0;
		}

        GiveOverlay(iClientChoose, "");
        g_bPlayerChecking[iClientChoose] = false;
		g_iPlayerInfo[iClient].ActionPlayer = 0;
		g_iPlayerInfo[iClient].ActionSelect[0] = 0;
		g_iPlayerInfo[iClient].BlockSpec = false;
		g_iPlayerInfo[iClient].StatusCheck = 0;
	}

	if(CC_IsCheckedPlayer(iClient)) {
		for(int i = 1; i <= MaxClients; i++) {
			if(IsClientInGame(i)) {
				if(g_iPlayerInfo[i].ActionPlayer == GetClientUserId(iClient) && StrEqual(g_iPlayerInfo[i].ActionSelect, "CheckCheats")) {
					iClient = i;
					iClientChoose = GetClientOfUserId(g_iPlayerInfo[i].ActionPlayer);
				}
			}
		}

        g_bPlayerChecking[iClientChoose] = false;
        g_iPlayerInfo[iClient].ActionPlayer = 0;
		g_iPlayerInfo[iClient].ActionSelect[0] = 0;
        g_iPlayerInfo[iClient].BlockSpec = false;
        g_iPlayerInfo[iClient].StatusCheck = 0;

        FormatEx(sMessage, sizeof sMessage, "%T", "CheckLeavePlayer", iClient);
        GiveOverlay(iClientChoose, "");
        CC_PrintLog(iClient, iClientChoose, "CheckPlayerLeave", "", "");
        CC_PrintToChat(iClient, sMessage);

		if(g_iBanEnabled) CC_BanClient(iClientChoose, 0, true);
    }
}

public void OnMapStart() {
    char sFile[256], sBuffer[256], sBufferFull[256];
    
    BuildPath(Path_SM, sFile, sizeof sFile, "data/checkcheats/downloads.txt");
    File hFile = OpenFile(sFile, "r");

    if(hFile != null) {
        while(ReadFileLine(hFile, sBuffer, sizeof sBuffer)) {
            TrimString(sBuffer);

            if(sBuffer[0] && sBuffer[0] != '/' && sBuffer[1] != '/') {
                FormatEx(sBufferFull, sizeof sBufferFull, "materials/%s", sBuffer);
                
                if(FileExists(sBufferFull)) {
                    PrecacheDecal(sBuffer, true);
                    AddFileToDownloadsTable(sBufferFull);
                }else{
                    PrintToServer("[OS] File does not exist, check your path to overlay! %s", sBufferFull);
                }
            }
        }

        hFile.Close();
    }
}

public void OnAllPluginsLoaded() {
    bool bSearchMA = LibraryExists("materialadmin");
    bool bSearchSBPP = LibraryExists("sourcebanspp");
    bool bSearchSB = LibraryExists("sourcebans");
    Handle hSearchBB = FindPluginByFile("basebans.smx");

    if(hSearchBB != INVALID_HANDLE) {
        g_sBanSystem = "Base Bans";

        CC_PrintLog(0, 0, "BanPluginFound", "", "");
    }else if(bSearchSB) {
        g_sBanSystem = "SourceBans";

        CC_PrintLog(0, 0, "BanPluginFound", "", "");
    }else if(bSearchSBPP) {
        g_sBanSystem = "SourceBans++";

        CC_PrintLog(0, 0, "BanPluginFound", "", "");
    }else if(bSearchMA) {
        g_sBanSystem = "Material Admin";

        CC_PrintLog(0, 0, "BanPluginFound", "", "");
    }else{
        CC_PrintLog(0, 0, "BanPluginNotFound", "", "");
        SetFailState("[CheckCheats] Ban plugin not found!");
    }
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    if(convar == g_cPluginTag) GetConVarString(g_cPluginTag, g_sTag, sizeof g_sTag);
    if(convar == g_cWaitMessengerTime) g_iWaitTime = GetConVarInt(g_cWaitMessengerTime) * 60;
    if(convar == g_cBanEnabled) g_iBanEnabled = convar.IntValue;
    if(convar == g_cDownloadsPath) GetConVarString(g_cDownloadsPath, g_sDownloadsPath, sizeof g_sDownloadsPath);
    if(convar == g_cBanReason) GetConVarString(g_cBanReason, g_sBanReason, sizeof g_sBanReason);
    if(convar == g_cHideAdmins) g_bHideAdmins = convar.BoolValue;
    if(convar == g_cSoundPath) GetConVarString(g_cSoundPath, g_sSoundPath, sizeof g_sSoundPath);
    if(convar == g_cBanTime) g_iBanTime = convar.IntValue;
    if(convar == g_cMessengers) GetConVarString(g_cMessengers, g_sMessenger, sizeof g_sMessenger);
    if(convar == g_cOverlayPath) GetConVarString(g_cOverlayPath, g_sOverlayPath, sizeof g_sOverlayPath);
}

public void OnLibraryRemoved(const char[] szName) {
    if(StrEqual(szName, "adminmenu")) {
        g_hTopMenu = null;
    }
}

public void GetConVarsValues() {
    g_bHideAdmins = GetConVarBool(g_cHideAdmins);
    g_iWaitTime = GetConVarInt(g_cWaitMessengerTime) * 60;
    g_iBanEnabled = GetConVarInt(g_cBanEnabled);
    g_iBanTime = GetConVarInt(g_cBanTime);
    GetConVarString(g_cPluginTag, g_sTag, sizeof g_sTag);
    GetConVarString(g_cDownloadsPath, g_sDownloadsPath, sizeof g_sDownloadsPath);
    GetConVarString(g_cBanReason, g_sBanReason, sizeof g_sBanReason);
    GetConVarString(g_cSoundPath, g_sSoundPath, sizeof g_sSoundPath);
    GetConVarString(g_cMessengers, g_sMessenger, sizeof g_sMessenger);
    GetConVarString(g_cOverlayPath, g_sOverlayPath, sizeof g_sOverlayPath);
}

public Action Command_JoinTeam(int iClient, const char[] sCommand, int iArgs) {
    char sMessage[256];
    
	if(CC_IsCheckedPlayer(iClient) && g_iPlayerInfo[iClient].BlockSpec) {
        FormatEx(sMessage, sizeof sMessage, "%T", "BlockSpecText", iClient, iClient);
		CC_PrintToChat(iClient, sMessage);
		
        return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Timer_GiveOverlay(Handle hTimer) {
    for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			int iClient, iClientChoose;

			for(int x = 1; x <= MaxClients; x++) {
				if(IsClientInGame(x)) {
					if(g_iPlayerInfo[x].ActionPlayer == GetClientUserId(i) && StrEqual(g_iPlayerInfo[x].ActionSelect, "CheckCheats")) {
						iClient = x;
						iClientChoose = GetClientOfUserId(g_iPlayerInfo[x].ActionPlayer);

                        if(g_iWaitTime && !g_iPlayerInfo[iClientChoose].Discord[0] && GetTime() >= g_iWaitMessengerTime[iClientChoose]) {
                            CC_PrintLog(iClient, iClientChoose, "IgnoreEnterData", "", "");
                            CC_BanClient(iClientChoose, iClient, false);
                        }
					}
				}
			}

			if(iClientChoose) {
				GiveOverlay(iClientChoose, g_sOverlayPath);

                if(!g_iMessenger[iClientChoose] && StrEqual(g_sMessenger, "All") && g_bPlayerChecking[iClientChoose]) {
                    ChooseMessengerMenu(iClientChoose);
                }
			}

			if(iClient) {
				Menu_PanelCheck(iClient);
			}
		}
	}
}

public Action OnClientSayCommand(int iClient, const char[] sCommand, const char[] sNameDiscord) {
    int iClientChoose;
    char sMessage[256];

	if(iClient && CC_IsCheckedPlayer(iClient)) {
		if(StrEqual(g_sMessenger, "All") && !g_iMessenger[iClient]) {
            FormatEx(sMessage, sizeof sMessage, "%T", "ChooseMessengerText", iClient);
			CC_PrintToChat(iClient, sMessage);
			
            return Plugin_Handled;
		}
		
        for(int i = 1; i <= MaxClients; i++) {
			if(IsClientInGame(i)) {
				if(g_iPlayerInfo[i].ActionPlayer == GetClientUserId(iClient) && StrEqual(g_iPlayerInfo[i].ActionSelect, "CheckCheats")) {
					iClient = i;
					iClientChoose = GetClientOfUserId(g_iPlayerInfo[i].ActionPlayer);
				}
			}
		}

		if(g_iPlayerInfo[iClient].StatusCheck == STATUS_WAITCOMMUNICATION) {
			if(StrEqual(g_sMessenger, "Discord")) {
				bool bHaveSharp = false;

				for(int i = 0; i < strlen(sNameDiscord); i++) {
					if(sNameDiscord[i] == '#') {
						bHaveSharp = true;
					}
				}

				strcopy(g_iPlayerInfo[iClientChoose].Discord, 100, sNameDiscord);

				if(bHaveSharp) {
                    char sPlayerMessage[256], sAdminMessage[256];
                    
                    FormatEx(sAdminMessage, sizeof sAdminMessage, "%T", "PlayerSendedDiscordAdmin", iClient, iClientChoose, sNameDiscord);
                    Format(sPlayerMessage, sizeof sPlayerMessage, "%T", "PlayerSendedDiscord", iClientChoose);
                    
                    CC_PrintToChat(iClient, sAdminMessage);
                    CC_PrintToChat(iClientChoose, sPlayerMessage);
					CC_PrintLog(iClient, iClientChoose, "PlayerSendedDiscord", sNameDiscord, "");
                    
                    g_iPlayerInfo[iClient].StatusCheck++;

					return Plugin_Handled;
				}else{
					FormatEx(sMessage, sizeof sMessage, "%T", "DataError", iClientChoose);
                    CC_PrintToChat(iClientChoose, sMessage);
					
                    return Plugin_Handled;
				}
			}else if (StrEqual(g_sMessenger, "Skype")) {
				strcopy(g_iPlayerInfo[iClientChoose].Discord, 100, sNameDiscord);

				char sPlayerMessage[256], sAdminMessage[256];
                    
                FormatEx(sAdminMessage, sizeof sAdminMessage, "%T", "PlayerSendedSkypeAdmin", iClient, iClientChoose, sNameDiscord);
                Format(sPlayerMessage, sizeof sPlayerMessage, "%T", "PlayerSendedSkype", iClientChoose);
                    
                CC_PrintToChat(iClient, sAdminMessage);
                CC_PrintToChat(iClientChoose, sPlayerMessage);
				CC_PrintLog(iClient, iClientChoose, "PlayerSendedSkype", sNameDiscord, "");
                
                g_iPlayerInfo[iClient].StatusCheck++;
			}else if(StrEqual(g_sMessenger, "All")) {
				if(g_iMessenger[iClientChoose] == 1) {
					bool bHaveSharp = false;
					
                    for(int i = 0; i < strlen(sNameDiscord); i++) {
						if(sNameDiscord[i] == '#') {
							bHaveSharp = true;
						}
					}

					strcopy(g_iPlayerInfo[iClientChoose].Discord, 100, sNameDiscord);

					if(bHaveSharp) {
						char sPlayerMessage[256], sAdminMessage[256];
                    
                        FormatEx(sAdminMessage, sizeof sAdminMessage, "%T", "PlayerSendedDiscordAdmin", iClient, iClientChoose, sNameDiscord);
                        Format(sPlayerMessage, sizeof sPlayerMessage, "%T", "PlayerSendedDiscord", iClientChoose);
                        
                        CC_PrintToChat(iClient, sAdminMessage);
                        CC_PrintToChat(iClientChoose, sPlayerMessage);
						CC_PrintLog(iClient, iClientChoose, "PlayerSendedDiscord", sNameDiscord, "");

                        g_iPlayerInfo[iClient].StatusCheck++;

						return Plugin_Handled;
					}else{
						FormatEx(sMessage, sizeof sMessage, "%T", "DataError", iClientChoose);
                        CC_PrintToChat(iClientChoose, sMessage);

                        return Plugin_Handled;
					}
				}else if(g_iMessenger[iClientChoose] == 2) {
					strcopy(g_iPlayerInfo[iClientChoose].Discord, 100, sNameDiscord);

					char sPlayerMessage[256], sAdminMessage[256];
                    
                    FormatEx(sAdminMessage, sizeof sAdminMessage, "%T", "PlayerSendedSkypeAdmin", iClient, iClientChoose, sNameDiscord);
                    Format(sPlayerMessage, sizeof sPlayerMessage, "%T", "PlayerSendedSkype", iClientChoose);
                        
                    CC_PrintToChat(iClient, sAdminMessage);
                    CC_PrintToChat(iClientChoose, sPlayerMessage);
                    CC_PrintLog(iClient, iClientChoose, "PlayerSendedSkype", sNameDiscord, "");

                    g_iPlayerInfo[iClient].StatusCheck++;
				}
			}
		}

		return Plugin_Continue;
	}

	return Plugin_Continue;
}

/********************************************************* РАБОТА С АДМИН МЕНЮ *********************************************************/

public void OnAdminMenuReady(Handle hTopMenu) {
    TopMenu pTopMenu = TopMenu.FromHandle(hTopMenu);

    if(pTopMenu == g_hTopMenu) return;

    g_hTopMenu = pTopMenu;

    TopMenuObject hMyCategory = g_hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

    if(hMyCategory != INVALID_TOPMENUOBJECT) {
        g_hTopMenu.AddItem(CHECKCHEATS_MAINMENU, CheckCheatsMainMenu_Handler, hMyCategory, "check_cheats", ADMFLAG_BAN, "");
    }
}

public void CheckCheatsMainMenu_Handler(TopMenu hMenu, TopMenuAction action, TopMenuObject object_id, int iClient, char[] sBuffer, int maxlength) {
    char sMainMenuName[256];
    FormatEx(sMainMenuName, sizeof sMainMenuName, "%T", "AdminMenuCategoryName", iClient);

    switch(action) {
        case TopMenuAction_DisplayOption: FormatEx(sBuffer, maxlength, sMainMenuName);
        case TopMenuAction_SelectOption: MainMenu(iClient);
    }
}

public void MainMenu(int iClient) {
    char sTitle[256], sMainMenuFirstItem[256], sMainMenuSecondItem[256];

    FormatEx(sTitle, sizeof sTitle, "[Check Cheats] - %T", "MainMenuTitle", iClient);
    FormatEx(sMainMenuFirstItem, sizeof sMainMenuFirstItem, "%T", "MainMenuFirstItem", iClient);
    FormatEx(sMainMenuSecondItem, sizeof sMainMenuSecondItem, "%T", "MainMenuSecondItem", iClient);

    Menu hMenu = CreateMenu(MainMenu_Handler);

    SetMenuTitle(hMenu, sTitle);
    AddMenuItem(hMenu, "0", sMainMenuFirstItem);
    AddMenuItem(hMenu, "1", sMainMenuSecondItem);

    SetMenuExitBackButton(hMenu, true);
    SetMenuExitButton(hMenu, true);

    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

public int MainMenu_Handler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) {
    switch(mAction) {
        case MenuAction_Select: {
            char sInfo[2];

			GetMenuItem(hMenu, iSlot, sInfo, sizeof sInfo);

            switch(sInfo[0]) {
                case '0': ChoosePlayerMenu(iClient);
                case '1': ShowInformationPanel(iClient);
            }
        }

        case MenuAction_Cancel: {
            if(iSlot == MenuCancel_ExitBack) RedisplayAdminMenu(g_hTopMenu, iClient);
        }

        case MenuAction_End: hMenu.Cancel();
    }
}

public void ChoosePlayerMenu(int iClient) {
    int iPlayers;
    char sTemp[256], sTemps[256], sTitle[256], sPlayersNotFound[256], sMessage[256];

    FormatEx(sTitle, sizeof sTitle, "[Check Cheats] - %T", "ChoosePlayerMenuTitle", iClient);
    FormatEx(sPlayersNotFound, sizeof sPlayersNotFound, "%T", "PlayersNotFound", iClient);

    Menu hMenu = CreateMenu(ChoosePlayerMenu_Handler);

    SetMenuTitle(hMenu, sTitle);

    for(int i = 0; i <= MaxClients; i++) {        
        if(!g_bHideAdmins) {
            if(CC_IsValidClient(i)) iPlayers++;
        }else{
            if(CC_IsValidClient(i) && !GetAdminFlag(GetUserAdmin(i), Admin_Ban)) iPlayers++;
        }
    }

    if(!iPlayers) {
        AddMenuItem(hMenu, "0", sPlayersNotFound, ITEMDRAW_DISABLED);
    }else{
        if(StrEqual(g_iPlayerInfo[iClient].ActionSelect, "CheckCheats") && CC_IsCheckedPlayer(GetClientOfUserId(g_iPlayerInfo[iClient].ActionPlayer))) {
            FormatEx(sMessage, sizeof sMessage, "%T", "PlayerAlreadyCheck", iClient, iClient, GetClientOfUserId(g_iPlayerInfo[iClient].ActionPlayer));
            CC_PrintToChat(iClient, sMessage);
        }else{
            for(int i = 0; i <= MaxClients; i++) {
                if(CC_IsValidClient(i) && GetClientUserId(i) != GetClientUserId(iClient)) {
                    Format(sTemp, sizeof sTemp, "%i", GetClientUserId(i));
                    Format(sTemps, sizeof sTemps, "%N", i);

                    AddMenuItem(hMenu, sTemp, sTemps, CC_IsCheckedPlayer(i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
                }
            }
        }
    }

    SetMenuExitBackButton(hMenu, true);
    SetMenuExitButton(hMenu, true);

    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

public int ChoosePlayerMenu_Handler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) {
    switch(mAction) {
        case MenuAction_Select: {
            char sInfo[256], sMessage[256];

            GetMenuItem(hMenu, iSlot, sInfo, sizeof sInfo);

            int iClientChoose = GetClientOfUserId(StringToInt(sInfo));
            
            if(iClientChoose) {
                g_iPlayerInfo[iClient].ActionSelect[0] = StringToInt(sInfo);
                MakeVerify(iClient, iClientChoose);
            }else{
                FormatEx(sMessage, sizeof sMessage, "%T", "CheckPlayerLeft", iClient, iClientChoose);
                CC_PrintToChat(iClient, sMessage);
            }
        }

        case MenuAction_Cancel: {
            if(iSlot == MenuCancel_ExitBack) MainMenu(iClient);
        }

        case MenuAction_End: hMenu.Cancel();
    }
}

public void ChooseMessengerMenu(int iClient) {
    char sTitle[256], sRefusal[256];

    FormatEx(sTitle, sizeof sTitle, "%T\n ", "ChooseMessengerMenuTitle", iClient);
	FormatEx(sRefusal, sizeof sRefusal, "%T", "RefusalToCheck", iClient);
    Menu hMenu = CreateMenu(ChooseMessengerMenu_Handler);

    SetMenuTitle(hMenu, sTitle);

	if(StrEqual(g_sMessenger, "Discord")) {
		AddMenuItem(hMenu, "discord", "Discord\n ");
        AddMenuItem(hMenu, "refusal", sRefusal);

        SetMenuExitBackButton(hMenu, false);
        SetMenuExitButton(hMenu, false);

        DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
	}else if(StrEqual(g_sMessenger, "Skype")) {
        AddMenuItem(hMenu, "skype", "Skype");
        AddMenuItem(hMenu, "refusal", sRefusal);
		
        SetMenuExitBackButton(hMenu, false);
        SetMenuExitButton(hMenu, false);

        DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
	}else if(StrEqual(g_sMessenger, "All")) {
        AddMenuItem(hMenu, "discord", "Discord");
        AddMenuItem(hMenu, "skype", "Skype\n ");
        AddMenuItem(hMenu, "refusal", sRefusal);
		
        SetMenuExitBackButton(hMenu, false);
        SetMenuExitButton(hMenu, false);

        DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
	}
}

public int ChooseMessengerMenu_Handler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) {
    char sInfo[256], sMessage[256];

    GetMenuItem(hMenu, iSlot, sInfo, sizeof sInfo);

    switch(mAction) {
        case MenuAction_Select: {
            if(!g_bPlayerChecking[iClient]) {
                hMenu.Cancel();

                FormatEx(sMessage, sizeof sMessage, "%T", "InteractionErrorPlayer", iClient);
                CC_PrintToChat(iClient, sMessage);

                return;
            }

            if(StrEqual(sInfo, "discord")) {
                hMenu.Cancel();

                g_iMessenger[iClient] = 1;

                FormatEx(sMessage, sizeof sMessage, "%T", "PlayerNotifyWriteData", iClient, "Discord");
                CC_PrintToChat(iClient, sMessage);
            }else if(StrEqual(sInfo, "skype")) {
                hMenu.Cancel();

                g_iMessenger[iClient] = 2;

                FormatEx(sMessage, sizeof sMessage, "%T", "PlayerNotifyWriteData", iClient, "Skype");
                CC_PrintToChat(iClient, sMessage);
            }else if(StrEqual(sInfo, "refusal")) {
                hMenu.Cancel();

                if(g_iBanEnabled) CC_BanClient(iClient, 0, false);
            }
        }

        case MenuAction_End: hMenu.Cancel();
    }
}

public void Menu_PanelCheck(int iClient) {
	int iClientChoose = GetClientOfUserId(g_iPlayerInfo[iClient].ActionPlayer);
	
	char sTemp[1280], sMessenger[256], sWaitCommunication[256];

    FormatEx(sWaitCommunication, sizeof sWaitCommunication, "%T", "Status_WaitCommunication", iClient);

    if(!g_iMessenger[iClientChoose]) {
        sMessenger = sWaitCommunication;
    }else{
        sMessenger = GetStatus(g_iPlayerInfo[iClient].StatusCheck, g_iMessenger[iClientChoose] == 1 ? true : false);
    }

    FormatEx(sTemp, sizeof sTemp, "%T", "CheckMenuTitle", iClient, iClientChoose, sMessenger);
	Menu hMenu = CreateMenu(Menu_PanelCheck_Handler);
	
    SetMenuTitle(hMenu, sTemp);

	if(g_iPlayerInfo[iClient].StatusCheck == STATUS_WAITCOMMUNICATION) {
        char sNotif[256], sEnd[256];

		FormatEx(sTemp, sizeof sTemp, "%s\n ", sTemp);
        FormatEx(sEnd, sizeof sEnd, "%T", "EndCheckPlayer", iClient);
        FormatEx(sNotif, sizeof sNotif, "%T", "CheckMenuNotifyItem", iClient);

		SetMenuTitle(hMenu, sTemp);

        AddMenuItem(hMenu, "Notif", sNotif);
        AddMenuItem(hMenu, "GoodResult", sEnd);
	}else if(g_iPlayerInfo[iClient].StatusCheck == STATUS_WAITCALL) {
		char sWait[256], sItem[256];

		if(StrEqual(g_sMessenger, "Discord")) sWait = "Discord";
		if(StrEqual(g_sMessenger, "Skype")) sWait = "Skype";
		if(StrEqual(g_sMessenger, "All")) sWait = g_iMessenger[iClientChoose] == 1 ? "Discord" : "Skype";

        FormatEx(sItem ,sizeof sItem, "%T", "EndCheckPlayer", iClient);
        FormatEx(sTemp, sizeof sTemp, "%T", "CheckMenuFirstItem", iClient, sWait, g_iPlayerInfo[iClientChoose].Discord);

        AddMenuItem(hMenu, "GoodResult", sItem);
        AddMenuItem(hMenu, "Status", sTemp);
	}else if(g_iPlayerInfo[iClient].StatusCheck == STATUS_CHECKING) {
        char sItem[256];

        FormatEx(sItem, sizeof sItem, "%T", "EndCheckPlayer", iClient);
        FormatEx(sTemp, sizeof sTemp, "%T", "CheckEnded", iClient);

        AddMenuItem(hMenu, "GoodResult", sItem);
        AddMenuItem(hMenu, "Status", sTemp);
	}else if(g_iPlayerInfo[iClient].StatusCheck == STATUS_RESULT) {
        char sGood[256], sBad[256];

        FormatEx(sGood, sizeof sGood, "%T", "GoodResult", iClient);
        FormatEx(sBad, sizeof sBad, "%T", "BadResult", iClient);

        AddMenuItem(hMenu, "GoodResult", sGood);
        AddMenuItem(hMenu, "BadResult", sBad);
	}
	
    if(!g_iPlayerInfo[iClientChoose].BlockSpec) {
        char sAction[256];

		if(GetClientTeam(iClientChoose) != CS_TEAM_SPECTATOR) {
            FormatEx(sAction, sizeof sAction, "%T", "PlayerToSpec", iClient);

            AddMenuItem(hMenu, "ToSpec", sAction);
		}else{
            FormatEx(sAction, sizeof sAction, "%T", "PlayerBlockSpec", iClient);
            
            AddMenuItem(hMenu, "BlockSpec", sAction);
		}
	}
    
    SetMenuExitBackButton(hMenu, false);
    SetMenuExitButton(hMenu, false);

    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

public int Menu_PanelCheck_Handler(Menu hMenu, MenuAction mAction, int iClient, int iSlot) {
    switch(mAction) {
        case MenuAction_Select: {
            char sInfo[128], sAdmin[256], sPlayer[256];
            int iClientChoose = GetClientOfUserId(g_iPlayerInfo[iClient].ActionPlayer);

            GetMenuItem(hMenu, iSlot, sInfo, sizeof sInfo);

            if(!CC_IsValidClient(iClientChoose)) {
                hMenu.Cancel();

                FormatEx(sAdmin, sizeof sAdmin, "%T", "InteractionErrorAdmin", iClient);
                CC_PrintToChat(iClient, sAdmin);

                return;
            }

            if(StrEqual(sInfo, "ToSpec")) {
                FormatEx(sPlayer, sizeof sPlayer, "%T", "PlayerToSpecText", iClientChoose);
                FormatEx(sAdmin, sizeof sAdmin, "%T", "PlayerToSpecAdmin", iClient, iClientChoose);

                ChangeClientTeam(iClientChoose, CS_TEAM_SPECTATOR);
                CC_PrintLog(iClient, iClientChoose, "PlayerToSpec", "", "");
                CC_PrintToChat(iClientChoose, sPlayer);
                CC_PrintToChat(iClient, sAdmin);
            }else if(StrEqual(sInfo, "Notif")) {
                FormatEx(sAdmin, sizeof sAdmin, "%T", "PlayerNotifyAdmin", iClient, iClientChoose);
                CC_PrintToChat(iClient, sAdmin);

                if(StrEqual(g_sMessenger, "Discord")) {
                    FormatEx(sPlayer, sizeof sPlayer, "%T", "PlayerNotifyWriteData", iClientChoose, "Discord");
                    CC_PrintToChat(iClientChoose, sPlayer);
                }else if(StrEqual(g_sMessenger, "Skype")) {
                    FormatEx(sPlayer, sizeof sPlayer, "%T", "PlayerNotifyWriteData", iClientChoose, "Skype");
                    CC_PrintToChat(iClientChoose, sPlayer);
                }else{
                    if(g_iMessenger[iClientChoose] == 1) {
                        FormatEx(sPlayer, sizeof sPlayer, "%T", "PlayerNotifyWriteData", iClientChoose, "Discord");
                        CC_PrintToChat(iClientChoose, sPlayer);
                    }else if(g_iMessenger[iClientChoose]) {
                        FormatEx(sPlayer, sizeof sPlayer, "%T", "PlayerNotifyWriteData", iClientChoose, "Skype");
                        CC_PrintToChat(iClientChoose, sPlayer);
                    }else{
                        FormatEx(sPlayer, sizeof sPlayer, "%T", "ChooseMessengerText", iClientChoose);
                        CC_PrintToChat(iClientChoose, sPlayer);

                        ChooseMessengerMenu(iClientChoose);
                    }
                }
            }else if(StrEqual(sInfo, "BlockSpec")) {
                FormatEx(sPlayer, sizeof sPlayer, "%T", "PlayerBlockSpecText", iClientChoose);
                FormatEx(sAdmin, sizeof sAdmin, "%T", "PlayerBlockSpecAdmin", iClient, iClientChoose);

                g_iPlayerInfo[iClientChoose].BlockSpec = true;

                CC_PrintLog(iClient, iClientChoose, "PlayerBlockSpec", "", "");
                CC_PrintToChat(iClientChoose, sPlayer);
                CC_PrintToChat(iClient, sAdmin);
            }else if(StrEqual(sInfo, "Status")) {
                g_iPlayerInfo[iClient].StatusCheck++;
            }else if(StrEqual(sInfo, "GoodResult")) {
                hMenu.Cancel();

                FormatEx(sPlayer, sizeof sPlayer, "%T", "PlayerCheatsNotFound", iClientChoose);
                FormatEx(sAdmin, sizeof sAdmin, "%T", "PlayerCheatsNotFoundAdmin", iClient);

                g_iPlayerInfo[iClient].ActionPlayer = 0;
				g_iPlayerInfo[iClient].ActionSelect[0] = 0;
				g_iPlayerInfo[iClient].StatusCheck = 0;
				g_iPlayerInfo[iClientChoose].Discord[0] = 0;
				g_iPlayerInfo[iClientChoose].BlockSpec = false;
                g_bPlayerChecking[iClientChoose] = false;

                GiveOverlay(iClientChoose, "");
                CC_PrintLog(iClient, iClientChoose, "PlayerCheatsNotFound", "", "");
                CC_PrintToChat(iClientChoose, sPlayer);
                CC_PrintToChat(iClient, sAdmin);
            }else if(StrEqual(sInfo, "BadResult")) {
                hMenu.Cancel();

                FormatEx(sPlayer, sizeof sPlayer, "%T", "PlayerCheatsFound", iClientChoose);
                FormatEx(sAdmin, sizeof sAdmin, "%T", "PlayerCheatsFoundAdmin", iClient);

                g_iPlayerInfo[iClient].ActionPlayer = 0;
				g_iPlayerInfo[iClient].ActionSelect[0] = 0;
				g_iPlayerInfo[iClient].StatusCheck = 0;
				g_iPlayerInfo[iClientChoose].Discord[0] = 0;
                g_bPlayerChecking[iClientChoose] = false;

                GiveOverlay(iClientChoose, "");
                CC_PrintLog(iClient, iClientChoose, "PlayerCheatsFound", "", "");
                CC_PrintToChat(iClientChoose, sPlayer);
                CC_PrintToChat(iClient, sAdmin);
                
                if(g_iBanEnabled) CC_BanClient(iClientChoose, iClient, false);
            }
        }

        case MenuAction_End: hMenu.Cancel();
    }
}

public void ShowInformationPanel(int iClient) {
    Panel hPanel = CreatePanel();

    char sTitle[256], sFirstItem[256], sSecondItem[256], sThirdItem[256];
    FormatEx(sTitle, sizeof sTitle, "%s: %s", PLUGIN_NAME, PLUGIN_VERSION);
    FormatEx(sFirstItem, sizeof sFirstItem, "%T", "InfoFirstItem", iClient, PLUGIN_AUTHOR);
    FormatEx(sSecondItem, sizeof sSecondItem, "%T", "InfoSecondItem", iClient, PLUGIN_URL);
    FormatEx(sThirdItem, sizeof sThirdItem, "%T", "InfoThirdItem", iClient);

    SetPanelTitle(hPanel, sTitle);
    SetPanelCurrentKey(hPanel, 1);
    DrawPanelText(hPanel, sFirstItem);
    SetPanelCurrentKey(hPanel, 2);
    DrawPanelText(hPanel, sSecondItem);
    SetPanelCurrentKey(hPanel, 9);
    DrawPanelItem(hPanel, sThirdItem);

    SendPanelToClient(hPanel, iClient, ShowInformationPanel_Handler, MENU_TIME_FOREVER);
}

public int ShowInformationPanel_Handler(Handle hPanel, MenuAction mAction, int iClient, int iSlot) {
    if(iSlot == 9) MainMenu(iClient);
}

/******************************************************* ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ *******************************************************/

public void MakeVerify(int iClient, int iClientChoose) {
    char sMessage[256], sAll[256], sDiscord[256], sSkype[256], sMessageAll[256];

    FormatEx(sMessage, sizeof sMessage, "%T", "CheckStartPlayerText", iClientChoose, iClient);
    FormatEx(sMessageAll, sizeof sMessageAll, "%t", "CheckStartAllText", iClient, iClientChoose);
    FormatEx(sSkype, sizeof sSkype, "%T", "PlayerNotifyWriteData", iClientChoose, "Skype");
    FormatEx(sDiscord, sizeof sDiscord, "%T", "PlayerNotifyWriteData", iClientChoose, "Discord");
    FormatEx(sAll, sizeof sAll, "%T", "ChooseMessengerText", iClientChoose);

    PrintToServer("%i", g_iWaitTime);

	strcopy(g_iPlayerInfo[iClient].ActionSelect, 100, "CheckCheats");
    g_iWaitMessengerTime[iClientChoose] = GetTime() + g_iWaitTime;
	g_bPlayerChecking[iClientChoose] = true;
    g_iPlayerInfo[iClient].ActionPlayer = GetClientUserId(iClientChoose);
    
    CC_PrintLog(iClient, iClientChoose, "CheckStart", "", "");
    CC_PrintToChat(iClientChoose, sMessage);
    CC_PrintToChatAll(sMessageAll);
    
    if(StrEqual(g_sMessenger, "Discord")) {
        CC_PrintToChat(iClientChoose, sDiscord);
    }else if(StrEqual(g_sMessenger, "Skype")) {
        CC_PrintToChat(iClientChoose, sSkype);
    }else if(StrEqual(g_sMessenger, "All")) {
        ChooseMessengerMenu(iClientChoose);
        CC_PrintToChat(iClientChoose, sAll);
    }

    if(g_sSoundPath[0]) ClientCommand(iClientChoose, "playgamesound \"%s\"", g_sSoundPath);
}

public void GiveOverlay(int iClient, char[] sPath) {
    if(!IsClientInGame(iClient)) return;
    
	ClientCommand(iClient, "r_screenoverlay \"%s\"", sPath);
}

char[] GetStatus(int iStatus, bool bType) {
	char iStatuses[100], sWaitDiscord[256], sWaitSkype[256], sWaitCall[256], sChecking[256], sResult[256];

    FormatEx(sWaitDiscord, sizeof sWaitDiscord, "%t", "Status_WaitDiscord");
    FormatEx(sWaitSkype, sizeof sWaitSkype, "%t", "Status_WaitSkype");
    FormatEx(sWaitCall, sizeof sWaitCall, "%t", "Status_WaitCall");
    FormatEx(sChecking, sizeof sChecking, "%t", "Status_Checking");
    FormatEx(sResult, sizeof sResult, "%t", "Status_Result");

	switch(iStatus) {
		case STATUS_WAITCOMMUNICATION: {
			strcopy(iStatuses, sizeof iStatuses, bType ? sWaitDiscord : sWaitSkype);
		}

		case STATUS_WAITCALL: {
			strcopy(iStatuses, sizeof iStatuses, sWaitCall);
		}

		case STATUS_CHECKING: {
			strcopy(iStatuses, sizeof iStatuses, sChecking);
		}
		
        case STATUS_RESULT: {
			strcopy(iStatuses, sizeof iStatuses, sResult);
		}
	}

	return iStatuses;
}

public void CC_BanClient(int iClient, int iAdmin, bool bOffline) {
    if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "MABanPlayer") == FeatureStatus_Available) {
        if(bOffline) {
            char sSteamID[256], sIP[256], sName[256];

            GetClientAuthId(iClient, AuthId_Steam2, sSteamID, sizeof sSteamID);
            GetClientIP(iClient, sIP, sizeof sIP);
            GetClientName(iClient, sName, sizeof sName);

            MAOffBanPlayer(iAdmin, MA_BAN_STEAM, sSteamID, sIP, sName, g_iBanTime, g_sBanReason);
        }else{
            MABanPlayer(iAdmin, iClient, MA_BAN_STEAM, g_iBanTime, g_sBanReason);
        }
    }else if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available) {
		SBPP_BanPlayer(iAdmin, iClient, g_iBanTime, g_sBanReason);
	}else if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SBBanPlayer") == FeatureStatus_Available) {
		SBPP_BanPlayer(iAdmin, iClient, g_iBanTime, g_sBanReason);
	}else{
		BanClient(iClient, g_iBanTime, BANFLAG_AUTHID, g_sBanReason);
	}
}

public void CC_PrintLog(int iClient, int iClientChoose, const char[] sLog, const char[] sMessenger, const char[] sFilePath) {
    char sLogPath[256], sUserID[256], sAdminID[256];
    BuildPath(Path_SM, sLogPath, sizeof sLogPath, "logs/CheckCheats.log");

    if(iClient < 1) {
        sAdminID = "INVALID_STEAM";
    }else{
        GetClientAuthId(iClient, AuthId_Steam2, sAdminID, sizeof sAdminID);

        if(iClientChoose < 1) {
            sUserID = "INVALID_STEAM";
        }else{
            GetClientAuthId(iClientChoose, AuthId_Steam2, sUserID, sizeof sUserID);
        }
    }

    if(StrEqual(sLog, "CheckStart")) LogToFileEx(sLogPath, "[CheckCheats] Администратор %N (%s) вызвал на проверку игрока %N (%s)", iClient, sAdminID, iClientChoose, sUserID);
    if(StrEqual(sLog, "BanPluginFound")) LogToFileEx(sLogPath, "[CheckCheats] На сервере обнаружен следующий плагин для бана: %s", g_sBanSystem);
    if(StrEqual(sLog, "BanPluginNotFound")) LogToFileEx(sLogPath, "[CheckCheats] Плагин для выдачи банов не обнаружен на сервере! Поддерживаются: SourceBans, SourceBans++ и Material Admin");
    if(StrEqual(sLog, "CheckPlayerLeave")) LogToFileEx(sLogPath, "[CheckCheats] Игрок %N (%s) покинул сервер, проверка автоматически отменена!", iClientChoose, sUserID);
    if(StrEqual(sLog, "CheckLeaveAdmin")) LogToFileEx(sLogPath, "[CheckCheats] Администратор %N (%s) покинул сервер, проверка автоматически отменена!", iClient, sAdminID);
    if(StrEqual(sLog, "PlayerSendedDiscord")) LogToFileEx(sLogPath, "[CheckCheats] Игрок %N (%s) успешно ввёл свой Discord: %s", iClientChoose, sUserID, sMessenger);
    if(StrEqual(sLog, "PlayerSendedSkype")) LogToFileEx(sLogPath, "[CheckCheats] Игрок %N (%s) успешно ввёл свой Skype: %s", iClientChoose, sUserID, sMessenger);
    if(StrEqual(sLog, "PlayerToSpec")) LogToFileEx(sLogPath, "[CheckCheats] Администратор %N (%s) переместил игрока %N (%s) в наблюдатели!", iClient, sAdminID, iClientChoose, sUserID);
    if(StrEqual(sLog, "PlayerBlockSpec")) LogToFileEx(sLogPath, "[CheckCheats] Администратор %N (%s) заблокировал игроку %N (%s) переход в другие команды!", iClient, sAdminID, iClientChoose, sUserID);
    if(StrEqual(sLog, "PlayerCheatsNotFound")) LogToFileEx(sLogPath, "[CheckCheats] Администратор %N (%s) завершил проверку игрока %N (%s). Результат: Читы не обнаружены!", iClient, sAdminID, iClientChoose, sUserID);
    if(StrEqual(sLog, "PlayerCheatsFound")) LogToFileEx(sLogPath, "[CheckCheats] Администратор %N (%s) завершил проверку игрока %N (%s). Результат: Читы обнаружены!", iClient, sAdminID, iClientChoose, sUserID);
    if(StrEqual(sLog, "IgnoreEnterData")) LogToFileEx(sLogPath, "[CheckCheats] Игрок %N (%s) был забанен по причине игнорирования ввода данных для проверки!", iClientChoose, sUserID);
}

public bool CC_IsValidClient(int iClient) {
    if(iClient < 1 || iClient > MaxClients) return false;
    else if(!IsClientInGame(iClient)) return false;
    else if(IsFakeClient(iClient)) return false;

    return true;
}

public bool CC_IsCheckedPlayer(int iClient) {
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i)) {
            if(g_iPlayerInfo[i].ActionPlayer == GetClientUserId(iClient) && StrEqual(g_iPlayerInfo[i].ActionSelect, "CheckCheats")) return true;
        }
    }

    return false;
}

/*********************************************************** ОБРАБОТЧИК ЧАТА ***********************************************************/

public void CC_PrintToChat(int iClient, const char[] sMessage) {
    switch(g_EngineVersion) {
        case Engine_SourceSDK2006: CPrintToChat(iClient, "%s %s", g_sTag, sMessage);
        case Engine_CSS: CPrintToChat(iClient, "%s %s", g_sTag, sMessage);
        case Engine_CSGO: CGOPrintToChat(iClient, "%s %s", g_sTag, sMessage);
    }
}

public void CC_PrintToChatAll(const char[] sMessage) {
    switch(g_EngineVersion) {
        case Engine_SourceSDK2006: CPrintToChatAll("%s %s", g_sTag, sMessage);
        case Engine_CSS: CPrintToChatAll("%s %s", g_sTag, sMessage);
        case Engine_CSGO: CGOPrintToChatAll("%s %s", g_sTag, sMessage);
    }
}