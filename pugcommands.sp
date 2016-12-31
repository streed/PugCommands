#include <sourcemod>
#include <sdktools>
#include <admin>
#include <timers>

ConVar g_WarmupPause;
ConVar g_RestartGame;
bool readyStatus[MAXPLAYERS + 1];
int readyCount = 0;
bool live = false;
int clientThatPaused;
int requiredReadies = 10;
int requiredReadiesForceStart = 8;
int connectedClients = 0;

public Plugin:myinfo = 
{
	name = "Simple ReadyUP System",
	author = "Bladesmc",
	description = "!ready, !unready, !forcestart",
	version = "1.0",
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
	
	//REGISTER ADMIN COMMANDS
	RegAdminCmd("sm_forcestart", Command_ForceStart, ADMFLAG_CONVARS, "Force match to start without all players.");
	RegAdminCmd("sm_notlive", Command_NotLive, ADMFLAG_CONVARS, "Force warmup.");
	RegAdminCmd("sm_forceunpause", Command_ForceUnpause, ADMFLAG_CONVARS, "Force unpause.");
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
		startMatch();
	}
	return 0;
}


//Start the match my dudes!
public void startMatch()
{
	
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
	
	//Tell them their client ID and Status
	PrintToChat(client, "[BLADESMC] Client id: %d, Ready Status: %b", client, readyStatus[client]);
	
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
	PrintToChat(client, "[BLADESMC] Client id: %d, Ready Status: %b", client, readyStatus[client]);
	
	return Plugin_Continue;
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
	
	startMatch();
	
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
	PrintToChatAll("[BLADESMC] Match has been set to pause during freezetime. Match can only be unpaused by the player that paused the match, or an admin can force-unpause.");
	
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
			ServerCommand("mp_unpause_match");
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
	menu.SetTitle("Force start?");
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
	static int numRestarted = 0;
 
	if (numRestarted >= 3) 
        {
		numRestarted = 0;
		PrintToChatAll("[BLADESMC] LIVE!!!");
		PrintToChatAll("[BLADESMC] LIVE!!!");
		PrintToChatAll("[BLADESMC] LIVE!!!");
		return Plugin_Stop;
	}
 
	g_RestartGame.IntValue = 1;
	numRestarted++;
 
	return Plugin_Continue;
}