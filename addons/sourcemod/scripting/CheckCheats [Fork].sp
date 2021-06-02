/*************************************************************************
*                             Check Cheats                               *
*                                                                        *
*                             Version: 3.1.1                             *
**************************************************************************
* Релиз 2.0: 03.01.2021                             	         		 *
* Обновление 3.0: 05.01.2021 - Увеличение функционала 					 *
* Обновление 3.1: 21.01.2021 - Фикс багов и оптимизация кода             *
* Обновление 3.1.1: 01.06.2021 - Исправление багов                       *
**************************************************************************
* Developers: xyligan & Nico Yazawa                                      *
*************************************************************************/

#pragma tabsize 0

#include <cstrike>
#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <materialadmin>
#include <sourcebanspp>

TopMenu g_hTopMenu = null;

char g_sSound[256],
	sPrefix[256];

enum player
{
	String:ActionSelect[64],
	ActionPlayer,
	bool:BlockSpec,
	any:StatusCheck,
	String:Discord[64],
}

enum StatusCheckEnum
{
	STATUS_WAITDISCORD = 0,
	STATUS_WAITCALL = 1,
	STATUS_CHECKING = 2,
	STATUS_RESULT = 3,
}

any player_info[MAXPLAYERS + 1][player];

int g_iTime[MAXPLAYERS+1],
	g_iMessenger[MAXPLAYERS+1],
	TimeToReady = 15,
	g_iSound = 0,
	g_iLogs = 0,
	BANTIME,
	MESSENGER,
	bantype;

bool g_bIsSended[MAXPLAYERS+1];

public Plugin myinfo =
{
	name 			= "[CS:GO|CS:S] Check Cheats [Fork]",
	author 			= "xyligan & Nico Yazawa",
	description 	= "Позволяет вызывать людей на проверку",
	version 		= "3.1.1"
}

public void OnMapStart()
{
	char file[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, file, sizeof file, "configs/CheckCheats_resources.ini");
	File fileh = OpenFile(file, "r");
	if (fileh != null)
	{
		char sBuffer[256];
		char sBuffer_full[PLATFORM_MAX_PATH];

		while(ReadFileLine(fileh, sBuffer, sizeof sBuffer ))
		{
			TrimString(sBuffer);
			if ( sBuffer[0]  && sBuffer[0] != '/' && sBuffer[1] != '/' )
			{
				FormatEx(sBuffer_full, sizeof(sBuffer_full), "materials/%s", sBuffer);
				if (FileExists(sBuffer_full))
				{
					PrecacheDecal(sBuffer, true);
					AddFileToDownloadsTable(sBuffer_full);
					pluginLog(8, 0, 0, "", "", sBuffer_full);
				}
				else
				{
					PrintToServer("[OS] File does not exist, check your path to overlay! %s", sBuffer_full);
					pluginLog(7, 0, 0, "", "", sBuffer_full);
				}
			}
		}
		delete fileh;
	}
	checkPluginConfig();
	LoadConfig();
	OnAllPluginsLoaded();
}

