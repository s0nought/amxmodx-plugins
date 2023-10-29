/*
* This is a fork of iG_os's (jopmako's) Map Spawns Editor plugin (v 1.0.16) for CS 1.6.
* 
* Changelog: https://github.com/s0nought/amxmodx-plugins/blob/main/map-spawns-editor/CHANGELOG.md
*/

#include <amxmodx>
#include <amxmisc>
#include <engine>

#define REQUIRED_ADMIN_LEVEL ADMIN_BAN // ADMIN_LEVEL_C

#define PLUGIN_NAME "Map Spawns Editor"
#define VERSION     "1.1.0"
#define AUTHOR      "iG_os"

// CS default MDL and SPR
#define T_MDL     "models/player/leet/leet.mdl"
#define CT_MDL    "models/player/gign/gign.mdl"
#define LINE_SPR  "sprites/laserbeam.spr"

#define CHECKTIMER   0.8
#define CHECKTASKID  666
#define RESETENTITYTASKID 777

#define EDIT_CLASSNAME "Map_Spawns_Editor"

new g_sMapName[32]
new g_sAmxMapCommand[40]

new g_Cvar_SafeP2PDist
new g_Cvar_SafeP2WDist
new g_Cvar_RotationAngle
new g_Cvar_ZOffset
new g_Cvar_UnsafeCheck

// store filename
new g_SpawnFile[256], g_DieFile[256], g_EntFile[256]

new g_nMSEMenuID = -1

new bool:g_bSpawnsChanged = false

new bool:g_DeathCheck_end = false
new bool:g_LoadSuccessed = false
new bool:g_LoadInit = false

/*
* 1 - T
* 2 - CT
*/
new g_nActiveEntType = 1

new g_Editing
new g_SpawnT, g_EditT
new g_SpawnCT,g_EditCT
new Laser_Spr
new g_BeamColors[4][3]={{255,0,0},{0,255,0},{200,200,0},{0,0,255}}


public plugin_init()
{
    register_plugin(PLUGIN_NAME, VERSION, AUTHOR)
    register_dictionary("map_spawns_editor.txt")

    g_LoadInit = true // disabled pfn_keyvalue using

    Spawns_Count()
    new sSpawnsInfo[16]
    format(sSpawnsInfo, 15, "T(%d) CT(%d)", g_SpawnT, g_SpawnCT)
    register_cvar("map_spawns", sSpawnsInfo, FCVAR_SERVER) // HLSW

    register_event("TextMsg", "event_restartgame", "a", "2&#Game_C","2&#Game_w")
    register_event("DeathMsg", "event_death", "a")
    register_event("HLTV", "event_newround", "a", "1=0", "2=0")

    register_clcmd("amx_spawn_editor", "editor_onoff", REQUIRED_ADMIN_LEVEL, "- 1/0 switch editor function on/off")
    register_clcmd("amx_mse_menu", "mse_menu", REQUIRED_ADMIN_LEVEL, "Map Spawns Editor menu")

    // min distance between neighbouring points to consider them safe
    g_Cvar_SafeP2PDist = register_cvar("amx_mse_safe_p2p", "100")

    // min distance between a world object and a spawn to consider latter one safe
    g_Cvar_SafeP2WDist = register_cvar("amx_mse_safe_p2w", "40")

    // rotation angle to rotate spawns clockwise and counterclockwise
    g_Cvar_RotationAngle = register_cvar("amx_mse_rotation_angle", "30")

    // Z offset to apply when creating spawns
    g_Cvar_ZOffset = register_cvar("amx_mse_z_offset", "28")

    // a toggle to enable and disable unsafe position check
    g_Cvar_UnsafeCheck = register_cvar("amx_mse_unsafe_check", "1")
}


public editor_onoff(id,level,cid)
{
    if (!cmd_access(id,level,cid,1)) return PLUGIN_HANDLED

    if (g_Editing && g_Editing!=id){
        client_print(id,print_chat,"* %L",id,"MSG_ALREADY_INUSE")
        return PLUGIN_HANDLED
    }

    new arg[2]
    read_argv(1,arg,2)
    if (equal(arg,"1",1) && !g_Editing){
        g_Editing = id
        Clear_AllEdit(0)
        Load_SpawnFlie(0)
        Spawns_To_Edit()
        client_print(0, print_chat, ">> %s - %L", PLUGIN_NAME, id, "ON")
    }else if (equal(arg,"0",1)){
        g_Editing = 0
        Clear_AllEdit(0)
        if (task_exists(id+CHECKTASKID)) remove_task(id+CHECKTASKID)
        client_print(0, print_chat, ">> %s - %L", PLUGIN_NAME, id, "OFF")
    }
    return PLUGIN_HANDLED 
}


