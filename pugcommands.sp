#include <sourcemod>
#include <sdktools>
#include <admin>
#include <timers>
#include <events>

ConVar g_WarmupPause;
ConVar g_RestartGame;
ConVar g_KnifeEnabled;

bool readyStatus[MAXPLAYERS + 1];
int readyCount = 0;
bool live = false;
int clientThatPaused;
int requiredReadies = 10;
int requiredReadiesForceStart = 8;
int connectedClients = 0;
bool knifeRound = false;
int knifeWinner;
bool knifeVote = false;
int knifeVoteStay=0;
int knifeVoteSwitch=0;
bool clientVoteStatus[MAXPLAYERS + 1];
int CS_TEAM_CT = 3;
int CS_TEAM_T = 2;
int knifeCVar;

public Plugin:myinfo = 
{
	name = "Simple ReadyUP System",
	author = "Bladesmc",
	description = "!pughelp",
	version = "1.2",
	url = "steamcommunity.com/groups/weplaygamesgoodyo"
}

public void OnPluginStart()
{
	//REGISTER PLAYER COMMANDS
	/****************************************************
	* 													*
	* 	SIDENOTE: Comment out any lines that defines	*
	* 	a command if that command conflicts with		*
	* 	another command in your server.					*
	* 													*
	****************************************************/
	//READY
	RegConsoleCmd("sm_readyup", Command_Ready, "Ready up.");
	RegConsoleCmd("sm_ready", Command_Ready, "Ready up.");
	RegConsoleCmd("sm_r", Command_Ready, "Ready up.");
	//NOT READY
	RegConsoleCmd("sm_readydown", Command_NotReady, "Not ready.");
	RegConsoleCmd("sm_notready", Command_NotReady, "Not ready.");
	RegConsoleCmd("sm_unready", Command_NotReady, "Not ready.");
	RegConsoleCmd("sm_nr", Command_NotReady, "Not ready.");
	RegConsoleCmd("sm_ur", Command_NotReady, "Not ready.");
	//READY COUNT
	RegConsoleCmd("sm_readycount", Command_ReadyCount, "Print readyCount");
	RegConsoleCmd("sm_rc", Command_ReadyCount, "Print readyCount");
	//STATUS
	RegConsoleCmd("sm_mystatus", Command_MyStatus, "Print player's ready status");
	RegConsoleCmd("sm_ms", Command_MyStatus, "Print player's ready status");
	//HELP
	RegConsoleCmd("sm_pugcommands", Command_PugHelp, "Print pug commands");
	RegConsoleCmd("sm_pughelp", Command_PugHelp, "Print pug commands");
	//PAUSE + UNPAUSE VOTE
	RegConsoleCmd("sm_pause", Command_PauseMatch, "Pause the match.");
	RegConsoleCmd("sm_p", Command_PauseMatch, "Pause the match.");
	RegConsoleCmd("sm_unpause", Command_UnPauseMatch, "Unpause the match.");
	RegConsoleCmd("sm_up", Command_UnPauseMatch, "Unpause the match.");
	RegConsoleCmd("sm_voteunpause", Command_UnpauseVote, "Starts a vote to unpause the match.");
	RegConsoleCmd("sm_vup", Command_UnpauseVote, "Starts a vote to unpause the match.");
	//VOTE START
	RegConsoleCmd("sm_votestart", Command_ForceStartVote, "Starts a vote to begin the match with less than 10 players.");
	RegConsoleCmd("sm_vs", Command_ForceStartVote, "Starts a vote to begin the match with less than 10 players.");
	
	//KNIFEROUND
	RegAdminCmd("sm_kniferound", Command_KnifeRound, ADMFLAG_CONVARS, "Kniferound");
	RegConsoleCmd("sm_stay", Command_VoteStay, "Vote to stay on your side");
	RegConsoleCmd("sm_switch", Command_VoteSwitch, "Vote to switch");
	
	//REGISTER ADMIN COMMANDS
	RegAdminCmd("sm_forcestart", Command_ForceStart, ADMFLAG_CONVARS, "Force match to start without all players.");
	RegAdminCmd("sm_notlive", Command_NotLive, ADMFLAG_CONVARS, "Force warmup.");
	RegAdminCmd("sm_forceunpause", Command_ForceUnpause, ADMFLAG_CONVARS, "Force unpause.");
	
	//HOOKS
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	
	//CONVARS
	g_KnifeEnabled = CreateConVar("pug_kniferound", "1", "0|1 Enables or disables kniferound.");
}