void pluginLog(int logtype, int client, int clientChoose, const char[] Skype ="", const char[] sDiscord="", const char[] filePath ="", const char[] banSystem ="", const char[] configPath ="") {
	if(g_iLogs == 1)
	{
		/*
			=== Логи проверок ===
			0 - Начало проверки
			1 - Написание Skype
			2 - Написание Discord
			3 - Завершение проверки (читы не обнаружены)
			4 - Завершение проверки (читы обнаружены)
			5 - Человек ушёл с проверки (бан)
			6 - Администратор вышел с сервера
			9 - Перемещение игрока в наблюдатели
			10 - Блокировка перехода за команду
			11 - Бан игрока (игнорирование ввода данных для проверки)
			=== Системные логи ===
			7 - Ошибка загрузки файлов для плагина
			8 - Успешная загрузка файлов для плагина
			12 - Обнаружение SourceBans, SoureBans++ или Material Admin
			13 - Ошибка обнаружения SourceBans, SoureBans++ или Material Admin
			14 - Успешная загрузка конфига
			15 - Ошибка загрузки конфига
			
		*/
		char date[32];
		FormatTime(date, sizeof(date), "%d/%m/%Y %H:%M:%S", GetTime());
		char LogPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, LogPath, sizeof(LogPath), "logs/CheckCheats.log");
		
		if(logtype == 0)
		{
			char steamid[28];
			char name[100];
			char adminSteamid[28];
			char adminName[100];
			GetClientAuthId(clientChoose, AuthId_Steam2, steamid, sizeof(steamid));
			GetClientName(clientChoose, name, sizeof(name));
			GetClientAuthId(client, AuthId_Steam2, adminSteamid, sizeof(steamid));
			GetClientName(client, adminName, sizeof(name));
			
			LogToFileEx(LogPath, "[CheckCheats] Администратор %s (%s) вызвал на проверку игрока %s (%s)", adminName, adminSteamid, name, steamid);
		}else if(logtype == 1) {
			char steamid[28];
			char name[100];
			
			GetClientAuthId(clientChoose, AuthId_Steam2, steamid, sizeof(steamid));
			GetClientName(clientChoose, name, sizeof(name));
			
			LogToFileEx(LogPath, "[CheckCheats] Игрок %s (%s) ввёл свой Skype: %s", name, steamid, Skype);
		}else if(logtype == 2) {
			char steamid[28];
			char name[100];
			
			GetClientAuthId(clientChoose, AuthId_Steam2, steamid, sizeof(steamid));
			GetClientName(clientChoose, name, sizeof(name));
			
			LogToFileEx(LogPath, "[CheckCheats] Игрок %s (%s) ввёл свой Discord: %s", name, steamid, sDiscord);
		}else if(logtype == 3) {
			char steamid[28];
			char name[100];
			char adminSteamid[28];
			char adminName[100];
			GetClientAuthId(clientChoose, AuthId_Steam2, steamid, sizeof(steamid));
			GetClientName(clientChoose, name, sizeof(name));
			GetClientAuthId(client, AuthId_Steam2, adminSteamid, sizeof(steamid));
			GetClientName(client, adminName, sizeof(name));
			
			LogToFileEx(LogPath, "[CheckCheats] Администратор %s (%s) завершил проверку игрока %s (%s) | Читы не обнаружены!", adminName, adminSteamid, name, steamid);
		}else if(logtype == 4) {
			char steamid[28];
			char name[100];
			char adminSteamid[28];
			char adminName[100];
			GetClientAuthId(clientChoose, AuthId_Steam2, steamid, sizeof(steamid));
			GetClientName(clientChoose, name, sizeof(name));
			GetClientAuthId(client, AuthId_Steam2, adminSteamid, sizeof(steamid));
			GetClientName(client, adminName, sizeof(name));
			
			LogToFileEx(LogPath, "[CheckCheats] Администратор %s (%s) завершил проверку игрока %s (%s) | Читы обнаружены, игрок забанен!", adminName, adminSteamid, name, steamid);
		}else if(logtype == 5) {
			char steamid[28];
			char name[100];
			
			GetClientAuthId(clientChoose, AuthId_Steam2, steamid, sizeof(steamid));
			GetClientName(clientChoose, name, sizeof(name));
			
			LogToFileEx(LogPath, "[CheckCheats] Игрок %s (%s) покинул сервер во время проверки! | Был выдан автоматический бан. Причина: Отказ пройти проверку на читы!", name, steamid);
		}else if(logtype == 6) {
			LogToFileEx(LogPath, "[CheckCheats] Администратор покинул сервер во время проверки игрока! | Проверка была автоматически отменена!");
		}else if(logtype == 7) {
			LogToFileEx(LogPath, "[CheckCheats] Файл %s не обнаружен!", filePath);
		}else if(logtype == 8) {
			LogToFileEx(LogPath, "[CheckCheats] Файл %s успешно обнаружен и загружен!", filePath);
		}else if(logtype == 9) {
			char steamid[28];
			char name[100];
			char adminSteamid[28];
			char adminName[100];
			GetClientAuthId(clientChoose, AuthId_Steam2, steamid, sizeof(steamid));
			GetClientName(clientChoose, name, sizeof(name));
			GetClientAuthId(client, AuthId_Steam2, adminSteamid, sizeof(steamid));
			GetClientName(client, adminName, sizeof(name));
			
			LogToFileEx(LogPath, "[CheckCheats] Администратор %s (%s) переместил игрока %s (%s) в наблюдатели!", adminName, adminSteamid, name, steamid);
		}else if(logtype == 10) {
			char steamid[28];
			char name[100];
			char adminSteamid[28];
			char adminName[100];
			GetClientAuthId(clientChoose, AuthId_Steam2, steamid, sizeof(steamid));
			GetClientName(clientChoose, name, sizeof(name));
			GetClientAuthId(client, AuthId_Steam2, adminSteamid, sizeof(steamid));
			GetClientName(client, adminName, sizeof(name));
			
			LogToFileEx(LogPath, "[CheckCheats] Администратор %s (%s) запретил игроку %s (%s) заход в игру!", adminName, adminSteamid, name, steamid);
		}else if(logtype == 11) {
			char steamid[28];
			char name[100];
			
			GetClientAuthId(clientChoose, AuthId_Steam2, steamid, sizeof(steamid));
			GetClientName(clientChoose, name, sizeof(name));
			
			LogToFileEx(LogPath, "[CheckCheats] По причине игнорирования ввода данных для проверки игрок %s (%s) был забанен!", name, steamid);
		}else if(logtype == 12) {
			LogToFileEx(LogPath, "[CheckCheats] На сервер обнаружен следующий плагин для бана: %s", banSystem);
		}else if(logtype == 13) {
			LogToFileEx(LogPath, "[CheckCheats] Плагин для бана игроков не обнаружен на сервере! Поддерживаются: SourceBans, SourceBans++ и Material Admin");
		}else if(logtype == 14) {
			LogToFileEx(LogPath, "[CheckCheats] Конфиг плагина успешно загружен!");
		}else if(logtype == 15) {
			LogToFileEx(LogPath, "[CheckCheats] Конфиг плагина не обнаружен в директории: %s", configPath);
		}
	}
}

