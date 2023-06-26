#include <sourcemod>
#include <sdkhooks>
#include <sdktools_functions>
#include <vscript>

#pragma semicolon 1
#pragma newdecls required

#define PURPLECOIN_COUNT 120
#define PURPLECOIN_PATH "purplecoin_coin_"
#define PURPLECOIN_PATH_ENCORE "encore_purplecoin_coin_"
#define MAX_PLAYERS 34

bool g_bOuterWallCoinTransmitEnabled = false;
bool g_bPlayerCoinStatus[MAX_PLAYERS][PURPLECOIN_COUNT];
int g_iCoinIndex[2048] = {-1, ...};

VScriptFunction g_CoinCollectFunction;
VScriptFunction g_CoinResetFunction;

public Plugin myinfo =
{
	name = "Outer Wall Coin Transmit",
	author = "Horiuchi",
	description = "A companion plugin for pf_outerwall that replaces the bonus 6 coin radar with coins that disappear per player",
	version = "1.0",
};

public void OnPluginStart()
{
	char mapName[64];
	GetCurrentMap(mapName, sizeof(mapName));
	CheckIfPluginShouldBeActive(mapName);

	HookEvent("player_spawn", SetVScriptPluginEnabled, EventHookMode_Pre);
	HookEvent("teamplay_round_start", HookCoinTransmit, EventHookMode_Post);

	PrintToServer("Loaded outerwall_cointransmit...");
}

public void SetVScriptPluginEnabled(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bOuterWallCoinTransmitEnabled)
		ServerCommand("script SetTransmitCoinActive = true");
}

public void HookCoinTransmit(Event event, const char[] name, bool dontBroadcast)
{
	int iEnt = 33;
	while((iEnt = FindEntityByClassname(iEnt, "prop_dynamic")) != -1)
	{
		char EntityName[64];
		GetEntPropString(iEnt, Prop_Data, "m_iName", EntityName, sizeof(EntityName));

		if(StrContains(EntityName, PURPLECOIN_PATH) != -1)
		{
			ReplaceString(EntityName, sizeof(EntityName), PURPLECOIN_PATH, "");
			g_iCoinIndex[iEnt] = StringToInt(EntityName) - 1;

			SDKHook(iEnt, SDKHook_SetTransmit, PurpleCoinTransmitCallback);
		}
	}
}

public void OnMapInit(const char[] mapName)
{
	CheckIfPluginShouldBeActive(mapName);
}

void CheckIfPluginShouldBeActive(const char[] mapName)
{
	g_bOuterWallCoinTransmitEnabled = StrContains(mapName, "pf_outerwall") != -1 ? true : false;
	PrintToServer(g_bOuterWallCoinTransmitEnabled ? "Outerwall_cointransmit is now ENABLED." : "Outerwall_cointransmit is now DISABLED.");
}

public MRESReturn Detour_PluginResetPlayerCoinCount(DHookReturn hReturn, DHookParam hParam)
{
	for(int iArrayIndex = 0; iArrayIndex < PURPLECOIN_COUNT; iArrayIndex++)
	{
		g_bPlayerCoinStatus[hParam.Get(1)][iArrayIndex] = true;
	}
	return MRES_Ignored;
}

public MRESReturn Detour_PluginCollectCoin(DHookReturn hReturn, DHookParam hParam)
{
	g_bPlayerCoinStatus[hParam.Get(1)][hParam.Get(2)] = false;
	return MRES_Ignored;
}

public void OnMapStart()
{
	if(!g_bOuterWallCoinTransmitEnabled)
		return;

	g_CoinCollectFunction = VScript_GetGlobalFunction("PluginCollectCoin");
	if(!g_CoinCollectFunction)
	{
		g_CoinCollectFunction = VScript_CreateFunction();
		g_CoinCollectFunction.SetScriptName("PluginCollectCoin");
		g_CoinCollectFunction.SetParam(1, FIELD_INTEGER);
		g_CoinCollectFunction.SetParam(2, FIELD_INTEGER);
		g_CoinCollectFunction.Return = FIELD_FLOAT;
		g_CoinCollectFunction.SetFunctionEmpty();
	}

	g_CoinResetFunction = VScript_GetGlobalFunction("PluginResetPlayerCoinCount");
	if(!g_CoinResetFunction)
	{
		g_CoinResetFunction = VScript_CreateFunction();
		g_CoinResetFunction.SetScriptName("PluginResetPlayerCoinCount");
		g_CoinResetFunction.SetParam(1, FIELD_INTEGER);
		g_CoinResetFunction.Return = FIELD_FLOAT;
		g_CoinResetFunction.SetFunctionEmpty();
	}

	if(!VScript_GetGlobalFunction("PluginCollectCoin"))
		g_CoinCollectFunction.Register();

	if(!VScript_GetGlobalFunction("ResetPlayerCoinCount"))
		g_CoinResetFunction.Register();

	g_CoinCollectFunction.CreateDetour().Enable(Hook_Post, Detour_PluginCollectCoin);

	g_CoinResetFunction.CreateDetour().Enable(Hook_Post, Detour_PluginResetPlayerCoinCount);
}

public Action PurpleCoinTransmitCallback(int iCoin, int iOther)
{
	if(!(0 < iOther <= MaxClients))
		return Plugin_Continue;

	if(!g_bPlayerCoinStatus[iOther][g_iCoinIndex[iCoin]])
		return Plugin_Handled;
	
	return Plugin_Continue;
}