public void handleWarmup()
{
	//FIND CONVARS
	g_WarmupPause = FindConVar("mp_warmup_pausetimer");
	g_RestartGame = FindConVar("mp_restartgame");
	//SET CONVARS
	g_WarmupPause.IntValue = 1;
	
	//START WARMUP
	ServerCommand("mp_warmup_start");
	ServerCommand("bot_kick");
	live = false;
	PrintToChatAll("[BLADESMC] Warmup started.");
}

public int handleReady(bool action) 
{	
	if(live)
	{
		//Match is already live...
		return 0;
	}
	
	//Handle the ready count
	if(action) {
		//TODO: implement ready count
		readyCount++;
	} else if(!action) 
	{
		//TODO: implement unready count
		readyCount--;
	}
	//Print how many players are ready
	PrintToChatAll("[BLADESMC] %d out of %d players ready! (%d required to  start)", readyCount, connectedClients, requiredReadies);
	
	if(readyCount == requiredReadies)
	{
		PrintToChatAll("[BLADESMC] All players are ready!");
		knifeCVar =  g_KnifeEnabled.IntValue;
		PrintToChatAll("pug_kniferound: %d", knifeCVar);
		if(knifeCVar == 1)
		{
			startKnifeRound();
		} else if(knifeCVar == 0)
		{
			startMatch();
		}
	}
	return 0;
}


//Start the match my dudes!
public void startMatch()
{
	ServerCommand("exec gamemode_competitive.cfg");
	ServerCommand("bot_kick");
	//g_WarmupTime.IntValue = 1;
	//g_WarmupPause.IntValue = 0;
	//GO LIVE
	PrintToChatAll("[BLADESMC] LIVE ON 3 RESTARTS!!!");
	PrintToChatAll("[BLADESMC] LIVE ON 3 RESTARTS!!!");
	PrintToChatAll("[BLADESMC] LIVE ON 3 RESTARTS!!!");
	
	ServerCommand("mp_warmup_end");
	CreateTimer(3.0, Timer_LiveOn3, _, TIMER_REPEAT);
	
	/*NOTIFY PLAYERS
	PrintToChatAll("[BLADESMC] LIVE ON 3 RESTARTS!!!");
	PrintToChatAll("[BLADESMC] LIVE ON 3 RESTARTS!!!");
	PrintToChatAll("[BLADESMC] LIVE ON 3 RESTARTS!!!");
	//PrintToChatAll("[BLADESMC] LIVE IN 5 SECONDS!!!");
	*/
	live = true;
}

public void startKnifeRound()
{
	ServerCommand("mp_freezetime 5");
	ServerCommand("mp_t_default_secondary \"\" ");
	ServerCommand("mp_ct_default_secondary \"\" ");
	ServerCommand("mp_give_player_c4 0");
	ServerCommand("mp_buytime 0");
	ServerCommand("mp_maxmoney 0");
	ServerCommand("mp_round_restart_delay 0");
	ServerCommand("mp_warmup_end");
	knifeRound = true;
	PrintToChatAll("[BLADESMC] Knife for sides started!");
}

//KNIFEROUND
public Action Command_KnifeRound(int client, int args)
{
	PrintToChatAll("pug_kniferound: %d", knifeCVar);
	if(knifeCVar == 1)
	{
		startKnifeRound();
	} else if(knifeCVar == 0)
	{
		startMatch();
	}
}