public void OnAllPluginsLoaded()
{
	 Handle searchMA = FindPluginByFile("materialadmin.smx");
	if(searchMA != INVALID_HANDLE) {
		pluginLog(12, 0, 0, "", "", "", "Material Admin");
		bantype = 1;
	}else{
		Handle searchSB = FindPluginByFile("sourcebans.smx");
		if(searchSB != INVALID_HANDLE) {
			pluginLog(12, 0, 0, "", "", "", "SourceBans");
			bantype = 2;
		}else{
			Handle searchSBPP = FindPluginByFile("sbpp_main.smx");
			if(searchSBPP != INVALID_HANDLE) {
				pluginLog(12, 0, 0, "", "", "", "SourceBans++");
				bantype = 3;
			}else{
				pluginLog(12, 0, 0, "", "", "", "Base Bans");
				bantype = 0;
			}
		}
	}
}

public void OnPluginStart()
{
	if (LibraryExists("adminmenu"))
    {
        TopMenu hTopMenu;
        if ((hTopMenu = GetAdminTopMenu()) != null)
        {
            OnAdminMenuReady(hTopMenu);
        }
    }
	
	CreateTimer(0.1, Timer_GiveOverlay, _, TIMER_REPEAT);
	
	AddCommandListener(Command_JoinTeam, "jointeam");

	checkPluginConfig();
	LoadConfig();
}

public Action ReloadConfig(int iClient, int args)
{
	LoadConfig();

	ReplyToCommand(iClient, "%s Конфиг плагина успешно перезагружен!", sPrefix);

	return Plugin_Handled;
}

void LoadConfig()
{
	char sBuff[256]; static bool bComms;

	KeyValues hKV = new KeyValues("CheckCheats");

	BuildPath(Path_SM, sBuff, sizeof sBuff, "configs/CheckCheats.ini");
	if (!hKV.ImportFromFile(sBuff))
	{
		g_iLogs = 1;
		pluginLog(15, 0, 0, "", "", "", "", sBuff);
		SetFailState("The config file is missing: %s", sBuff);
	}
	hKV.GetString("soundpath", g_sSound, sizeof(g_sSound));
	g_iSound = hKV.GetNum("sound");
	g_iLogs = hKV.GetNum("logs");

	bool GET_BANTIME_RESULT = hKV.GetNum("bantime");
	if(GET_BANTIME_RESULT == false) {
		BANTIME = 0;
	}else{
		BANTIME = hKV.GetNum("bantime");
	}

	bool GET_MESSENGERS = hKV.GetNum("messengers");
	if(GET_MESSENGERS == false) {
		MESSENGER = 3;
	}else{
		MESSENGER = hKV.GetNum("messengers");
	}

	hKV.GetString("chatPrefix", sPrefix, sizeof(sPrefix));
	pluginLog(14, 0, 0);

	int iIntBuff;

	if (!bComms)
	{
		char sFullCommads[128], sExplodeComms[8][32];

		hKV.GetString("cmds", sFullCommads, sizeof sFullCommads);
		
		iIntBuff = ExplodeString(sFullCommads, ";", sExplodeComms, sizeof sExplodeComms, sizeof sExplodeComms[]);
	
		for (int i; i < iIntBuff; i++)
		{
			RegAdminCmd(sExplodeComms[i], cmd_CheckCheats, ADMFLAG_BAN);		
		}
		
		hKV.GetString("refcmd", sFullCommads, sizeof sFullCommads);
		
		iIntBuff = ExplodeString(sFullCommads, ";", sExplodeComms, sizeof sExplodeComms, sizeof sExplodeComms[]);
	
		for (int i; i < iIntBuff; i++)
		{
			RegAdminCmd(sExplodeComms[i], ReloadConfig, ADMFLAG_ROOT);		
		}
		
		bComms = true;
	}
}

void checkPluginConfig() {
	if (!FileExists("addons/sourcemod/configs/CheckCheats.ini")) {
		OpenFile("addons/sourcemod/configs/CheckCheats.ini", "w");
		
		Handle CONFIG = CreateKeyValues("CheckCheats");

     	KvSetString(CONFIG, "messengers", "3");
     	KvSetString(CONFIG, "bantime", "0");
     	KvSetString(CONFIG, "chatPrefix", "[Проверка на читы]");
     	KvSetString(CONFIG, "logs", "1");
     	KvSetString(CONFIG, "sound", "0");
     	KvSetString(CONFIG, "soundpath", "buttons/weapon_cant_buy.wav");
     	KvSetString(CONFIG, "cmds", "sm_cheats;sm_checkcheats");
     	KvSetString(CONFIG, "refcmd", "sm_rfcheats;sm_rfcheckcheats");
     	
     	KvRewind(CONFIG);

     	KeyValuesToFile(CONFIG, "addons/sourcemod/configs/CheckCheats.ini");
     	CloseHandle(CONFIG);
	}
}