stock get_menu_item_info(menu, item)
{
    new iItemInfo, nItemAccessLevel, nItemCallbackID
    new sItemInfo[6], sItemCurText[101]

    menu_item_getinfo(menu, item, nItemAccessLevel, sItemInfo, 5, sItemCurText, 100, nItemCallbackID)

    iItemInfo = str_to_num(sItemInfo)

    return iItemInfo
}


stock play_sound(id, type)
{
    /*
    * type:
    * 1 - success (add)
    * 2 - success (delete)
    * 3 - success (rotate)
    * 4 - success (file system)
    * 5-9 - reserved
    * 10 - failure (any)
    */

    switch (type)
    {
        case 1:
        {
            client_cmd(id, "spk buttons/button9")
        }
        case 2:
        {
            client_cmd(id, "spk buttons/button3")
        }
        case 3:
        {
            client_cmd(id, "spk buttons/blip1")
        }
        case 4:
        {
            client_cmd(id, "spk buttons/blip2")
        }
        case 10:
        {
            client_cmd(id, "spk buttons/button2")
        }
    }

    return 1
}


// Menu 2.0

public mse_menu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED
    }

    if (!g_Editing)
    {
        client_print(id, print_chat, "%L", id, "MSG_FUNCTION_DISABLED")
        return PLUGIN_HANDLED
    }

    if (g_Editing != id)
    {
        client_print(id, print_chat, "%L", id, "MSG_ALREADY_INUSE")
        return PLUGIN_HANDLED
    }

    new sItemText[101]

    // title

    format(sItemText, 100, "%s", PLUGIN_NAME)
    g_nMSEMenuID = menu_create(sItemText, "mse_menu_handler")

    new cbMenu = menu_makecallback("mse_menu_callback")

    // menu_addblank's cause problems, I'm going with ^n for vertical spacers

    // page 1

    menu_additem(g_nMSEMenuID, "[Spawns Count]", "1", 0, cbMenu)
    menu_additem(g_nMSEMenuID, "[Spawn Type]^n", "2", 0, cbMenu)

    format(sItemText, 100, "%L^n", id, "MENU_ADD")
    menu_additem(g_nMSEMenuID, sItemText, "3", 0, cbMenu)

    format(sItemText, 100, "%L", id, "MENU_ROTATE_COUNTERCLOCKWISE")
    menu_additem(g_nMSEMenuID, sItemText, "4", 0, -1)

    format(sItemText, 100, "%L^n", id, "MENU_ROTATE_CLOCKWISE")
    menu_additem(g_nMSEMenuID, sItemText, "5", 0, -1)

    format(sItemText, 100, "%L^n", id, "MENU_DELETE")
    menu_additem(g_nMSEMenuID, sItemText, "6", 0, cbMenu)

    menu_additem(g_nMSEMenuID, "[Save Spawns to File]", "7", 0, cbMenu)

    // page 2

    menu_additem(g_nMSEMenuID, "[Spawns Count]", "8", 0, cbMenu)
    menu_additem(g_nMSEMenuID, "[Spawn Type]^n", "9", 0, cbMenu)

    format(sItemText, 100, "%L^n", id, "MENU_DELETE_ALL")
    menu_additem(g_nMSEMenuID, sItemText, "10", 0, cbMenu)

    format(sItemText, 100, "\r%L", id, "MENU_DELETE_CONFIG")
    menu_additem(g_nMSEMenuID, sItemText, "11", 0, -1)
    format(sItemText, 100, "\y%L^n", id, "MENU_EXPORT_ENT")
    menu_additem(g_nMSEMenuID, sItemText, "12", 0, -1)

    format(sItemText, 100, "%L^n", id, "MENU_MIRROR")
    menu_additem(g_nMSEMenuID, sItemText, "13", 0, -1)

    format(sItemText, 100, "%s^n", g_sAmxMapCommand)
    menu_additem(g_nMSEMenuID, sItemText, "14", 0, -1)

    // controls

    format(sItemText, 100, "\r%L", id, "MENU_EXIT")
    menu_setprop(g_nMSEMenuID, MPROP_EXITNAME, sItemText)
    format(sItemText, 100, "\y%L", id, "MENU_NEXT")
    menu_setprop(g_nMSEMenuID, MPROP_NEXTNAME, sItemText)
    format(sItemText, 100, "\y%L", id, "MENU_BACK")
    menu_setprop(g_nMSEMenuID, MPROP_BACKNAME, sItemText)
    menu_setprop(g_nMSEMenuID, MPROP_EXIT, MEXIT_ALL)

    menu_display(id, g_nMSEMenuID, 0)

    set_task(CHECKTIMER, "check_Task", id + CHECKTASKID, _, _, "b")

    return PLUGIN_HANDLED
}