public Action Command_VoteStay(int client, int args)
{
	if(knifeVote && !clientVoteStatus[client])
	{
		int team = GetClientTeam(client);
		if (team == knifeWinner) {
			clientVoteStatus[client] = true;
			knifeVoteStay++;
			PrintToChat(client, "[BLADESMC] You have voted to stay.");
		} else {
			PrintToChat(client, "[BLADESMC] You did not win the kniferound.");
		}
	}
}

public Action Command_VoteSwitch(int client, int args)
{
	if(knifeVote && !clientVoteStatus[client])
	{
		int team = GetClientTeam(client);
		if (team == knifeWinner) {
			clientVoteStatus[client] = true;
			knifeVoteSwitch++;
			PrintToChat(client, "[BLADESMC] You have voted to switch.");
		} else {
			PrintToChat(client, "[BLADESMC] You did not win the kniferound.");
		}
	}
}

//READY
public Action Command_Ready(int client, int args)
{
	if(live)
	{
		//Match is already live...
		PrintToChat(client, "[BLADESMC] The match is already live.");
		return Plugin_Continue;
	}
	
	if(!readyStatus[client])
	{
		//They are not ready, so make them ready
		readyStatus[client] = true;
		handleReady(true);
		PrintToChat(client, "[BLADESMC] You are now ready!");
	} else if(readyStatus[client])
	{
		//They are already ready, so tell them that they are already ready and set readyStatus to True just to be safe
		readyStatus[client] = true;
		PrintToChat(client, "[BLADESMC] You are already ready!");
	} else
	{
		//In case there is some glitch in the system, they must have done !ready so just make them ready anyways
		readyStatus[client] = true;
		PrintToChat(client, "[BLADESMC] You are now ready!");
	}
	
	//Print player info etc
	playerInfo(client);
	
	return Plugin_Continue;
}


//UNREADY
public Action Command_NotReady(int client, int args)
{
	if(live)
	{
		//Match is already live...
		PrintToChat(client, "[BLADESMC] The match is already live.");
		return Plugin_Continue;
		
	}
	
	if(readyStatus[client])
	{
		//They are ready, so make them unready
		readyStatus[client] = false;
		handleReady(false);
		PrintToChat(client, "[BLADESMC] You are no longer ready!");
	} else if(!readyStatus[client])
	{
		//They are already unready. Tell them this
		readyStatus[client] = false;
		PrintToChat(client, "[BLADESMC] You are already not ready!");
	} else
	{
		//Catch any errors by making sure that they are set to unready.
		readyStatus[client] = false;
		PrintToChat(client, "[BLADESMC] You are not ready!");
	}
	//Print player info etc
	playerInfo(client);
	
	return Plugin_Continue;
}

//PRINT  ClientID and ReadyStatus
public void playerInfo(int client)
{
	if(readyStatus[client])
	{
		PrintToChat(client, "[BLADESMC] Client id: %d, Ready Status: ready.", client);
	} else {
		PrintToChat(client, "[BLADESMC] Client id: %d, Ready Status: not ready.", client);
	}
}


//FORCESTART
public Action Command_ForceStart(int client, int args)
{
	if(live)
	{
		//Match is already live...
		PrintToChat(client, "[BLADESMC] The match is already live.");
		return Plugin_Continue;
		
	}
	
	knifeCVar =  g_KnifeEnabled.IntValue;
	PrintToChatAll("pug_kniferound: %d", knifeCVar);
	if(knifeCVar == 1)
	{
		startKnifeRound();
	} else if(knifeCVar == 0)
	{
		startMatch();
	}
		
	return Plugin_Continue;
}

//FORCE WARMUP
public Action Command_NotLive(int client, int args)
{
	handleWarmup();
}

public Action Command_ReadyCount(int client, int args)
{
	if(live)
	{
		//Match is already live...
		PrintToChat(client, "[BLADESMC] The match is already live.");
		return Plugin_Continue;
		
	}
	
	PrintToChatAll("[BLADESMC] There are %d out of %d players ready! (%d required)", readyCount, connectedClients, requiredReadies);
	
	return Plugin_Continue;
}