public Action Command_JoinTeam(client, const char[] command, args)
{
	if(player_info[client][BlockSpec])
	{
		CGOPrintToChat(client, "%s Вам запрещено заходить в игру!", sPrefix);
		return Plugin_Handled;
	}
	return Plugin_Continue;
} 

public Action Timer_GiveOverlay(Handle hTimer)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			int client;
			int clientChoose
			for(int x = 1; x <= MaxClients; x++)
			{
				if(IsClientInGame(x))
				{
					if(player_info[x][ActionPlayer] == GetClientUserId(i) && StrEqual(player_info[x][ActionSelect], "CheckCheats"))
					{
						client = x;
						clientChoose = GetClientOfUserId(player_info[x][ActionPlayer]);

						if (g_iTime[clientChoose] && GetTime() >= g_iTime[clientChoose])
						{
							BanPlayer(clientChoose);
							pluginLog(11, 0, clientChoose);
						}
					}
				}
			}
			if(clientChoose)
			{
				GiveOverlay(clientChoose, "overlay_cheats/ban_cheats_v10");

				if (!g_bIsSended[clientChoose])
				{
					SendMenu(clientChoose);
					g_bIsSended[clientChoose] = true;
					CGOPrintToChat(clientChoose, "%s Ваша задача выбрать мессенджер и указать требуемые данные!", sPrefix);
				}
			}
			if(client)
			{
				Menu_PanelCheck(client);
			}
		}
	}
}

void SendMenu(int iClient)
{
	Menu hMenu = new Menu(TopMenuMenuHandler);

	if(MESSENGER == 1) {
		hMenu.SetTitle("Выберите мессенджер\n ");

		hMenu.AddItem(NULL_STRING, "Discord\n");

		hMenu.AddItem(NULL_STRING, "Отказаться от проверки");

		hMenu.ExitButton = false;
		hMenu.Display(iClient, 0);
	}else if(MESSENGER == 2) {
		hMenu.SetTitle("Выберите мессенджер\n ");

		hMenu.AddItem(NULL_STRING, "Skype\n ");

		hMenu.AddItem(NULL_STRING, "Отказаться от проверки");

		hMenu.ExitButton = false;
		hMenu.Display(iClient, 0);
	}else if(MESSENGER == 3) {
		hMenu.SetTitle("Выберите мессенджер\n ");

		hMenu.AddItem(NULL_STRING, "Discord");
		hMenu.AddItem(NULL_STRING, "Skype\n ");

		hMenu.AddItem(NULL_STRING, "Отказаться от проверки");

		hMenu.ExitButton = false;
		hMenu.Display(iClient, 0);
	}
}

public int TopMenuMenuHandler(Menu hMenu, MenuAction action, int iClient, int iPick)
{
	if (action == MenuAction_End)
	{
		delete hMenu;
	}
	else if (action == MenuAction_Select)
	{
		if(MESSENGER == 3) {
		
			switch(iPick)
			{
				case 0:
				{
					g_iMessenger[iClient] = 1;
					CGOPrintToChat(iClient, "%s Проверьте корректность введённых данных Discord! Пример: mynickname#1234", sPrefix);
				}
				case 1:
				{
					g_iMessenger[iClient] = 2;
					CGOPrintToChat(iClient, "%s Проверьте корректность введённых данных Skype! Пример: mynickname", sPrefix);
				}
				case 2:
				{
					BanPlayer(iClient);
				}
			}
		}else if(MESSENGER == 2) {
			switch(iPick)
			{
				case 0:
				{
					g_iMessenger[iClient] = 1;
					CGOPrintToChat(iClient, "%s Проверьте корректность введённых данных Skype! Пример: mynickname", sPrefix);
				}
				case 1:
				{
					BanPlayer(iClient);
				}
			}
		}else if(MESSENGER == 1) {
			switch(iPick)
			{
				case 0:
				{
					g_iMessenger[iClient] = 1;
					CGOPrintToChat(iClient, "%s Проверьте корректность введённых данных Discord! Пример: mynickname#1234", sPrefix);
				}
				case 1:
				{
					BanPlayer(iClient);
				}
			}
		}
	}
}

void BanPlayer(int iClient)
{
	if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "MABanPlayer") == FeatureStatus_Available)
	{
		MABanPlayer(0, iClient, MA_BAN_STEAM, BANTIME, "Отказ пройти проверку на читы.");
	}
	else if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SBPP_BanPlayer") == FeatureStatus_Available)
	{
		SBPP_BanPlayer(0, iClient, BANTIME, "Отказ пройти проверку на читы.");
	}
	else if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SBBanPlayer") == FeatureStatus_Available)
	{
		SBPP_BanPlayer(0, iClient, BANTIME, "Отказ пройти проверку на читы.");
	}
	else
	{
		// BanClient(iClient, BANTIME, BANFLAG_AUTHID, "Отказ пройти проверку на читы.");
	}
}