public mse_menu_callback(id, menu, item)
{
    if (item < 0)
    {
        return PLUGIN_CONTINUE
    }

    new sItemNewText[101]

    new iItemInfo = get_menu_item_info(menu, item)

    if (iItemInfo == 1 || iItemInfo == 8)
    {
        format(sItemNewText, 100, "\wT: %d -> \y%d\w | CT: %d -> \y%d\w", g_SpawnT, g_EditT, g_SpawnCT, g_EditCT)

        menu_item_setname(menu, item, sItemNewText)

        return ITEM_DISABLED
    }
    else if (iItemInfo == 2 || iItemInfo == 9)
    {
        new sEntType[4]

        switch (g_nActiveEntType)
        {
            case 1:
            {
                copy(sEntType, 4, "T")
            }
            case 2:
            {
                copy(sEntType, 4, "CT")
            }
        }

        format(sItemNewText, 100, "%s^n", sEntType)

        menu_item_setname(menu, item, sItemNewText)
    }
    else if (iItemInfo == 7)
    {
        if (g_bSpawnsChanged)
        {
            format(sItemNewText, 100, "\r%L^n", id, "MENU_SAVE")

            menu_item_setname(menu, 6, sItemNewText)
        }
        else
        {
            format(sItemNewText, 100, "\y%L^n", id, "MENU_SAVE")

            menu_item_setname(menu, 6, sItemNewText)
        }
    }

    return PLUGIN_CONTINUE
}