public Action Command_MyStatus(int client, int args)
{
	if(live)
	{
		//Match is already live...
		PrintToChat(client, "[BLADESMC] The match is already live.");
		return Plugin_Continue;
		
	}
	
	if(readyStatus[client])
	{
		PrintToChat(client, "[BLADESMC] Your ready status is: ready.");
	} else
	{
		PrintToChat(client, "[BLADESMC] Your ready status is: not ready.");
	}
	
	return Plugin_Continue;
}

public Action Command_PugHelp(int client, int args)
{
	PrintToChatAll("[BLADESMC] Ready Status: 0 = unready, 1 = ready");
	PrintToChatAll("[BLADESMC] Available commands are: !ready, !unready, !readycount, !mystatus, !pause, !unpause (if you paused the match), !voteunpause");
	PrintToChatAll("[BLADESMC] Admin commands are: !forcestart, !notlive, !forceunpause");
	
	return Plugin_Continue;
}


public Action Command_PauseMatch(int client, int args)
{
	if(!live)
	{
		//Match is not live
		PrintToChat(client, "[BLADESMC] You cannot do that right now.");
		return Plugin_Handled;
		
	}
	clientThatPaused = client;
	ServerCommand("mp_pause_match");
	PrintToChatAll("[BLADESMC] Match has been set to pause during freezetime. Match can only be unpaused by the player that paused the match, an admin can force-unpause, or players can vote to unpause the match.");
	
	return Plugin_Continue;
}

public Action Command_UnPauseMatch(int client, int args)
{
	//TODO: Implement unpause
	if(!live)
	{
		//Match is already live...
		PrintToChat(client, "[BLADESMC] The match is not live.");
		return Plugin_Handled;
		
	}
	
	if(client == clientThatPaused)
	{
		ServerCommand("mp_unpause_match");
		PrintToChatAll("[BLADESMC] Match has been unpaused!");
		clientThatPaused = 0;
	} else
	{
		PrintToChat(client, "[BLADESMC] You did not pause this match. If the player that paused it refuses to unpause it, then please notify an admin.");
	}
	
	return Plugin_Continue;
}

public Action Command_ForceUnpause(int client, int args)
{
	//TODO: Implement force unpause
	ServerCommand("mp_unpause_match");
	PrintToChatAll("[BLADESMC] Admin has force-unpaused the match!");
}

//UNPAUSE VOTE
public int Handle_UnpauseVoteMenu(Menu menu, MenuAction action, int param1,int param2)
{
	if (action == MenuAction_End)
	{
		/* This is called after VoteEnd */
		delete menu;
	} else if (action == MenuAction_VoteEnd) {
		/* 0=yes, 1=no */
		if (param1 == 0)
		{
			ServerCommand("mp_unpause_match");
			PrintToChatAll("[BLADESMC] Players have voted to unpause the match!");
		} else
		{
			PrintToChatAll("[BLADESMC] Players have voted to remain paused!");
		}
	}
}
 
public Action Command_UnpauseVote(int client, int args)
{
	if(!live)
	{
		//Match is already live...
		PrintToChat(client, "[BLADESMC] The match is not live.");
		return Plugin_Handled;
		
	}
	
	if (IsVoteInProgress())
	{
		return Plugin_Handled;
	}
 
	Menu menu = new Menu(Handle_UnpauseVoteMenu);
	menu.SetTitle("Unpause match?");
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(20);
	
	return Plugin_Handled;
}