public void OnClientConnected(int client)
{
	player_info[client][ActionSelect] = g_iTime[client] = g_iMessenger[client] = 0;
	player_info[client][ActionPlayer] = 0;
	player_info[client][BlockSpec] = g_bIsSended[client] = false;
	player_info[client][StatusCheck] = 0;
	player_info[client][Discord] = 0;
}

public void OnClientDisconnect(int client)
{
	if(StrEqual(player_info[client][ActionSelect], "CheckCheats"))
	{
		int clientChoose = GetClientOfUserId(player_info[client][ActionSelect]);
		pluginLog(6, client, clientChoose);
		if(clientChoose)
		{
			CGOPrintToChat(clientChoose, "%s Администратор покинул сервер! Проверка отменена!", sPrefix);
			player_info[clientChoose][BlockSpec] = false;
			player_info[clientChoose][Discord][0] = 0;
			g_iMessenger[clientChoose] = g_iTime[clientChoose] = 0;
			g_bIsSended[clientChoose] = false;
		}
		player_info[client][ActionPlayer] = 0;
		player_info[client][ActionSelect] = 0;
		player_info[client][BlockSpec] = false;
		player_info[client][StatusCheck] = 0;
	}
	if(HaveCheck(client))
	{
		int clientChoose;
		pluginLog(6, client, clientChoose);
		for(int x = 1; x <= MaxClients; x++)
		{
			if(IsClientInGame(x))
			{
				if(player_info[x][ActionPlayer] == GetClientUserId(client) && StrEqual(player_info[x][ActionSelect], "CheckCheats"))
				{
					client = x;
					clientChoose = GetClientOfUserId(player_info[x][ActionPlayer]);
				}
			}
		}
		CGOPrintToChat(client, "%s Игрок, которого вы проверяли, вышел с сервера! Был выдан вечный бан на сервере!", sPrefix);
		pluginLog(5, client, clientChoose);
		player_info[client][ActionPlayer] = 0;
		player_info[client][ActionSelect] = 0;
		GiveOverlay(clientChoose, "");
		BanPlayer(clientChoose);
	}
}

public Action cmd_CheckCheats(int client, any args)
{
	Menu_CheckCheats_PlayerChoose(client);
}

public Action OnClientSayCommand(int client, const char[] sCommand, const char[] NameDiscord)  
{
	if(HaveCheck(client))
	{
		if (!g_iMessenger[client])
		{
			CGOPrintToChat(client, "%s Сначала выберите тип мессенджера!", sPrefix);
			return Plugin_Handled;
		}

		int clientChoose;
		for (int x = 1; x <= MaxClients; x++)
		{
			if(IsClientInGame(x))
			{
				if(player_info[x][ActionPlayer] == GetClientUserId(client) && StrEqual(player_info[x][ActionSelect], "CheckCheats"))
				{
					client = x;
					clientChoose = GetClientOfUserId(player_info[x][ActionPlayer]);
				}
			}
		}	

		if (player_info[client][StatusCheck] == STATUS_WAITDISCORD)
		{
			if(MESSENGER == 1)
			{
				bool HaveSharp = false;
				for (int i = 0; i < strlen(NameDiscord); i++)
				{
					if(NameDiscord[i] == '#')
					{
						HaveSharp = true;
					}
				}

				strcopy(player_info[clientChoose][Discord], 100, NameDiscord);

				if (HaveSharp)
				{
					CGOPrintToChat(client, "%s Игрок {LIGHTGREEN}%N {DEFAULT} ввел свой Discord: {LIGHTGREEN}%s", sPrefix, clientChoose, NameDiscord);
					CGOPrintToChat(clientChoose, "%s Вы успешно ввели Discord: %s | Ожидайте звонка администратора!", sPrefix, NameDiscord);
					player_info[client][StatusCheck]++;
					
					pluginLog(2, client, clientChoose, NameDiscord, NameDiscord);
					return Plugin_Handled;
				}
				else
				{
					CGOPrintToChat(clientChoose, "%s В введённых данных была найдена ошибка! Проверьте, пожалуйста ещё раз!", sPrefix);
					return Plugin_Handled;
				}
			}
			else if (MESSENGER == 2)
			{
				strcopy(player_info[clientChoose][Discord], 100, NameDiscord);
				player_info[client][StatusCheck]++;

				CGOPrintToChat(client, "%s Игрок {LIGHTGREEN}%N {DEFAULT} ввел свой Skype: {LIGHTGREEN}%s", sPrefix, clientChoose, NameDiscord);
				CGOPrintToChat(clientChoose, "%s Вы успешно ввели Skype: %s | Ожидайте звонка администратора!", sPrefix, NameDiscord);
				
				pluginLog(1, client, clientChoose, NameDiscord, NameDiscord);
			}
			else if(MESSENGER == 3) {
				if (g_iMessenger[clientChoose] == 1) {
					bool HaveSharp = false;
					for (int i = 0; i < strlen(NameDiscord); i++)
					{
						if(NameDiscord[i] == '#')
						{
							HaveSharp = true;
						}
					}

					strcopy(player_info[clientChoose][Discord], 100, NameDiscord);

					if (HaveSharp)
					{
						CGOPrintToChat(client, "%s Игрок {LIGHTGREEN}%N {DEFAULT} ввел свой Discord: {LIGHTGREEN}%s", sPrefix, clientChoose, NameDiscord);
						CGOPrintToChat(clientChoose, "%s Вы успешно ввели Discord: %s | Ожидайте звонка администратора!", sPrefix, NameDiscord);
						player_info[client][StatusCheck]++;
					
						pluginLog(2, client, clientChoose, NameDiscord, NameDiscord);
						return Plugin_Handled;
					}
					else
					{
						CGOPrintToChat(clientChoose, "%s В введённых данных была найдена ошибка! Проверьте, пожалуйста ещё раз!", sPrefix);
						return Plugin_Handled;
					}
				}else if(g_iMessenger[clientChoose] == 2) {
					strcopy(player_info[clientChoose][Discord], 100, NameDiscord);
					player_info[client][StatusCheck]++;

					CGOPrintToChat(client, "%s Игрок {LIGHTGREEN}%N {DEFAULT} ввел свой Skype: {LIGHTGREEN}%s", sPrefix, clientChoose, NameDiscord);
					CGOPrintToChat(clientChoose, "%s Вы успешно ввели Skype: %s | Ожидайте звонка администратора!", sPrefix, NameDiscord);
				
					pluginLog(1, client, clientChoose, NameDiscord, NameDiscord);
				}
			}
		}

		return Plugin_Continue;
	}

	return Plugin_Continue;
}