public mse_menu_handler(id, menu, item)
{
    if (item == MENU_EXIT || !g_Editing)
    {
        if (task_exists(id + CHECKTASKID))
        {
            remove_task(id + CHECKTASKID)
        }

        menu_destroy(g_nMSEMenuID)

        return PLUGIN_HANDLED
    }

    new iRotationAngle = get_pcvar_num(g_Cvar_RotationAngle)
    new iZOffset = get_pcvar_num(g_Cvar_ZOffset)
    new iUnsafeCheck = get_pcvar_num(g_Cvar_UnsafeCheck)

    new iItemInfo = get_menu_item_info(menu, item)

    switch (iItemInfo)
    {
        case 2:
        {
            g_nActiveEntType++

            if (g_nActiveEntType > 2)
            {
                g_nActiveEntType = 1
            }
        }
        case 3:
        {
            if (iUnsafeCheck && !SafeRangeCheck(id, iZOffset))
            {
                play_sound(id, 10)

                client_print(0, print_chat, ">> %L", id, "MSG_CHECK_FAULT")
            }
            else
            {
                switch (g_nActiveEntType)
                {
                    case 1:
                    {
                        if (CreateEditEntity(1, id, iZOffset) == 1)
                        {
                            g_bSpawnsChanged = true

                            g_EditT++

                            client_print(0, print_chat, ">> %L", id, "MSG_ADD_SPAWN", "T")
                        }
                    }
                    case 2:
                    {
                        if (CreateEditEntity(2, id, iZOffset) == 2)
                        {
                            g_bSpawnsChanged = true

                            g_EditCT++

                            client_print(0, print_chat, ">> %L", id, "MSG_ADD_SPAWN", "CT")
                        }
                    }
                }

                play_sound(id, 1)
            }
        }
        case 4:
        {
            new entity = Get_Edit_Point_By_Aim(id)

            if (entity && is_valid_ent(entity))
            {
                g_bSpawnsChanged = true

                Entity_Turn_angle(entity, iRotationAngle)

                play_sound(id, 3)
            }
            else
            {
                play_sound(id, 10)

                client_print(0, print_chat, ">> %L", id, "ERROR_POINT_NOTFOUND")
            }
        }
        case 5:
        {
            new entity = Get_Edit_Point_By_Aim(id)

            if (entity && is_valid_ent(entity))
            {
                g_bSpawnsChanged = true

                Entity_Turn_angle(entity, iRotationAngle * -1)

                play_sound(id, 3)
            }
            else
            {
                play_sound(id, 10)

                client_print(0, print_chat, ">> %L", id, "ERROR_POINT_NOTFOUND")
            }
        }
        case 6:
        {
            new entity = Get_Edit_Point_By_Aim(id)

            if (entity && is_valid_ent(entity))
            {
                new team = entity_get_int(entity, EV_INT_iuser2)

                remove_entity(entity)

                play_sound(id, 2)

                if (team == 1)
                {
                    g_bSpawnsChanged = true

                    g_EditT--

                    client_print(0, print_chat, ">> %L", id, "MSG_CLEAR_SPAWN", "T")
                }
                else if (team == 2)
                {
                    g_bSpawnsChanged = true

                    g_EditCT--

                    client_print(0, print_chat, ">> %L", id, "MSG_CLEAR_SPAWN", "CT")
                }
            }
            else
            {
                play_sound(id, 10)

                client_print(0, print_chat, ">> %L", id, "ERROR_POINT_NOTFOUND")
            }
        }
        case 7:
        {
            if (Save_SpawnsFile(1))
            {
                g_bSpawnsChanged = false

                Load_SpawnFlie(0)

                play_sound(id, 4)

                client_print(0, print_chat, ">> %L (T=%d,CT=%d)", id, "MSG_SAVE_SPAWNS_FILE", g_EditT, g_EditCT)
            }
            else
            {
                client_print(0, print_chat, ">> %L", id, "ERROR_SAVE_SPAWNS_FILE")
            }
        }
        case 9:
        {
            g_nActiveEntType++

            if (g_nActiveEntType > 2)
            {
                g_nActiveEntType = 1
            }
        }
        case 10:
        {
            Clear_AllEdit(g_nActiveEntType)

            g_bSpawnsChanged = true

            play_sound(id, 4)

            switch (g_nActiveEntType)
            {
                case 1:
                {
                    client_print(0, print_chat, ">> %L", id, "MENU_CLEAR_ALL_T_SPAWNS")
                }
                case 2:
                {
                    client_print(0, print_chat, ">> %L", id, "MENU_CLEAR_ALL_CT_SPAWNS")
                }
            }
        }
        case 11:
        {
            if (file_exists(g_SpawnFile))
            {
                delete_file(g_SpawnFile)

                play_sound(id, 4)

                client_print(0, print_chat, ">> %L", id, "MSG_DEL_SPAWNSFILE")
            }
        }
        case 12:
        {
            if (Export_RipentFormatFile())
            {
                play_sound(id, 4)

                client_print(0, print_chat, ">> %L [%s] (T=%d,CT=%d)", id, "MSG_EXPORT_SPAWNS_FILE", g_EntFile, g_EditT, g_EditCT)
            }
        }
        case 13:
        {
            Save_SpawnsFile(3)

            server_cmd(g_sAmxMapCommand)
        }
        case 14:
        {
            server_cmd(g_sAmxMapCommand)
        }
    }

    // stay on the first page
    if (iItemInfo >= 1 && iItemInfo <= 7)
    {
        menu_display(id, g_nMSEMenuID, 0)
    }
    // stay on the second page
    else if (iItemInfo >= 8 && iItemInfo <= 12)
    {
        menu_display(id, g_nMSEMenuID, 1)
    }

    return PLUGIN_CONTINUE
}