//FORCE START VOTE
public int Handle_ForceStartVoteMenu(Menu menu, MenuAction action, int param1,int param2)
{
	if (action == MenuAction_End)
	{
		/* This is called after VoteEnd */
		delete menu;
	} else if (action == MenuAction_VoteEnd) {
		/* 0=yes, 1=no */
		if (param1 == 0)
		{
			knifeCVar = g_KnifeEnabled.IntValue;
			PrintToChatAll("pug_kniferound: %d", knifeCVar);
			if(knifeCVar == 1)
			{
				startKnifeRound();
			} else if(knifeCVar == 0)
			{
				startMatch();
			}
			PrintToChatAll("[BLADESMC] Players have voted to start the match with less than 10 players!");
		} else
		{
			PrintToChatAll("[BLADESMC] Players have voted to wait until there are %d players!", requiredReadies);
		}
	}
}
 
public Action Command_ForceStartVote(int client, int args)
{
	if(live)
	{
		//Match is already live...
		PrintToChat(client, "[BLADESMC] The match is already live.");
		return Plugin_Handled;
		
	} else if(connectedClients < requiredReadiesForceStart)
	{
		PrintToChat(client, "[BLADESMC] There are not enough players to force-start the match!");
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		return Plugin_Handled;
	}
 
	Menu menu = new Menu(Handle_ForceStartVoteMenu);
	menu.SetTitle("Start the match without full teams?");
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	menu.ExitButton = false;
	menu.DisplayVoteToAll(20);
	
	return Plugin_Handled;
}
 
public void OnClientDisconnect(int client)
{
	readyStatus[client] = false;
	connectedClients--;
	PrintToChatAll("There are %d clients in the server.", connectedClients);
}

public void OnClientConnected(int client)
{
	if(connectedClients == 0)
	{
		handleWarmup();
	}
	
	connectedClients++;
	PrintToChatAll("There are %d clients in the server.", connectedClients);
}

public Action Timer_LiveOn3(Handle timer)
{
	// Create a global variable visible only in the local scope (this function).
	static int numRestarted = 1;
 
	if (numRestarted > 3) 
        {
		numRestarted = 0;
		PrintToChatAll("[BLADESMC] LIVE!!!");
		PrintToChatAll("[BLADESMC] LIVE!!!");
		PrintToChatAll("[BLADESMC] LIVE!!!");
		return Plugin_Stop;
	}
	PrintToChatAll("[BLADESMC] Restarting in 1 second. (%d/3)", numRestarted);
	g_RestartGame.IntValue = 1;
	numRestarted++;
 
	return Plugin_Continue;
}

//EVENT_ROUND_END
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	int winner = event.GetInt("winner");
	//PrintToChatAll("%d", winner);
	
	if(knifeRound)
	{
		knifeVote = true;
		if(winner == CS_TEAM_T)
		{
			//T Side won the kniferound
			knifeWinner = CS_TEAM_T;
		} else if(winner == CS_TEAM_CT)
		{
			//CT won the kniferound
			knifeWinner = CS_TEAM_CT;
		}  else
		{
			PrintToChatAll("Could not get kniferound winner...");	
		}
		knifeRound = false;
		
		for (int i = 1; i <= connectedClients; i++) {
			int team = GetClientTeam(i);
			if (team == winner) {
				PrintToChat(i, "[BLADESMC] Your team won the knife round. You have 15 seconds to vote. Type !stay or !switch to cast your vote.");
			}
		}
		ServerCommand("mp_restartgame 15");
		CreateTimer(15.0, Timer_KnifeVote);
	}
}

public void performSideSwap()
{
    for (int i = 1; i <= connectedClients; i++) {
		int team = GetClientTeam(i);
		if (team == CS_TEAM_T) {
			ChangeClientTeam(i, CS_TEAM_CT);
		} else if (team == CS_TEAM_CT) {
			ChangeClientTeam(i, CS_TEAM_T);
		}
	}
}

public Action Timer_KnifeVote(Handle timer)
{
	knifeVote = false;
	knifeRound = false;
	if(knifeVoteStay < knifeVoteSwitch)
	{
		performSideSwap();
	}
	
	knifeVoteStay = 0;
	knifeVoteSwitch = 0;
	
	for(int i = 1; i <= connectedClients;  i++)
	{
		clientVoteStatus[i] = false;
	}
	
	startMatch();
	
	return Plugin_Continue;
}