bool HaveCheck(int client)
{
	for(int x = 1; x <= MaxClients; x++)
	{
		if(IsClientInGame(x))
		{
			if(player_info[x][ActionPlayer] == GetClientUserId(client) && StrEqual(player_info[x][ActionSelect], "CheckCheats"))
			{
				return true;
			}
		}
	}

	return false;
}

public void Menu_PanelCheck(int client)
{
	int clientChoose = GetClientOfUserId(player_info[client][ActionPlayer]);
	
	char temp[1280];
	Menu hMenu = new Menu(MenuHandler_PanelCheck);
	Format(temp, sizeof(temp), "Панель проверки на читы\n \nПроверяется: %N\n \nСтатус проверки: %s", clientChoose, GetStatus(player_info[client][StatusCheck], g_iMessenger[clientChoose] == 1 ? false:true));
	hMenu.SetTitle(temp);
	if(player_info[client][StatusCheck] == STATUS_WAITDISCORD)
	{
		Format(temp, sizeof(temp), "%s\n ", temp);
		hMenu.SetTitle(temp);
		hMenu.AddItem("Notif", "Напомнить о введении данных");
	}
	else if(player_info[client][StatusCheck] == STATUS_WAITCALL)
	{
		char userMESSENGER[256];
		if(MESSENGER == 1) userMESSENGER = "Discord";
		if(MESSENGER == 2) userMESSENGER = "Skype";
		if(MESSENGER == 3) userMESSENGER = g_iMessenger[clientChoose] == 1 ? "Discord":"Skype";
		Format(temp, sizeof(temp), "Звонок был принят\n \n%s игрока: %s\n ", userMESSENGER, player_info[clientChoose][Discord]);
		hMenu.AddItem("Status", temp);
	}
	else if(player_info[client][StatusCheck] == STATUS_CHECKING)
	{
		hMenu.AddItem("Status", "Проверка окончена");
	}
	else if(player_info[client][StatusCheck] == STATUS_RESULT)
	{
		hMenu.AddItem("GoodResult", "Читы не обнаружены");
		hMenu.AddItem("BadResult", "Обнаружены читы");
	}
	if(!player_info[clientChoose][BlockSpec])
	{
		if(GetClientTeam(clientChoose) != CS_TEAM_SPECTATOR)
		{
			hMenu.AddItem("ToSpec", "Переместить в наблюдатели");
		}
		else
		{
			hMenu.AddItem("BlockSpec", "Заблокировать переход");
		}
	}
	hMenu.AddItem("GoodResult", "Принудительно окончить проверку");
	hMenu.ExitButton = false;
	hMenu.Display(client, 0);
}