public plugin_precache()
{
    new configdir[128]
    get_configsdir(configdir, 127 )
    new spawndir[256]
    format(spawndir,255,"%s/spawns",configdir)
    if (!dir_exists(spawndir)){
        if (mkdir(spawndir)==0){ // Create a dir,if it's not exist
            log_amx("Create [%s] dir successfully finished.",spawndir)
        }else{
            log_error(AMX_ERR_NOTFOUND,"Couldn't create [%s] dir,plugin stoped.",spawndir)
            pause("ad")
            return PLUGIN_CONTINUE
        }
    }

    precache_model(T_MDL)
    precache_model(CT_MDL)
    Laser_Spr = precache_model(LINE_SPR)

    get_mapname(g_sMapName, 31)

    format(g_sAmxMapCommand, 39, "amx_map %s", g_sMapName)

    //store spawns point data in this file
    format(g_SpawnFile, 255, "%s/%s_spawns.cfg",spawndir, g_sMapName)
    //when restart game some bad spawn point will make user die,store data in this file,it's useful.
    format(g_DieFile, 255, "%s/%s_spawns_die.cfg",spawndir, g_sMapName)
    //export spawns data to this file for ripent.exe format,it's useful for import to bsp for ripent.exe
    format(g_EntFile, 255, "%s/%s_ent.txt",spawndir, g_sMapName)

    if (Load_SpawnFlie(1)) //load spawn file and create player spawn points
        g_LoadSuccessed = true
    else
        g_LoadSuccessed = false

    return PLUGIN_CONTINUE
}


//load spawns from file, Return 0 when didn't load anything.
stock Load_SpawnFlie(type) //createEntity = 1 create an entity when load a point
{
    if (file_exists(g_SpawnFile))
    {
        new ent_T, ent_CT
        new Data[128], len, line = 0
        new team[8], p_origin[3][8], p_angles[3][8]
        new Float:origin[3], Float:angles[3]

        while((line = read_file(g_SpawnFile , line , Data , 127 , len) ) != 0 ) 
        {
            if (strlen(Data)<2) continue

            parse(Data, team,7, p_origin[0],7, p_origin[1],7, p_origin[2],7, p_angles[0],7, p_angles[1],7, p_angles[2],7)
            
            origin[0] = str_to_float(p_origin[0]); origin[1] = str_to_float(p_origin[1]); origin[2] = str_to_float(p_origin[2]);
            angles[0] = str_to_float(p_angles[0]); angles[1] = str_to_float(p_angles[1]); angles[2] = str_to_float(p_angles[2]);

            if (equali(team,"T")){
                if (type==1) ent_T = create_entity("info_player_deathmatch")
                else ent_T = find_ent_by_class(ent_T, "info_player_deathmatch")
                if (ent_T>0){
                    entity_set_int(ent_T,EV_INT_iuser1,1) // mark that create by map spawns editor
                    entity_set_origin(ent_T,origin)
                    entity_set_vector(ent_T, EV_VEC_angles, angles)
                }
            }
            else if (equali(team,"CT")){
                if (type==1) ent_CT = create_entity("info_player_start")
                else ent_CT = find_ent_by_class(ent_CT, "info_player_start")
                if (ent_CT>0){
                    entity_set_int(ent_CT,EV_INT_iuser1,1) // mark that create by map spawns editor
                    entity_set_origin(ent_CT,origin)
                    entity_set_vector(ent_CT, EV_VEC_angles, angles)
                }
            }
        }
        return 1
    }
    return 0
}


// pfn_keyvalue..Execure after plugin_precache and before plugin_init
public pfn_keyvalue(entid)
{  // when load custom spawns file successed,we are del all spawns by map originate create
    if (g_LoadSuccessed && !g_LoadInit){
        new classname[32], key[32], value[32]
        copy_keyvalue(classname, 31, key, 31, value, 31)

        if (equal(classname, "info_player_deathmatch") || equal(classname, "info_player_start")){
            if (is_valid_ent(entid) && entity_get_int(entid,EV_INT_iuser1)!=1) //filter out custom spawns
                remove_entity(entid)
        }
    }
    return PLUGIN_CONTINUE
}


public event_restartgame()
{
    if (g_Editing && file_exists(g_DieFile))
        delete_file(g_DieFile)

    g_DeathCheck_end = false

    if (g_Editing){
        Clear_AllEdit(0)
        Load_SpawnFlie(0)
        Spawns_To_Edit()
    }
    return PLUGIN_CONTINUE
}