public int MenuHandler_PanelCheck(Menu hMenu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[128];
			hMenu.GetItem(item, info, sizeof(info));
			int clientChoose = GetClientOfUserId(player_info[client][ActionPlayer]);
			
			if(clientChoose)
			{
				if(StrEqual(info, "ToSpec"))
				{
					ChangeClientTeam(clientChoose, CS_TEAM_SPECTATOR);
					CGOPrintToChat(clientChoose, "%s Администратор переместил Вас в наблюдатели!", sPrefix);
					CGOPrintToChat(client, "%s Вы успешно перенесли в наблюдатели игрока {LIGHTGREEN}%N!", sPrefix, clientChoose);
					pluginLog(9, client, clientChoose);
				}
				else if(StrEqual(info, "Notif"))
				{
					CGOPrintToChat(clientChoose, "%s Ваша задача выбрать мессенджер и указать данные!", sPrefix);
					CGOPrintToChat(client, "%s Вы успешно напомнили игроку {LIGHTGREEN}%N {DEFAULT}о том что он должен ввести данные Discord или Skype!", sPrefix, clientChoose);
					SendMenu(clientChoose);
					g_bIsSended[clientChoose] = true;
				}
				else if(StrEqual(info, "BlockSpec"))
				{
					CGOPrintToChat(clientChoose, "%s Вам был заблокирован переход за другую команду!", sPrefix);
					CGOPrintToChat(client, "%s Вы успешно заблокировали игроку {LIGHTGREEN}%N {DEFAULT}переход за другую команду!", sPrefix, clientChoose);
					player_info[clientChoose][BlockSpec] = true;
					pluginLog(10, client, clientChoose);
				}
				else if(StrEqual(info, "Status"))
				{
					player_info[client][StatusCheck]++;
				}
				else if(StrEqual(info, "GoodResult"))
				{
					CGOPrintToChat(clientChoose, "%s У Вас не обнаружено читов, проверка окончена! Спасибо за игру без читов!", sPrefix);
					CGOPrintToChat(client, "%s Вы успешно окончили проверку (читы не обнаружены)", sPrefix);
					pluginLog(3, client, clientChoose);
					player_info[client][ActionPlayer] = 0;
					player_info[client][ActionSelect] = 0;
					player_info[client][StatusCheck] = 0;
					player_info[clientChoose][Discord][0] = 0;
					player_info[clientChoose][BlockSpec] = g_bIsSended[clientChoose] = false;
					GiveOverlay(clientChoose, "");
					
				}
				else if(StrEqual(info, "BadResult"))
				{
					CGOPrintToChat(clientChoose, "%s У Вас были найдены читы, проверка окончена!", sPrefix);
					CGOPrintToChat(client, "%s Вы успешно окончили проверку (обнаружены читы)", sPrefix);
					pluginLog(4, client, clientChoose);
					BanPlayer(clientChoose);
					
					player_info[client][ActionPlayer] = 0;
					player_info[client][ActionSelect] = 0;
					player_info[client][StatusCheck] = 0;
					player_info[clientChoose][Discord][0] = 0;
					GiveOverlay(clientChoose, "");
				}
			}
		}
	}
}

public void Menu_CheckCheats_PlayerChoose(int client)
{
	if(StrEqual(player_info[client][ActionSelect], "CheckCheats") && HaveCheck(GetClientOfUserId(player_info[client][ActionPlayer])))
	{
		CGOPrintToChat(client, "%s Вы уже проверяете на читы игрока {LIGHTGREEN}%N", sPrefix, GetClientOfUserId(player_info[client][ActionPlayer]));
	}
	else
	{
		char temp[128];
		char temp2[128];
		Menu hMenu = new Menu(MenuHandler_CheckCheats_PlayerChoose);
		hMenu.SetTitle("Выберите игрока,\nкоторого хотите проверить на читы:\n ");
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				Format(temp, sizeof(temp), "%i", GetClientUserId(i));
				Format(temp2, sizeof(temp2), "%N", i)
				hMenu.AddItem(temp, temp2, HaveCheck(i) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			}
		}
		hMenu.Display(client, 0);
	}
}

public int MenuHandler_CheckCheats_PlayerChoose(Menu hMenu, MenuAction action, int client, int item)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[128];
			hMenu.GetItem(item, info, sizeof(info));
			int clientChoose = GetClientOfUserId(StringToInt(info));
			if(clientChoose)
			{
				player_info[client][ActionSelect] = StringToInt(info);
				MakeVerify(client, clientChoose);
			}
			else
			{
				CGOPrintToChat(client, "%s Игрок вышел с сервера!", sPrefix);
				BanPlayer(clientChoose);
			}
		}
	}
}

public void MakeVerify(int client, int clientChoose)
{
	strcopy(player_info[client][ActionSelect], 100, "CheckCheats");
	player_info[client][ActionPlayer] = GetClientUserId(clientChoose);
	CGOPrintToChatAll("%s Администратор {LIGHTGREEN}%N {DEFAULT}вызвал на проверку на читы игрока {LIGHTGREEN}%N", sPrefix, client, clientChoose);
	CGOPrintToChat(clientChoose, "%s {LIGHTRED}ВНИМАНИЕ! {DEFAULT}Администратор {LIGHTGREEN}%N {DEFAULT}вызвал Вас на проверку на читы!", sPrefix, client, TimeToReady);
	if(g_iSound == 1)
	{
		ClientCommand(clientChoose, "playgamesound \"%s\"", g_sSound);
	}
	pluginLog(0, client, clientChoose);
	g_iTime[clientChoose] = GetTime()+600;
}