// Remove & save bad spawn point where force user die.
public event_death()
{
    if (!g_DeathCheck_end){
        new string[12]
        read_data(4,string,11)
        if (equal(string,"worldspawn")){
            new id = read_data(2)
            if (g_Editing){
                new entList[1],team
                find_sphere_class(id,EDIT_CLASSNAME, 30.0, entList, 1)
                if (entList[0]){
                    team = entity_get_int(entList[0],EV_INT_iuser2) // team mark
                    if (team==1){
                        client_print(0,print_chat,">> %L",id,"MSG_AUTO_REMOVE_SPAWN","T")
                        g_EditT--
                    }else{
                        client_print(0,print_chat,">> %L",id,"MSG_AUTO_REMOVE_SPAWN","CT")
                        g_EditCT--
                    }
                    remove_entity(entList[0])
                    return PLUGIN_CONTINUE
                }
            }else{
                new team = get_user_team(id)
                if (team==1) Point_WriteToFlie(g_DieFile,1,id,1)
                else if (team==2) Point_WriteToFlie(g_DieFile,2,id,1)
            }
        }
    }
    return PLUGIN_CONTINUE
}


public event_newround()
    set_task(3.0,"deathCheck_end")


public deathCheck_end()
    g_DeathCheck_end = true


// create a edit point
stock CreateEditEntity(team,iEnt,offset)
{
    new Float:fOrigin[3],Float:fAngles[3]
    entity_get_vector(iEnt, EV_VEC_origin, fOrigin)
    entity_get_vector(iEnt, EV_VEC_angles, fAngles)
    fOrigin[2] += float(offset) //offset Z

    new entity = create_entity("info_target")
    if (entity){
        entity_set_string(entity, EV_SZ_classname, EDIT_CLASSNAME)
        entity_set_model(entity,(team==1) ? T_MDL:CT_MDL)
        entity_set_origin(entity, fOrigin)
        entity_set_vector(entity, EV_VEC_angles, fAngles)
        entity_set_int(entity, EV_INT_sequence, 4)
        entity_set_int(entity,EV_INT_iuser2,team) // team mark
        return team
    }
    return 0
}


// clear up all edit points
stock Clear_AllEdit(team){
    new entity
    switch (team){
        case 0:{
            while ((entity = find_ent_by_class(entity, EDIT_CLASSNAME)))
                remove_entity(entity)
            g_EditT = 0
            g_EditCT = 0
        }
        case 1:{
            while ((entity = find_ent_by_class(entity, EDIT_CLASSNAME)))
                if (entity_get_int(entity,EV_INT_iuser2)==1)
                    remove_entity(entity)
            g_EditT = 0
        }
        case 2:{
            while ((entity = find_ent_by_class(entity, EDIT_CLASSNAME)))
                if (entity_get_int(entity,EV_INT_iuser2)==2)
                    remove_entity(entity)
            g_EditCT = 0
        }
    }
}


// convert origin spawns to edit points
stock Spawns_To_Edit()
{
    new entity
    g_EditT = 0
    while ((entity = find_ent_by_class(entity, "info_player_deathmatch"))){
        CreateEditEntity(1,entity,0)
        g_EditT++
    }
    entity = 0
    g_EditCT = 0
    while ((entity = find_ent_by_class(entity, "info_player_start"))){
        CreateEditEntity(2,entity,0)
        g_EditCT++
    }
}


stock Spawns_Count()
{
    new entity
    g_SpawnT = 0
    while ((entity = find_ent_by_class(entity, "info_player_deathmatch")))
        g_SpawnT++

    entity = 0
    g_SpawnCT = 0
    while ((entity = find_ent_by_class(entity, "info_player_start")))
        g_SpawnCT++
}

public check_Task(taskid){
    new iZOffset = get_pcvar_num(g_Cvar_ZOffset)

    SafeRangeCheck(taskid - CHECKTASKID, iZOffset)

    Get_Edit_Point_By_Aim(taskid - CHECKTASKID)
}


// reset entity sequence
public reset_entity_stats(param){
    new entity = param - RESETENTITYTASKID
    if (is_valid_ent(entity)){
        entity_set_float(entity, EV_FL_animtime, 0.0)
        entity_set_float(entity, EV_FL_framerate, 0.0)
        entity_set_int(entity, EV_INT_sequence, 4)
    }
}


// set entity vangle[1]+turn
stock Entity_Turn_angle(entity,turn){
    if (is_valid_ent(entity)){
        new Float:fAngles[3]
        entity_get_vector(entity, EV_VEC_angles, fAngles)
        fAngles[1] += turn
        if (fAngles[1]>=360) fAngles[1] -= 360
        if (fAngles[1]<0) fAngles[1] += 360
        entity_set_vector(entity, EV_VEC_angles, fAngles)
    }
}


// check edit point or wall distance to id
stock SafeRangeCheck(id,offset)
{
    new safepostion = 1
    new Float:fOrigin[3],Float:fAngles[3],Float:inFrontPoint[3],Float:HitPoint[3]
    entity_get_vector(id, EV_VEC_origin, fOrigin)
    fOrigin[2] += offset // hight offset,same as Edit Point offset
    entity_get_vector(id, EV_VEC_angles, fAngles)

    new iSafeP2W = get_pcvar_num(g_Cvar_SafeP2WDist)

    for (new i=0;i<360;i+=10)
    {
        fAngles[1] = float(i)
        // get the id infront point for trace_line
        Vector_By_Angle(fOrigin,fAngles, iSafeP2W * 2.0, 1, inFrontPoint)

        // check id nearby wall
        trace_line(-1,fOrigin,inFrontPoint,HitPoint)
        new distance = floatround(vector_distance(fOrigin, HitPoint))

        if (distance < iSafeP2W){ // unsafe distance to wall
            Make_TE_BEAMPOINTS(id,0,fOrigin,HitPoint,2,255)
            safepostion = 0
        }
        else if (distance < iSafeP2W * 1.5)
            Make_TE_BEAMPOINTS(id,2,fOrigin,HitPoint,2,255)
    }

    // check id nearby Edit Points
    new entList[10],Float:vDistance
    new Float:entity_origin[3]
    new iSafeP2P = get_pcvar_num(g_Cvar_SafeP2PDist)

    find_sphere_class(0,EDIT_CLASSNAME, iSafeP2P * 1.5, entList, 9, fOrigin)

    for(new i=0;i<10;i++){
        if (entList[i]){
            entity_get_vector(entList[i], EV_VEC_origin, entity_origin)
            vDistance = vector_distance(fOrigin,entity_origin)
            if (vDistance < iSafeP2P){ // unsafe location to Edit Points
                Make_TE_BEAMPOINTS(id,0,fOrigin,entity_origin,5,255)
                entity_set_int(entList[i], EV_INT_sequence, 64)
                safepostion = 0
                if (task_exists(entList[i]+RESETENTITYTASKID)) 
                    remove_task(entList[i]+RESETENTITYTASKID)
                set_task(CHECKTIMER+0.1,"reset_entity_stats",entList[i]+RESETENTITYTASKID)
            } else Make_TE_BEAMPOINTS(id,1,fOrigin,entity_origin,5,255)
        }
    }

    return safepostion
}


stock Get_Edit_Point_By_Aim(id)
{
    new entList[1],team
    new Float:fOrigin[3],Float:vAngles[3],Float:vecReturn[3]
    entity_get_vector(id, EV_VEC_origin, fOrigin)
    fOrigin[2] += 10 // offset Z of id
    entity_get_vector(id, EV_VEC_v_angle, vAngles)

    for(new Float:i=0.0;i<=1000.0;i+=20.0)
    {
        Vector_By_Angle(fOrigin,vAngles,i,1,vecReturn)

        find_sphere_class(0,EDIT_CLASSNAME, 20.0, entList, 1, vecReturn)
        if (entList[0]){
            // let entity have anim.
            entity_set_float(entList[0], EV_FL_animtime, 1.0)
            entity_set_float(entList[0], EV_FL_framerate, 1.0)
            team = entity_get_int(entList[0],EV_INT_iuser2)
            client_print(id,print_center,"%L #%d",id,"MSG_AIM_SPAWN",(team==1) ? "T":"CT",entList[0])
            if (task_exists(entList[0]+RESETENTITYTASKID)) 
                remove_task(entList[0]+RESETENTITYTASKID)
            set_task(CHECKTIMER+0.1,"reset_entity_stats",entList[0]+RESETENTITYTASKID)
            break
        }
    }
    return entList[0] // return entity if be found
}


/* FRU define in vector.inc
#define ANGLEVECTOR_FORWARD      1
#define ANGLEVECTOR_RIGHT        2
#define ANGLEVECTOR_UP           3
*/
stock Vector_By_Angle(Float:fOrigin[3],Float:vAngles[3], Float:multiplier, FRU, Float:vecReturn[3])
{
    angle_vector(vAngles, FRU, vecReturn)
    vecReturn[0] = vecReturn[0] * multiplier + fOrigin[0]
    vecReturn[1] = vecReturn[1] * multiplier + fOrigin[1]
    vecReturn[2] = vecReturn[2] * multiplier + fOrigin[2]
}