public void GiveOverlay(int client, char[] path)
{
	ClientCommand(client, "r_screenoverlay \"%s\"", path);
}

public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu hTopMenu = TopMenu.FromHandle(aTopMenu);

    if (hTopMenu == g_hTopMenu)
    {
        return;
    }

    g_hTopMenu = hTopMenu;
	
	TopMenuObject hMyCategory = g_hTopMenu.AddCategory("check_category", Handler_Admin_CheckCheats, "check_admin", ADMFLAG_BAN, "Проверка на читы");
	
	if (hMyCategory != INVALID_TOPMENUOBJECT)
    {
        g_hTopMenu.AddItem("check_cheats", Handler_Admin_CheckCheats2, hMyCategory, "check_cheats", ADMFLAG_BAN, "check_cheats");
	}
}

public void Handler_Admin_CheckCheats(TopMenu hMenu, TopMenuAction action, TopMenuObject object_id, int client, char[] sBuffer, int maxlength)
{
    switch (action)
    {
		case TopMenuAction_DisplayOption:
		{
			FormatEx(sBuffer, maxlength, "Проверка на читы");
		}
		case TopMenuAction_DisplayTitle:
		{
			FormatEx(sBuffer, maxlength, "Выберите действие:\n ");
		}
    }
}

public void Handler_Admin_CheckCheats2(TopMenu hMenu, TopMenuAction action, TopMenuObject object_id, int client, char[] sBuffer, int maxlength)
{
    switch (action)
    {
		case TopMenuAction_DisplayOption:
        {
            FormatEx(sBuffer, maxlength, "Проверить игрока на читы");
        }
		case TopMenuAction_SelectOption:
        {
            Menu_CheckCheats_PlayerChoose(client);
        }
    }
}

char[] GetStatus(int status, bool bType)
{
	char status2[100];
	switch(status)
	{
		case STATUS_WAITDISCORD:
		{
			strcopy(status2, sizeof(status2), !bType ? "Ожидание Discord":"Ожидание Skype");
		}
		case STATUS_WAITCALL:
		{
			strcopy(status2, sizeof(status2), "Ожидание звонка");
		}
		case STATUS_CHECKING:
		{
			strcopy(status2, sizeof(status2), "Проверка на читы");
		}
		case STATUS_RESULT:
		{
			strcopy(status2, sizeof(status2), "Результат проверки");
		}
	}
	return status2;
}

public void OnLibraryRemoved(const char[] szName)
{
    if (StrEqual(szName, "adminmenu"))
    {
        g_hTopMenu = null;
    }
}

/**************************************************************************
 *                             CS:GO COLORS                               *
 *                                                                        *
 *                            Version: 1.6                                *
 **************************************************************************/

#define ZCOLOR 14
static char g_sBuf[2048];

static const char color_t[ZCOLOR][] = {"{DEFAULT}", "{RED}", "{LIGHTPURPLE}", "{GREEN}", "{LIME}", "{LIGHTGREEN}", "{LIGHTRED}", "{GRAY}", "{LIGHTOLIVE}", "{OLIVE}", "{LIGHTBLUE}", "{BLUE}", "{PURPLE}", "{GRAYBLUE}"},
	color_c[ZCOLOR][] = {"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0B", "\x0C", "\x0E", "\x0A"};


public void CGOPrintToChat(int iClient, const char[] message, any ...)
{
	SetGlobalTransTarget(iClient);
	VFormat(g_sBuf, sizeof g_sBuf, message, 3);
	
	int iLastStart = 0, i = 0;
	for(; i < ZCOLOR; i++)
	{
		ReplaceString(g_sBuf, sizeof g_sBuf, color_t[i], color_c[i], false);
	}
	
	i = 0;
	
	while(g_sBuf[i])
	{
		if(g_sBuf[i] == '\n')
		{
			g_sBuf[i] = 0;
			PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
			iLastStart = i+1;
		}
		
		i++;
	}
	
	PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
}

public void CGOPrintToChatAll(const char[] message, any ...)
{
	int iLastStart = 0, i = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++) if(IsClientInGame(iClient) && !IsFakeClient(iClient))
	{
		SetGlobalTransTarget(iClient);
		VFormat(g_sBuf, sizeof g_sBuf, message, 2);
		
		for(i = 0; i < ZCOLOR; i++)
		{
			ReplaceString(g_sBuf, sizeof g_sBuf, color_t[i], color_c[i], false);
		}
		
		iLastStart = 0, i = 0;
		
		while(g_sBuf[i])
		{
			if(g_sBuf[i] == '\n')
			{
				g_sBuf[i] = 0;
				PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
				iLastStart = i+1;
			}
			
			i++;
		}
		
		PrintToChat(iClient, " %s", g_sBuf[iLastStart]);
	}
}