// draw laserBeam
stock Make_TE_BEAMPOINTS(id,color,Float:Vec1[3],Float:Vec2[3],width,brightness){
    message_begin(MSG_ONE_UNRELIABLE ,SVC_TEMPENTITY,{0,0,0},id)
    write_byte(TE_BEAMPOINTS) // TE_BEAMPOINTS = 0
    write_coord(floatround(Vec1[0])) // start position
    write_coord(floatround(Vec1[1]))
    write_coord(floatround(Vec1[2]))
    write_coord(floatround(Vec2[0])) // end position
    write_coord(floatround(Vec2[1]))
    write_coord(floatround(Vec2[2]))
    write_short(Laser_Spr) // sprite index
    write_byte(1) // starting frame
    write_byte(0) // frame rate in 0.1's
    write_byte(4) // life in 0.1's
    write_byte(width) // line width in 0.1's
    write_byte(0) // noise amplitude in 0.01's
    write_byte(g_BeamColors[color][0])
    write_byte(g_BeamColors[color][1])
    write_byte(g_BeamColors[color][2])
    write_byte(brightness) // brightness)
    write_byte(0) // scroll speed in 0.1's
    message_end()
}


stock Save_SpawnsFile(saveformat)
{
    if (file_exists(g_SpawnFile))
    {
        delete_file(g_SpawnFile)
    }

    new line[128]

    format(line, 127, "/* %s T=%d,CT=%d */ Map Spawns Editor Format File", g_sMapName, g_EditT, g_EditCT)

    write_file(g_SpawnFile, line, -1)

    new entity, team

    while ((entity = find_ent_by_class(entity, EDIT_CLASSNAME)))
    {
        team = entity_get_int(entity, EV_INT_iuser2)

        Point_WriteToFlie(g_SpawnFile, team, entity, saveformat)
    }

    return 1
}


stock Export_RipentFormatFile()
{
    if (file_exists(g_EntFile))
        delete_file(g_EntFile)

    new entity,team
    while ((entity = find_ent_by_class(entity, EDIT_CLASSNAME))){
        team = entity_get_int(entity,EV_INT_iuser2)
        Point_WriteToFlie(g_EntFile,team,entity,2)
    }
    return 1
}


// store one entity data to file
stock Point_WriteToFlie(Flie[],team,entity,saveformat)
{
    new line[128],sTeam[32]
    new nOrigin[3],nAngles[3]
    new Float:fOrigin[3],Float:fAngles[3]

    entity_get_vector(entity, EV_VEC_origin, fOrigin)
    entity_get_vector(entity, EV_VEC_angles, fAngles)
    FVecIVec(fOrigin,nOrigin)
    FVecIVec(fAngles,nAngles)
    if (nAngles[1]>=360) nAngles[1] -= 360
    if (nAngles[1]<0) nAngles[1] += 360

    if (saveformat==1){ // write for plugin using format
        if (team==1) sTeam = "T"
        else sTeam = "CT"
        format(line, 127, "%s %d %d %d %d %d %d", sTeam, nOrigin[0], nOrigin[1], nOrigin[2], 0, nAngles[1], 0)
        write_file(Flie, line, -1)
    }
    else if (saveformat==2){ // write for ripent.exe format
        if (team==1) sTeam = "info_player_deathmatch"
        else sTeam = "info_player_start"
        format(line, 127,"{^n^"classname^" ^"%s^"",sTeam)
        write_file(Flie, line , -1)
        format(line, 127, "^"origin^" ^"%d %d %d^"", nOrigin[0], nOrigin[1], nOrigin[2])
        write_file(Flie, line, -1)
        format(line, 127, "^"angles^" ^"0 %d 0^"^n}", nAngles[1])
        write_file(Flie, line, -1)
    }
    else if (saveformat == 3) // mirrored
    {
        if (team == 1)
        {
            sTeam = "CT"
        }
        else
        {
            sTeam = "T"
        }

        format(line, 127, "%s %d %d %d %d %d %d", sTeam, nOrigin[0], nOrigin[1], nOrigin[2], 0, nAngles[1], 0)

        write_file(Flie, line, -1)
    }
}
